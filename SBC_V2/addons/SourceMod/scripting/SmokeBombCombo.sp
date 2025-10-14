#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <topmenus>
#include <sdktools_sound>

#define PLUGIN_VERSION "1.0.1"

// Array indices for tracking smoke grenades
#define GRENADE_OWNER_ID 0
#define GRENADE_TEAM 1
#define GRENADE_PROJECTILE 2
#define GRENADE_PARTICLE 3
#define GRENADE_LIGHT 4
#define GRENADE_REMOVETIMER 5
#define GRENADE_DAMAGETIMER 6

// Plugin Info
public Plugin:myinfo = 
{
	name = "SmokeBomb Combo",
	author = "Gemini (based on HSFighter & Peace-Maker)",
	description = "Merges Poison Smoke and Grenade Smoke Color with enhanced features.",
	version = PLUGIN_VERSION,
	url = "https://github.com/google/gemini-cli"
};

// --- Global Handles and Variables ---

// CVar Handles
new Handle:g_hEnabled;
new Handle:g_hDamageEnabled;
new Handle:g_hDamageAmount;
new Handle:g_hDamageInterval;
new Handle:g_hColorMode;
new Handle:g_hColorT;
new Handle:g_hColorCT;
new Handle:g_hAllowTeamDamage;

// Other Globals
new Handle:g_hSmokeGrenades;       // Array to track active smoke grenades
new Handle:g_hPlayerColors;        // KeyValues handle for player-specific colors

// --- Plugin Lifecycle ---

