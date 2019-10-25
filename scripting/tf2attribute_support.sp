/**
 * TF2 Attribute Extended Support plugin
 * 
 * Certain combinations of attributes and weapons just don't work.  This plugin intends to fix
 * the known problematic combinations so modders can apply game attributes for their own uses.
 */
#pragma semicolon 1
#include <sourcemod>

#include <sdktools>
#include <dhooks>

#pragma newdecls required

#include <tf2attributes>

#define PLUGIN_VERSION "1.0.2"
public Plugin myinfo = {
	name = "[TF2] TF2 Attribute Extended Support",
	author = "nosoop",
	description = "Improves support for game attributes on weapons.",
	version = PLUGIN_VERSION,
	url = "https://github.com/nosoop/SM-TFAttributeSupport"
}

Handle g_DHookBaseEntityGetDamage;
Handle g_DHookGrenadeGetDamageRadius;
Handle g_DHookWeaponGetProjectileSpeed;

enum eTFProjectileOverride {
	Projectile_Bullet = 1,
	Projectile_Rocket = 2,
	Projectile_Pipebomb = 3,
	Projectile_Stickybomb = 4,
	Projectile_Syringe = 5,
	Projectile_Flare = 6,
	Projectile_Arrow = 8,
	Projectile_CrossbowBolt = 11,
	Projectile_EnergyBall = 12,
	Projectile_EnergyRing = 13,
	Projectile_TrainingSticky = 14,
	Projectile_Cannonball = 17,
	Projectile_RescueClaw = 18,
	Projectile_ArrowFestive = 19,
	Projectile_JarFestive = 22,
	Projectile_CrossbowBoltFestive = 23,
	Projectile_JarBread = 24,
	Projectile_JarMilkBread = 25,
	Projectile_GrapplingHook = 26,
}

public void OnPluginStart() {
	Handle hGameConf = LoadGameConfigFile("tf2.attribute_support");
	if (!hGameConf) {
		SetFailState("Failed to load gamedata (tf2.attribute_support).");
	}
	
	g_DHookBaseEntityGetDamage = DHookCreateFromConf(hGameConf, "CBaseEntity::GetDamage()");
	
	g_DHookGrenadeGetDamageRadius = DHookCreateFromConf(hGameConf,
			"CBaseGrenade::GetDamageRadius()");
	
	g_DHookWeaponGetProjectileSpeed = DHookCreateFromConf(hGameConf,
			"CTFWeaponBaseGun::GetProjectileSpeed()");
	
	delete hGameConf;
}

public void OnMapStart() {
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "*")) != -1) {
		if (IsWeaponBaseGun(entity)) {
			HookWeaponBaseGun(entity);
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
	
	if (IsWeaponBaseGun(entity)) {
		HookWeaponBaseGun(entity);
	}
}

static void HookWeaponBaseGun(int entity) {
	DHookEntity(g_DHookWeaponGetProjectileSpeed, true, entity,
				.callback = OnGetProjectileSpeedPost);
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
			speed = 2400.0;
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

/**
 * Kludge to detect CTFWeaponBaseGun-derived entities.
 */
static bool IsWeaponBaseGun(int entity) {
	return HasEntProp(entity, Prop_Data, "CTFWeaponBaseGunZoomOutIn");
}
