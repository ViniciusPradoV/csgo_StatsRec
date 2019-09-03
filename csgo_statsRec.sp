#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Vinicius do Prado Vieira"
#define PLUGIN_VERSION "0.00"

#define MAX_STEAMID_LENGTH 128

#include <sourcemod>
#include <sdktools>

#pragma newdecls required

// DB //
	
Database g_DB = null;
	
// Players Statistics //
	
int g_iPlayerKills[MAXPLAYERS + 1] = 0;
int g_iPlayerDeaths[MAXPLAYERS + 1] = 0;
int g_iPlayerHeadshots[MAXPLAYERS + 1] = 0;
int g_iPlayerAccuracy[MAXPLAYERS + 1] = 0;
int g_iPlayerAssists[MAXPLAYERS + 1] = 0;
int g_iTimePlayed[MAXPLAYERS + 1] = 0;

public Plugin myinfo = 
{
	name = "[CS:GO] StatsRec",
	author = PLUGIN_AUTHOR,
	description = "A plugin to record player statistics",
	version = PLUGIN_VERSION,
	url = ""
};

public void OnPluginStart()
{
	
	// Event Hooks //
	
	//HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
	//HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);
	//HookEvent("weapon_fire", Event_WeaponFire, EventHookMode_Post);
	//HookEvent("round_end", Event_RoundEnd, EventHookMode_Post);
	
	InitializeDB();
	
	for (int i = 1; i <= MaxClients + 1; i++)
	{
		if(!IsFakeClient(i))
			OnClientPutInServer(i);
	}
		
}

public void OnClientPutInServer(int client)
{
	if(g_DB == null)
	{
		PrintToServer("OnClientPutInServer DB not connected")
		return;
	}
	
	// Player stats
	
	 g_iPlayerKills[client] = 0;
	 g_iPlayerDeaths[client] = 0;
	 g_iPlayerHeadshots[client] = 0;
	 g_iPlayerAccuracy[client] = 0;
	 g_iPlayerAssists[client] = 0;
	 g_iTimePlayed[client] = 0;
	 
	 char PlayerName[MAX_NAME_LENGTH];
	 GetClientName(client, PlayerName, MAX_NAME_LENGTH);
	 
	 char SteamID[MAX_STEAMID_LENGTH];
	 if (!GetClientAuthId(client, AuthId_Engine, SteamID, MAX_STEAMID_LENGTH)
	 {
	 	PrintToServer("STEAMID: %s", SteamID);
		KickClient(client, "Verification problem");
		return;
	 }
	
	PrintToServer("STEAMID: %s", SteamID);
}


void InitializeDB()
{
	char error[255];
	if (SQL_CheckConfig("statsrec"))
	{
		g_DB = SQL_Connect("statsrec", true, error, sizeof(error));
		
		if (g_DB == null)
		{
			SetFailState("[SR] Error on start. Reason: %s", error);
		}
	}
	else
	{
		SetFailState("[SR] Cant find `statsrec` on database.cfg");
	}
	
	if(g_DB == INVALID_HANDLE)
	{
		SetFailState(error);
	}
	
	g_DB.SetCharset("utf8");
	
	char query[255];
	PrintToServer("Before FormatEx");
	FormatEx(query, sizeof(query), "CREATE TABLE IF NOT EXISTS `players` (`steamid` VARCHAR(17) NOT NULL, `name` VARCHAR(32), PRIMARY KEY (`steamid`))");
	if (!SQL_FastQuery(g_DB, query))
	{
		SQL_GetError(g_DB, error, sizeof(error));
		LogError("[SR] Cant create table. Error : %s", error);
	}
}
