// =============================================================================
// SM Skinchooser (CSS) v5.5.1 — Patched by Gemini
// - Fixed flag restrictions not applying to menus.
// - Added robust auto-download system with explicit material lists.
// - Hardened KeyValues traversal to prevent errors from bad configs.
// - Improved original model capture for reliable resets.
// - Force lists are now reloaded on CVar changes.
// =============================================================================

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <cstrike>

#define PLUGIN_VERSION "5.5.1"

// CVars
ConVar g_cvarEnabled;
ConVar g_cvarMapbased;
ConVar g_cvarAdminOnly;
ConVar g_cvarCloseMenuTimer;
ConVar g_cvarAutodisplay;
ConVar g_cvarDisplayTimer;
ConVar g_cvarMenuStartTime;
ConVar g_cvarForcePlayerSkin;
ConVar g_cvarForcePlayerSkinTimer;
ConVar g_cvarForcePlayerSkinTimerEnabled;
ConVar g_cvarSkinAdmin;
ConVar g_cvarSkinAdminTimer;
ConVar g_cvarSkinAdminTimerEnabled;
ConVar g_cvarSkinBots;

// Handles
KeyValues g_hKVModels;
KeyValues g_hKVPlayerChoice;

// State
char g_authId[MAXPLAYERS+1][64];
char g_originalModel[MAXPLAYERS+1][PLATFORM_MAX_PATH];

char g_ForcePlayerTeamT[128][PLATFORM_MAX_PATH];
char g_ForcePlayerTeamCT[128][PLATFORM_MAX_PATH];
int  g_ForcePlayerCountT = 0;
int  g_ForcePlayerCountCT = 0;

char g_ForceAdminTeamT[128][PLATFORM_MAX_PATH];
char g_ForceAdminTeamCT[128][PLATFORM_MAX_PATH];
int  g_ForceAdminCountT = 0;
int  g_ForceAdminCountCT = 0;

char g_ForceBotsTeamT[128][PLATFORM_MAX_PATH];
char g_ForceBotsTeamCT[128][PLATFORM_MAX_PATH];
int  g_ForceBotsCountT = 0;
int  g_ForceBotsCountCT = 0;

public Plugin myinfo = {
    name        = "SM Skinchooser (CSS - v5.5.1)",
    author      = "Andi67, Gemini",
    description = "Model menu for Counter-Strike: Source with flag restrictions",
    version     = PLUGIN_VERSION,
    url         = "https://github.com/ZloyHohol/Counter-Strike-Plugins"
};

public void OnPluginStart()
{
    CreateConVar("sm_skinchooser_version", PLUGIN_VERSION, "SM Skinchooser version", FCVAR_NOTIFY | FCVAR_SPONLY);

    g_cvarEnabled = CreateConVar("sm_skinchooser_enabled", "1", "Enable plugin");
    g_cvarMapbased = CreateConVar("sm_skinchooser_mapbased", "0", "Use map-based player choice files (0=global,1=per-map)");
    g_cvarAdminOnly = CreateConVar("sm_skinchooser_adminonly", "0", "Menu only for admins (0=no,1=yes)");
    g_cvarCloseMenuTimer = CreateConVar("sm_skinchooser_closemenutimer", "30", "Menu auto-close seconds");
    g_cvarAutodisplay = CreateConVar("sm_skinchooser_autodisplay", "1", "Auto-show menu on team join (0=no,1=yes)");
    g_cvarDisplayTimer = CreateConVar("sm_skinchooser_displaytimer", "0", "Delay auto-show by sm_skinchooser_menustarttime (0=no,1=yes)");
    g_cvarMenuStartTime = CreateConVar("sm_skinchooser_menustarttime", "5.0", "Seconds before auto-show when enabled");

    g_cvarForcePlayerSkin = CreateConVar("sm_skinchooser_forceplayerskin", "0", "Force player skins (non-admin) (0=no,1=yes)");
    g_cvarForcePlayerSkinTimer = CreateConVar("sm_skinchooser_forceplayerskintimer", "0.3", "Timer when force player skin applies");
    g_cvarForcePlayerSkinTimerEnabled = CreateConVar("sm_skinchooser_forceplayerskintimer_enabled", "0", "Use timer for force player skin (0=no,1=yes)");

    g_cvarSkinAdmin = CreateConVar("sm_skinchooser_skinadmin", "0", "Force admin skins (0=no,1=yes)");
    g_cvarSkinAdminTimer = CreateConVar("sm_skinchooser_skinadmintimer", "0.3", "Timer when force admin skin applies");
    g_cvarSkinAdminTimerEnabled = CreateConVar("sm_skinchooser_skinadmintimer_enabled", "0", "Use timer for force admin skin (0=no,1=yes)");

    g_cvarSkinBots = CreateConVar("sm_skinchooser_skinbots", "0", "Force bot skins (0=no,1=yes)");

    RegConsoleCmd("sm_models", Command_Model, "Open the skin chooser menu");

    HookEvent("player_team",  Event_PlayerTeam, EventHookMode_Post);
    HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
    
    HookConVarChange(g_cvarForcePlayerSkin, OnForceCvarChanged);
    HookConVarChange(g_cvarSkinAdmin, OnForceCvarChanged);
    HookConVarChange(g_cvarSkinBots, OnForceCvarChanged);

    AutoExecConfig(true, "sm_skinchooser");
}

