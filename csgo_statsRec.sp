#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Vinicius do Prado Vieira"
#define PLUGIN_VERSION "0.01"

#define MAX_STEAMID_LENGTH 34
#define MAX_QUERY_LENGTH 512
#define MAX_ERROR_LENGTH 255

#include <sourcemod>
#include <sdktools>

#pragma newdecls required

EngineVersion g_Game;

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
	
	g_Game = GetEngineVersion();
	if(g_Game != Engine_CSGO && g_Game != Engine_CSS)
	{
		SetFailState("This plugin is for CSGO/CSS only.");	
	}
	
	// Event Hooks //
	
	//HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
	//HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);
	//HookEvent("weapon_fire", Event_WeaponFire, EventHookMode_Post);
	//HookEvent("round_end", Event_RoundEnd, EventHookMode_Post);
	
	InitializeDB();
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i))
		{
			if(!IsFakeClient(i))
				OnClientPutInServer(i);
		}
			
	}
		
}

public void OnClientPutInServer(int client)
{
	if(g_DB == null)
	{
		PrintToServer("OnClientPutInServer DB not connected");
		return;
	}
	
	// Player stats
	
	g_iPlayerKills[client] = 0;
	g_iPlayerDeaths[client] = 0;
	g_iPlayerHeadshots[client] = 0;
	g_iPlayerAccuracy[client] = 0;
	g_iPlayerAssists[client] = 0;
	g_iTimePlayed[client] = 0;
	 
	char sPlayerName[MAX_NAME_LENGTH];
	GetClientName(client, sPlayerName, MAX_NAME_LENGTH);
	 
	char sSteamID[MAX_STEAMID_LENGTH];
	// Getting client ID
	if (!GetClientAuthId(client, AuthId_Engine, sSteamID, MAX_STEAMID_LENGTH))
	{
	 	PrintToServer("SteamID: %s", sSteamID);
		KickClient(client, "Verification problem");
		return;
	}
	
	PrintToServer("SteamID: %s", sSteamID);
	
	// Escaping name to fit DB
	int iNameLength = ((strlen(sPlayerName) * 2) + 1);
	char[] sEscapedName = new char[iNameLength];
	g_DB.Escape(sPlayerName, sEscapedName, iNameLength);
	
	
	char sQuery[MAX_QUERY_LENGTH];
	FormatEx(sQuery, MAX_QUERY_LENGTH, "INSERT INTO `players` (`steamid`, `name`, `lastconn`) VALUES ('%s', '%s', UNIX_TIMESTAMP()) ON DUPLICATE KEY UPDATE `name` = '%s', `lastconn` = CURRENT_TIMESTAMP();", sSteamID, sEscapedName, sEscapedName);
	g_DB.Query(SQL_InsertPlayerCallback, sQuery, GetClientSerial(client), DBPrio_Normal);
}


void InitializeDB()
{
	char error[MAX_ERROR_LENGTH];
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
	
	char query[MAX_ERROR_LENGTH];
	PrintToServer("Before FormatEx");
	FormatEx(query, sizeof(query), "CREATE TABLE IF NOT EXISTS `players` (`steamid` VARCHAR(34) NOT NULL, `name` VARCHAR(32), `lastconn` INT(32) NOT NULL, PRIMARY KEY (`steamid`))");
	if (!SQL_FastQuery(g_DB, query))
	{
		SQL_GetError(g_DB, error, sizeof(error));
		LogError("[SR] Cant create table. Error : %s", error);
	}
}

public void SQL_InsertPlayerCallback(Database db, DBResultSet results, const char[] error, any data)
{
	
	if(results == null)
	{
		LogError("[SR] Client data fetch failed. Reason: %s", error);
	}
	
	int client = GetClientFromSerial(data);
	
	char sSteamID[MAX_STEAMID_LENGTH];
	if(!GetClientAuthId(client, AuthId_Engine, sSteamID, MAX_STEAMID_LENGTH))
	{
		LogError("[SR] Couldn't fetch client SteamID");
	}
	
}