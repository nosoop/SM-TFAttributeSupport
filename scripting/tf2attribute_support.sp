/**
 * TF2 Attribute Extended Support plugin
 * 
 * Certain combinations of attributes and weapons just don't work.  This plugin intends to fix
 * the known problematic combinations so modders can apply game attributes for their own uses.
 */
#pragma semicolon 1
#include <sourcemod>

#include <sdktools>
#include <sdkhooks>
#include <dhooks>

#include <stocksoup/memory>
#include <stocksoup/tf/entity_prop_stocks>
#include <stocksoup/tf/tempents_stocks>
#include <stocksoup/tf/weapon>

#pragma newdecls required

#include <tf2attributes>

#define PLUGIN_VERSION "1.4.0"
public Plugin myinfo = {
	name = "[TF2] TF2 Attribute Extended Support",
	author = "nosoop",
	description = "Improves support for game attributes on weapons.",
	version = PLUGIN_VERSION,
	url = "https://github.com/nosoop/SM-TFAttributeSupport"
}

Handle g_DHookBaseEntityGetDamage;
Handle g_DHookWeaponSendAnim;
Handle g_DHookGrenadeGetDamageRadius;
Handle g_DHookWeaponGetProjectileSpeed;
Handle g_DHookWeaponGetInitialAfterburn;
Handle g_DHookFireJar;
Handle g_DHookRocketExplode;

Handle g_DHookPlayerRegenerate;

Handle g_SDKCallBaseWeaponSendAnim;
Handle g_SDKCallIsBaseEntityWeapon;
Handle g_SDKCallGetPlayerShootPosition;
Handle g_SDKCallInitGrenade;
Handle g_SDKCallInternalGetEffectBarRechargeTime;

int voffs_SendWeaponAnim;

#define TF_ITEMDEF_FORCE_A_NATURE                45
#define TF_ITEMDEF_FORCE_A_NATURE_FESTIVE        1078

#define ITEM_METER_CHARGE_OVER_TIME (1 << 0)
#define ITEM_METER_CHARGE_BY_DAMAGE (1 << 1)

enum eTFProjectileOverride {
	Projectile_Bullet = 1,
	Projectile_Rocket = 2,
	Projectile_Pipebomb = 3,
	Projectile_Stickybomb = 4,
	Projectile_Syringe = 5,
	Projectile_Flare = 6,
	Projectile_Jar = 7,
	Projectile_Arrow = 8,
	Projectile_FlameRocket = 9, // late addition?
	Projectile_JarMilk = 10,
	Projectile_CrossbowBolt = 11,
	Projectile_EnergyBall = 12,
	Projectile_EnergyRing = 13,
	Projectile_TrainingSticky = 14,
	Projectile_Cleaver = 15,
	// 16 is not referecned in ::FireProjectile
	Projectile_Cannonball = 17,
	Projectile_RescueClaw = 18,
	Projectile_ArrowFestive = 19,
	Projectile_Spellbook = 20,
	// 21 is not referenced in ::FireProjectile
	Projectile_JarFestive = 22,
	Projectile_CrossbowBoltFestive = 23,
	Projectile_JarBread = 24,
	Projectile_JarMilkBread = 25,
	Projectile_GrapplingHook = 26,
	Projectile_JarGas = 29,
}