public void OnConfigsExecuted()
{
    LoadConfigAndChoices();
    LoadForceConfigs();
}

public void OnForceCvarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    LoadForceConfigs();
}

public void OnMapStart()
{
    LoadConfigAndChoices();
    LoadForceConfigs();
}

public void OnPluginEnd()
{
    if (g_hKVModels != null) CloseHandle(g_hKVModels);
    if (g_hKVPlayerChoice != null) CloseHandle(g_hKVPlayerChoice);
}

void LoadConfigAndChoices()
{
    char mapName[64];
    GetCurrentMap(mapName, sizeof(mapName));

    char configPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, configPath, sizeof(configPath), "configs/sm_skinchooser/maps/%s.ini", mapName);
    if (!FileExists(configPath)) {
        BuildPath(Path_SM, configPath, sizeof(configPath), "configs/sm_skinchooser/default_skins.ini");
    }

    if (g_hKVModels != null) CloseHandle(g_hKVModels);
    g_hKVModels = new KeyValues("Models");
    if (!g_hKVModels.ImportFromFile(configPath)) {
        LogError("[SM_SKINCHOOSER] Failed to load %s.", configPath);
    }

    char choicePath[PLATFORM_MAX_PATH];
    if (g_cvarMapbased.BoolValue) {
        BuildPath(Path_SM, choicePath, sizeof(choicePath), "data/%s_skinchooser_playermodels.ini", mapName);
    } else {
        BuildPath(Path_SM, choicePath, sizeof(choicePath), "data/skinchooser_playermodels.ini");
    }

    if (g_hKVPlayerChoice != null) CloseHandle(g_hKVPlayerChoice);
    g_hKVPlayerChoice = new KeyValues("Models");
    g_hKVPlayerChoice.ImportFromFile(choicePath);

    SafePrecacheAllModelsFromConfig();
}

void SafePrecacheAllModelsFromConfig()
{
    if (g_hKVModels == null) return;

    g_hKVModels.Rewind();
    if (!g_hKVModels.GotoFirstSubKey()) return;

    do {
        if (g_hKVModels.JumpToKey("Team_T", false)) {
            if (g_hKVModels.GotoFirstSubKey()) {
                do {
                    ValidateAndPrecacheModelEntry();
                } while (g_hKVModels.GotoNextKey());
                g_hKVModels.GoBack();
            }
            g_hKVModels.GoBack();
        }

        if (g_hKVModels.JumpToKey("Team_CT", false)) {
            if (g_hKVModels.GotoFirstSubKey()) {
                do {
                    ValidateAndPrecacheModelEntry();
                } while (g_hKVModels.GotoNextKey());
                g_hKVModels.GoBack();
            }
            g_hKVModels.GoBack();
        }
    } while (g_hKVModels.GotoNextKey());

    g_hKVModels.Rewind();
}

void ValidateAndPrecacheModelEntry()
{
    char path[PLATFORM_MAX_PATH];
    g_hKVModels.GetString("path", path, sizeof(path));

    if (path[0] == '\0' || !FileExists(path)) {
        return;
    }

    PrecacheModel(path, true);
    AddModelAndDependenciesToDownloads(path);
}

