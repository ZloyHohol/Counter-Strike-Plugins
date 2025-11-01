#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <multicolors>
#include <easy_hudmessage>
#include <keyvalues>
#include <menus>

#define PLUGIN_VERSION "1.1"

// --- Глобальные переменные ---
// MVP
int g_iMVP = -1;
bool g_bHasVoted[MAXPLAYERS + 1];
int g_iYesVotes = 0;

// Teamkill
ConVar g_hTeamkillPunishMode;
ConVar g_hTeamkillForgiveThreshold;
ConVar g_hTeamDamageMutualThreshold;
int g_iTeamKills[MAXPLAYERS + 1];
int g_iMutualDamage[MAXPLAYERS + 1][MAXPLAYERS + 1];
ArrayList g_hTeamkillIncidents;

// Camper
ConVar g_hAntiCamperTime;
float g_vLastPosition[MAXPLAYERS + 1][3];
int g_iCampingTime[MAXPLAYERS + 1];
bool g_bIsCamping[MAXPLAYERS + 1];
Handle g_hBeaconTimers[MAXPLAYERS + 1];
int g_hBeaconSprite;

// Rules
ConVar g_hFreezeTime;

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
    g_hTeamkillPunishMode = CreateConVar("sm_teamkill_punish_mode", "2", "0=выкл, 1=автонаказание, 2=голосование жертвы", _, true, 0.0, true, 2.0);
    g_hTeamkillForgiveThreshold = CreateConVar("sm_teamkill_forgive_threshold", "2", "Сколько тимкиллов нужно, чтобы убийство считалось правосудием", _, true, 1.0);
    g_hTeamDamageMutualThreshold = CreateConVar("sm_teamdamage_mutual_threshold", "25", "Урон для взаимной агрессии", _, true, 1.0);

    g_hAntiCamperTime = CreateConVar("sm_anticamper_time", "10.0", "Время (сек), после которого игрок считается кемпером", _, true, 5.0);

    g_hFreezeTime = FindConVar("mp_freezetime");

    g_hTeamkillIncidents = new ArrayList();

    // Хуки
    HookEvent("round_start", Event_RoundStart);
    HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("round_mvp", Event_RoundMVP);
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Pre);
}
// --- Обработка тимкиллов ---

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int victim   = GetClientOfUserId(event.GetInt("userid"));

    if (attacker == 0 || victim == 0 || attacker == victim)
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
        if (g_iMutualDamage[victim][attacker] >= g_hTeamDamageMutualThreshold.IntValue)
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
            kv.SetInt("victim_userid", GetClientUserId(victim));
            kv.SetInt("attacker_userid", GetClientUserId(attacker));
            g_hTeamkillIncidents.Push(kv);

            CPrintToChat(victim, "%t", "Teamkill_VictimNotice", attacker);
        }
    }

    return Plugin_Continue;
}

public Action Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int victim   = GetClientOfUserId(event.GetInt("userid"));

    if (attacker == 0 || victim == 0 || attacker == victim)
        return Plugin_Continue;

    if (GetClientTeam(attacker) == GetClientTeam(victim))
    {
        int damage = event.GetInt("damage");
        g_iMutualDamage[attacker][victim] += damage;
    }

    return Plugin_Continue;
}
// --- Начало раунда ---
public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    // Сброс счётчиков
    for (int i = 1; i <= MaxClients; i++)
    {
        g_iTeamKills[i] = 0;
        for (int j = 1; j <= MaxClients; j++)
        {
            g_iMutualDamage[i][j] = 0;
        }
    }

    // Обработка инцидентов тимкилла
    if (g_hTeamkillPunishMode.IntValue == 2)
    {
        for (int i = 0; i < g_hTeamkillIncidents.Length; i++)
        {
            Handle h = g_hTeamkillIncidents.Get(i);
            KeyValues kv = KeyValues.FromHandle(h);

            int victim_userid   = kv.GetInt("victim_userid");
            int attacker_userid = kv.GetInt("attacker_userid");

            int victim   = GetClientOfUserId(victim_userid);
            int attacker = GetClientOfUserId(attacker_userid);

            if (victim != 0 && attacker != 0 && IsClientInGame(victim) && IsClientInGame(attacker))
            {
                char sName[MAX_NAME_LENGTH];
                GetClientName(attacker, sName, sizeof(sName));

                Menu menu = new Menu(MenuHandler_TeamkillPunishment);
                menu.SetTitle("%t", "MVP_MenuTitle", sName);
                menu.AddItem("forgive", "%t", "MVP_No"); // переводы
                menu.AddItem("slay",    "%t", "Teamkill_Slay");
                menu.AddItem("burn",    "%t", "Teamkill_Burn");
                menu.AddItem("slap",    "%t", "Teamkill_Slap");

                menu.SetData(attacker_userid);
                menu.Display(victim, 15);
            }
            delete kv;
        }
    }
    g_hTeamkillIncidents.Clear();

    // Голосование за MVP
    if (g_iMVP != -1 && IsClientInGame(g_iMVP))
    {
        int team = GetClientTeam(g_iMVP);
        char sMVPName[MAX_NAME_LENGTH];
        GetClientName(g_iMVP, sMVPName, sizeof(sMVPName));

        Menu menu = new Menu(MenuHandler_MVPVote);
        menu.SetTitle("%t", "MVP_MenuTitle", sMVPName);
        menu.AddItem("yes", "%t", "MVP_Yes");
        menu.AddItem("no",  "%t", "MVP_No");

        for (int i = 1; i <= MaxClients; i++)
        {
            if (IsClientInGame(i) && GetClientTeam(i) == team)
            {
                menu.Display(i, 15);
            }
        }
    }

    // Показ правил
    CreateTimer(1.0, Timer_DisplayRules, _, TIMER_REPEAT);

    return Plugin_Continue;
}

