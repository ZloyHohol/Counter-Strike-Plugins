// =============================================================================
// SM Skinchooser (CSS) — Clean, safe, no arms, with Team_T / Team_CT
// - Clean group menu (no Team_* in the top level)
// - Team-aware model listing (Team_T for T, Team_CT for CT)
// - Reset to default model
// - Safe KV reading with validation (one "path" per model, file existence)
// - Auto-download dependencies for models (mdl, vtx, vvd, phy, materials)
// - Remember player choice (global by default, optional mapbased toggle)
// - Optional force skins for Admins & Bots via configs
// =============================================================================

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <cstrike>

// -----------------------------------------------------------------------------
// Version/CVARs
// -----------------------------------------------------------------------------
#define PLUGIN_VERSION "6.0-clean-css"

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

// -----------------------------------------------------------------------------
// Handles / KV
// -----------------------------------------------------------------------------
Handle g_hKVModels = INVALID_HANDLE;           // configs/sm_skinchooser/default_skins.ini (or map-based)
Handle g_hKVPlayerChoice = INVALID_HANDLE;     // data/skinchooser_playermodels.ini OR map-based

// -----------------------------------------------------------------------------
// State
// -----------------------------------------------------------------------------
char g_authId[MAXPLAYERS+1][64];
char g_originalModel[MAXPLAYERS+1][PLATFORM_MAX_PATH];

char g_ForcePlayerTeamT[128][PLATFORM_MAX_PATH]; // optional force player models (T)
char g_ForcePlayerTeamCT[128][PLATFORM_MAX_PATH];
int  g_ForcePlayerCountT = 0;
int  g_ForcePlayerCountCT = 0;

char g_ForceAdminTeamT[128][PLATFORM_MAX_PATH];  // optional force admin models (T)
char g_ForceAdminTeamCT[128][PLATFORM_MAX_PATH];
int  g_ForceAdminCountT = 0;
int  g_ForceAdminCountCT = 0;

char g_ForceBotsTeamT[128][PLATFORM_MAX_PATH];   // optional force bots (T)
char g_ForceBotsTeamCT[128][PLATFORM_MAX_PATH];
int  g_ForceBotsCountT = 0;
int  g_ForceBotsCountCT = 0;

// -----------------------------------------------------------------------------
// Plugin info
// -----------------------------------------------------------------------------
public Plugin myinfo = {
    name        = "SM Skinchooser (CSS - clean)",
    author      = "Andi67, refactor by Gemini",
    description = "Model menu for Counter-Strike: Source (no arms, safe INI)",
    version     = PLUGIN_VERSION,
    url         = "https://github.com"
};

