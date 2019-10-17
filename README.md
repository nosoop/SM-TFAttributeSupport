# TF2 Attribute Extended Support Fixes

Hooks into all sorts of game functions so they work with attributes correctly when they
previously didn't.  This allows other modders to use the game's attributes in previously
unsupported cases, instead of needing their own fixes.

Adds the ability to control:

- Effect radius of Jarate-based entities with blast radius-modifying attributes.
- Pomson / Righteous Bison projectile speeds.
- Pomson / Righteous Bison damage amounts.

## Dependencies

Requires my personal fork of TF2Attributes, which exposes the game's attribute value hooks as
native functions for plugins to use.
