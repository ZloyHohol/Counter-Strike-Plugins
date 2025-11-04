#if defined _mvp_data_included
#endinput
#endif
#define _mvp_data_included

enum struct PlayerStats
{
    int kills;
    float last_kill_time;
}

PlayerStats g_PlayerStats[MAXPLAYERS + 1];
int g_iAssists[MAXPLAYERS + 1];
float g_fJoinTime[MAXPLAYERS + 1];
float g_fTeamDamage[5];
int g_iBombPlanter = -1;
int g_iHostagesRemaining = 0;
int g_iMVP = -1;