public OnPluginStart()
{
	CreateConVar("sm_sbc_version", PLUGIN_VERSION, "SmokeBomb Combo Version", FCVAR_NOTIFY|FCVAR_REPLICATED|FCVAR_DONTRECORD);

	// General
	g_hEnabled = CreateConVar("sm_sbc_enabled", "1", "Enable or disable the entire plugin.", FCVAR_NONE, true, 0.0, true, 1.0);

	// Damage CVars
	g_hDamageEnabled = CreateConVar("sm_sbc_damage_enabled", "1", "Enable or disable smoke damage.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_hDamageAmount = CreateConVar("sm_sbc_damage_amount", "10", "Damage dealt per tick.", FCVAR_NONE, true, 1.0, true, 100.0);
	g_hDamageInterval = CreateConVar("sm_sbc_damage_interval", "1.0", "Time in seconds between damage ticks.", FCVAR_NONE, true, 1.0, true, 90.0);
	g_hAllowTeamDamage = CreateConVar("sm_sbc_teammate_damage", "0", "Allow smoke to damage teammates. 0 = No, 1 = Yes.", FCVAR_NONE, true, 0.0, true, 1.0);

	// Color CVars
	g_hColorMode = CreateConVar("sm_sbc_color_mode", "0", "Smoke color mode. 0 = Team Colors, 1 = Player-specific colors (falls back to team colors).", FCVAR_NONE, true, 0.0, true, 1.0);
	g_hColorT = CreateConVar("sm_sbc_color_t", "255 0 0", "Smoke color for Terrorists (RGB).");
	g_hColorCT = CreateConVar("sm_sbc_color_ct", "0 0 255", "Smoke color for Counter-Terrorists (RGB).");

	// Admin Commands
	RegAdminCmd("sm_smokecolor", Cmd_SetSmokeColor, ADMFLAG_CONFIG, "sm_smokecolor <#userid|name> <r> <g> <b> | <disable>");

	// Hooking
	HookEvent("player_death", Event_OnPlayerDeath, EventHookMode_Pre);
	HookEvent("round_start", Event_OnResetSmokes);
	HookEvent("round_end", Event_OnResetSmokes);

	// Other setup
	g_hSmokeGrenades = CreateArray();
	g_hPlayerColors = CreateKeyValues("PlayerSmokeColors");
	LoadPlayerColors();

	AutoExecConfig(true, "plugin.sm_sbc");
}

public OnMapStart()
{
    // Precache the smoke particle to be safe
    PrecacheGeneric("particles/smokegrenade.pcf", true);
    PrecacheSound("player/cough-1.wav", true);
    PrecacheSound("player/cough-2.wav", true);
    PrecacheSound("player/cough-3.wav", true);
    PrecacheSound("player/cough-4.wav", true);
}

public OnMapEnd()
{
	ResetAllSmokes();
}

public OnEntityCreated(entity, const String:classname[])
{
	if (GetConVarInt(g_hEnabled) == 0) return;

	if (StrEqual(classname, "smokegrenade_projectile"))
	{
		SDKHook(entity, SDKHook_Spawn, Hook_OnSpawnProjectile);
	}
	
	if (StrEqual(classname, "env_particlesmokegrenade"))
	{
		SDKHook(entity, SDKHook_Spawn, Hook_OnSpawnParticles);
	}
}

// --- Event & Hook Callbacks ---

public Hook_OnSpawnProjectile(entity)
{
	new client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	
	if (client == -1 || !IsClientInGame(client)) return;
	
	// Track this projectile
	new Handle:hGrenade = CreateArray();
	PushArrayCell(hGrenade, GetClientUserId(client));
	PushArrayCell(hGrenade, GetClientTeam(client));
	PushArrayCell(hGrenade, entity);
	PushArrayCell(g_hSmokeGrenades, hGrenade);
}

public Hook_OnSpawnParticles(entity)
{
	new Float:fOrigin[3], Float:fOriginSmoke[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", fOrigin);
	
	// Find the matching projectile we tracked
	for (new i = 0; i < GetArraySize(g_hSmokeGrenades); i++)
	{
		new Handle:hGrenade = GetArrayCell(g_hSmokeGrenades, i);
		
		// Skip if this smoke has already been processed
		if (GetArraySize(hGrenade) > 3) continue;

		new iGrenade = GetArrayCell(hGrenade, GRENADE_PROJECTILE);
		GetEntPropVector(iGrenade, Prop_Send, "m_vecOrigin", fOriginSmoke);

		if (fOrigin[0] == fOriginSmoke[0] && fOrigin[1] == fOriginSmoke[1] && fOrigin[2] == fOriginSmoke[2])
		{
			PushArrayCell(hGrenade, entity);
			
			// --- Main Logic: Color and Damage ---
			decl String:sColor[32];
			GetSmokeColor(hGrenade, sColor, sizeof(sColor));
			
			new iLight = CreateSmokeLight(entity, fOrigin, sColor);
			PushArrayCell(hGrenade, iLight);
			
			new Float:fFadeEndTime = GetEntPropFloat(entity, Prop_Send, "m_FadeEndTime");
			new Handle:hRemoveTimer = CreateTimer(fFadeEndTime, Timer_RemoveSmoke, entity, TIMER_FLAG_NO_MAPCHANGE);
			PushArrayCell(hGrenade, hRemoveTimer);
			
			new Handle:hDamageTimer = INVALID_HANDLE;
			if (GetConVarBool(g_hDamageEnabled))
			{
				hDamageTimer = CreateTimer(GetConVarFloat(g_hDamageInterval), Timer_CheckDamage, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
			}
			PushArrayCell(hGrenade, hDamageTimer);
			
			return; // Found and processed
		}
	}
}

public Action:Event_OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	// Change kill icon to something more appropriate
	decl String:sWeapon[64];
	GetEventString(event, "weapon", sWeapon, sizeof(sWeapon));
	if (StrEqual(sWeapon, "env_particlesmokegrenade"))
	{
		SetEventString(event, "weapon", "hegrenade"); // hegrenade icon is more visible than flashbang
	}
	return Plugin_Continue;
}

public Event_OnResetSmokes(Handle:event, const String:name[], bool:dontBroadcast)
{
	ResetAllSmokes();
}

// --- Timers ---

public Action:Timer_CheckDamage(Handle:timer, any:entityref)
{
	new entity = EntRefToEntIndex(entityref);
	if (entity == INVALID_ENT_REFERENCE) return Plugin_Continue;

	// Find the grenade data associated with this smoke entity
	new Handle:hGrenade;
	new iGrenade = -1;
	for (new i = 0; i < GetArraySize(g_hSmokeGrenades); i++)
	{
		hGrenade = GetArrayCell(g_hSmokeGrenades, i);
		if (GetArraySize(hGrenade) > GRENADE_PARTICLE)
		{
			iGrenade = GetArrayCell(hGrenade, GRENADE_PARTICLE);
			if (iGrenade == entity) break;
		}
		iGrenade = -1;
	}
	
	if (iGrenade == -1) return Plugin_Continue;
	
	new owner_userid = GetArrayCell(hGrenade, GRENADE_OWNER_ID);
	new owner_client = GetClientOfUserId(owner_userid);
	if (!owner_client) return Plugin_Continue; // Owner left
	
	new Float:fSmokeOrigin[3];
	GetEntPropVector(iGrenade, Prop_Send, "m_vecOrigin", fSmokeOrigin);
	
	new iGrenadeTeam = GetArrayCell(hGrenade, GRENADE_TEAM);
	new bool:bAllowTeamDmg = GetConVarBool(g_hAllowTeamDamage);
	new Float:fDamage = GetConVarFloat(g_hDamageAmount);

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i))
		{
			// If it's a teammate and teammate damage is disabled by our CVar, skip them.
			if (GetClientTeam(i) == iGrenadeTeam && !bAllowTeamDmg)
			{
				continue;
			}

			new Float:fPlayerOrigin[3];
			GetClientAbsOrigin(i, fPlayerOrigin);
			if (GetVectorDistance(fSmokeOrigin, fPlayerOrigin) <= 220.0)
			{
				SDKHooks_TakeDamage(i, iGrenade, owner_client, fDamage, DMG_POISON, -1, NULL_VECTOR, fSmokeOrigin);
				switch(GetRandomInt(1, 4))
				{
					case 1: { EmitSoundToAll("player/cough-1.wav", i); break; }
					case 2: { EmitSoundToAll("player/cough-2.wav", i); break; }
					case 3: { EmitSoundToAll("player/cough-3.wav", i); break; }
					case 4: { EmitSoundToAll("player/cough-4.wav", i); break; }
				}
			}
		}
	}
	
	return Plugin_Continue;
}