void AddModelAndDependenciesToDownloads(const char[] modelPath)
{
    AddFileToDownloadsTable(modelPath);

    char base[PLATFORM_MAX_PATH];
    strcopy(base, sizeof(base), modelPath);
    ReplaceString(base, sizeof(base), ".mdl", "");

    char dep[PLATFORM_MAX_PATH];
    Format(dep, sizeof(dep), "%s.vvd", base);      if (FileExists(dep)) AddFileToDownloadsTable(dep);
    Format(dep, sizeof(dep), "%s.dx90.vtx", base); if (FileExists(dep)) AddFileToDownloadsTable(dep);
    Format(dep, sizeof(dep), "%s.phy", base);      if (FileExists(dep)) AddFileToDownloadsTable(dep);

    if (g_hKVModels.JumpToKey("materials", false)) {
        if (g_hKVModels.GotoFirstSubKey(false)) {
            char mat[PLATFORM_MAX_PATH];
            do {
                g_hKVModels.GetString(NULL_STRING, mat, sizeof(mat));
                if (mat[0] != '\0' && FileExists(mat)) {
                    AddFileToDownloadsTable(mat);
                }
            } while (g_hKVModels.GotoNextKey(false));
            g_hKVModels.GoBack();
        }
        g_hKVModels.GoBack();
    }
}

void LoadForceConfigs()
{
    g_ForcePlayerCountT = g_ForcePlayerCountCT = 0;
    g_ForceAdminCountT  = g_ForceAdminCountCT  = 0;
    g_ForceBotsCountT   = g_ForceBotsCountCT   = 0;

    if (g_cvarForcePlayerSkin.BoolValue) {
        g_ForcePlayerCountT  = LoadSimpleModelList("configs/sm_skinchooser/force/player_t.ini",  g_ForcePlayerTeamT,  sizeof(g_ForcePlayerTeamT));
        g_ForcePlayerCountCT = LoadSimpleModelList("configs/sm_skinchooser/force/player_ct.ini", g_ForcePlayerTeamCT, sizeof(g_ForcePlayerTeamCT));
    }
    if (g_cvarSkinAdmin.BoolValue) {
        g_ForceAdminCountT  = LoadSimpleModelList("configs/sm_skinchooser/force/admin_t.ini",  g_ForceAdminTeamT,  sizeof(g_ForceAdminTeamT));
        g_ForceAdminCountCT = LoadSimpleModelList("configs/sm_skinchooser/force/admin_ct.ini", g_ForceAdminTeamCT, sizeof(g_ForceAdminTeamCT));
    }
    if (g_cvarSkinBots.BoolValue) {
        g_ForceBotsCountT  = LoadSimpleModelList("configs/sm_skinchooser/force/bots_t.ini",  g_ForceBotsTeamT,  sizeof(g_ForceBotsTeamT));
        g_ForceBotsCountCT = LoadSimpleModelList("configs/sm_skinchooser/force/bots_ct.ini", g_ForceBotsTeamCT, sizeof(g_ForceBotsTeamCT));
    }
}

int LoadSimpleModelList(const char[] iniPath, char[][] outArray, int outArraySize)
{
    int count = 0;
    char file[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, file, sizeof(file), iniPath);

    File fh = OpenFile(file, "r");
    if (fh == null) return 0;

    char line[PLATFORM_MAX_PATH];
    while (fh.ReadLine(line, sizeof(line))) {
        TrimString(line);
        if (line[0] == '\0' || (line[0] == '/' && line[1] == '/')) continue;

        if (!FileExists(line)) {
            continue;
        }

        if (count < (outArraySize / PLATFORM_MAX_PATH)) {
            strcopy(outArray[count], PLATFORM_MAX_PATH, line);
            PrecacheModel(line, true);
            // We assume force list models are simple and don't have extra materials for now
            char base[PLATFORM_MAX_PATH];
            strcopy(base, sizeof(base), line);
            ReplaceString(base, sizeof(base), ".mdl", "");
            char dep[PLATFORM_MAX_PATH];
            Format(dep, sizeof(dep), "%s.vvd", base);      if (FileExists(dep)) AddFileToDownloadsTable(dep);
            Format(dep, sizeof(dep), "%s.dx90.vtx", base); if (FileExists(dep)) AddFileToDownloadsTable(dep);
            Format(dep, sizeof(dep), "%s.phy", base);      if (FileExists(dep)) AddFileToDownloadsTable(dep);
            count++;
        } else {
            break;
        }
    }
    delete fh;
    return count;
}


