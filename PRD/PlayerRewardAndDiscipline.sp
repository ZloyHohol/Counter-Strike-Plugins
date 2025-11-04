#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <multicolors>
#include <easy_hudmessage>
#include <keyvalues>
#include <menus>
#include <adt_trie>
#include "mvp_data.inc"

#define PLUGIN_VERSION "1.7"

// --- Глобальные переменные ---
// MVP
bool g_bHasVoted[MAXPLAYERS + 1];
int g_iYesVotes = 0;
ConVar g_hMVPVoteEnable;
ConVar g_hMVPVoteAmount;
ConVar g_hMVPMaxReward;

// Teamkill
ConVar g_hTeamkillEnable;
ConVar g_hTeamkillPunishMode;
ConVar g_hTeamkillForgiveThreshold;
ConVar g_hTeamDamageMutualThreshold;
ConVar g_hBotPunishment;
int g_iTeamKills[MAXPLAYERS + 1];
ArrayList g_hTeamkillIncidents;
ArrayList g_hPunishments;
ConVar g_hPunishmentsFile;
int g_iTeamkillAttacker[MAXPLAYERS + 1];

// Mutual Damage (sparse structure)
Handle g_hMutualDamageMap = INVALID_HANDLE;

// Camper
ConVar g_hAntiCamperEnable;
ConVar g_hAntiCamperTime;
float g_vLastPosition[MAXPLAYERS + 1][3];
int g_iCampingTime[MAXPLAYERS + 1];
bool g_bIsCamping[MAXPLAYERS + 1];
Handle g_hCampingTimers[MAXPLAYERS + 1];
int g_hBeaconSprite;

// Rules
ConVar g_hFreezeTime;
ArrayList g_hPlayerRules;
ArrayList g_hAdminRules;
ConVar g_hPlayerRulesFile;
ConVar g_hAdminRulesFile;
ConVar g_hRulesInterval;
int g_iRoundCounter = 0;
Handle g_hRulesTimer = INVALID_HANDLE;

// --- Информация о плагине ---
public Plugin myinfo =
{
    name        = "Player Reward and Discipline",
    author      = "Gemini (адаптация)",
    description = "Rewards MVP players and penalizes campers and teamkillers.",
    version     = PLUGIN_VERSION,
    url         = "https://github.com/M-G-E/Counter-Strike-Plugins"
};