public Action:Timer_RemoveSmoke(Handle:timer, any:entity)
{
	for (new i = 0; i < GetArraySize(g_hSmokeGrenades); i++)
	{
		new Handle:hGrenade = GetArrayCell(g_hSmokeGrenades, i);
		if (GetArraySize(hGrenade) > GRENADE_PARTICLE && GetArrayCell(hGrenade, GRENADE_PARTICLE) == entity)
		{
			// Kill damage timer
			new Handle:hDamageTimer = GetArrayCell(hGrenade, GRENADE_DAMAGETIMER);
			if (hDamageTimer != INVALID_HANDLE) KillTimer(hDamageTimer);

			// Kill light entity
			new iLight = GetArrayCell(hGrenade, GRENADE_LIGHT);
			if (iLight > 0 && IsValidEntity(iLight)) AcceptEntityInput(iLight, "kill");
			
			// Kill smoke entity
			if (entity > 0 && IsValidEntity(entity)) AcceptEntityInput(entity, "kill");

			RemoveFromArray(g_hSmokeGrenades, i);
			CloseHandle(hGrenade);
			break;
		}
	}
	return Plugin_Stop;
}

// --- Admin Commands ---

public Action:Cmd_SetSmokeColor(client, args)
{
	if (args < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_smokecolor <#userid|name> <r> <g> <b> | <disable>");
		return Plugin_Handled;
	}

	decl String:sTarget[64], String:sArg2[32];
	GetCmdArg(1, sTarget, sizeof(sTarget));
	GetCmdArg(2, sArg2, sizeof(sArg2));

	decl String:sTargetID[32];
	new iTarget = FindTarget(client, sTarget, true, false);
	if (iTarget == -1)
	{
		ReplyToCommand(client, "[SM] Target player not found.");
		return Plugin_Handled;
	}
	GetClientAuthId(iTarget, AuthId_Steam2, sTargetID, sizeof(sTargetID));

	// Disable custom color
	if (StrEqual(sArg2, "disable", false))
	{
		if (KvJumpToKey(g_hPlayerColors, sTargetID, false))
		{
			KvDeleteThis(g_hPlayerColors);
			SavePlayerColors();
			ReplyToCommand(client, "[SM] Custom smoke color for %N has been disabled.", iTarget);
		}
		else
		{
			ReplyToCommand(client, "[SM] %N does not have a custom smoke color set.", iTarget);
		}
		return Plugin_Handled;
	}

	// Set custom color
	if (args < 4)
	{
		ReplyToCommand(client, "[SM] Usage: sm_smokecolor <#userid|name> <r> <g> <b>");
		return Plugin_Handled;
	}

	decl String:sR[4], String:sG[4], String:sB[4];
	GetCmdArg(2, sR, sizeof(sR));
	GetCmdArg(3, sG, sizeof(sG));
	GetCmdArg(4, sB, sizeof(sB));

	new r = StringToInt(sR);
	new g = StringToInt(sG);
	new b = StringToInt(sB);

	if (r < 0 || r > 255 || g < 0 || g > 255 || b < 0 || b > 255)
	{
		ReplyToCommand(client, "[SM] Invalid color value. R, G, and B must be between 0 and 255.");
		return Plugin_Handled;
	}

	decl String:sColor[32];
	Format(sColor, sizeof(sColor), "%d %d %d", r, g, b);
	
	KvJumpToKey(g_hPlayerColors, sTargetID, true);
	KvSetString(g_hPlayerColors, "color", sColor);
	
	SavePlayerColors();
	ReplyToCommand(client, "[SM] Custom smoke color for %N set to \"%s\".", iTarget, sColor);

	return Plugin_Handled;
}

