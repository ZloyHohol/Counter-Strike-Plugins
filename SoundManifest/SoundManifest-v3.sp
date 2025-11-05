/*******************************************************************************

  SM_SoundManifest - A Unified Sound Event Plugin

  Version: 1.5 (finalized)
  Author: Gemini for ZloyHohol

  Description:
  A modern, configurable plugin to play sounds for various game events,
  including a flexible welcome sound system and Quake-style kill events.
  All messages are now localized via translations.

*******************************************************************************/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <multicolors>
#include <easy_hudmessage>

#define PLUGIN_VERSION "1.5"

// --- Constants & Enums ---

#define MAX_SOUNDS_PER_GROUP 16
#define MAX_GROUPS 8
#define COMBO_TIME 4.0 // Time in seconds to chain kills for a combo



// --- Data Structures ---

char g_sWelcomeSoundPaths[MAX_GROUPS][MAX_SOUNDS_PER_GROUP][PLATFORM_MAX_PATH];
int g_iWelcomeSoundCounts[MAX_GROUPS];
char g_sWelcomeGroupFlags[MAX_GROUPS][32];
int g_iWelcomeGroupCount = 0;
int g_iDefaultGroupIndex = -1;

KeyValues g_hEventSounds;

// --- ConVars ---
ConVar g_hEnabled;
ConVar g_hJoinDelay;
ConVar g_hJoinAudience;
ConVar g_hJoinInterval;
ConVar g_hDefaultSetting;
ConVar g_hJusticeKillThreshold;
ConVar g_hComboKillTime;
ConVar g_hQuadKillThreshold;
ConVar g_hEpicStreakThreshold;
ConVar g_hCooldownInterval;

// --- State Variables ---
Handle g_hCookieSoundPref;
bool g_bSoundEnabled[MAXPLAYERS + 1];
int g_iLastWelcomeSoundTime = 0;
float g_fLastPlayedTime[EVENT_TYPE_COUNT]; // Track last played time for each event type

// Killstreak Tracking
int g_iKillstreak[MAXPLAYERS + 1];
int g_iLastKillTime[MAXPLAYERS + 1];
int g_iTotalKillsThisRound = 0;
int g_iLastKillCount[MAXPLAYERS + 1]; // For Combo
int g_iPlayerTeamkills[MAXPLAYERS + 1]; // For JusticeKill
int g_iEpicStreak[MAXPLAYERS + 1]; // For Epic Streaks (MultiKill, etc.)
char g_sLastWeaponType[MAXPLAYERS + 1][64]; // For SpecialKill detection

enum EventType {
    FirstBlood,
    Headshot,
    DoubleKill,
    TripleKill,
    QuadKill,
    MultiKill,
    SuperKill,
    UltraKill,
    MegaKill,
    MonsterKill,
    Godlike,
    Combo,
    KnifeKill,
    GrenadeKill,
    Suicide,
    TeamKill,
    JusticeKill,
    SpecialKill,
    PlayerDisconnect,
    PlayerKick,
    PlayerVACBanned,
    EVENT_TYPE_COUNT
}

// --- Plugin Info ---

public Plugin myinfo = {
    name        = "Sound Manifest",
    author      = "Gemini for ZloyHohol",
    description = "Unified plugin for game event sounds.",
    version     = PLUGIN_VERSION
};

// --- Plugin Forwards ---