public void OnPluginStart() {
	Handle hGameConf = LoadGameConfigFile("tf2.attribute_support");
	if (!hGameConf) {
		SetFailState("Failed to load gamedata (tf2.attribute_support).");
	}
	
	g_DHookBaseEntityGetDamage = DHookCreateFromConf(hGameConf, "CBaseEntity::GetDamage()");
	
	voffs_SendWeaponAnim = GameConfGetOffset(hGameConf, "CBaseCombatWeapon::SendWeaponAnim()");
	g_DHookWeaponSendAnim = DHookCreateFromConf(hGameConf,
			"CBaseCombatWeapon::SendWeaponAnim()");
	
	g_DHookGrenadeGetDamageRadius = DHookCreateFromConf(hGameConf,
			"CBaseGrenade::GetDamageRadius()");
	
	g_DHookWeaponGetInitialAfterburn = DHookCreateFromConf(hGameConf,
			"CTFWeaponBase::GetInitialAfterburnDuration()");
	
	g_DHookWeaponGetProjectileSpeed = DHookCreateFromConf(hGameConf,
			"CTFWeaponBaseGun::GetProjectileSpeed()");
	
	g_DHookFireJar = DHookCreateFromConf(hGameConf, "CTFWeaponBaseGun::FireJar()");
	
	g_DHookRocketExplode = DHookCreateFromConf(hGameConf, "CTFBaseRocket::Explode()");
	
	g_DHookPlayerRegenerate = DHookCreateFromConf(hGameConf, "CTFPlayer::Regenerate()");
	DHookEnableDetour(g_DHookPlayerRegenerate, true, OnPlayerRegeneratePost);
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Virtual,
			"CBaseCombatWeapon::IsBaseCombatWeapon()");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_SDKCallIsBaseEntityWeapon = EndPrepSDKCall();
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Virtual, "CBasePlayer::Weapon_ShootPosition()");
	PrepSDKCall_SetReturnInfo(SDKType_Vector, SDKPass_ByValue);
	g_SDKCallGetPlayerShootPosition = EndPrepSDKCall();
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Virtual,
			"CTFWeaponBaseGrenadeProj::InitGrenade(int float)");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	g_SDKCallInitGrenade = EndPrepSDKCall();
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Virtual,
			"CTFWeaponBase::InternalGetEffectBarRechargeTime()");
	PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);
	g_SDKCallInternalGetEffectBarRechargeTime = EndPrepSDKCall();
	
	delete hGameConf;
	
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i)) {
			OnClientPutInServer(i);
		}
	}
}

public void OnMapStart() {
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "*")) != -1) {
		if (!IsValidEdict(entity)) {
			continue;
		}
		
		if (IsEntityWeapon(entity)) {
			HookWeaponBase(entity);
		}
		if (IsWeaponBaseGun(entity)) {
			char className[64];
			GetEntityClassname(entity, className, sizeof(className));
			HookWeaponBaseGun(entity, className);
		}
	}
	
	// get the address of CTFWeaponBase::SendWeaponAnim() directly
	if (!g_SDKCallBaseWeaponSendAnim) {
		int shotgun = CreateEntityByName("tf_weapon_shotgun_primary");
		
		Address vmt = DereferencePointer(GetEntityAddress(shotgun));
		Address pfnBaseWeaponSendAnim = DereferencePointer(
				vmt + view_as<Address>(4 * voffs_SendWeaponAnim));
		
		RemoveEntity(shotgun);
		
		StartPrepSDKCall(SDKCall_Entity);
		PrepSDKCall_SetAddress(pfnBaseWeaponSendAnim);
		PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		g_SDKCallBaseWeaponSendAnim = EndPrepSDKCall();
		
		if (!g_SDKCallBaseWeaponSendAnim) {
			SetFailState("Failed to determine address of CBaseCombatWeapon::SendWeaponAnim()");
		}
	}
}

public void OnEntityCreated(int entity, const char[] className) {
	if (!IsValidEdict(entity)) {
		return;
	}
	
	if (StrEqual(className, "tf_projectile_energy_ring")) {
		RequestFrame(EnergyRingPostSpawnPost, EntIndexToEntRef(entity));
		
		// this is broken on SM1.10 ??
		DHookEntity(g_DHookBaseEntityGetDamage, true, entity,
				.callback = OnGetEnergyRingDamagePost);
	}
	
	if (strncmp(className, "tf_projectile_jar", strlen("tf_projectile_jar")) == 0) {
		DHookEntity(g_DHookGrenadeGetDamageRadius, true, entity,
				.callback = OnGetGrenadeDamageRadiusPost);
	}
	if (StrEqual(className, "tf_projectile_flare")) {
		DHookEntity(g_DHookRocketExplode, true, entity, .callback = OnRocketExplodePost);
	}
	
	if (IsEntityWeapon(entity)) {
		HookWeaponBase(entity);
	}
	if (IsWeaponBaseGun(entity)) {
		HookWeaponBaseGun(entity, className);
	}
}

public void OnClientPutInServer(int client) {
	SDKHook(client, SDKHook_SpawnPost, OnClientSpawnPost);
	SDKHook(client, SDKHook_OnTakeDamageAlivePost, OnClientTakeDamageAlivePost);
}

/**
 * Called when the player is finished spawning in (e.g. changing classes).
 * Starts regenerating the effect bar on any items with item_meter_resupply_denied set.
 */
void OnClientSpawnPost(int client) {
	for (int i; i < 3; i++) {
		int weapon = GetPlayerWeaponSlot(client, i);
		if (IsValidEntity(weapon)) {
			PostSpawnUnsetItemCharge(weapon);
		}
	}
}