// --- Helper Functions ---

stock GetSmokeColor(Handle:hGrenade, String:buffer[], maxlen)
{
	new colorMode = GetConVarInt(g_hColorMode);
	new owner_userid = GetArrayCell(hGrenade, GRENADE_OWNER_ID);
	new owner_client = GetClientOfUserId(owner_userid);

	// Mode 1: Player-specific colors
	if (colorMode == 1 && owner_client > 0)
	{
		decl String:sAuthID[32];
		GetClientAuthId(owner_client, AuthId_Steam2, sAuthID, sizeof(sAuthID));
		if (KvJumpToKey(g_hPlayerColors, sAuthID, false))
		{
			KvGetString(g_hPlayerColors, "color", buffer, maxlen);
			KvGoBack(g_hPlayerColors);
			return;
		}
	}

	// Mode 0 or fallback: Team colors
	new team = GetArrayCell(hGrenade, GRENADE_TEAM);
	if (team == 2) // T
	{
		GetConVarString(g_hColorT, buffer, maxlen);
	}
	else // CT or Spectator
	{
		GetConVarString(g_hColorCT, buffer, maxlen);
	}
}

stock CreateSmokeLight(entity, Float:origin[3], const String:color[])
{
	new iLight = CreateEntityByName("light_dynamic");
	if (iLight == -1) return -1;

	decl String:sBuffer[64];
	Format(sBuffer, sizeof(sBuffer), "smokelight_%d", entity);
	DispatchKeyValue(iLight, "targetname", sBuffer);
	
	Format(sBuffer, sizeof(sBuffer), "%f %f %f", origin[0], origin[1], origin[2]);
	DispatchKeyValue(iLight, "origin", sBuffer);
	
	DispatchKeyValue(iLight, "_light", color);
	DispatchKeyValue(iLight, "pitch", "-90");
	DispatchKeyValue(iLight, "distance", "250");
	DispatchKeyValue(iLight, "brightness", "4");
	DispatchKeyValue(iLight, "spotlight_radius", "80");
	DispatchKeyValue(iLight, "style", "6"); // "6" is a soft pulse, looks good
	DispatchKeyValue(iLight, "spawnflags", "1"); // No dynamic light
	DispatchSpawn(iLight);
	AcceptEntityInput(iLight, "DisableShadow");
	AcceptEntityInput(iLight, "TurnOn");

	return iLight;
}

stock void ResetAllSmokes()
{
	// Iterate backwards when removing from an array to avoid index shifting issues.
	for (new i = GetArraySize(g_hSmokeGrenades) - 1; i >= 0; i--)
	{
		new Handle:hGrenade = GetArrayCell(g_hSmokeGrenades, i);
		
		// Check if the grenade was fully initialized before trying to access all its data.
		if (GetArraySize(hGrenade) > GRENADE_PARTICLE)
		{
			// Kill timers
			new Handle:hRemoveTimer = GetArrayCell(hGrenade, GRENADE_REMOVETIMER);
			if (hRemoveTimer != INVALID_HANDLE) KillTimer(hRemoveTimer);
			
			new Handle:hDamageTimer = GetArrayCell(hGrenade, GRENADE_DAMAGETIMER);
			if (hDamageTimer != INVALID_HANDLE) KillTimer(hDamageTimer);

			// Kill entities
			new iLight = GetArrayCell(hGrenade, GRENADE_LIGHT);
			if (iLight > 0 && IsValidEntity(iLight)) AcceptEntityInput(iLight, "kill");
			
			new iParticle = GetArrayCell(hGrenade, GRENADE_PARTICLE);
			if (iParticle > 0 && IsValidEntity(iParticle)) AcceptEntityInput(iParticle, "kill");
		}
		
		CloseHandle(hGrenade);
	}
	ClearArray(g_hSmokeGrenades);
}

stock void LoadPlayerColors()
{
	decl String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/sm_sbc_player_colors.cfg");

	if (FileExists(sPath))
	{
		FileToKeyValues(g_hPlayerColors, sPath);
	}
}

stock void SavePlayerColors()
{
	decl String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/smokebomb_player_colors.cfg");
	KeyValuesToFile(g_hPlayerColors, sPath);
}