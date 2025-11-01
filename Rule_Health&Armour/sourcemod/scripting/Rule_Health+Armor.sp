#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <keyvalues>
#include <multicolors>
#include <adminmenu>

#define PLUGIN_VERSION "1.0"

ConVar g_hCvarEnabled;
ConVar g_hCvarImmortalityMode;
ConVar g_hCvarEnableLogging;

KeyValues g_kvHumans;
KeyValues g_kvBots;

TopMenu g_hAdminMenu;

bool g_bImmortalityAdmins[MAXPLAYERS + 1];

public Plugin myinfo = 
{
    name = "Rule_Health&Armor",
    author = "Gemini",
    description = "Sets health and armor based on admin flags.",
    version = PLUGIN_VERSION,
    url = "https://github.com/ZloyHohol/Counter-Strike-Plugins"
};

public void OnPluginStart()
{
    g_hCvarEnabled = CreateConVar("sm_rha_enabled", "1", "Enable/Disable the Rule_Health&Armor plugin.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_hCvarImmortalityMode = CreateConVar("sm_rha_admin_immortality_mode", "0", "Global immortality mode for eligible admins (0: Disabled, 1: Invincible).", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    g_hCvarEnableLogging = CreateConVar("sm_rha_enable_logging", "0", "Enable/Disable logging for the RHA plugin.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
    CreateConVar("sm_rha_version", PLUGIN_VERSION, "Rule_Health&Armor plugin version.", FCVAR_NOTIFY | FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_DONTRECORD);

    LoadConfig();

    HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
    HookEvent("round_start", Event_RoundStart, EventHookMode_Post);

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            SDKHook(i, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
        }
    }

    RegAdminCmd("sm_rha", Command_RHA, ADMFLAG_GENERIC, "RHA admin menu");
}

public void OnPluginEnd()
{
    if (g_kvHumans != null)
    {
        delete g_kvHumans;
    }
    if (g_kvBots != null)
    {
        delete g_kvBots;
    }
}

public void OnAllPluginsLoaded()
{
    TopMenu topmenu;
    if (LibraryExists("adminmenu") && (topmenu = GetAdminTopMenu()) != null)
    {
        OnAdminMenuReady(view_as<Handle>(topmenu));
    }
}

public void OnAdminMenuReady(Handle topmenu)
{
    TopMenu hMenu = view_as<TopMenu>(topmenu);
    if (hMenu == g_hAdminMenu) return;
    g_hAdminMenu = hMenu;

    TopMenuObject category = hMenu.FindCategory(ADMINMENU_PLAYERCOMMANDS);
    if (category != INVALID_TOPMENUOBJECT)
    {
        hMenu.AddItem(
            "sm_rha",
            AdminMenu_RHAMenu,
            category,
            "sm_rha",
            ADMFLAG_GENERIC
        );
    }
}

public void AdminMenu_RHAMenu(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
    if (action == TopMenuAction_DisplayOption)
    {
        strcopy(buffer, maxlength, "RHA Settings");
    }
    else if (action == TopMenuAction_SelectOption)
    {
        BuildRHAMenu(param);
    }
}

void BuildRHAMenu(int client)
{
    Menu menu = new Menu(RHAMenuHandler);
    menu.SetTitle("RHA Settings");

    char buffer[64];
    Format(buffer, sizeof(buffer), "Plugin Status: %s", g_hCvarEnabled.BoolValue ? "Enabled" : "Disabled");
    menu.AddItem("sm_rha_enabled", buffer);

    Format(buffer, sizeof(buffer), "Immortality Mode: %s", g_hCvarImmortalityMode.BoolValue ? "Invincible" : "Disabled");
    menu.AddItem("sm_rha_admin_immortality_mode", buffer);

    menu.Display(client, MENU_TIME_FOREVER);
}