// -----------------------------------------------------------------------------
// Forwards
// -----------------------------------------------------------------------------
public void OnPluginStart()
{
    CreateConVar("sm_skinchooser_version", PLUGIN_VERSION, "SM Skinchooser version", FCVAR_NOTIFY);

    g_cvarEnabled           = CreateConVar("sm_skinchooser_enabled", "1", "Enable plugin", FCVAR_NONE, true, 0.0, true, 1.0);
    g_cvarMapbased          = CreateConVar("sm_skinchooser_mapbased", "0", "Use map-based player choice files (0=global,1=per-map)", FCVAR_NONE, true, 0.0, true, 1.0);
    g_cvarAdminOnly         = CreateConVar("sm_skinchooser_adminonly", "0", "Menu only for admins (0=no,1=yes)", FCVAR_NONE, true, 0.0, true, 1.0);
    g_cvarCloseMenuTimer    = CreateConVar("sm_skinchooser_closemenutimer", "30", "Menu auto-close seconds", FCVAR_NONE, true, 5.0, true, 600.0);

    g_cvarAutodisplay       = CreateConVar("sm_skinchooser_autodisplay", "1", "Auto-show menu on team join (0=no,1=yes)", FCVAR_NONE, true, 0.0, true, 1.0);
    g_cvarDisplayTimer      = CreateConVar("sm_skinchooser_displaytimer", "0", "Delay auto-show by sm_skinchooser_menustarttime (0=no,1=yes)", FCVAR_NONE, true, 0.0, true, 1.0);
    g_cvarMenuStartTime     = CreateConVar("sm_skinchooser_menustarttime", "5.0", "Seconds before auto-show when enabled", FCVAR_NONE, true, 0.0, true, 60.0);

    // Optional force systems
    g_cvarForcePlayerSkin           = CreateConVar("sm_skinchooser_forceplayerskin", "0", "Force player skins (non-admin) (0=no,1=yes)", FCVAR_NONE, true, 0.0, true, 1.0);
    g_cvarForcePlayerSkinTimer      = CreateConVar("sm_skinchooser_forceplayerskintimer", "0.3", "Timer when force player skin applies", FCVAR_NONE, true, 0.1, true, 30.0);
    g_cvarForcePlayerSkinTimerEnabled = CreateConVar("sm_skinchooser_forceplayerskintimer_enabled", "0", "Use timer for force player skin (0=no,1=yes)", FCVAR_NONE, true, 0.0, true, 1.0);

    g_cvarSkinAdmin                 = CreateConVar("sm_skinchooser_skinadmin", "0", "Force admin skins (0=no,1=yes)", FCVAR_NONE, true, 0.0, true, 1.0);
    g_cvarSkinAdminTimer            = CreateConVar("sm_skinchooser_skinadmintimer", "0.3", "Timer when force admin skin applies", FCVAR_NONE, true, 0.1, true, 30.0);
    g_cvarSkinAdminTimerEnabled     = CreateConVar("sm_skinchooser_skinadmintimer_enabled", "0", "Use timer for force admin skin (0=no,1=yes)", FCVAR_NONE, true, 0.0, true, 1.0);

    g_cvarSkinBots                  = CreateConVar("sm_skinchooser_skinbots", "0", "Force bot skins (0=no,1=yes)", FCVAR_NONE, true, 0.0, true, 1.0);

    RegConsoleCmd("sm_models", Command_Model, "Open the skin chooser menu");

    HookEvent("player_team",  Event_PlayerTeam, EventHookMode_Post);
    HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);

    AutoExecConfig(true, "sm_skinchooser");

    LoadConfigAndChoices();
    LoadForceConfigs();
}

public void OnMapStart()
{
    // Re-load config/KV on map start to catch map-based changes if any.
    LoadConfigAndChoices();
    LoadForceConfigs();
}

public void OnPluginEnd()
{
    if (g_hKVModels != INVALID_HANDLE) {
        CloseHandle(g_hKVModels);
        g_hKVModels = INVALID_HANDLE;
    }
    if (g_hKVPlayerChoice != INVALID_HANDLE) {
        CloseHandle(g_hKVPlayerChoice);
        g_hKVPlayerChoice = INVALID_HANDLE;
    }
}

// -----------------------------------------------------------------------------
// Load configs (safe parsing, Team_T / Team_CT)
// -----------------------------------------------------------------------------
void LoadConfigAndChoices()
{
    // Load main config (default or map-based override). We DO NOT create new files here.
    char mapName[PLATFORM_MAX_PATH];
    GetCurrentMap(mapName, sizeof(mapName));

    char configPath[PLATFORM_MAX_PATH];

    // Try map-based config first
    BuildPath(Path_SM, configPath, sizeof(configPath), "configs/sm_skinchooser/maps/%s.ini", mapName);
    if (!FileExists(configPath)) {
        // Fallback to default_skins.ini
        BuildPath(Path_SM, configPath, sizeof(configPath), "configs/sm_skinchooser/default_skins.ini");
    }

    if (g_hKVModels != INVALID_HANDLE)
        CloseHandle(g_hKVModels);

    g_hKVModels = CreateKeyValues("Models");
    if (!FileToKeyValues(g_hKVModels, configPath)) {
        LogError("[SM_SKINCHOOSER] Failed to load %s. Check syntax.", configPath);
    }

    // Load player choices (global or per-map file)
    char choicePath[PLATFORM_MAX_PATH];

    if (GetConVarInt(g_cvarMapbased) == 1) {
        BuildPath(Path_SM, choicePath, sizeof(choicePath), "data/%s_skinchooser_playermodels.ini", mapName);
    } else {
        BuildPath(Path_SM, choicePath, sizeof(choicePath), "data/skinchooser_playermodels.ini");
    }

    if (g_hKVPlayerChoice != INVALID_HANDLE)
        CloseHandle(g_hKVPlayerChoice);

    g_hKVPlayerChoice = CreateKeyValues("Models");
    // It’s fine if file doesn’t exist yet — KV remains empty until we save.
    FileToKeyValues(g_hKVPlayerChoice, choicePath);

    // Precache all valid models and add dependencies to downloads table
    SafePrecacheAllModelsFromConfig();
}

