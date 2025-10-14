# SmokeBomb Combo v2

This plugin enhances smoke grenades, allowing them to deal damage and have custom colors. This version (v2) introduces renamed cvars and a new sound feature.

## Features

- **Poison Smoke:** Smoke grenades can deal damage to players inside the smoke cloud.
- **Custom Colors:** Smoke color can be customized based on the team or individual player.
- **Damage Sound:** Plays a coughing sound from players who are taking damage from the smoke, making it audible to nearby players.

## Installation

1. Copy the contents of the `addons` and `cfg` directories to your server's `cstrike` directory.
2. Make sure the sound files (`cough-1.wav` to `cough-4.wav`) are in the `sound/player` directory.

## CVars

- `sm_sbc_enabled` (1/0): Enable or disable the entire plugin.
- `sm_sbc_damage_enabled` (1/0): Enable or disable smoke damage.
- `sm_sbc_damage_amount` (10): Damage dealt per tick.
- `sm_sbc_damage_interval` (1.0): Time in seconds between damage ticks.
- `sm_sbc_teammate_damage` (0/1): Allow smoke to damage teammates.
- `sm_sbc_color_mode` (0/1): Smoke color mode. 0 = Team Colors, 1 = Player-specific colors.
- `sm_sbc_color_t` ("255 0 0"): Smoke color for Terrorists (RGB).
- `sm_sbc_color_ct` ("0 0 255"): Smoke color for Counter-Terrorists (RGB).

## Admin Commands

- `sm_smokecolor <#userid|name> <r> <g> <b> | <disable>`: Sets a custom smoke color for a player.