Menu BuildMainMenu(int client)
{
    if (g_hKVModels == null) return null;
    g_hKVModels.Rewind();
    if (!g_hKVModels.GotoFirstSubKey()) return null;

    Menu menu = new Menu(Menu_Group);
    menu.SetTitle("Выбор группы моделей");

    do {
        char groupName[64];
        g_hKVModels.GetSectionName(groupName, sizeof(groupName));

        // Check for flags
        char sFlags[32];
        g_hKVModels.GetString("Admin", sFlags, sizeof(sFlags), ""); // Use "Admin" key
        if (sFlags[0] != '\0') {
            int iFlags = ReadFlagString(sFlags);
            if ((GetUserFlagBits(client) & iFlags) != iFlags) {
                continue; // Skip if the player does not have all required flags
            }
        }

        menu.AddItem(groupName, groupName);
    } while (g_hKVModels.GotoNextKey());

    menu.AddItem("reset", "[Вернуть стандартную модель]");

    g_hKVModels.Rewind();
    return menu;
}

public void Menu_Group(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select) {
        char group[64];
        menu.GetItem(param2, group, sizeof(group));

        if (StrEqual(group, "reset")) {
            ResetToDefaultModel(client);
            SavePlayerChoice(client, "");
            PrintToChat(client, "[SM] Вернул стандартную модель.");
            return;
        }

        g_hKVModels.JumpToKey(group);

        if (GetClientTeam(client) == CS_TEAM_T) {
            g_hKVModels.JumpToKey("Team_T");
        } else if (GetClientTeam(client) == CS_TEAM_CT) {
            g_hKVModels.JumpToKey("Team_CT");
        } else {
            g_hKVModels.Rewind();
            return;
        }

        if (!g_hKVModels.GotoFirstSubKey()) {
            g_hKVModels.Rewind();
            PrintToChat(client, "[SM] В группе '%s' нет доступных моделей.", group);
            return;
        }

        Menu sub = new Menu(Menu_Model);
        sub.SetTitle(group);
        char entryName[64], path[PLATFORM_MAX_PATH];

        do {
            g_hKVModels.GetSectionName(entryName, sizeof(entryName));
            g_hKVModels.GetString("path", path, sizeof(path), "");

            if (path[0] != '\0' && FileExists(path, true)) { // Corrected: added true for use_engine_path
                sub.AddItem(path, entryName);
            }
        } while (g_hKVModels.GotoNextKey());

        sub.Display(client, g_cvarCloseMenuTimer.IntValue);
        g_hKVModels.Rewind();
    }
    else if (action == MenuAction_End) {
        delete menu;
    }
}

public void Menu_Model(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select) {
        char path[PLATFORM_MAX_PATH];
        menu.GetItem(param2, path, sizeof(path));

        CacheClientAuthId(client);

        if (!FileExists(path)) {
            return;
        }

        if (!IsModelPrecached(path)) {
            PrecacheModel(path, true);
            // Don't call AddModelAndDependenciesToDownloads here, it's too late
        }

        SetEntityModel(client, path);
        SavePlayerChoice(client, path);
        PrintToChat(client, "[SM] Установлена модель: %s", path);
    }
    else if (action == MenuAction_End) {
        delete menu;
    }
}