// Validate and precache models safely, with per-section guard.
void SafePrecacheAllModelsFromConfig()
{
    if (g_hKVModels == INVALID_HANDLE)
        return;

    // The top-level has sub-sections (e.g., "Public Models", "Admin Models")
    if (!KvGotoFirstSubKey(g_hKVModels))
        return;

    do {
        // Skip service sections at top; we expect group sections here,
        // inside them will be Team_T and Team_CT.
        char groupName[64];
        KvGetSectionName(g_hKVModels, groupName, sizeof(groupName));

        // Dive into group -> Team_T/Team_CT if present
        KvJumpToKey(g_hKVModels, "Team_T", false);
        if (KvGotoFirstSubKey(g_hKVModels)) {
            do {
                ValidateAndPrecacheModelEntry();
            } while (KvGotoNextKey(g_hKVModels));
            KvGoBack(g_hKVModels); // leave model list
        }
        KvGoBack(g_hKVModels); // back to group

        KvJumpToKey(g_hKVModels, "Team_CT", false);
        if (KvGotoFirstSubKey(g_hKVModels)) {
            do {
                ValidateAndPrecacheModelEntry();
            } while (KvGotoNextKey(g_hKVModels));
            KvGoBack(g_hKVModels); // leave model list
        }
        KvGoBack(g_hKVModels); // back to group
    } while (KvGotoNextKey(g_hKVModels));

    KvRewind(g_hKVModels);
}

// One entry = one model section with exactly one "path"
void ValidateAndPrecacheModelEntry()
{
    // Collect exactly one "path"
    char path[PLATFORM_MAX_PATH];
    KvGetString(g_hKVModels, "path", path, sizeof(path), "");

    // If empty or missing — skip
    if (path[0] == '\0') {
        char secName[64];
        KvGetSectionName(g_hKVModels, secName, sizeof(secName));
        LogError("[SM_SKINCHOOSER] Section '%s' has empty path. Skipping.", secName);
        return;
    }

    // Additional guard: if section contains multiple "path" lines (bad config),
    // we won't iterate KV pairs to count keys — we trust single path by spec.
    // If admins break config adding multiple "path", KV usually keeps last one.
    // To protect server, we validate existence only.
    if (!FileExists(path, true)) {
        LogError("[SM_SKINCHOOSER] Model file missing '%s'. Skipping.", path);
        return;
    }

    // Precache + add dependencies to downloads table
    PrecacheModel(path, true);
    AddModelAndDependenciesToDownloads(path);
}

// Add typical model dependencies and materials folder
void AddModelAndDependenciesToDownloads(const char[] modelPath)
{
    AddFileToDownloadsTable(modelPath);

    char base[PLATFORM_MAX_PATH];
    strcopy(base, sizeof(base), modelPath);
    ReplaceString(base, sizeof(base), ".mdl", "");

    char dep[PLATFORM_MAX_PATH];
    Format(dep, sizeof(dep), "%s.vvd", base);        AddFileToDownloadsTable(dep);
    Format(dep, sizeof(dep), "%s.vtx", base);        AddFileToDownloadsTable(dep);
    Format(dep, sizeof(dep), "%s.dx90.vtx", base);   AddFileToDownloadsTable(dep);
    Format(dep, sizeof(dep), "%s.phy", base);        AddFileToDownloadsTable(dep);

    // naive materials mapping (models/... -> materials/...)
    char mat[PLATFORM_MAX_PATH];
    strcopy(mat, sizeof(mat), base);
    ReplaceString(mat, sizeof(mat), "models/", "materials/");
    AddFileToDownloadsTable(mat);
}

