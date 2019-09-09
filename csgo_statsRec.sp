#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Vinicius do Prado Vieira"
#define PLUGIN_VERSION "0.01"

#define MAX_STEAMID_LENGTH 34
#define MAX_QUERY_LENGTH 512
#define MAX_ERROR_LENGTH 255

// Defining stats for usage on SELECT callbacks
#define STAT_KILLS  0
#define STAT_DEATHS 1


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
	
	HookEvent("player_death", PlayerDeath_Callback, EventHookMode_Post);
	HookEvent("round_end", RoundEnd_Callback, EventHookMode_Post);
	//HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);
	//HookEvent("weapon_fire", Event_WeaponFire, EventHookMode_Post);
	
	InitializeDB();	
}

public void OnClientPutInServer(int client)
{
	if(IsFakeClient(client))
	{
		return;
	}
	
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
		KickClient(client, "Verification problem, try again, please");
		return;
	}
	
	PrintToServer("OnClientPutInServer");
	PrintToServer("SteamID: %s", sSteamID); // Just for debug purposes
	
	// Escaping name to fit DB
	int iNameLength = ((strlen(sPlayerName) * 2) + 1);
	char[] sEscapedName = new char[iNameLength];
	g_DB.Escape(sPlayerName, sEscapedName, iNameLength);
	
	
	char sQuery[MAX_QUERY_LENGTH];
	FormatEx(sQuery, MAX_QUERY_LENGTH, "INSERT INTO `players` (`steamid`, `name`, `lastconn`) VALUES ('%s', '%s', CURRENT_TIMESTAMP()) ON DUPLICATE KEY UPDATE `name` = '%s', `lastconn` = CURRENT_TIMESTAMP();", sSteamID, sEscapedName, sEscapedName);
	// Inserting player on DB 
	g_DB.Query(SQL_InsertPlayerCallback, sQuery, GetClientSerial(client), DBPrio_Normal); 
}


void InitializeDB()
{
	char error[MAX_ERROR_LENGTH];
	if (SQL_CheckConfig("statsrec"))
	{
		g_DB = SQL_Connect("statsrec", true, error, sizeof(error));
		
		if (g_DB == null || g_DB == INVALID_HANDLE)
		{
			SetFailState("[SR] Error on start. Reason: %s", error);
		}
	}
	else
	{
		SetFailState("[SR] Cant find `statsrec` on database.cfg");
	}
	
	g_DB.SetCharset("utf8");
	
	char sQuery[MAX_QUERY_LENGTH];
	PrintToServer("Before FormatEx");
	FormatEx(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `players` (`steamid` VARCHAR(34) NOT NULL, `name` VARCHAR(32), `lastconn` VARCHAR(32) NOT NULL, `kills` INT(11) NOT NULL DEFAULT 0, `deaths` INT(11) NOT NULL DEFAULT 0, PRIMARY KEY (`steamid`))");
	if (!SQL_FastQuery(g_DB, sQuery))
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
		PrintToServer("InsertPlayer");
		LogError("[SR] Couldn't fetch client SteamID");
	}
	
	char sQueryStats[MAX_QUERY_LENGTH];
	char sQueryUpdate[MAX_QUERY_LENGTH];
	
	FormatEx(sQueryStats, sizeof(sQueryStats), "SELECT kills, deaths FROM `players` WHERE `steamid` = '%s'", sSteamID);
	
	g_DB.Query(SQL_SelectPlayerCallback, sQueryStats, GetClientSerial(client), DBPrio_Normal);
	
	FormatEx(sQueryUpdate, sizeof(sQueryUpdate), "UPDATE `players` SET `lastconn`= CURRENT_TIMESTAMP() WHERE `steamid` = '%s';", sSteamID);
	
	g_DB.Query(SQL_UpdatePlayerLastConnectionCallback, sQueryUpdate, GetClientSerial(client), DBPrio_Normal);
	
}

public void SQL_SelectPlayerCallback(Database db, DBResultSet results, const char[] error, any data)
{
	if(results == null)
	{
		LogError("[SR] Client data fetch failed. Reason: %s", error);
		return;
	}
	
	int client = GetClientFromSerial(data);
	
	while(results.FetchRow())
	{
		g_iPlayerKills[client] = results.FetchInt(STAT_KILLS);
		g_iPlayerDeaths[client] = results.FetchInt(STAT_DEATHS);
	}
	
}

public void PlayerDeath_Callback(Event e, const char[] name, bool dontBroadcast)
{
	if (g_DB == null)
	{
		return;
	}
	
	// Getting values from event
	int client = GetClientOfUserId(GetEventInt(e, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(e, "attacker"));
	
	if(!IsFakeClient(attacker))
	{
		g_iPlayerKills[attacker]++;
	}
	if(!IsFakeClient(client))
	{
		g_iPlayerDeaths[client]++;
	}
}

void UpdatePlayer(int client)
{
	if (g_DB == null)
	{
		return;
	}
	
	char sSteamID[MAX_STEAMID_LENGTH];
	if(!GetClientAuthId(client, AuthId_Engine, sSteamID, MAX_STEAMID_LENGTH))
	{
		PrintToServer("SteamID: %s", sSteamID);
		LogError("[SR] Couldn't fetch client SteamID");
		return;
	}
	
	char sQuery[MAX_QUERY_LENGTH];
	FormatEx(sQuery, sizeof(sQuery), "UPDATE `players` SET `kills`= %d,`deaths`= %d WHERE `steamid` = '%s';", g_iPlayerKills[client], g_iPlayerDeaths[client], sSteamID);
	
	g_DB.Query(SQL_UpdatePlayerCallback, sQuery, GetClientSerial(client), DBPrio_Normal);
	
}

public void SQL_UpdatePlayerCallback(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
	{
		LogError("[SR] UpdatePlayerCallback cant use client data. Reason: %s", error);
		return;
	}
}

public void SQL_UpdatePlayerLastConnectionCallback(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
	{
		LogError("[SR] UpdatePlayerLastConnectionCallback cant use client data. Reason: %s", error);
		return;
	}
}

public void RoundEnd_Callback(Event e, const char[] name, bool dontBroadcast)
{
	if (g_DB == null)
	{
		return;
	}
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i))
		{
			if(!IsFakeClient(i))
				UpdatePlayer(i);
		}
	}
}

public void OnClientDisconnect(int client)
{
	if (IsFakeClient(client))
	{
		return;
	}

	if (g_DB == null)
	{
		return;
	}
	
	UpdatePlayer(client);
}
