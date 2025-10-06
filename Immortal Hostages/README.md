ImmortalHostages (fixed)
=========================

This package contains a safe, reviewed SourceMod plugin to control hostage damage behavior.

Modes (set with `sm_hostages_setmode <mode>`):
- 0 = normal (hostages take damage normally)
- 1 = vulnerable_to_T (only Terrorists can damage hostages)
- 2 = vulnerable_to_CT (only Counter-Terrorists can damage hostages)
- 3 = invulnerable (hostages take no damage from any source)

Installation:
1) Copy `addons/sourcemod/plugins/ImmortalHostages_fixed.smx` to your server's `cstrike/addons/sourcemod/plugins/`.
2) Put `cfg/sourcemod/immortal_hostages.cfg` into `cstrike/cfg/sourcemod/`.
3) Restart server or load plugin via `sm plugins load ImmortalHostages_fixed`.

Admin commands:
- `sm_hostages_setmode <0-3>` — set mode (requires admin rights).
- `sm_hostages_debug <0/1>` — enable debug logging.

Notes:
- The plugin uses SDKHooks and SourceMod; ensure your server has compatible versions.
- Test on a staging server before production.

Files in this package:
- `scripting/ImmortalHostages_fixed.sp` — source
- `addons/sourcemod/plugins/ImmortalHostages_fixed.smx` — compiled binary
- `addons/sourcemod/plugins/ImmortalHostages_fixed_compilation_Journal.txt` — compilation log
- `cfg/sourcemod/immortal_hostages.cfg` — example config

License: adapt as you prefer. Suggested: MIT/ISC.