// --- OnPluginStart ---
public void OnPluginStart()
{
    LoadTranslations("PlayerRewardAndDiscipline.phrases.txt");

    // ConVars
    CreateConVar("sm_prd_version", PLUGIN_VERSION, "Plugin version", FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY);
    g_hMVPVoteEnable = CreateConVar("sm_prd_mvp_enable", "1", "Enable/disable MVP reward system.", _, true, 0.0, true, 1.0);
    g_hMVPVoteAmount = CreateConVar("sm_prd_mvp_amount", "1000", "Amount of money per vote for MVP.", _, true, 0.0);
    g_hMVPMaxReward = CreateConVar("sm_prd_mvp_max_reward", "16000", "Maximum MVP reward.", _, true, 0.0);

    g_hTeamkillEnable = CreateConVar("sm_prd_teamkill_enable", "1", "Enable/disable teamkill punishment system.", _, true, 0.0, true, 1.0);
    g_hTeamkillPunishMode = CreateConVar("sm_teamkill_punish_mode", "2", "0=off, 1=auto-punish, 2=victim vote", _, true, 0.0, true, 2.0);
    g_hTeamkillForgiveThreshold = CreateConVar("sm_teamkill_forgive_threshold", "2", "How many teamkills are needed for it to be considered justice.", _, true, 1.0);
    g_hTeamDamageMutualThreshold = CreateConVar("sm_teamdamage_mutual_threshold", "25", "Damage for mutual aggression.", _, true, 1.0);
    g_hBotPunishment = CreateConVar("sm_prd_bot_punishment", "0", "Enable/disable punishments for bots.", _, true, 0.0, true, 1.0);

    g_hAntiCamperEnable = CreateConVar("sm_prd_anticamper_enable", "1", "Enable/disable anti-camper system.", _, true, 0.0, true, 1.0);
    g_hAntiCamperTime = CreateConVar("sm_anticamper_time", "10.0", "Time (sec) after which a player is considered a camper.", _, true, 5.0);

    g_hPlayerRulesFile = CreateConVar("sm_prd_player_rules_file", "configs/prd_rules_players.txt", "File with rules for players.");
    g_hAdminRulesFile = CreateConVar("sm_prd_admin_rules_file", "configs/prd_rules_admins.txt", "File with rules for admins.");
    g_hRulesInterval = CreateConVar("sm_prd_rules_interval", "1", "How many rounds to wait before showing the next rule.", _, true, 1.0);
    g_hPunishmentsFile = CreateConVar("sm_prd_punishments_file", "configs/prd_punishments.cfg", "File with teamkill punishments.");

    g_hFreezeTime = FindConVar("mp_freezetime");

    // Initialize arrays and handles
    if (g_hTeamkillIncidents == null) g_hTeamkillIncidents = new ArrayList();
    if (g_hPunishments == null) g_hPunishments = new ArrayList(8);
    if (g_hPlayerRules == null) g_hPlayerRules = new ArrayList(256);
    if (g_hAdminRules == null) g_hAdminRules = new ArrayList(256);
    for (int i = 0; i <= MaxClients; i++)
    {
        g_hBeaconTimers[i] = INVALID_HANDLE;
    }

    InitMutualDamage();

    RegAdminCmd("sm_prd", Command_AdminMenu, ADMFLAG_CONFIG, "Open the Player Reward and Discipline admin menu.");

    // Hooks
    HookEvent("round_start", Event_RoundStart);
    HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("round_end", Event_OnRoundEnd);
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Pre);
    HookEvent("bomb_defused", Event_BombDefused);
    HookEvent("bomb_planted", Event_BombPlanted);
    HookEvent("hostage_rescued", Event_HostageRescued);

    LoadRules();
    LoadPunishments();
    CreateOrRestartRulesTimer();
}

public void OnPluginEnd()
{
    StopRulesTimer();

    // Kill all beacon timers
    for (int i = 1; i <= MaxClients; i++)
    {
        if (g_hBeaconTimers[i] != INVALID_HANDLE)
        {
            KillTimer(g_hBeaconTimers[i]);
            g_hBeaconTimers[i] = INVALID_HANDLE;
        }
    }

    // Clean KeyValues in punishments ArrayList
    if (g_hPunishments != null)
    {
        for (int i = 0; i < g_hPunishments.Length; i++)
        {
            KeyValues kv = g_hPunishments.Get(i);
            if (kv != null) delete kv;
        }
        g_hPunishments.Clear();
        delete g_hPunishments;
        g_hPunishments = null;
    }

    // Clean other arrays
    if (g_hTeamkillIncidents != null) { g_hTeamkillIncidents.Clear(); delete g_hTeamkillIncidents; g_hTeamkillIncidents = null; }
    if (g_hPlayerRules != null)  { g_hPlayerRules.Clear();  delete g_hPlayerRules;  g_hPlayerRules = null; }
    if (g_hAdminRules != null)   { g_hAdminRules.Clear();   delete g_hAdminRules;   g_hAdminRules = null; }

    // Destroy mutual damage map
    DestroyMutualDamage();
}

public void OnClientPutInServer(int client)
{
    g_fJoinTime[client] = GetGameTime();
}

public void OnClientDisconnect(int client)
{
    if (IsValidClient(client))
    {
        if (g_hBeaconTimers[client] != INVALID_HANDLE)
        {
            KillTimer(g_hBeaconTimers[client]);
            g_hBeaconTimers[client] = INVALID_HANDLE;
        }
        g_iTeamkillAttacker[client] = 0; // Clear attacker data on disconnect
    }
}

