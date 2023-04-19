# TF2 Attribute Extended Support Fixes

Hooks into all sorts of game functions so they work with attributes correctly when they
previously didn't.  This allows other modders to use the game's attributes in previously
unsupported cases, instead of needing their own fixes.

Improves support for, among other things:

- Effect radius of Jarate-based entities with blast radius-modifying attributes.
- Pomson / Righteous Bison projectile speeds and damage amounts.
- Weapons using the `override projectile type` attribute:
  - &hellip; allows players to shoot jar-based projectiles (Jarate, Mad Milk,
  Flying Guillotine, Gas Passer).
  - &hellip; initializing damage radius for grenades spawned by non-grenade launchers.
  - &hellip; now initialize projectiles with the correct speed.
  - &hellip; now spawn projectiles on the correct side, taking into account if the viewmodel is
  flipped internally.
- Scatterguns can now use the Force-a-Nature's `scattergun has knockback` attribute without any
animation quirks.
- Weapons are now able to use `Set DamageType Ignite` again.
  - The attribute value has been reworked to specify an initial burn duration in seconds, which
  must be equal to or greater than 1.
  - Weapons that already support burn durations will retain their default values &mdash; you
  cannot override their durations here (use `weapon burn time *` in those cases).
  - The burn time currently cannot exceed 10 seconds.  The game clamps burn durations to this
  value at ignite time (while there are ways around it, none of them can be implemented
  cleanly).
- Weapons with pre-Jungle Inferno-style recharge meters (Jars, lunch items, Sandman / Wrap
Assassin) are now able to use `item_meter_resupply_denied` to not have their charge meters
filled on spawn and / or resupply.
  - Setting this to a positive number will empty the charge during spawn and on resupply; a
  negative number will allow it to spawn with full charge, but not on resupply.  (This
  replicates the behavior specified in [sigsegv's documentation on item meters][].)
  - Plugins that grant weapons to players after spawn or resupply are likely to not work with
  this attribute.  (Shameless plug:  My own [Custom Weapons X][] has no problem here.)
  - This portion was sponsored by kingofings, who has allowed me to publish it as part of this
  plugin.  Thanks!
- Weapons with pre-Jungle Inferno-style recharge meters (see above) are now able to use
`item_meter_charge_type` and `item_meter_damage_for_full_charge` to gain meter charge when the
owner deals damage.
  - `item_meter_charge_type` must have bit `(1 << 1)` set, per the documentation linked above.
  - This portion was sponsored by G14.  Thanks!
- `bot custom jump particle` can now be used on players in non-MvM mode.
  - This portion was sponsored by @JohnnyAlexanderTF2.  Thanks!
- The delay on being granted triple jumps with the Atomizer now scales with `mult_deploy_time`
and `mult_single_wep_deploy_time`, instead of being set to a fixed 0.7 second delay.
- The addition / removal of player attributes now clears the attribute cache on the player's
equipment.
- The `sniper zoom penalty` attribute that is present but unused in the schema is now
implemented.

## Dependencies

This plugin depends on [TF2Attributes][], which exposes the game's attribute value hooks as
native functions for plugins to use, [TF2Utils][], which provides common gameplay-related
functions for plugins to work with, and [Source Scramble][], which handles patching memory for
certain functions.

[TF2Attributes]: https://github.com/FlaminSarge/tf2attributes
[TF2Utils]: https://github.com/nosoop/SM-TFUtils
[sigsegv's documentation on item meters]: https://gist.github.com/sigsegv-mvm/43e76b30cedca0717e88988ac9172526
[Custom Weapons X]: https://github.com/nosoop/SM-TFCustomWeaponsX
[Source Scramble]: https://github.com/nosoop/SMExt-SourceScramble