public int RHAMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        char info[32];
        menu.GetItem(param2, info, sizeof(info));

        if (StrEqual(info, "sm_rha_enabled"))
        {
            g_hCvarEnabled.BoolValue = !g_hCvarEnabled.BoolValue;
            RHA_LogAction(param1, -1, "Toggled RHA plugin %s", g_hCvarEnabled.BoolValue ? "On" : "Off");
        }
        else if (StrEqual(info, "sm_rha_admin_immortality_mode"))
        {
            g_hCvarImmortalityMode.BoolValue = !g_hCvarImmortalityMode.BoolValue;
            RHA_LogAction(param1, -1, "Toggled RHA immortality %s", g_hCvarImmortalityMode.BoolValue ? "On" : "Off");
        }

        BuildRHAMenu(param1);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

public Action Command_RHA(int client, int args)
{
    if (client > 0 && IsClientInGame(client))
    {
        BuildRHAMenu(client);
    }
    return Plugin_Handled;
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
}

public void OnClientDisconnect(int client)
{
    SDKUnhook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    // Empty
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_hCvarEnabled.BoolValue) return;

    int userid = event.GetInt("userid");
    int client = GetClientOfUserId(userid);

    if (client == 0 || !IsClientInGame(client) || !IsPlayerAlive(client)) return;

    CreateTimer(0.1, Timer_ApplySettings, userid);
}

public Action Timer_ApplySettings(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if (client > 0 && IsClientInGame(client) && IsPlayerAlive(client))
    {
        ApplyHealthArmorToClient(client, false);
    }
    return Plugin_Stop;
}

void LoadConfig()
{
    // --- Load Humans Config ---
    char human_path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, human_path, sizeof(human_path), "configs/RHA_humans.cfg");

    g_kvHumans = new KeyValues("Groups");
    if (!FileExists(human_path))
    {
        // Create default RHA_humans.cfg
        KeyValues kv = new KeyValues("Groups");
        kv.JumpToKey("Guest", true);
        kv.SetString("Flags", "");
        kv.JumpToKey("Team_T", true);
        kv.SetNum("health", 100);
        kv.SetNum("armor", 0);
        kv.GoBack();
        kv.JumpToKey("Team_CT", true);
        kv.SetNum("health", 100);
        kv.SetNum("armor", 0);
        kv.GoBack();
        kv.GoBack();
        kv.JumpToKey("Admin_z", true);
        kv.SetString("Flags", "z");
        kv.SetNum("CanUseImmortality", 1);
        kv.JumpToKey("Team_T", true);
        kv.SetNum("health", 120);
        kv.SetNum("armor", 100);
        kv.GoBack();
        kv.JumpToKey("Team_CT", true);
        kv.SetNum("health", 120);
        kv.SetNum("armor", 100);
        kv.GoBack();
        kv.GoBack();
        kv.ExportToFile(human_path);
        delete kv;
    }
    if (!g_kvHumans.ImportFromFile(human_path))
    {
        LogError("Failed to load config file: %s", human_path);
    }

    // --- Load Bots Config ---
    char bot_path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, bot_path, sizeof(bot_path), "configs/RHA_bots.cfg");

    g_kvBots = new KeyValues("Bots");
    if (!FileExists(bot_path))
    {
        // Create default RHA_bots.cfg
        KeyValues kv = new KeyValues("Bots");
        kv.JumpToKey("Team_T", true);
        kv.SetNum("health", 90);
        kv.SetNum("armor", 50);
        kv.GoBack();
        kv.JumpToKey("Team_CT", true);
        kv.SetNum("health", 90);
        kv.SetNum("armor", 50);
        kv.GoBack();
        kv.ExportToFile(bot_path);
        delete kv;
    }
    if (!g_kvBots.ImportFromFile(bot_path))
    {
        LogError("Failed to load config file: %s", bot_path);
    }
}