public void OnMapStart()
{
    PrecacheAndAddSound("plugins/weapons_SFX/Flame/a-sudden-burst-of-fire.wav");
    g_hBeaconSprite = PrecacheModel("sprites/laserbeam.vmt");
    // Перезагрузки конфигов
    LoadRules();
    LoadPunishments();

    // Recreate rules timer (safe)
    CreateOrRestartRulesTimer();
}

// --- Rules timer helpers ---
void CreateOrRestartRulesTimer()
{
    if (g_hRulesTimer != INVALID_HANDLE)
    {
        KillTimer(g_hRulesTimer);
        g_hRulesTimer = INVALID_HANDLE;
    }
    g_hRulesTimer = CreateTimer(1.0, Timer_DisplayRules, _, TIMER_REPEAT);
}

void StopRulesTimer()
{
    if (g_hRulesTimer != INVALID_HANDLE)
    {
        KillTimer(g_hRulesTimer);
        g_hRulesTimer = INVALID_HANDLE;
    }
}

// --- Mutual Damage (Trie) functions ---
void InitMutualDamage()
{
    if (g_hMutualDamageMap != INVALID_HANDLE) CloseHandle(g_hMutualDamageMap);
    g_hMutualDamageMap = CreateTrie();
}

void StoreMutualDamageAdd(int attacker, int victim, int damage)
{
    if (!IsValidClient(attacker) || !IsValidClient(victim)) return;
    char key[32];
    Format(key, sizeof(key), "%d:%d", attacker, victim);

    char sval[32];
    StringMap map = view_as<StringMap>(g_hMutualDamageMap);
    if (map.GetString(key, sval, sizeof(sval)))
    {
        int cur = StringToInt(sval);
        cur += damage;
        IntToString(cur, sval, sizeof(sval));
        map.SetString(key, sval);
    }
    else
    {
        IntToString(damage, sval, sizeof(sval));
        map.SetString(key, sval);
    }
}

int GetMutualDamage(int attacker, int victim)
{
    if (g_hMutualDamageMap == INVALID_HANDLE) return 0;
    char key[32], sval[32];
    Format(key, sizeof(key), "%d:%d", attacker, victim);
    StringMap map = view_as<StringMap>(g_hMutualDamageMap);
    if (map.GetString(key, sval, sizeof(sval)))
        return StringToInt(sval);
    return 0;
}

void ClearMutualDamageAll()
{
    if (g_hMutualDamageMap != INVALID_HANDLE)
    {
        CloseHandle(g_hMutualDamageMap);
        g_hMutualDamageMap = INVALID_HANDLE;
    }
    InitMutualDamage();
}

void DestroyMutualDamage()
{
    if (g_hMutualDamageMap != INVALID_HANDLE)
    {
        CloseHandle(g_hMutualDamageMap);
        g_hMutualDamageMap = INVALID_HANDLE;
    }
}

// --- Load Rules ---
void LoadRules()
{
    g_hPlayerRules.Clear();
    g_hAdminRules.Clear();

    char path[PLATFORM_MAX_PATH];
    g_hPlayerRulesFile.GetString(path, sizeof(path));

    char file_path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, file_path, sizeof(file_path), path);

    File file = OpenFile(file_path, "r");
    if (file != null)
    {
        char line[256];
        while (file.ReadLine(line, sizeof(line)))
        {
            TrimString(line);
            if (line[0] != 0)
            {
                g_hPlayerRules.PushString(line);
            }
        }
        delete file;
    }

    g_hAdminRulesFile.GetString(path, sizeof(path));
    BuildPath(Path_SM, file_path, sizeof(file_path), path);

    file = OpenFile(file_path, "r");
    if (file != null)
    {
        char line[256];
        while (file.ReadLine(line, sizeof(line)))
        {
            TrimString(line);
            if (line[0] != 0)
            {
                g_hAdminRules.PushString(line);
            }
        }
        delete file;
    }
}