/**
 * Called when a player takes damage.  Attacker gains charge on legacy item meters.
 */
void OnClientTakeDamageAlivePost(int victim, int attacker, int inflictor, float damage,
		int damagetype, int weapon, const float damageForce[3], const float damagePosition[3],
		int damagecustom) {
	if (attacker < 1 || attacker >= MaxClients) {
		return;
	}
	
	// the 'correct' way would be to implement this within `CTFPlayer::OnDamageDealt()`
	for (int i; i < 3; i++) {
		int attackerWeapon = GetPlayerWeaponSlot(attacker, i);
		if (IsValidEntity(attackerWeapon)) {
			ApplyItemChargeDamageModifier(attackerWeapon, damage);
		}
	}
}

/**
 * Called when the player is finished regenerating.
 * Clears ammo granted during regeneration on items with item_meter_resupply_denied set.
 */
MRESReturn OnPlayerRegeneratePost(int client, Handle hParams) {
	bool bRefillHealthAndAmmo = DHookGetParam(hParams, 1);
	if (!bRefillHealthAndAmmo) {
		return;
	}
	
	for (int i; i < 3; i++) {
		int weapon = GetPlayerWeaponSlot(client, i);
		if (IsValidEntity(weapon)) {
			ProcessItemRecharge(weapon);
		}
	}
}

static MRESReturn HookWeaponBase(int entity) {
	DHookEntity(g_DHookWeaponGetInitialAfterburn, true, entity,
			.callback = OnGetInitialAfterburnPost);
}

static void HookWeaponBaseGun(int entity, const char[] className) {
	DHookEntity(g_DHookWeaponGetProjectileSpeed, true, entity,
			.callback = OnGetProjectileSpeedPost);
	
	if (strncmp(className, "tf_weapon_jar", strlen("tf_weapon_jar")) != 0) {
		DHookEntity(g_DHookFireJar, false, entity, .callback = OnFireJarPre);
	}
	
	if (StrEqual(className, "tf_weapon_scattergun")
			|| StrEqual(className, "tf_weapon_soda_popper")) {
		DHookEntity(g_DHookWeaponSendAnim, false, entity, .callback = OnScattergunSendAnimPre);
	}
}

/**
 * Adds "mult_projectile_speed" support on the Pomson and Righteous Bison's energy projectiles.
 * Note that the velocity starts to break down around 3600HU/s (3x speed)
 */
public void EnergyRingPostSpawnPost(int entref) {
	if (!IsValidEntity(entref)) {
		return;
	}
	
	int weapon = GetEntPropEnt(entref, Prop_Send, "m_hOriginalLauncher");
	if (!IsValidEntity(weapon)) {
		return;
	}
	
	float vecVelocity[3];
	GetEntPropVector(entref, Prop_Data, "m_vecAbsVelocity", vecVelocity);
	
	ScaleVector(vecVelocity, TF2Attrib_HookValueFloat(1.0, "mult_projectile_speed", weapon));
	TeleportEntity(entref, NULL_VECTOR, NULL_VECTOR, vecVelocity);
}

/**
 * Prevents a Scattergun-based weapon from using Force-a-Nature animations even if it has the
 * knockback attribute applied, as long as it's not actually a Force-a-Nature.
 */
MRESReturn OnScattergunSendAnimPre(int entity, Handle hReturn, Handle hParams) {
	int activity = DHookGetParam(hParams, 1);
	
	if (!TF2Attrib_HookValueInt(0, "set_scattergun_has_knockback", entity)) {
		return MRES_Ignored;
	}
	
	// dumb hack -- short of using econ data for schema-based markers this will have to do
	switch (GetEntProp(entity, Prop_Send, "m_iItemDefinitionIndex")) {
		case TF_ITEMDEF_FORCE_A_NATURE, TF_ITEMDEF_FORCE_A_NATURE_FESTIVE: {
			return MRES_Ignored;
		}
	}
	
	// bypass the ITEM2 conversion table and call the baseclass's SendWeaponAnim
	DHookSetReturn(hReturn, SendWeaponAnim(entity, activity));
	return MRES_Supercede;
}

/**
 * Adds "mult_dmg" support on the Pomson and Righteous Bison's energy projectiles.
 */