// --- Меню наказания за тимкилл ---
public int MenuHandler_TeamkillPunishment(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_Select)
    {
        int attacker_userid = menu.GetData();
        int attacker = GetClientOfUserId(attacker_userid);

        if (attacker == 0 || !IsClientInGame(attacker))
        {
            CPrintToChat(client, "{red}[Сервер]{default} Агрессор покинул сервер.");
            return 0;
        }

        char info[32];
        menu.GetItem(item, info, sizeof(info));

        if (StrEqual(info, "forgive"))
        {
            CPrintToChatAll("%t", "Teamkill_Forgive", client, attacker);
        }
        else if (StrEqual(info, "slay"))
        {
            ForcePlayerSuicide(attacker);
            CPrintToChatAll("%t", "Teamkill_Slay", client, attacker);
        }
        else if (StrEqual(info, "burn"))
        {
            IgniteEntity(attacker, 5.0);
            CPrintToChatAll("%t", "Teamkill_Burn", client, attacker);
        }
        else if (StrEqual(info, "slap"))
        {
            SlapPlayer(attacker, 10, false);
            CPrintToChatAll("%t", "Teamkill_Slap", client, attacker);
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

// --- Спавн игрока ---
public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    g_iCampingTime[client] = 0;
    g_bIsCamping[client] = false;
    if (g_hBeaconTimers[client] != null)
    {
        KillTimer(g_hBeaconTimers[client]);
        g_hBeaconTimers[client] = null;
    }

    CreateTimer(1.0, Timer_CheckCamper, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
    return Plugin_Continue;
}

// --- MVP ---
public Action Event_RoundMVP(Event event, const char[] name, bool dontBroadcast)
{
    g_iMVP = GetClientOfUserId(event.GetInt("userid"));
    return Plugin_Continue;
}
// --- Меню голосования за MVP ---
public int MenuHandler_MVPVote(Menu menu, MenuAction action, int client, int item)
{
    if (action == MenuAction_Select)
    {
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
        if (g_iMVP != -1 && IsClientInGame(g_iMVP))
        {
            int team = GetClientTeam(g_iMVP);
            int bot_count = 0;
            for (int i = 1; i <= MaxClients; i++)
            {
                if (IsClientInGame(i) && GetClientTeam(i) == team && IsFakeClient(i))
                    bot_count++;
            }

            int reward = (g_iYesVotes + bot_count) * 1000;
            if (reward > 0)
            {
                int money = GetEntProp(g_iMVP, Prop_Send, "m_iAccount");
                SetEntProp(g_iMVP, Prop_Send, "m_iAccount", money + reward);
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

// --- Таймер анти‑кемпера ---
public Action Timer_CheckCamper(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if (client == 0 || !IsClientInGame(client) || !IsPlayerAlive(client))
        return Plugin_Stop;

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
            g_hBeaconTimers[client] = CreateTimer(1.0, Timer_DrawBeacon, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
        }
    }
    else
    {
        g_iCampingTime[client] = 0;
        if (g_bIsCamping[client])
        {
            g_bIsCamping[client] = false;
            StopSound(client, SNDCHAN_AUTO, "plugins/weapons_SFX/Flame/a-sudden-burst-of-fire.wav");
            if (g_hBeaconTimers[client] != null)
            {
                KillTimer(g_hBeaconTimers[client]);
                g_hBeaconTimers[client] = null;
            }
        }
    }

    StoreVector(pos, g_vLastPosition[client]);
    return Plugin_Continue;
}

// --- Рисование маяка ---
public Action Timer_DrawBeacon(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);
    if (client == 0 || !IsClientInGame(client) || !IsPlayerAlive(client))
        return Plugin_Stop;

    float origin[3];
    GetClientAbsOrigin(client, origin);

    TE_SetupBeamRingPoint(origin, 50.0, 250.0, g_hBeaconSprite, g_hBeaconSprite,
                          0, 10, 1.0, 5.0, 0.0, {255,0,0,255}, 10, 0);
    TE_SendToAll();

    return Plugin_Continue;
}

// --- Показ правил ---
public Action Timer_DisplayRules(Handle timer)
{
    if (g_hFreezeTime != null && GetGameTime() > g_hFreezeTime.FloatValue)
        return Plugin_Stop;

    char rules[256];
    Format(rules, sizeof(rules), "%t", "Rules_Message");

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            SendHudMessage(i, 3, -1.0, 0.25,
                           0xFFFF00FF, 0xFFFFFFFF, 0,
                           0.5, 0.5, 3.0, 0.0,
                           rules);
        }
    }
    return Plugin_Continue;
}
// --- OnMapStart: прелоад ресурсов ---
public void OnMapStart()
{
    PrecacheAndAddSound("plugins/weapons_SFX/Flame/a-sudden-burst-of-fire.wav");
    g_hBeaconSprite = PrecacheModel("sprites/laserbeam.vmt");
}

// --- Утилиты ---

void StoreVector(float src[3], float dest[3])
{
    dest[0] = src[0];
    dest[1] = src[1];
    dest[2] = src[2];
}

bool PrecacheAndAddSound(const char[] relPath)
{
    if (relPath[0] == '\0')
        return false;

    char fullPath[PLATFORM_MAX_PATH];
    Format(fullPath, sizeof(fullPath), "sound/%s", relPath);

    AddFileToDownloadsTable(fullPath);
    PrecacheSound(relPath, true);
    return true;
}