// --- Load Punishments ---
void LoadPunishments()
{
    // Clear existing punishments and their KeyValues handles
    if (g_hPunishments != null)
    {
        for (int i = 0; i < g_hPunishments.Length; i++)
        {
            KeyValues kv = g_hPunishments.Get(i);
            if (kv != null) delete kv;
        }
        g_hPunishments.Clear();
    }

    char path[PLATFORM_MAX_PATH];
    g_hPunishmentsFile.GetString(path, sizeof(path));
    char file_path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, file_path, sizeof(file_path), path);

    KeyValues kv = new KeyValues("Punishments");
    if (kv.ImportFromFile(file_path))
    {
        if (kv.GotoFirstSubKey())
        {
            do
            {
                char name[32];
                kv.GetSectionName(name, sizeof(name));
                KeyValues punishment = new KeyValues(name);
                KvCopySubkeys(kv, punishment);
                g_hPunishments.Push(punishment);
            } while (kv.GotoNextKey());
        }
    }
    delete kv;
}

// --- Event Handlers ---

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    g_iRoundCounter++;

    g_iMVP = -1; // Reset MVP
    g_iBombPlanter = -1; // Reset bomb planter

    for (int i = 0; i < 5; i++)
    {
        g_fTeamDamage[i] = 0.0;
    }

    // reset per-round counters
    for (int i = 1; i <= MaxClients; i++)
    {
        g_iTeamKills[i] = 0;
        g_bHasVoted[i] = false; // Reset MVP votes
        g_PlayerStats[i].kills = 0;
        g_PlayerStats[i].last_kill_time = 0.0;
        g_iAssists[i] = 0;
    }

    // Get hostage count
    g_iHostagesRemaining = 0;
    int maxEntities = GetMaxEntities();
    for (int i = 1; i <= maxEntities; i++)
    {
        char classname[64];
        GetEntityClassname(i, classname, sizeof(classname));
        if (IsValidEdict(i) && StrEqual(classname, "hostage_entity", false))
        {
            g_iHostagesRemaining++;
        }
    }

    // clear mutual damage
    ClearMutualDamageAll();

    // process incidents by snapshotting list
    if (g_hTeamkillIncidents != null && g_hTeamkillIncidents.Length > 0 && g_hTeamkillPunishMode.IntValue == 2)
    {
        int len = g_hTeamkillIncidents.Length;
        ArrayList incidentsSnapshot = new ArrayList();
        for (int idx = 0; idx < len; idx++)
        {
            KeyValues kv = g_hTeamkillIncidents.Get(idx);
            if (kv != null) incidentsSnapshot.Push(kv);
        }
        g_hTeamkillIncidents.Clear(); // Clear original list after snapshotting

        for (int idx = 0; idx < incidentsSnapshot.Length; idx++)
        {
            KeyValues kv = incidentsSnapshot.Get(idx);
            if (kv == null) continue;

            int victim_userid = kv.GetNum("victim_userid");
            int attacker_userid = kv.GetNum("attacker_userid");

            int victim = GetClientOfUserId(victim_userid);
            int attacker = GetClientOfUserId(attacker_userid);

            if (IsValidClient(victim) && IsValidClient(attacker) && attacker != 0 && victim != 0)
            {
                char sName[MAX_NAME_LENGTH];
                GetClientName(attacker, sName, sizeof(sName));

                Menu menu = new Menu(MenuHandler_TeamkillPunishment);
                menu.SetTitle("%t", "MVP_MenuTitle", sName);
                menu.AddItem("forgive", "Forgive");

                for (int j = 0; j < g_hPunishments.Length; j++)
                {
                    KeyValues p = g_hPunishments.Get(j);
                    char p_name[32], p_translation[64];
                    p.GetSectionName(p_name, sizeof(p_name));
                    p.GetString("translation", p_translation, sizeof(p_translation));
                    menu.AddItem(p_name, p_translation);
                }

                g_iTeamkillAttacker[victim] = attacker; // Store attacker for menu handler
                menu.Display(victim, 15);
            }
            delete kv; // Delete KeyValues handle after processing
        }
        delete incidentsSnapshot; // Delete the snapshot ArrayList
    }

    // Голосование за MVP
    if (g_hMVPVoteEnable.BoolValue && g_iMVP != -1 && IsValidClient(g_iMVP))
    {
        int team = GetClientTeam(g_iMVP);
        char sMVPName[MAX_NAME_LENGTH];
        GetClientName(g_iMVP, sMVPName, sizeof(sMVPName));

        Menu menu = new Menu(MenuHandler_MVPVote);
        menu.SetTitle("%t", "MVP_MenuTitle", sMVPName);
        menu.AddItem("yes", "Yes");
        menu.AddItem("no",  "No");

        for (int i = 1; i <= MaxClients; i++)
        {
            if (IsValidClient(i) && GetClientTeam(i) == team)
            {
                menu.Display(i, 15);
            }
        }
    }

    return Plugin_Continue;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsValidClient(client)) return Plugin_Continue;

    g_iCampingTime[client] = 0;
    g_bIsCamping[client] = false;
    if (g_hBeaconTimers[client] != INVALID_HANDLE)
    {
        KillTimer(g_hBeaconTimers[client]);
        g_hBeaconTimers[client] = INVALID_HANDLE;
    }

    if (g_hAntiCamperEnable.BoolValue)
        g_hCampingTimers[client] = CreateTimer(1.0, Timer_Camping, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
    return Plugin_Continue;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_hTeamkillEnable.BoolValue)
        return Plugin_Continue;

    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int victim   = GetClientOfUserId(event.GetInt("userid"));
    int assister = GetClientOfUserId(event.GetInt("assister"));

    if (assister > 0 && assister != attacker)
    {
        g_iAssists[assister]++;
    }

    if (!IsValidClient(attacker) || !IsValidClient(victim) || attacker == victim)
        return Plugin_Continue;

    if (IsFakeClient(attacker) && !g_hBotPunishment.BoolValue)
        return Plugin_Continue;

    if (GetClientTeam(attacker) == GetClientTeam(victim))
    {
        // --- Проверка "Правосудие" ---
        if (g_iTeamKills[victim] >= g_hTeamkillForgiveThreshold.IntValue)
        {
            CPrintToChatAll("%t", "Teamkill_Justice", attacker, victim);
            return Plugin_Continue;
        }

        // --- Проверка "Взаимная агрессия" ---
        int mutual = GetMutualDamage(victim, attacker);
        if (mutual >= g_hTeamDamageMutualThreshold.IntValue)
        {
            g_iTeamKills[attacker]++;
            CPrintToChatAll("%t", "Teamkill_Mutual", attacker, victim);
            return Plugin_Continue;
        }

        // --- Невинная жертва ---
        g_iTeamKills[attacker]++;

        int punishMode = g_hTeamkillPunishMode.IntValue;

        if (punishMode == 1)
        {
            ForcePlayerSuicide(attacker);
            CPrintToChatAll("%t", "Teamkill_AutoPunish", attacker, victim);
        }
        else if (punishMode == 2)
        {
            KeyValues kv = new KeyValues("TeamkillIncident");
            kv.SetNum("victim_userid", GetClientUserId(victim));
            kv.SetNum("attacker_userid", GetClientUserId(attacker));
            g_hTeamkillIncidents.Push(kv);

            CPrintToChat(victim, "%t", "Teamkill_VictimNotice", attacker);
        }
    }
    else
    {
        g_PlayerStats[attacker].kills++;
        g_PlayerStats[attacker].last_kill_time = GetGameTime();
    }

    return Plugin_Continue;
}