// -----------------------------------------------------------------------------
// Force configs (optional)
// -----------------------------------------------------------------------------
void LoadForceConfigs()
{
    // Clear counts
    g_ForcePlayerCountT = g_ForcePlayerCountCT = 0;
    g_ForceAdminCountT  = g_ForceAdminCountCT  = 0;
    g_ForceBotsCountT   = g_ForceBotsCountCT   = 0;

    // Player force
    if (GetConVarInt(g_cvarForcePlayerSkin) == 1) {
        g_ForcePlayerCountT  = LoadSimpleModelList("configs/sm_skinchooser/force/player_t.ini",  g_ForcePlayerTeamT,  sizeof(g_ForcePlayerTeamT));
        g_ForcePlayerCountCT = LoadSimpleModelList("configs/sm_skinchooser/force/player_ct.ini", g_ForcePlayerTeamCT, sizeof(g_ForcePlayerTeamCT));
    }

    // Admin force
    if (GetConVarInt(g_cvarSkinAdmin) == 1) {
        g_ForceAdminCountT  = LoadSimpleModelList("configs/sm_skinchooser/force/admin_t.ini",  g_ForceAdminTeamT,  sizeof(g_ForceAdminTeamT));
        g_ForceAdminCountCT = LoadSimpleModelList("configs/sm_skinchooser/force/admin_ct.ini", g_ForceAdminTeamCT, sizeof(g_ForceAdminTeamCT));
    }

    // Bots force
    if (GetConVarInt(g_cvarSkinBots) == 1) {
        g_ForceBotsCountT  = LoadSimpleModelList("configs/sm_skinchooser/force/bots_t.ini",  g_ForceBotsTeamT,  sizeof(g_ForceBotsTeamT));
        g_ForceBotsCountCT = LoadSimpleModelList("configs/sm_skinchooser/force/bots_ct.ini", g_ForceBotsTeamCT, sizeof(g_ForceBotsTeamCT));
    }
}

// Each line is a model path; validates existence and precaches safely.
int LoadSimpleModelList(const char[] iniPath, char[][] outArray, int outArraySize)
{
    int count = 0;
    char file[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, file, sizeof(file), iniPath);

    Handle fh = OpenFile(file, "r");
    if (fh == INVALID_HANDLE) {
        return 0;
    }

    char line[PLATFORM_MAX_PATH];
    while (ReadFileLine(fh, line, sizeof(line))) {
        TrimString(line);
        if (line[0] == '\0')            continue;
        if (line[0] == '/' && line[1] == '/') continue; // comment

        if (!FileExists(line, true)) {
            LogError("[SM_SKINCHOOSER] Force list missing file '%s' in %s", line, file);
            continue;
        }

        if (count < (outArraySize / PLATFORM_MAX_PATH)) {
            strcopy(outArray[count], PLATFORM_MAX_PATH, line);
            PrecacheModel(line, true);
            AddModelAndDependenciesToDownloads(line);
            count++;
        } else {
            LogError("[SM_SKINCHOOSER] Force list overflow for %s", iniPath);
            break;
        }
    }
    CloseHandle(fh);
    return count;
}

// -----------------------------------------------------------------------------
// Menus
// -----------------------------------------------------------------------------
Handle BuildMainMenu(int client)
{
    if (g_hKVModels == INVALID_HANDLE || !KvGotoFirstSubKey(g_hKVModels))
        return INVALID_HANDLE;

    Handle menu = CreateMenu(Menu_Group);
    char groupName[64];

    do {
        KvGetSectionName(g_hKVModels, groupName, sizeof(groupName));

        // Filter out service sections if any were accidentally at top-level
        if (StrEqual(groupName, "Team_T") || StrEqual(groupName, "Team_CT"))
            continue;

        AddMenuItem(menu, groupName, groupName);
    } while (KvGotoNextKey(g_hKVModels));

    // Moved from submenu to main menu
    AddMenuItem(menu, "reset", "[Вернуть стандартную модель]");

    KvRewind(g_hKVModels);
    SetMenuTitle(menu, "Выбор группы моделей");
    return menu;
}

public int Menu_Group(Handle menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select) {
        char group[64];
        GetMenuItem(menu, param2, group, sizeof(group));

        // Handle reset option from main menu
        if (StrEqual(group, "reset")) {
            ResetToDefaultModel(client);
            SavePlayerChoice(client, "");
            PrintToChat(client, "[SM] Вернул стандартную модель.");
            return 0;
        }

        KvJumpToKey(g_hKVModels, group, false);

        // Determine team section
        if (GetClientTeam(client) == CS_TEAM_T) {
            KvJumpToKey(g_hKVModels, "Team_T", false);
        } else if (GetClientTeam(client) == CS_TEAM_CT) {
            KvJumpToKey(g_hKVModels, "Team_CT", false);
        } else {
            KvRewind(g_hKVModels);
            return 0; // spectator: no menu
        }

        if (!KvGotoFirstSubKey(g_hKVModels)) {
            KvRewind(g_hKVModels);
            PrintToChat(client, "[SM] В группе '%s' нет доступных моделей.", group);
            return 0;
        }

        Handle sub = CreateMenu(Menu_Model);
        char entryName[64], path[PLATFORM_MAX_PATH];

        do {
            entryName[0] = '\0';
            path[0] = '\0';
            KvGetSectionName(g_hKVModels, entryName, sizeof(entryName));
            KvGetString(g_hKVModels, "path", path, sizeof(path), "");

            if (path[0] == '\0' || !FileExists(path, true)) {
                LogError("[SM_SKINCHOOSER] Bad model entry '%s' in group '%s' (missing path)", entryName, group);
                continue;
            }

            AddMenuItem(sub, path, entryName);
        } while (KvGotoNextKey(g_hKVModels));

        SetMenuTitle(sub, group);
        DisplayMenu(sub, client, MENU_TIME_FOREVER);
        KvRewind(g_hKVModels);
    }
    else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
    return 0;
}

