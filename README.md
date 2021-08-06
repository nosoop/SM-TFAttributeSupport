# TF2 Attribute Extended Support Fixes

Hooks into all sorts of game functions so they work with attributes correctly when they
previously didn't.  This allows other modders to use the game's attributes in previously
unsupported cases, instead of needing their own fixes.

Improves support for:

- Effect radius of Jarate-based entities with blast radius-modifying attributes.
- Pomson / Righteous Bison projectile speeds and damage amounts.
- Weapons using the `override projectile type` attribute; projectiles are initialized with the
correct speed.
- Improved support for the `override projectile type` attribute, enabling players to shoot
jar-based projectiles (Jarate, Mad Milk, Flying Guillotine, Gas Passer).
- Scatterguns can now use the Force-a-Nature's `scattergun has knockback` attribute without any
animation quirks.
- Weapons are now able to use `Set DamageType Ignite` again.
  - The attribute value has been reworked to specify an initial burn duration in seconds, which
  must be equal to or greater than 1.
  - Weapons that already support burn durations will retain their default values &mdash; you
  cannot override their durations here (use `weapon burn time *` in those cases).
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

## Dependencies

Requires my personal fork of [TF2Attributes][], which exposes the game's attribute value hooks
as native functions for plugins to use.

This also needs the [detour-supporting version of DHooks][dynhooks].

[TF2Attributes]: https://github.com/nosoop/tf2attributes
[dynhooks]: https://forums.alliedmods.net/showpost.php?p=2588686&postcount=589
[sigsegv's documentation on item meters]: https://gist.github.com/sigsegv-mvm/43e76b30cedca0717e88988ac9172526
[Custom Weapons X]: https://github.com/nosoop/SM-TFCustomWeaponsX