public MRESReturn OnGetEnergyRingDamagePost(int entity, Handle hReturn) {
	int weapon = GetEntPropEnt(entity, Prop_Send, "m_hOriginalLauncher");
	if (!IsValidEntity(weapon)) {
		return MRES_Ignored;
	}
	
	float damage = DHookGetReturn(hReturn);
	DHookSetReturn(hReturn, TF2Attrib_HookValueFloat(damage, "mult_dmg", weapon));
	
	return MRES_Supercede;
}

/**
 * Allows the use of "mult_explosion_radius" to increase the effect radius on Jarate-based
 * entities (Jarate, Mad Milk, Gas Passer).
 */
public MRESReturn OnGetGrenadeDamageRadiusPost(int grenade, Handle hReturn) {
	float radius = DHookGetReturn(hReturn);
	
	int weapon = GetEntPropEnt(grenade, Prop_Send, "m_hOriginalLauncher");
	if (!IsValidEntity(weapon)) {
		return MRES_Ignored;
	}
	
	DHookSetReturn(hReturn, TF2Attrib_HookValueFloat(radius, "mult_explosion_radius", weapon));
	return MRES_Supercede;
}

/**
 * Patches unsupported weapons' projectile speed getters based on "override projectile type"
 */
public MRESReturn OnGetProjectileSpeedPost(int weapon, Handle hReturn) {
	float speed = DHookGetReturn(hReturn);
	
	// TODO how should we deal with items that already have a speed?
	
	switch (TF2Attrib_HookValueInt(0, "override_projectile_type", weapon)) {
		case Projectile_Pipebomb, Projectile_Cannonball: {
			// CTFGrenadeLauncher::GetProjectileSpeed()
			speed = TF2Attrib_HookValueFloat(1200.0, "mult_projectile_speed", weapon);
		}
		case Projectile_Arrow, Projectile_ArrowFestive: {
			// CTFCompoundBow::GetProjectileSpeed()
			// 1800 + (charge * 800);
			speed = 2600.0;
		}
		case Projectile_CrossbowBolt, Projectile_CrossbowBoltFestive, Projectile_RescueClaw: {
			// CTFCrossbow::GetProjectileSpeed()
			// same as Projectile_Arrow but charge = 0.75
			speed = TF2Attrib_HookValueFloat(2400.0, "mult_projectile_speed", weapon);
		}
		case Projectile_EnergyBall: {
			// CTFParticleCannon::GetProjectileSpeed()
			speed = 1100.0;
		}
		case Projectile_EnergyRing: {
			// CTFRaygun::GetProjectileSpeed()
			speed = 1200.0;
		}
		case Projectile_GrapplingHook: {
			// CTFGrapplingHook::GetProjectileSpeed()
			// doesn't include CTFPlayerShared::GetCarryingRuneType() checks
			speed = FindConVar("tf_grapplinghook_projectile_speed").FloatValue;
		}
	}
	
	if (speed) {
		DHookSetReturn(hReturn, speed);
		return MRES_Supercede;
	}
	return MRES_Ignored;
}

MRESReturn OnGetInitialAfterburnPost(int weapon, Handle hReturn) {
	if (DHookGetReturn(hReturn)) {
		return MRES_Ignored;
	}
	float flAfterburn = TF2Attrib_HookValueFloat(0.0, "set_dmgtype_ignite", weapon);
	DHookSetReturn(hReturn, flAfterburn);
	return MRES_Override;
}

MRESReturn OnRocketExplodePost(int rocket, Handle hParams) {
	int owner = TF2_GetEntityOwner(rocket);
	if (0 < owner < MaxClients
			&& TF2Attrib_HookValueInt(0, "use_large_smoke_explosion", owner)) {
		float origin[3], angles[3];
		GetEntPropVector(rocket, Prop_Data, "m_vecAbsOrigin", origin);
		GetEntPropVector(rocket, Prop_Data, "m_angAbsRotation", angles);
		
		TE_SetupTFParticleEffect("explosionTrail_seeds_mvm", origin, .vecAngles = angles);
		TE_SendToAll();
		
		TE_SetupTFParticleEffect("fluidSmokeExpl_ring_mvm", origin, .vecAngles = angles);
		TE_SendToAll();
	}
	return MRES_Ignored;
}