public Action Command_Model(int client, int args)
{
    if (!g_cvarEnabled.BoolValue || !IsValidClient(client) || IsFakeClient(client)) {
        return Plugin_Handled;
    }

    if (g_cvarAdminOnly.BoolValue) {
        AdminId adm = GetUserAdmin(client);
        if (adm == INVALID_ADMIN_ID || !adm.HasFlag(Admin_Generic)) {
            PrintToChat(client, "[SM] Меню доступно только админам.");
            return Plugin_Handled;
        }
    }

    Menu menu = BuildMainMenu(client);
    if (menu == null) {
        PrintToChat(client, "[SM] Ошибка генерации меню.");
        return Plugin_Handled;
    }

    menu.Display(client, g_cvarCloseMenuTimer.IntValue);
    return Plugin_Handled;
}

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cvarEnabled.BoolValue) return;

    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsValidClient(client) || IsFakeClient(client)) return;

    CacheClientAuthId(client);

    if (g_cvarAutodisplay.BoolValue && (event.GetInt("team") >= CS_TEAM_T)) {
        if (g_cvarDisplayTimer.BoolValue) {
            CreateTimer(g_cvarMenuStartTime.FloatValue, Timer_ShowMenuDelayed, GetClientUserId(client));
        } else {
            Command_Model(client, 0);
        }
    }
}

public void Timer_ShowMenuDelayed(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if (IsValidClient(client) && !IsFakeClient(client)) {
        Command_Model(client, 0);
    }
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cvarEnabled.BoolValue) return;

    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsValidClient(client)) return;

    CaptureOriginalModelIfUnset(client);
    ApplySavedChoiceIfAny(client);

    if (IsFakeClient(client)) {
        if (g_cvarSkinBots.BoolValue) ForceBotSkinNow(client);
    } else {
        AdminId adm = GetUserAdmin(client);
        if (adm != INVALID_ADMIN_ID && g_cvarSkinAdmin.BoolValue) {
             if (g_cvarSkinAdminTimerEnabled.BoolValue) {
                CreateTimer(g_cvarSkinAdminTimer.FloatValue, Timer_ForceAdminSkin, GetClientUserId(client));
            } else {
                ForceAdminSkinNow(client);
            }
        } else if (adm == INVALID_ADMIN_ID && g_cvarForcePlayerSkin.BoolValue) {
            if (g_cvarForcePlayerSkinTimerEnabled.BoolValue) {
                CreateTimer(g_cvarForcePlayerSkinTimer.FloatValue, Timer_ForcePlayerSkin, GetClientUserId(client));
            } else {
                ForcePlayerSkinNow(client);
            }
        }
    }
}

void CaptureOriginalModelIfUnset(int client)
{
    if (g_originalModel[client][0] != '\0') return;

    char cur[PLATFORM_MAX_PATH];
    GetEntPropString(client, Prop_Data, "m_ModelName", cur, sizeof(cur));
    if (StrContains(cur, "models/player", false) != -1) {
        strcopy(g_originalModel[client], sizeof(g_originalModel[]), cur);
    }
}

void CacheClientAuthId(int client)
{
    if (g_authId[client][0] == '\0') {
        GetClientAuthId(client, AuthId_Steam2, g_authId[client], sizeof(g_authId[]));
    }
}

void SavePlayerChoice(int client, const char[] modelPath)
{
    if (g_hKVPlayerChoice == null) return;

    CacheClientAuthId(client);
    g_hKVPlayerChoice.JumpToKey(g_authId[client], true);

    int team = GetClientTeam(client);
    if (team == CS_TEAM_T) g_hKVPlayerChoice.SetString("Team_T", modelPath);
    else if (team == CS_TEAM_CT) g_hKVPlayerChoice.SetString("Team_CT", modelPath);

    g_hKVPlayerChoice.GoBack();

    char mapName[64], filePath[PLATFORM_MAX_PATH];
    GetCurrentMap(mapName, sizeof(mapName));

    if (g_cvarMapbased.BoolValue) {
        BuildPath(Path_SM, filePath, sizeof(filePath), "data/%s_skinchooser_playermodels.ini", mapName);
    } else {
        BuildPath(Path_SM, filePath, sizeof(filePath), "data/skinchooser_playermodels.ini");
    }

    g_hKVPlayerChoice.ExportToFile(filePath);
}