public Action Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_hTeamkillEnable.BoolValue)
        return Plugin_Continue;

    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int victim   = GetClientOfUserId(event.GetInt("userid"));

    if (!IsValidClient(attacker) || !IsValidClient(victim) || attacker == victim)
        return Plugin_Continue;

    int team = GetClientTeam(attacker);
    if (team >= 2 && team <= 3)
    {
        g_fTeamDamage[team] += event.GetInt("damage");
    }

    if (GetClientTeam(attacker) == GetClientTeam(victim))
    {
        int damage = event.GetInt("damage");
        StoreMutualDamageAdd(attacker, victim, damage);
    }

    return Plugin_Continue;
}

public Action Event_OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    int winner = event.GetInt("winner");
    if (winner == 0) return Plugin_Continue; // No MVP on draw

    int reason = event.GetInt("reason");

    if (reason == 1 && g_fTeamDamage[winner] == 0.0) return Plugin_Continue; // Target saved, no damage

    // Objective-based MVP
    if (g_iMVP != -1)
    {
        // Bomb defused
        if (reason == 8) // CSRoundEnd_BombDefused
        {
            if (g_PlayerStats[g_iMVP].kills == 0)
            {
                // Defuser has no kills, find player with most kills on winning team
                g_iMVP = FindMVPByKills(winner);
            }
        }
        // Hostages rescued - g_iMVP is already set to the last rescuer
    }
    else if (reason == 9) // CSRoundEnd_Bomb
    {
        if (g_iBombPlanter != -1 && IsValidClient(g_iBombPlanter))
        {
            g_iMVP = g_iBombPlanter;
        }
    }
    else
    {
        // Elimination or time-out win
        g_iMVP = FindMVPByKills(winner);
    }

    return Plugin_Continue;
}