public void OnPluginStart()
{
    CreateConVar("sm_soundmanifest_version", PLUGIN_VERSION, "Sound Manifest Version", FCVAR_NOTIFY | FCVAR_SPONLY);
    g_hEnabled          = CreateConVar("sm_soundmanifest_enabled", "1", "0 = Disable the plugin, 1 = Enable.");
    g_hJoinDelay        = CreateConVar("sm_soundmanifest_join_delay", "3.0", "Delay in seconds before playing the welcome sound.", _, true, 0.0, true, 30.0);
    g_hJoinAudience     = CreateConVar("sm_soundmanifest_join_audience", "0", "Who hears the welcome sound: 0 = Joiner only, 1 = Everyone.", _, true, 0.0, true, 1.0);
    g_hJoinInterval     = CreateConVar("sm_soundmanifest_join_interval", "10.0", "Minimum interval in seconds between playing welcome sounds.", _, true, 0.0, true, 300.0);
    g_hDefaultSetting   = CreateConVar("sm_soundmanifest_default_setting", "1", "Should sounds be enabled by default for new players? 1 = Yes, 0 = No.");
    g_hJusticeKillThreshold = CreateConVar("sm_soundmanifest_justicekill_threshold", "2", "Number of teamkills a victim must have to trigger JusticeKill.", _, true, 0.0, true, 10.0);
    g_hComboKillTime    = CreateConVar("sm_soundmanifest_combokill_time", "4.0", "Time in seconds to chain kills for a combo.", _, true, 0.0, true, 10.0);
    g_hQuadKillThreshold = CreateConVar("sm_soundmanifest_quadkill_threshold", "4", "Number of kills for a QuadKill.", _, true, 0.0, true, 10.0);
    g_hEpicStreakThreshold = CreateConVar("sm_soundmanifest_epicstreak_threshold", "5", "Number of kills for an Epic Streak (MultiKill, etc.).", _, true, 0.0, true, 10.0);
    g_hCooldownInterval = CreateConVar("sm_soundmanifest_cooldown_interval", "2.0", "Minimum interval in seconds between repetitions of the same sound.", _, true, 0.0, true, 10.0);

    AutoExecConfig(true, "SM_SoundManifest");

    LoadTranslations("SM_SoundManifest.phrases");

    g_hCookieSoundPref = RegClientCookie("sm_soundmanifest_preference", "User preference for sounds", CookieAccess_Private);

    RegConsoleCmd("sm_soundmanifest", Command_SoundMenu, "Open the Sound Manifest settings menu");
    RegConsoleCmd("soundmanifest", Command_SoundMenu);

    HookEvent("player_death", OnPlayerDeath, EventHookMode_Post);
    HookEvent("round_start", OnRoundStart, EventHookMode_Post);
    HookEvent("player_disconnect", OnPlayerDisconnect, EventHookMode_Post);
}

public void OnAllPluginsLoaded() { LoadSoundsConfig(); }
public void OnConfigsExecuted() { LoadSoundsConfig(); }