KeyValues GetClientGroupSettings(int client, bool isBot)
{
    if (isBot)
    {
        g_kvBots.Rewind();
        KeyValues kvBot = new KeyValues("Bots");
        KvCopySubkeys(g_kvBots, kvBot);
        return kvBot;
    }

    // Logic for humans
    g_kvHumans.Rewind();
    
    KeyValues kvBestGroup = null;
    int bestMatchCount = -1;

    if (g_kvHumans.GotoFirstSubKey(false))
    {
        do
        {
            char sGroupName[64];
            g_kvHumans.GetSectionName(sGroupName, sizeof(sGroupName));
            char sFlags[64];
            g_kvHumans.GetString("Flags", sFlags, sizeof(sFlags), "");

            int flagsMask = ReadFlagString(sFlags);
            int playerFlags = GetUserFlagBits(client);

            // Check if the player has all the required flags for this group
            if ((playerFlags & flagsMask) == flagsMask)
            {
                int currentMatchCount = strlen(sFlags);
                // If this group requires more flags than the best match so far, it's a better match
                if (currentMatchCount > bestMatchCount)
                {
                    bestMatchCount = currentMatchCount;
                    if (kvBestGroup != null) 
                    {
                        delete kvBestGroup;
                    }
                    kvBestGroup = new KeyValues(sGroupName);
                    KvCopySubkeys(g_kvHumans, kvBestGroup);
                }
            }
        } while (g_kvHumans.GotoNextKey(false));
    }

    return kvBestGroup;
}

void ApplyHealthArmorToClient(int client, bool silent)
{
    bool isBot = IsFakeClient(client);
    KeyValues kvGroup = GetClientGroupSettings(client, isBot);

    if (kvGroup == null) return;

    char groupName[64];
    kvGroup.GetSectionName(groupName, sizeof(groupName));

    int team = GetClientTeam(client);
    char sTeam[16];
    if (team == CS_TEAM_T) strcopy(sTeam, sizeof(sTeam), "Team_T");
    else if (team == CS_TEAM_CT) strcopy(sTeam, sizeof(sTeam), "Team_CT");
    else 
    {
        delete kvGroup;
        return;
    }

    if (kvGroup.JumpToKey(sTeam))
    {
        int health = kvGroup.GetNum("health", 100);
        int armor = kvGroup.GetNum("armor", 0);

        SetEntProp(client, Prop_Data, "m_iHealth", health);
        SetEntProp(client, Prop_Send, "m_ArmorValue", armor);

        if (g_hCvarEnableLogging.BoolValue)
        {
            char clientName[MAX_NAME_LENGTH];
            GetClientName(client, clientName, sizeof(clientName));
            RHA_LogAction(-1, client, "Applied settings to \"%s\" (group: %s, health: %d, armor: %d)", clientName, groupName, health, armor);
        }

        if (!silent)
        {
            CPrintToChat(client, " {blueviolet}[RHA]{default} You are in group {olive}\"%s\"{default}. Health: {darkgreen}%d{default}, Armor: {brown}%d{default}", groupName, health, armor);
        }
    }

    g_bImmortalityAdmins[client] = kvGroup.GetNum("CanUseImmortality", 0) == 1;

    delete kvGroup;
}

public Action Hook_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
    if (g_hCvarEnabled.BoolValue && g_hCvarImmortalityMode.BoolValue && g_bImmortalityAdmins[victim])
    {
        return Plugin_Handled;
    }
    return Plugin_Continue;
}

void RHA_LogAction(int client, int target, const char[] format, any ...)
{
    if (!g_hCvarEnableLogging.BoolValue) return;

    char buffer[256];
    VFormat(buffer, sizeof(buffer), format, 4);

    char clientName[MAX_NAME_LENGTH];
    if (client > 0)
    {
        GetClientName(client, clientName, sizeof(clientName));
    }
    else
    {
        Format(clientName, sizeof(clientName), "Console");
    }

    if (target > 0)
    {
        char targetName[MAX_NAME_LENGTH];
        GetClientName(target, targetName, sizeof(targetName));
        LogMessage("[%s] %s -> %s", clientName, buffer, targetName);
    }
    else
    {
        LogMessage("[%s] %s", clientName, buffer);
    }
}