public MRESReturn OnFireJarPre(int weapon, Handle hReturn, Handle hParams) {
	int owner = !DHookIsNullParam(hParams, 1) ?
			DHookGetParam(hParams, 1) : INVALID_ENT_REFERENCE;
	if (owner < 1 || owner > MaxClients) {
		return MRES_Ignored;
	}
	
	char className[64];
	switch (TF2Attrib_HookValueInt(0, "override_projectile_type", weapon)) {
		case Projectile_Jar, Projectile_JarBread, Projectile_JarFestive: {
			className = "tf_projectile_jar";
		}
		case Projectile_JarMilk, Projectile_JarMilkBread: {
			className = "tf_projectile_jar_milk";
		}
		case Projectile_Cleaver: {
			className = "tf_projectile_cleaver";
		}
		case Projectile_JarGas: {
			className = "tf_projectile_jar_gas";
		}
		case Projectile_Spellbook: {
			// not implemented
			return MRES_Ignored;
		}
		default: {
			return MRES_Ignored;
		}
	}
	if (!className[0]) {
		return MRES_Ignored;
	}
	
	float vecSpawnOrigin[3];
	GetPlayerShootPosition(owner, vecSpawnOrigin);
	
	float angEyes[3], vecEyeForward[3], vecEyeRight[3], vecEyeUp[3];
	
	GetClientEyeAngles(owner, angEyes);
	GetAngleVectors(angEyes, vecEyeForward, vecEyeRight, vecEyeUp);
	
	ScaleVector(vecEyeForward, 16.0);
	AddVectors(vecSpawnOrigin, vecEyeForward, vecSpawnOrigin);
	
	// fire projectile from center
	if (!TF2Attrib_HookValueInt(0, "centerfire_projectile", weapon)) {
		ScaleVector(vecEyeRight, 8.0); // TODO check if viewmodels are flipped
		AddVectors(vecSpawnOrigin, vecEyeRight, vecSpawnOrigin);
	}
	
	ScaleVector(vecEyeUp, -6.0);
	AddVectors(vecSpawnOrigin, vecEyeUp, vecSpawnOrigin);
	
	float vecSpawnAngles[3];
	GetEntPropVector(owner, Prop_Data, "m_angAbsRotation", vecSpawnAngles);
	
	GetAngleVectors(angEyes, vecEyeForward, vecEyeRight, vecEyeUp);
	
	float vecVelocity[3];
	vecVelocity = vecEyeForward;
	ScaleVector(vecVelocity, 1200.0);
	ScaleVector(vecEyeUp, 200.0);
	
	AddVectors(vecVelocity, vecEyeUp, vecVelocity);
	
	int jar = CreateEntityByName(className);
	DispatchSpawn(jar);
	TeleportEntity(jar, vecSpawnOrigin, vecSpawnAngles, NULL_VECTOR);
	
	float vecAngVelocity[3];
	vecAngVelocity[0] = 600.0;
	vecAngVelocity[1] = GetRandomFloat(-1200.0, 1200.0);
	
	SDKCall(g_SDKCallInitGrenade, jar, vecVelocity, vecAngVelocity, owner, 0, 3.0);
	SetEntProp(jar, Prop_Data, "m_bIsLive", true);
	
	SetEntPropEnt(jar, Prop_Send, "m_hOriginalLauncher", weapon);
	SetEntPropEnt(jar, Prop_Send, "m_hThrower", owner);
	
	DHookSetReturn(hReturn, false);
	return MRES_Supercede;
}

/**
 * Checks if the given weapon should have their charge meter zeroed out during spawn.
 */
void PostSpawnUnsetItemCharge(int weapon) {
	if (!IsEntityWeapon(weapon)) {
		return;
	} else if (TF2Attrib_HookValueInt(0, "item_meter_resupply_denied", weapon) <= 0) {
		// item charges are only unset during spawn when item_meter_resupply_denied > 0
		// see https://gist.github.com/sigsegv-mvm/43e76b30cedca0717e88988ac9172526
		return;
	} else if (GetEffectBarRechargeTime(weapon) <= 0.0) {
		// this item doesn't use the legacy recharge method (Gas Passer uses a new interface)
		return;
	}
	
	/**
	 * If we have an item that wants to not have their meter filled on spawn, zero out their
	 * ammo.  We also set `m_flLastFireTime` and `m_flEffectBarRegenTime` since both of those
	 * determine how the meter is rendered on the client.
	 */
	float flRechargeTime = GetEffectBarRechargeTime(weapon);
	SetEntPropFloat(weapon, Prop_Send, "m_flEffectBarRegenTime", GetGameTime() + flRechargeTime);
	SetEntPropFloat(weapon, Prop_Send, "m_flLastFireTime", GetGameTime());
	TF2_SetWeaponAmmo(weapon, 0);
}

