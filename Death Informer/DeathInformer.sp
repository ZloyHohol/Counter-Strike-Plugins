/*******************************************************************************

  Death Informer - Rewritten

  Author: Gemini for ZloyHohol

  Description:
  A complete rewrite of the old killer_info_display plugin.
  This version is self-contained, uses no external libraries or translation files,
  and focuses on providing a clean, configurable, and accurate death summary.

  Features:
  - Displays attacker's final HP and Armor.
  - Tracks and displays the last 5 damage events from the attacker.
  - A configurable time window to determine relevant damage history.
  - Custom message for suicide.
  - No external dependencies or phrase files.
  - Removed structs for wider compiler compatibility.

*******************************************************************************/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define MAX_HISTORY 5

// --- Global Variables ---

ConVar g_hHistoryTime;

// Parallel arrays to store damage history without using structs
// g_iDamageHistory[VICTIM][ATTACKER][HIT_INDEX]
int g_iDamageHistory_Damage[MAXPLAYERS+1][MAXPLAYERS+1][MAX_HISTORY];
int g_iDamageHistory_Timestamp[MAXPLAYERS+1][MAXPLAYERS+1][MAX_HISTORY];

// Tracks the next slot to use for each damage pair, implementing a circular buffer
int g_iDamageIndex[MAXPLAYERS+1][MAXPLAYERS+1];

// --- Plugin Info ---

public Plugin myinfo = {
    name        = "Death Informer",
    author      = "Gemini for ZloyHohol",
    description = "Displays detailed information about the killer upon death.",
    version     = "1.1"
};

// --- Plugin Forwards ---

public void OnPluginStart()
{
    g_hHistoryTime = CreateConVar("sm_deathinformer_history_time", "15.0", 
        "How long (in seconds) to track damage history from an attacker before death. Min 5.0, Max 50.0", 
        FCVAR_NONE, true, 5.0, true, 50.0);

    HookEvent("player_hurt", OnPlayerHurt, EventHookMode_Post);
    HookEvent("player_death", OnPlayerDeath, EventHookMode_Post);
    HookEvent("round_start", OnRoundStart, EventHookMode_Post);
}

public void OnMapStart()
{
    ClearAllDamageHistory();
}

// --- Event Handlers ---

public void OnRoundStart(Event event, const char[] name, bool silent)
{
    ClearAllDamageHistory();
}

public void OnPlayerHurt(Event event, const char[] name, bool silent)
{
    int iVictim = GetClientOfUserId(event.GetInt("userid"));
    int iAttacker = GetClientOfUserId(event.GetInt("attacker"));

    // We only care about player-on-player damage
    if (iVictim > 0 && iAttacker > 0 && iVictim != iAttacker)
    {
        int iDamage = event.GetInt("dmg_health");
        if (iDamage > 0)
        {
            RecordDamage(iVictim, iAttacker, iDamage);
        }
    }
}

public void OnPlayerDeath(Event event, const char[] name, bool silent)
{
    int iVictim = GetClientOfUserId(event.GetInt("userid"));
    int iAttacker = GetClientOfUserId(event.GetInt("attacker"));

    if (iVictim <= 0) return; // Not a player

    // --- Handle Suicide ---
    if (iAttacker == 0 || iAttacker == iVictim)
    {
        PrintToChat(iVictim, " Вы совершили самоубийство.");
        return;
    }

    // --- Handle Player Kill ---

    int iAttackerHealth = GetClientHealth(iAttacker);
    int iAttackerArmor = GetClientArmor(iAttacker);
    int iAttackerTeam = GetClientTeam(iAttacker);
    char sAttackerColor = (iAttackerTeam == 2) ? '\x04' : '\x07'; // Red for T, Blue-grey for CT

    char sBuffer[256];

    // Print initial killer info
    PrintToChat(iVictim, " "); // Spacer line
    FormatEx(sBuffer, sizeof(sBuffer), "\x01Вас убил %c%N\x01.", sAttackerColor, iAttacker);
    PrintToChat(iVictim, sBuffer);

    FormatEx(sBuffer, sizeof(sBuffer), "\x01HP Осталось: \x03%d\x01 | Броня: \x07%d", iAttackerHealth, iAttackerArmor);
    PrintToChat(iVictim, sBuffer);

    // --- Process and Print Damage History ---

    float fHistoryTime = g_hHistoryTime.FloatValue;
    int iCurrentTime = GetTime();

    int iTotalDamage = 0;
    int iHitCount = 0;
    char sDamageList[256] = "";

    // Iterate through the circular buffer for this attacker->victim pair
    for (int i = 0; i < MAX_HISTORY; i++)
    {
        int iTimestamp = g_iDamageHistory_Timestamp[iVictim][iAttacker][i];
        int iDamage = g_iDamageHistory_Damage[iVictim][iAttacker][i];

        if (iTimestamp > 0 && (iCurrentTime - iTimestamp) <= fHistoryTime)
        {
            iHitCount++;
            iTotalDamage += iDamage;

            char sDamage[8];
            Format(sDamage, sizeof(sDamage), "%d", iDamage);

            if (sDamageList[0] == '\0') {
                strcopy(sDamageList, sizeof(sDamageList), sDamage);
            }
            else {
                Format(sDamageList, sizeof(sDamageList), "%s, %s", sDamageList, sDamage);
            }
        }
    }

    if (iHitCount > 0)
    {
        FormatEx(sBuffer, sizeof(sBuffer), "\x01Вы получили \x04%d\x01 урона за \x04%d\x01 попаданий: [ \x04%s\x01 ]", iTotalDamage, iHitCount, sDamageList);
        PrintToChat(iVictim, sBuffer);
    }
    PrintToChat(iVictim, " "); // Spacer line
}

// --- Helper Functions ---

void RecordDamage(int iVictim, int iAttacker, int iDamage)
{
    int iIndex = g_iDamageIndex[iVictim][iAttacker];

    g_iDamageHistory_Damage[iVictim][iAttacker][iIndex] = iDamage;
    g_iDamageHistory_Timestamp[iVictim][iAttacker][iIndex] = GetTime();

    // Move to the next slot, wrap around if necessary
    g_iDamageIndex[iVictim][iAttacker] = (iIndex + 1) % MAX_HISTORY;
}

void ClearAllDamageHistory()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        for (int j = 1; j <= MaxClients; j++)
        {
            g_iDamageIndex[i][j] = 0;
            for (int k = 0; k < MAX_HISTORY; k++)
            {
                g_iDamageHistory_Timestamp[i][j][k] = 0;
                g_iDamageHistory_Damage[i][j][k] = 0;
            }
        }
    }
}