void ApplySavedChoiceIfAny(int client)
{
    if (g_hKVPlayerChoice == null) return;

    CacheClientAuthId(client);
    if (!g_hKVPlayerChoice.JumpToKey(g_authId[client])) return;

    char path[PLATFORM_MAX_PATH];
    int team = GetClientTeam(client);
    if (team == CS_TEAM_T) g_hKVPlayerChoice.GetString("Team_T", path, sizeof(path));
    else if (team == CS_TEAM_CT) g_hKVPlayerChoice.GetString("Team_CT", path, sizeof(path));
    else path[0] = '\0';
    
    g_hKVPlayerChoice.GoBack();

    if (path[0] == '\0' || !FileExists(path)) return;

    // Final check: does player still have access to this model's group?
    char groupName[64];
    if (FindGroupForModel(path, groupName, sizeof(groupName))) {
        g_hKVModels.Rewind();
        g_hKVModels.JumpToKey(groupName);
        char sFlags[32];
        g_hKVModels.GetString("Flags", sFlags, sizeof(sFlags));
        if (sFlags[0] != '\0') {
            int required = ReadFlagString(sFlags);
            if ((GetUserFlagBits(client) & required) != required) {
                return; // No longer has access
            }
        }
    }

    if (!IsModelPrecached(path)) PrecacheModel(path, true);
    SetEntityModel(client, path);
}


bool FindGroupForModel(const char[] modelPath, char[] groupBuffer, int bufferSize)
{
    g_hKVModels.Rewind();
    if (!g_hKVModels.GotoFirstSubKey()) return false;

    do {
        g_hKVModels.GetSectionName(groupBuffer, bufferSize);
        if (g_hKVModels.JumpToKey("Team_T", false)) {
            if (g_hKVModels.GotoFirstSubKey()) {
                do {
                    char path[PLATFORM_MAX_PATH];
                    g_hKVModels.GetString("path", path, sizeof(path));
                    if (StrEqual(path, modelPath)) return true;
                } while (g_hKVModels.GotoNextKey());
                g_hKVModels.GoBack();
            }
            g_hKVModels.GoBack();
        }
        if (g_hKVModels.JumpToKey("Team_CT", false)) {
            if (g_hKVModels.GotoFirstSubKey()) {
                do {
                    char path[PLATFORM_MAX_PATH];
                    g_hKVModels.GetString("path", path, sizeof(path));
                    if (StrEqual(path, modelPath)) return true;
                } while (g_hKVModels.GotoNextKey());
                g_hKVModels.GoBack();
            }
            g_hKVModels.GoBack();
        }
    } while (g_hKVModels.GotoNextKey());

    return false;
}

void ResetToDefaultModel(int client)
{
    if (g_originalModel[client][0] != '\0') {
        SetEntityModel(client, g_originalModel[client]);
    }
}

public void Timer_ForceAdminSkin(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if(IsValidClient(client)) ForceAdminSkinNow(client);
}
public void Timer_ForcePlayerSkin(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if(IsValidClient(client)) ForcePlayerSkinNow(client);
}

void ForceAdminSkinNow(int client)
{
    int team = GetClientTeam(client);
    if (team == CS_TEAM_T && g_ForceAdminCountT > 0) {
        SetEntityModel(client, g_ForceAdminTeamT[GetRandomInt(0, g_ForceAdminCountT - 1)]);
    } else if (team == CS_TEAM_CT && g_ForceAdminCountCT > 0) {
        SetEntityModel(client, g_ForceAdminTeamCT[GetRandomInt(0, g_ForceAdminCountCT - 1)]);
    }
}

void ForcePlayerSkinNow(int client)
{
    int team = GetClientTeam(client);
    if (team == CS_TEAM_T && g_ForcePlayerCountT > 0) {
        SetEntityModel(client, g_ForcePlayerTeamT[GetRandomInt(0, g_ForcePlayerCountT - 1)]);
    } else if (team == CS_TEAM_CT && g_ForcePlayerCountCT > 0) {
        SetEntityModel(client, g_ForcePlayerTeamCT[GetRandomInt(0, g_ForcePlayerCountCT - 1)]);
    }
}

void ForceBotSkinNow(int client)
{
    int team = GetClientTeam(client);
    if (team == CS_TEAM_T && g_ForceBotsCountT > 0) {
        SetEntityModel(client, g_ForceBotsTeamT[GetRandomInt(0, g_ForceBotsCountT - 1)]);
    } else if (team == CS_TEAM_CT && g_ForceBotsCountCT > 0) {
        SetEntityModel(client, g_ForceBotsTeamCT[GetRandomInt(0, g_ForceBotsCountCT - 1)]);
    }
}

stock bool IsValidClient(int client)
{
    return (client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client));
}
