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

## Dependencies

Requires my personal fork of [TF2Attributes][], which exposes the game's attribute value hooks
as native functions for plugins to use.

This also needs the [detour-supporting version of DHooks][dynhooks].

[TF2Attributes]: https://github.com/nosoop/tf2attributes
[dynhooks]: https://forums.alliedmods.net/showpost.php?p=2588686&postcount=589