public void Event_BombPlanted(Event event, const char[] name, bool dontBroadcast)
{
    int planter = GetClientOfUserId(event.GetInt("userid"));
    g_iBombPlanter = planter;
}

public void Event_BombDefused(Event event, const char[] name, bool dontBroadcast)
{
    int defuser = GetClientOfUserId(event.GetInt("userid"));
    g_iMVP = defuser;
}

public void Event_HostageRescued(Event event, const char[] name, bool dontBroadcast)
{
    g_iHostagesRemaining--;
    if (g_iHostagesRemaining == 0)
    {
        int rescuer = GetClientOfUserId(event.GetInt("userid"));
        g_iMVP = rescuer;
    }
}

int FindMVPByKills(int winning_team)
{
    int mvp = 0;
    int max_kills = -1;
    int max_points = -1;
    float earliest_join_time = 999999.0;

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidClient(i) && GetClientTeam(i) == winning_team)
        {
            int kills = g_PlayerStats[i].kills;
            int points = (kills * 2) + g_iAssists[i];

            if (kills > max_kills)
            {
                max_kills = kills;
                max_points = points;
                mvp = i;
                earliest_join_time = g_fJoinTime[i];
            }
            else if (kills == max_kills && kills > 0)
            {
                if (points > max_points)
                {
                    max_points = points;
                    mvp = i;
                    earliest_join_time = g_fJoinTime[i];
                }
                else if (points == max_points)
                {
                    if (g_fJoinTime[i] < earliest_join_time)
                    {
                        mvp = i;
                        earliest_join_time = g_fJoinTime[i];
                    }
                }
            }
        }
    }
    return mvp;
}

// --- Menu Handlers ---

public int MenuHandler_TeamkillPunishment(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_Select)
    {
        if (!IsValidClient(client)) return 0;

        int attacker = g_iTeamkillAttacker[client];

        if (!IsValidClient(attacker))
        {
            CPrintToChat(client, "{red}[Server]{default} The aggressor has left the server.");
            return 0;
        }

        char info[32];
        menu.GetItem(item, info, sizeof(info));

        if (StrEqual(info, "forgive"))
        {
            CPrintToChatAll("%t", "Teamkill_Forgive", client, attacker);
        }
        else
        {
            for (int i = 0; i < g_hPunishments.Length; i++)
            {
                KeyValues p = g_hPunishments.Get(i);
                char p_name[32];
                p.GetSectionName(p_name, sizeof(p_name));
                if (StrEqual(info, p_name))
                {
                    char command[256], translation[64];
                    p.GetString("command", command, sizeof(command));
                    p.GetString("translation", translation, sizeof(translation));
                    char formatted_command[256];
                    FormatEx(formatted_command, sizeof(formatted_command), command, attacker);
                    ServerCommand(formatted_command);
                    CPrintToChatAll("%t", translation, client, attacker);
                    break;
                }
            }
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
        g_iTeamkillAttacker[client] = 0; // Clear attacker data
    }
    return 0;
}