public int Menu_Model(Handle menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select) {
        char path[PLATFORM_MAX_PATH];
        GetMenuItem(menu, param2, path, sizeof(path));

        // Ensure we have SteamID cached
        CacheClientAuthId(client);

        if (StrEqual(path, "reset")) {
            ResetToDefaultModel(client);
            SavePlayerChoice(client, "");
            PrintToChat(client, "[SM] Вернул стандартную модель.");
            return 0;
        }

        if (!FileExists(path, true)) {
            PrintToChat(client, "[SM] Модель не найдена: %s", path);
            return 0;
        }

        if (!IsModelPrecached(path)) {
            PrecacheModel(path, true);
            AddModelAndDependenciesToDownloads(path);
        }

        SetEntityModel(client, path);
        SavePlayerChoice(client, path);
        PrintToChat(client, "[SM] Установлена модель: %s", path);
    }
    else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
    return 0;
}

// -----------------------------------------------------------------------------
// Commands
// -----------------------------------------------------------------------------
public Action Command_Model(int client, int args)
{
    if (GetConVarInt(g_cvarEnabled) != 1)
        return Plugin_Handled;

    if (!IsValidClient(client) || IsFakeClient(client))
        return Plugin_Handled;

    // Admin-only gate
    if (GetConVarInt(g_cvarAdminOnly) == 1) {
        AdminId adm = GetUserAdmin(client);
        if (adm == INVALID_ADMIN_ID) {
            PrintToChat(client, "[SM] Меню доступно только админам.");
            return Plugin_Handled;
        }
    }

    Handle menu = BuildMainMenu(client);
    if (menu == INVALID_HANDLE) {
        PrintToChat(client, "[SM] Ошибка генерации меню. Проверьте configs/sm_skinchooser/*.ini");
        return Plugin_Handled;
    }

    DisplayMenu(menu, client, GetConVarInt(g_cvarCloseMenuTimer));
    return Plugin_Handled;
}

// -----------------------------------------------------------------------------
// Events
// -----------------------------------------------------------------------------
public Action Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
    if (GetConVarInt(g_cvarEnabled) != 1)
        return Plugin_Continue;

    int client = GetClientOfUserId(event.GetInt("userid"));
    int team   = event.GetInt("team");

    if (!IsValidClient(client) || IsFakeClient(client))
        return Plugin_Continue;

    CacheClientAuthId(client);

    if (GetConVarBool(g_cvarAutodisplay) && (team == CS_TEAM_T || team == CS_TEAM_CT)) {
        if (GetConVarBool(g_cvarDisplayTimer)) {
            CreateTimer(GetConVarFloat(g_cvarMenuStartTime), Timer_ShowMenuDelayed, client);
        } else {
            Command_Model(client, 0);
        }
    }
    return Plugin_Continue;
}

public Action Timer_ShowMenuDelayed(Handle timer, any client)
{
    if (!IsValidClient(client) || IsFakeClient(client))
        return Plugin_Stop;

    Command_Model(client, 0);
    return Plugin_Stop;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    if (GetConVarInt(g_cvarEnabled) != 1)
        return Plugin_Continue;

    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsValidClient(client))
        return Plugin_Continue;

    // Capture original model (for reset)
    GetEntPropString(client, Prop_Data, "m_ModelName", g_originalModel[client], sizeof(g_originalModel[]));

    // Apply saved choice (if valid)
    ApplySavedChoiceIfAny(client);

    // Force Admin skins
    if (!IsFakeClient(client) && GetConVarInt(g_cvarSkinAdmin) == 1) {
        AdminId adm = GetUserAdmin(client);
        if (adm != INVALID_ADMIN_ID) {
            if (GetConVarInt(g_cvarSkinAdminTimerEnabled) == 1) {
                CreateTimer(GetConVarFloat(g_cvarSkinAdminTimer), Timer_ForceAdminSkin, client);
            } else {
                ForceAdminSkinNow(client);
            }
        }
    }

    // Force Player skins (non-admin)
    if (!IsFakeClient(client) && GetConVarInt(g_cvarForcePlayerSkin) == 1) {
        AdminId adm = GetUserAdmin(client);
        if (adm == INVALID_ADMIN_ID) {
            if (GetConVarInt(g_cvarForcePlayerSkinTimerEnabled) == 1) {
                CreateTimer(GetConVarFloat(g_cvarForcePlayerSkinTimer), Timer_ForcePlayerSkin, client);
            } else {
                ForcePlayerSkinNow(client);
            }
        }
    }

    // Force Bot skins
    if (IsFakeClient(client) && GetConVarInt(g_cvarSkinBots) == 1) {
        ForceBotSkinNow(client);
    }

    return Plugin_Continue;
}

