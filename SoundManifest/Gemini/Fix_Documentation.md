# SoundManifest Plugin Fix Documentation

## Investigation Findings

An issue was identified in both the `QWEN` and `Gemini` versions of the `SoundManifest-V3.2.sp` plugin where dynamic text, such as player names, was not being displayed correctly in chat and HUD messages.

The root cause was the incorrect use of `FormatEx` to pre-format translation strings. The `FormatEx` function does not correctly process phrase formatting tokens (like `{1}`, `{2}`) when they are nested inside a translation fetched via the `%t` specifier.

## Forking and Fix Implementation

To preserve the styling and configuration improvements made in the `QWEN` version (specifically regarding `SoundManifestConfuguration.ini` and the translation files), a fork of the plugin was created.

The file `SoundManifest\QWEN\cstrike\addons\sourcemod\scripting\SoundManifest-V3.2.sp` was copied to `SoundManifest\Gemini\cstrike\addons\sourcemod\scripting\SoundManifest-V3.2.sp`.

The following fixes were then applied to the new version in the `Gemini` directory:

### Chat Message Fix (`ShowMessageToAudience`)

The `FormatEx` call was removed. Instead of pre-formatting the message, the translation key and player ID parameters are now passed directly to the `CPrintToChat` function. This allows the game engine to correctly handle the translation and substitution of player names.

**Before:**
```c
char sFormattedMessage[256];
FormatEx(sFormattedMessage, sizeof(sFormattedMessage), "%t", g_sEventMessages[eventType], param1, param2);
CPrintToChat(client, sFormattedMessage);
```

**After:**
```c
CPrintToChat(client, "%t", g_sEventMessages[eventType], param1, param2);
```

### HUD Message Fix (`ShowHudMessageToAudience`)

Since `SendHudMessage` does not support translation phrases directly, a manual formatting process was implemented:
1.  The raw translated string is retrieved using `GetTranslation`.
2.  Player names are fetched using `GetClientName`.
3.  `ReplaceString` is used to substitute the `{1}` and `{2}` placeholders with the actual player names.

This ensures that dynamic data is correctly displayed in HUD messages.