public int MenuHandler_MVPVote(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_Select)
    {
        if (!IsValidClient(client)) return 0;
        if (g_bHasVoted[client])
            return 0;

        g_bHasVoted[client] = true;

        char info[32];
        menu.GetItem(item, info, sizeof(info));

        if (StrEqual(info, "yes"))
            g_iYesVotes++;
    }
    else if (action == MenuAction_End)
    {
        if (g_iMVP != -1 && IsValidClient(g_iMVP) && g_hMVPVoteEnable.BoolValue)
        {
            int team = GetClientTeam(g_iMVP);
            int bot_count = 0;
            for (int i = 1; i <= MaxClients; i++)
            {
                if (IsValidClient(i) && GetClientTeam(i) == team && IsFakeClient(i))
                    bot_count++;
            }

            int reward = (g_iYesVotes + bot_count) * g_hMVPVoteAmount.IntValue;
            if (reward > g_hMVPMaxReward.IntValue)
            {
                reward = g_hMVPMaxReward.IntValue;
            }

            if (reward > 0)
            {
                int money = GetEntProp(g_iMVP, Prop_Send, "m_iAccount");
                int newMoney = money + reward;
                if (newMoney > 16000) newMoney = 16000;
                SetEntProp(g_iMVP, Prop_Send, "m_iAccount", newMoney);
                CPrintToChat(g_iMVP, "%t", "MVP_Reward", reward);
            }
        }

        g_iMVP = -1;
        g_iYesVotes = 0;
        for (int i = 1; i <= MaxClients; i++)
            g_bHasVoted[i] = false;

        delete menu;
    }
    return 0;
}

// --- Timers ---

public Action Timer_Camping(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if (!IsValidClient(client) || !IsPlayerAlive(client))
    {
        return Plugin_Stop;
    }

    AdminId admin = GetUserAdmin(client);
    if (admin != INVALID_ADMIN_ID && (GetAdminFlags(admin, Access_Effective) & ADMFLAG_ROOT))
        return Plugin_Continue;

    float pos[3];
    GetClientAbsOrigin(client, pos);

    if (GetVectorDistance(pos, g_vLastPosition[client]) < 1.0)
    {
        g_iCampingTime[client]++;
        if (g_iCampingTime[client] >= g_hAntiCamperTime.IntValue && !g_bIsCamping[client])
        {
            g_bIsCamping[client] = true;
            EmitSoundToAll("plugins/weapons_SFX/Flame/a-sudden-burst-of-fire.wav", client);
        }
    }
    else
    {
        g_iCampingTime[client] = 0;
        if (g_bIsCamping[client])
        {
            g_bIsCamping[client] = false;
            StopSound(client, SNDCHAN_AUTO, "plugins/weapons_SFX/Flame/a-sudden-burst-of-fire.wav");
        }
    }

    if (g_bIsCamping[client])
    {
        float origin[3];
        GetClientAbsOrigin(client, origin);

        TE_SetupBeamRingPoint(origin, 50.0, 250.0, g_hBeaconSprite, g_hBeaconSprite,
                              0, 10, 1.0, 5.0, 0.0, {255,0,0,255}, 10, 0);
        TE_SendToAll();
    }

    StoreVector(pos, g_vLastPosition[client]);
    return Plugin_Continue;
}