public void OnClientPutInServer(int client)
{
    if (IsFakeClient(client) || !g_hEnabled.BoolValue) return;

    char sCookie[4];
    GetClientCookie(client, g_hCookieSoundPref, sCookie, sizeof(sCookie));
    g_bSoundEnabled[client] = (sCookie[0] == '\0') ? g_hDefaultSetting.BoolValue : view_as<bool>(StringToInt(sCookie));

    if (GetTime() - g_iLastWelcomeSoundTime < g_hJoinInterval.IntValue) return;

    CreateTimer(g_hJoinDelay.FloatValue, Timer_PlayWelcomeSound, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

// --- Sound Config Loading ---

void LoadSoundsConfig()
{
    g_iWelcomeGroupCount = 0;
    g_iDefaultGroupIndex = -1;
    if (g_hEventSounds != null) delete g_hEventSounds;
    g_hEventSounds = new KeyValues("EventSounds");

    char sPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, sPath, sizeof(sPath), "configs/SoundManifest_Sounds.ini");

    if (!FileExists(sPath)) {
        PrintToServer("[SM] Config file not found: %s. No sounds will be played.", sPath);
        return;
    }

    KeyValues hKV = new KeyValues("SoundManifest");
    if (!hKV.ImportFromFile(sPath)) {
        delete hKV;
        LogError("[SM] Failed to parse sound config file: %s", sPath);
        return;
    }

    if (!hKV.GotoFirstSubKey()) { delete hKV; return; }

    do {
        char sSectionName[64];
        hKV.GetSectionName(sSectionName, sizeof(sSectionName));

        if (StrEqual(sSectionName, "JoinServer")) {
            ParseWelcomeSounds(hKV);
        } else {
            ParseDynamicEvent(hKV, sSectionName);
        }
    } while (hKV.GotoNextKey(false));

    delete hKV;
}

void ParseWelcomeSounds(KeyValues hKV)
{
    if (!hKV.GotoFirstSubKey(false)) return;
    do {
        if (g_iWelcomeGroupCount >= MAX_GROUPS) break;

        hKV.GetSectionName(g_sWelcomeGroupFlags[g_iWelcomeGroupCount], 31);
        if (StrEqual(g_sWelcomeGroupFlags[g_iWelcomeGroupCount], "Default", false)) {
            g_sWelcomeGroupFlags[g_iWelcomeGroupCount][0] = '\0';
            g_iDefaultGroupIndex = g_iWelcomeGroupCount;
        }

        int iSoundCount = 0;
        if (hKV.GotoFirstSubKey(false)) {
            do {
                char sKey[64];
                hKV.GetSectionName(sKey, sizeof(sKey));
                if (StrContains(sKey, "sound", false) == 0 && iSoundCount < MAX_SOUNDS_PER_GROUP) {
                    char sSoundPath[PLATFORM_MAX_PATH];
                    hKV.GetString(NULL_STRING, sSoundPath, sizeof(sSoundPath));
                    NormalizePath(sSoundPath, sizeof(sSoundPath));
                    if (PrecacheAndAddSound(sSoundPath)) {
                        strcopy(g_sWelcomeSoundPaths[g_iWelcomeGroupCount][iSoundCount], PLATFORM_MAX_PATH, sSoundPath);
                        iSoundCount++;
                    }
                }
            } while (hKV.GotoNextKey(false));
            hKV.GoBack();
        }
        g_iWelcomeSoundCounts[g_iWelcomeGroupCount] = iSoundCount;
        g_iWelcomeGroupCount++;
    } while (hKV.GotoNextKey(false));
    hKV.GoBack();
}

void ParseDynamicEvent(KeyValues hKV, const char[] sEventName)
{
    g_hEventSounds.JumpToKey(sEventName, true);
    char sSoundPath[PLATFORM_MAX_PATH], sMessage[64];

    hKV.GetString("sound", sSoundPath, sizeof(sSoundPath));
    hKV.GetString("message", sMessage, sizeof(sMessage));

    NormalizePath(sSoundPath, sizeof(sSoundPath));

    if (PrecacheAndAddSound(sSoundPath)) g_hEventSounds.SetString("sound", sSoundPath);
    g_hEventSounds.SetString("message", sMessage);
    g_hEventSounds.GoBack();
}

bool PrecacheAndAddSound(const char[] sRelativePath)
{
    if (sRelativePath[0] == '\0') return false;
    char sFullPath[PLATFORM_MAX_PATH];
    Format(sFullPath, sizeof(sFullPath), "sound/%s", sRelativePath);
    AddFileToDownloadsTable(sFullPath);
    PrecacheSound(sRelativePath, true);
    return true;
}

void NormalizePath(char[] sPath, int iMaxLen) { ReplaceString(sPath, iMaxLen, "\\", "/"); }

// --- Event Handlers ---

public Action Timer_PlayWelcomeSound(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if (client == 0 || !IsClientInGame(client) || !g_bSoundEnabled[client]) return Plugin_Stop;

    int iTargetGroup = -1;
    AdminId admin = GetUserAdmin(client);

    if (admin != INVALID_ADMIN_ID) {
        for (int i = 0; i < g_iWelcomeGroupCount; i++) {
            if (g_sWelcomeGroupFlags[i][0] != '\0' && GetAdminFlags(admin, Access_Effective) & ReadFlagString(g_sWelcomeGroupFlags[i])) {
                if (g_iWelcomeSoundCounts[i] > 0) {
                    iTargetGroup = i;
                    break;
                }
            }
        }
    }

    if (iTargetGroup == -1 && g_iDefaultGroupIndex != -1 && g_iWelcomeSoundCounts[g_iDefaultGroupIndex] > 0) {
        iTargetGroup = g_iDefaultGroupIndex;
    }

    if (iTargetGroup != -1) {
        int iSoundIndex = GetRandomInt(0, g_iWelcomeSoundCounts[iTargetGroup] - 1);
        char sSound[PLATFORM_MAX_PATH];
        strcopy(sSound, sizeof(sSound), g_sWelcomeSoundPaths[iTargetGroup][iSoundIndex]);

        if (g_hJoinAudience.BoolValue) {
            PlaySoundToEnabledClients(sSound, client);
        } else {
            EmitSoundToClient(client, sSound);
        }

        g_iLastWelcomeSoundTime = GetTime();
    }

    return Plugin_Stop;
}
public void OnPlayerDeath(Event event, const char[] name, bool silent)
{
    if (!g_hEnabled.BoolValue) return;

    int iVictim = GetClientOfUserId(event.GetInt("userid"));
    int iAttacker = GetClientOfUserId(event.GetInt("attacker"));
    char sWeapon[64];
    event.GetString("weapon", sWeapon, sizeof(sWeapon));
    bool bHeadshot = event.GetBool("headshot");
    char sDamageType[64];
    event.GetString("damagetype", sDamageType, sizeof(sDamageType));

    // Reset victim's killstreak/combo/epicstreak if they die
    if (iVictim > 0) {
        g_iKillstreak[iVictim] = 0;
        g_iLastKillCount[iVictim] = 0;
        g_iEpicStreak[iVictim] = 0;
    }

    // --- Event Selection Logic ---
    char sEventToPlay[32] = "";
    int iEventParam = 0; // Used for combo count, etc.

    // 1. Suicide Check (Highest Priority, immediate return)
    if (iAttacker == 0 || iAttacker == iVictim) {
        PlayEvent("Suicide", iVictim, 0);
        return;
    }

    // 2. Teamkill Check (High Priority, immediate return)
    if (GetClientTeam(iAttacker) == GetClientTeam(iVictim)) {
        PlayEvent("TeamKill", iAttacker, iVictim);
        g_iPlayerTeamkills[iVictim]++; // Increment victim's teamkill count
        // Reset killer's progress as per scheme
        g_iKillstreak[iAttacker] = 0;
        g_iLastKillCount[iAttacker] = 0;
        g_iEpicStreak[iAttacker] = 0;
        return;
    }

    // 3. JusticeKill Check (High Priority, immediate return if triggered)
    if (g_iPlayerTeamkills[iVictim] >= g_hJusticeKillThreshold.IntValue) {
        PlayEvent("JusticeKill", iAttacker, iVictim);
        g_iPlayerTeamkills[iVictim] = 0; // Reset victim's teamkill count after justice
        return;
    }

    // Increment total kills for the round
    g_iTotalKillsThisRound++;

    // Update killstreak and combo counters
    if (GetTime() - g_iLastKillTime[iAttacker] <= g_hComboKillTime.FloatValue) {
        g_iKillstreak[iAttacker]++;
        g_iLastKillCount[iAttacker]++;
    } else {
        g_iKillstreak[iAttacker] = 1;
        g_iLastKillCount[iAttacker] = 1;
    }
    g_iLastKillTime[iAttacker] = GetTime();

    // Update epic streak
    g_iEpicStreak[iAttacker]++;

    // --- Determine the highest-weighted event ---
    int iCurrentWeight = 0;

    // Unique Event: FirstBlood
    if (g_iTotalKillsThisRound == 1) {
        strcopy(sEventToPlay, sizeof(sEventToPlay), "FirstBlood");
        iCurrentWeight = 1000;
    }

    // Tertiary Events: Epic Streaks (MultiKill, SuperKill, etc.)
    if (g_iEpicStreak[iAttacker] >= g_hEpicStreakThreshold.IntValue) {
        // Determine specific epic streak based on count
        char sEpicStreakEvent[32];
        if (g_iEpicStreak[iAttacker] == 5) strcopy(sEpicStreakEvent, sizeof(sEpicStreakEvent), "MultiKill");
        else if (g_iEpicStreak[iAttacker] == 6) strcopy(sEpicStreakEvent, sizeof(sEpicStreakEvent), "SuperKill");
        else if (g_iEpicStreak[iAttacker] == 7) strcopy(sEpicStreakEvent, sizeof(sEpicStreakEvent), "UltraKill");
        else if (g_iEpicStreak[iAttacker] == 8) strcopy(sEpicStreakEvent, sizeof(sEpicStreakEvent), "MegaKill");
        else if (g_iEpicStreak[iAttacker] == 9) strcopy(sEpicStreakEvent, sizeof(sEpicStreakEvent), "MonsterKill");
        else if (g_iEpicStreak[iAttacker] >= 10) strcopy(sEpicStreakEvent, sizeof(sEpicStreakEvent), "Godlike");

        if (iCurrentWeight < 600) {
            strcopy(sEventToPlay, sizeof(sEventToPlay), sEpicStreakEvent);
            iCurrentWeight = 600;
        }
    }

    // Special Events: ComboKill, SpecialKill
    if (g_iLastKillCount[iAttacker] >= 2) { // ComboKill
        if (iCurrentWeight < 160) {
            strcopy(sEventToPlay, sizeof(sEventToPlay), "Combo");
            iEventParam = g_iLastKillCount[iAttacker];
            iCurrentWeight = 160;
        }
    }

    // SpecialKill (unusual weapon/damage type)
    // This is a basic check, can be expanded later
    if (StrContains(sWeapon, "weapon_", false) == -1 && StrContains(sWeapon, "knife", false) == -1 && StrContains(sWeapon, "hegrenade", false) == -1 && StrContains(sWeapon, "taser", false) == -1) {
        if (iCurrentWeight < 160) {
            strcopy(sEventToPlay, sizeof(sEventToPlay), "SpecialKill");
            iCurrentWeight = 160;
        }
    }

    // Secondary Events: Killstreaks (Double, Triple, Quad)
    if (g_iKillstreak[iAttacker] == g_hQuadKillThreshold.IntValue) { // QuadKill
        if (iCurrentWeight < 90) {
            strcopy(sEventToPlay, sizeof(sEventToPlay), "QuadKill");
            iCurrentWeight = 90;
        }
    } else if (g_iKillstreak[iAttacker] == 3) { // TripleKill
        if (iCurrentWeight < 90) {
            strcopy(sEventToPlay, sizeof(sEventToPlay), "TripleKill");
            iCurrentWeight = 90;
        }
    } else if (g_iKillstreak[iAttacker] == 2) { // DoubleKill
        if (iCurrentWeight < 90) {
            strcopy(sEventToPlay, sizeof(sEventToPlay), "DoubleKill");
            iCurrentWeight = 90;
        }
    }

    // Primary Events: KnifeKill, GrenadeKill, Headshot
    if (iCurrentWeight < 20) { // Only consider if no higher priority event was selected
        if (bHeadshot) {
            strcopy(sEventToPlay, sizeof(sEventToPlay), "Headshot");
        } else if (StrContains(sWeapon, "knife", false) != -1) {
            strcopy(sEventToPlay, sizeof(sEventToPlay), "KnifeKill");
        } else if (StrContains(sWeapon, "hegrenade", false) != -1) {
            strcopy(sEventToPlay, sizeof(sEventToPlay), "GrenadeKill");
        }
    }

    // Play the selected event
    if (sEventToPlay[0] != '\0') {
        PlayEvent(sEventToPlay, iAttacker, iEventParam);
    }
}

public void OnRoundStart(Event event, const char[] name, bool silent)
{
    g_iTotalKillsThisRound = 0;
    for (int i = 1; i <= MaxClients; i++) {
        g_iKillstreak[i] = 0;
        g_iLastKillTime[i] = 0;
        g_iLastKillCount[i] = 0;
        g_iEpicStreak[i] = 0;
        // g_iPlayerTeamkills is not reset here, as it tracks across rounds/maps for JusticeKill
        // Clear g_sLastWeaponType
        g_sLastWeaponType[i][0] = '\0';
    }
    for (int i = 0; i < view_as<int>(EVENT_TYPE_COUNT); i++) {
        g_fLastPlayedTime[view_as<EventType>(i)] = 0.0;
    }
}

public void OnPlayerDisconnect(Event event, const char[] name, bool silent)
{
    if (!g_hEnabled.BoolValue) return;

    int client = GetClientOfUserId(event.GetInt("userid"));
    char sReason[256];
    event.GetString("reason", sReason, sizeof(sReason));

    if (StrContains(sReason, "VAC", false) != -1) {
        PlayEvent("PlayerVACBanned", client, 0);
    } else if (StrContains(sReason, "Kicked", false) != -1 || StrContains(sReason, "Banned", false) != -1) {
        PlayEvent("PlayerKick", client, 0);
    } else {
        PlayEvent("PlayerDisconnect", client, 0);
    }
}

// --- Sound & Message Logic ---

void PlayEvent(const char[] sEventName, int param1, int param2)
{
    PrintToServer("[SM] DEBUG: PlayEvent called for event: %s, param1: %d, param2: %d", sEventName, param1, param2);
    if (!g_hEventSounds.JumpToKey(sEventName)) {
        PrintToServer("[SM] DEBUG: PlayEvent - KeyValues for %s not found.", sEventName);
        return;
    }

    // Cooldown check
    EventType eventType = view_as<EventType>(FindEventType(sEventName));
    if (eventType != EVENT_TYPE_COUNT && GetTime() - g_fLastPlayedTime[eventType] < g_hCooldownInterval.FloatValue) {
        PrintToServer("[SM] DEBUG: PlayEvent - Event %s on cooldown.", sEventName);
        return;
    }

    char sSound[PLATFORM_MAX_PATH];
    char sMessage[64];
    g_hEventSounds.GetString("sound", sSound, sizeof(sSound));
    g_hEventSounds.GetString("message", sMessage, sizeof(sMessage));
    g_hEventSounds.GoBack();

    PrintToServer("[SM] DEBUG: PlayEvent - Event: %s, Sound: %s, Message: %s", sEventName, sSound, sMessage);

    // Determine audience based on event type
    bool bPlayToAll = false;
    bool bPlayToTeam = false;

    if (StrEqual(sEventName, "FirstBlood") || StrEqual(sEventName, "TeamKill") || StrEqual(sEventName, "JusticeKill") || StrEqual(sEventName, "Combo") || StrEqual(sEventName, "SpecialKill")) {
        bPlayToAll = true; // Unique and Special events play to all
    } else if (StrEqual(sEventName, "DoubleKill") || StrEqual(sEventName, "TripleKill") || StrEqual(sEventName, "QuadKill") || StrEqual(sEventName, "MultiKill") || StrEqual(sEventName, "SuperKill") || StrEqual(sEventName, "UltraKill") || StrEqual(sEventName, "MegaKill") || StrEqual(sEventName, "MonsterKill") || StrEqual(sEventName, "Godlike")) {
        bPlayToTeam = true; // Secondary and Tertiary events play to killer and team
    } else if (StrEqual(sEventName, "KnifeKill") || StrEqual(sEventName, "GrenadeKill") || StrEqual(sEventName, "Headshot")) {
        // Primary events play only to killer (default behavior of EmitSoundToClient if activator is specified)
    }

    if (sSound[0] != '\0') {
        if (bPlayToAll) {
            PlaySoundToEnabledClients(sSound, param1); // param1 is activator, but PlaySoundToEnabledClients plays to all
        } else if (bPlayToTeam) {
            // Play to killer and their team
            int iTeam = GetClientTeam(param1);
            for (int i = 1; i <= MaxClients; i++) {
                if (IsClientInGame(i) && g_bSoundEnabled[i] && GetClientTeam(i) == iTeam) {
                    EmitSoundToClient(i, sSound, param1, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, SNDPITCH_NORMAL);
                }
            }
        } else { // Play only to killer
            EmitSoundToClient(param1, sSound);
        }
        PrintToServer("[SM] DEBUG: PlayEvent - Sound played for %s (Audience: %s).", sEventName, bPlayToAll ? "All" : (bPlayToTeam ? "Team" : "Killer"));
    }

    if (sMessage[0] != '\0') {
        char sTranslationKey[PLATFORM_MAX_PATH];
        Format(sTranslationKey, sizeof(sTranslationKey), "%s", sMessage);

        // Вывод в чат
        if (bPlayToAll) {
            PrintToChatToEnabledClients("%t", sTranslationKey, param1, param2);
        } else if (bPlayToTeam) {
            int iTeam = GetClientTeam(param1);
            for (int i = 1; i <= MaxClients; i++) {
                if (IsClientInGame(i) && g_bSoundEnabled[i] && GetClientTeam(i) == iTeam) {
                    CPrintToChat(i, "%t", sTranslationKey, param1, param2);
                }
            }
        } else { // Print only to killer
            CPrintToChat(param1, "%t", sTranslationKey, param1, param2);
        }
        PrintToServer("[SM] DEBUG: PlayEvent - Chat message displayed for %s (key: %s, Audience: %s).", sEventName, sTranslationKey, bPlayToAll ? "All" : (bPlayToTeam ? "Team" : "Killer"));

        // Дополнительно HUD для ключевых событий (FirstBlood/TripleKill)
        if (StrEqual(sEventName, "FirstBlood") || StrEqual(sEventName, "TripleKill") || StrEqual(sEventName, "QuadKill") || StrEqual(sEventName, "MultiKill") || StrEqual(sEventName, "SuperKill") || StrEqual(sEventName, "UltraKill") || StrEqual(sEventName, "MegaKill") || StrEqual(sEventName, "MonsterKill") || StrEqual(sEventName, "Godlike")) {
            for (int i = 1; i <= MaxClients; i++) {
                if (IsClientInGame(i) && g_bSoundEnabled[i]) {
                    char sFormattedMsg[256];
                    Format(sFormattedMsg, sizeof(sFormattedMsg), "%t", sTranslationKey, param1, param2);

                    SendHudMessage(i,
                        2, -1.0, -0.3,   // channel=2, центр экрана
                        0xFF00FFFF, 0xFFFFFFFF, // цвет1 фиолетовый → цвет2 белый
                        0, 0.5, 1.0, 2.0, 0.0,
                        sFormattedMsg);
                    PrintToServer("[SM] DEBUG: PlayEvent - HUD message displayed for %s (key: %s) to client %d.", sEventName, sTranslationKey, i);
                }
            }
        }
    }

    // Update last played time for this event type
    if (eventType != EVENT_TYPE_COUNT) {
        g_fLastPlayedTime[eventType] = float(GetTime());
    }
}
void PlaySoundToEnabledClients(const char[] sSound, int iActivator)
{
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && g_bSoundEnabled[i]) {
            EmitSoundToClient(i, sSound, iActivator, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, SNDPITCH_NORMAL);
        }
    }
}