// -----------------------------------------------------------------------------
// Save / load player choice
// -----------------------------------------------------------------------------
void CacheClientAuthId(int client)
{
    if (g_authId[client][0] == '\0') {
        GetClientAuthId(client, AuthId_Steam2, g_authId[client], sizeof(g_authId[]));
    }
}

void SavePlayerChoice(int client, const char[] modelPath)
{
    if (g_hKVPlayerChoice == INVALID_HANDLE)
        return;

    CacheClientAuthId(client);
    KvJumpToKey(g_hKVPlayerChoice, g_authId[client], true);

    if (GetClientTeam(client) == CS_TEAM_T) {
        KvSetString(g_hKVPlayerChoice, "Team_T", modelPath);
    } else if (GetClientTeam(client) == CS_TEAM_CT) {
        KvSetString(g_hKVPlayerChoice, "Team_CT", modelPath);
    }

    KvGoBack(g_hKVPlayerChoice);

    // Persist to file
    char mapName[PLATFORM_MAX_PATH], filePath[PLATFORM_MAX_PATH];
    GetCurrentMap(mapName, sizeof(mapName));

    if (GetConVarInt(g_cvarMapbased) == 1) {
        BuildPath(Path_SM, filePath, sizeof(filePath), "data/%s_skinchooser_playermodels.ini", mapName);
    } else {
        BuildPath(Path_SM, filePath, sizeof(filePath), "data/skinchooser_playermodels.ini");
    }

    KeyValuesToFile(g_hKVPlayerChoice, filePath);
}

void ApplySavedChoiceIfAny(int client)
{
    if (g_hKVPlayerChoice == INVALID_HANDLE)
        return;

    CacheClientAuthId(client);
    KvJumpToKey(g_hKVPlayerChoice, g_authId[client], false);

    char path[PLATFORM_MAX_PATH];
    if (GetClientTeam(client) == CS_TEAM_T) {
        KvGetString(g_hKVPlayerChoice, "Team_T", path, sizeof(path), "");
    } else if (GetClientTeam(client) == CS_TEAM_CT) {
        KvGetString(g_hKVPlayerChoice, "Team_CT", path, sizeof(path), "");
    } else {
        path[0] = '\0';
    }
    KvGoBack(g_hKVPlayerChoice);

    if (path[0] == '\0')
        return;

    if (!FileExists(path, true)) {
        LogError("[SM_SKINCHOOSER] Saved model missing '%s' for %N. Ignoring.", path, client);
        return;
    }

    if (!IsModelPrecached(path)) {
        PrecacheModel(path, true);
        AddModelAndDependenciesToDownloads(path);
    }
    SetEntityModel(client, path);
}

// -----------------------------------------------------------------------------
// Reset
// -----------------------------------------------------------------------------
void ResetToDefaultModel(int client)
{
    if (g_originalModel[client][0] != '\0') {
        SetEntityModel(client, g_originalModel[client]);
    }
}

// -----------------------------------------------------------------------------
// Force systems
// -----------------------------------------------------------------------------
public Action Timer_ForceAdminSkin(Handle timer, any client)
{
    ForceAdminSkinNow(client);
    return Plugin_Stop;
}
public Action Timer_ForcePlayerSkin(Handle timer, any client)
{
    ForcePlayerSkinNow(client);
    return Plugin_Stop;
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

// -----------------------------------------------------------------------------
// Utils
// -----------------------------------------------------------------------------
stock bool IsValidClient(int client)
{
    return (client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client));
}