/**
 * Checks if the given weapon is recharging; if so, prevent ammo bring granted.
 */
void ProcessItemRecharge(int weapon) {
	if (!IsEntityWeapon(weapon)) {
		return;
	} else if (TF2Attrib_HookValueInt(0, "item_meter_resupply_denied", weapon) == 0) {
		// item charges are only unset on resupply when item_meter_resupply_denied != 0
		return;
	} else if (GetEffectBarRechargeTime(weapon) <= 0.0) {
		// this item doesn't use the legacy recharge method (Gas Passer uses a new interface)
		return;
	}
	
	/**
	 * If we have an item that isn't fully charged, unset our ammo count for it; we don't have
	 * to do anything with `m_flEffectBarRegenTime` since it'll only update itself when ammo is
	 * full in a later function call.
	 */
	float flEffectBarRegenTime = GetEntPropFloat(weapon, Prop_Send, "m_flEffectBarRegenTime");
	if (flEffectBarRegenTime > GetGameTime()) {
		// TODO is it possible to have multiple copies of an item for recharge?
		// if so we should reset it to the last known ammo count
		TF2_SetWeaponAmmo(weapon, 0);
	} else if (GetEntPropFloat(weapon, Prop_Send, "m_flLastFireTime") == 0.0) {
		// this weapon appears to have been freshly spawned; force it to recharge
		float flRechargeTime = GetEffectBarRechargeTime(weapon);
		SetEntPropFloat(weapon, Prop_Send, "m_flEffectBarRegenTime", GetGameTime() + flRechargeTime);
		SetEntPropFloat(weapon, Prop_Send, "m_flLastFireTime", GetGameTime());
		TF2_SetWeaponAmmo(weapon, 0);
	}
}

/**
 * Updates recharge time for legacy item meters with both item_meter_charge_type and
 * item_meter_damage_for_full_charge attributes.
 */
void ApplyItemChargeDamageModifier(int weapon, float flDamage) {
	if (!IsEntityWeapon(weapon)) {
		return;
	} else if (TF2Attrib_HookValueInt(0, "item_meter_charge_type", weapon)
			& ITEM_METER_CHARGE_BY_DAMAGE == 0) {
		// item_meter_charge_type is not set to recharge when dealing damage
		return;
	}
	
	float flRechargeTime = GetEffectBarRechargeTime(weapon);
	if (flRechargeTime <= 0.0) {
		// this item doesn't use the legacy recharge method (Gas Passer uses a new interface)
		return;
	}
	
	float flDamageForFullCharge = TF2Attrib_HookValueFloat(0.0,
			"item_meter_damage_for_full_charge", weapon);
	if (flDamageForFullCharge <= 0.0) {
		ThrowError("item_meter_damage_for_full_charge is a non-positive value on entity %d",
				weapon);
		return;
	}
	
	// reduce the amount of time until recharge
	float flCurrentRegenTime = GetEntPropFloat(weapon, Prop_Send, "m_flEffectBarRegenTime");
	flCurrentRegenTime -= (flDamage / flDamageForFullCharge) * flRechargeTime;
	
	SetEntPropFloat(weapon, Prop_Send, "m_flEffectBarRegenTime", flCurrentRegenTime);
}

/**
 * Kludge to detect CTFWeaponBaseGun-derived entities.
 */
static bool IsWeaponBaseGun(int entity) {
	return HasEntProp(entity, Prop_Data, "CTFWeaponBaseGunZoomOutIn");
}

void GetPlayerShootPosition(int client, float vecShootPosition[3]) {
	SDKCall(g_SDKCallGetPlayerShootPosition, client, vecShootPosition);
}

bool SendWeaponAnim(int weapon, int activity) {
	return SDKCall(g_SDKCallBaseWeaponSendAnim, weapon, activity);
}

bool IsEntityWeapon(int entity) {
	return SDKCall(g_SDKCallIsBaseEntityWeapon, entity);
}

float GetEffectBarRechargeTime(int entity) {
	if (!IsEntityWeapon(entity)) {
		ThrowError("Entity %d is not a weapon", entity);
	}
	float flRechargeTime = SDKCall(g_SDKCallInternalGetEffectBarRechargeTime, entity);
	return TF2Attrib_HookValueFloat(flRechargeTime, "effectbar_recharge_rate", entity);
}