void PrintToChatToEnabledClients(const char[] sPhrase, any...)
{
    char sBuffer[256];
    VFormat(sBuffer, sizeof(sBuffer), sPhrase, 2);

    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && g_bSoundEnabled[i]) {
            CPrintToChat(i, sBuffer);
        }
    }
}

// --- Player Settings Menu ---

public Action Command_SoundMenu(int client, int args)
{
    if (client == 0) return Plugin_Handled;

    Menu menu = new Menu(Handler_SoundMenu);
    menu.SetTitle("%t", "SoundMenu_Title");

    if (g_bSoundEnabled[client]) {
        menu.AddItem("toggle", "SoundMenu_ToggleOn");
    } else {
        menu.AddItem("toggle", "SoundMenu_ToggleOff");
    }

    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
    return Plugin_Handled;
}

public int Handler_SoundMenu(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_Select && item == 0) {
        g_bSoundEnabled[client] = !g_bSoundEnabled[client];

        char sCookieValue[4];
        IntToString(view_as<int>(g_bSoundEnabled[client]), sCookieValue, sizeof(sCookieValue));
        SetClientCookie(client, g_hCookieSoundPref, sCookieValue);

        if (g_bSoundEnabled[client]) {
            CPrintToChat(client, "%t", "SoundMenu_Enabled");
        } else {
            CPrintToChat(client, "%t", "SoundMenu_Disabled");
        }

        Command_SoundMenu(client, 0);
    } else if (action == MenuAction_End) {
        delete menu;
    }
    return 0;
}