public Action Timer_DisplayRules(Handle timer)
{
    if (g_hFreezeTime != null && GetGameTime() > g_hFreezeTime.FloatValue)
        return Plugin_Stop;

    if (g_hPlayerRules.Length == 0 && g_hAdminRules.Length == 0) return Plugin_Continue;

    if (g_iRoundCounter % g_hRulesInterval.IntValue != 0)
        return Plugin_Continue;

    int player_rule_index = (g_hPlayerRules.Length > 0) ? (g_iRoundCounter / g_hRulesInterval.IntValue) % g_hPlayerRules.Length : -1;
    int admin_rule_index = (g_hAdminRules.Length > 0) ? (g_iRoundCounter / g_hRulesInterval.IntValue) % g_hAdminRules.Length : -1;

    char player_rule[256];
    if (player_rule_index != -1) g_hPlayerRules.GetString(player_rule_index, player_rule, sizeof(player_rule));

    char admin_rule[256];
    if (admin_rule_index != -1) g_hAdminRules.GetString(admin_rule_index, admin_rule, sizeof(admin_rule));

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidClient(i))
        {
            AdminId admin = GetUserAdmin(i);
            if (admin != INVALID_ADMIN_ID && (GetAdminFlags(admin, Access_Effective) & ADMFLAG_ROOT))
            {
                if (admin_rule_index != -1) SendHudMessage(i, 4, -1.0, 0.25,
                               0xFFFF00FF, 0xFFFFFFFF, 0,
                               0.5, 0.5, 3.0, 0.0,
                               admin_rule);
            }
            else
            {
                if (player_rule_index != -1) SendHudMessage(i, 4, -1.0, 0.25,
                               0xFFFF00FF, 0xFFFFFFFF, 0,
                               0.5, 0.5, 3.0, 0.0,
                               player_rule);
            }
        }
    }
    return Plugin_Continue;
}

// --- Admin Menu ---
public Action Command_AdminMenu(int client, int args)
{
    if (!IsValidClient(client)) return Plugin_Handled;
    AdminMenu(client);
    return Plugin_Handled;
}

void AdminMenu(int client)
{
    Menu menu = new Menu(AdminMenuHandler);
    menu.SetTitle("PRD Admin Menu");

    menu.AddItem("mvp", g_hMVPVoteEnable.BoolValue ? "MVP Rewards (On)" : "MVP Rewards (Off)");
    menu.AddItem("teamkill", g_hTeamkillEnable.BoolValue ? "Teamkill Punish (On)" : "Teamkill Punish (Off)");
    menu.AddItem("camper", g_hAntiCamperEnable.BoolValue ? "Anti-Camper (On)" : "Anti-Camper (Off)");

    menu.Display(client, MENU_TIME_FOREVER);
}

public int AdminMenuHandler(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_Select)
    {
        if (!IsValidClient(client)) return 0;

        char info[32];
        menu.GetItem(item, info, sizeof(info));

        if (StrEqual(info, "mvp"))
        {
            g_hMVPVoteEnable.SetBool(!g_hMVPVoteEnable.BoolValue);
            AdminMenu(client);
        }
        else if (StrEqual(info, "teamkill"))
        {
            g_hTeamkillEnable.SetBool(!g_hTeamkillEnable.BoolValue);
            AdminMenu(client);
        }
        else if (StrEqual(info, "camper"))
        {
            g_hAntiCamperEnable.SetBool(!g_hAntiCamperEnable.BoolValue);
            AdminMenu(client);
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

// --- Utilities ---

void StoreVector(float src[3], float dest[3])
{
    dest[0] = src[0];
    dest[1] = src[1];
    dest[2] = src[2];
}

bool PrecacheAndAddSound(const char[] relPath)
{
    if (relPath[0] == ' ')
        return false;

    char fullPath[PLATFORM_MAX_PATH];
    Format(fullPath, sizeof(fullPath), "sound/%s", relPath);

    AddFileToDownloadsTable(fullPath);
    PrecacheSound(relPath, true);
    return true;
}

stock bool IsValidClient(int client)
{
    return (client > 0 && client <= MaxClients && IsClientInGame(client));
}