EventType FindEventType(const char[] sEventName)
{
    if (StrEqual(sEventName, "FirstBlood")) return FirstBlood;
    if (StrEqual(sEventName, "Headshot")) return Headshot;
    if (StrEqual(sEventName, "DoubleKill")) return DoubleKill;
    if (StrEqual(sEventName, "TripleKill")) return TripleKill;
    if (StrEqual(sEventName, "QuadKill")) return QuadKill;
    if (StrEqual(sEventName, "MultiKill")) return MultiKill;
    if (StrEqual(sEventName, "SuperKill")) return SuperKill;
    if (StrEqual(sEventName, "UltraKill")) return UltraKill;
    if (StrEqual(sEventName, "MegaKill")) return MegaKill;
    if (StrEqual(sEventName, "MonsterKill")) return MonsterKill;
    if (StrEqual(sEventName, "Godlike")) return Godlike;
    if (StrEqual(sEventName, "Combo")) return Combo;
    if (StrEqual(sEventName, "KnifeKill")) return KnifeKill;
    if (StrEqual(sEventName, "GrenadeKill")) return GrenadeKill;
    if (StrEqual(sEventName, "Suicide")) return Suicide;
    if (StrEqual(sEventName, "TeamKill")) return TeamKill;
    if (StrEqual(sEventName, "JusticeKill")) return JusticeKill;
    if (StrEqual(sEventName, "SpecialKill")) return SpecialKill;
    if (StrEqual(sEventName, "PlayerDisconnect")) return PlayerDisconnect;
    if (StrEqual(sEventName, "PlayerKick")) return PlayerKick;
    if (StrEqual(sEventName, "PlayerVACBanned")) return PlayerVACBanned;
    return EVENT_TYPE_COUNT;
}
