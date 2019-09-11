#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Vinicius do Prado Vieira"
#define PLUGIN_VERSION "0.01"

#define MAX_STEAMID_LENGTH 34
#define MAX_QUERY_LENGTH 512
#define MAX_ERROR_LENGTH 255

// Defining stats for usage on SELECT callbacks
#define STAT_KILLS  	0
#define STAT_DEATHS 	1
#define STAT_HEADSHOTS 	2
#define STAT_SHOTS 		3
#define STAT_HITS 		4
#define STAT_ASSISTS 	5
#define STAT_TIMEPLAYED	6


#include <sourcemod>
#include <sdktools>

#pragma newdecls required

															/* TODO */
	/* Create a menu to see player stats, create a function to convert time on seconds on DB to HH:MM:SS for display on the menu*/

EngineVersion g_Game;

// DB //
	
Database g_DB = null;
	
// Players Statistics //
	
int g_iPlayerKills[MAXPLAYERS + 1] = 0;
int g_iPlayerDeaths[MAXPLAYERS + 1] = 0;
int g_iPlayerHeadshots[MAXPLAYERS + 1] = 0;
int g_iPlayerShots[MAXPLAYERS + 1] = 0;
int g_iPlayerHits[MAXPLAYERS + 1] = 0;
int g_iPlayerAssists[MAXPLAYERS + 1] = 0;
int g_iTimePlayed[MAXPLAYERS + 1] = 0;

// ConVars //

ConVar g_cvPluginEnabled;

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
	
	// ConVars //
	
	CreateConVar("csgo_statsrec_version", PLUGIN_VERSION, "[CS:GO] StatsRec");
	g_cvPluginEnabled = CreateConVar("csgo_statsrec_enabled", "1", "Controls if plugin is enabled");
	
	
	// Event Hooks //
	
	HookEvent("player_death", PlayerDeath_Callback, EventHookMode_Post);
	HookEvent("round_end", RoundEnd_Callback, EventHookMode_Post);
	HookEvent("player_hurt", PlayerHurt_Callback, EventHookMode_Post);
	HookEvent("weapon_fire", WeaponFire_Callback, EventHookMode_Post);
	
	InitializeDB();	
	
	AutoExecConfig(true, "csgo_statsrec");
}

void InitializeDB()
{
	if(!g_cvPluginEnabled.BoolValue)
	{
		return;
	}
	
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
	// Concatenating separately for better readability
	StrCat(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `players`");
	StrCat(sQuery, sizeof(sQuery), " (`steamid` VARCHAR(34) NOT NULL,");
	StrCat(sQuery, sizeof(sQuery), " `name` VARCHAR(32),");
	StrCat(sQuery, sizeof(sQuery), " `lastconn` VARCHAR(32) NOT NULL,");
	StrCat(sQuery, sizeof(sQuery), " `kills` INT(11) NOT NULL DEFAULT 0,");
	StrCat(sQuery, sizeof(sQuery), " `deaths` INT(11) NOT NULL DEFAULT 0,");
	StrCat(sQuery, sizeof(sQuery), " `headshots` INT(11) NOT NULL DEFAULT 0,");
	StrCat(sQuery, sizeof(sQuery), " `hits` INT(11) NOT NULL DEFAULT 0,");
	StrCat(sQuery, sizeof(sQuery), " `shots` INT(11) NOT NULL DEFAULT 0,");
	StrCat(sQuery, sizeof(sQuery), " `assists` INT(11) NOT NULL DEFAULT 0,");
	StrCat(sQuery, sizeof(sQuery), " `timeplayed` INT(20) NOT NULL DEFAULT 0,");
	StrCat(sQuery, sizeof(sQuery), " PRIMARY KEY (`steamid`))");
	FormatEx(sQuery, sizeof(sQuery), sQuery);
	if (!SQL_FastQuery(g_DB, sQuery))
	{
		SQL_GetError(g_DB, error, sizeof(error));
		LogError("[SR] Cant create table. Error : %s", error);
	}
}

public void OnClientPutInServer(int client)
{
	// Checking for Enabled CVar, if false does not execute this function
	if(!g_cvPluginEnabled.BoolValue)
	{
		return;
	}
	
	if(IsFakeClient(client))
	{
		return;
	}
	
	if(g_DB == null)
	{
		PrintToServer("OnClientPutInServer DB not connected");
		return;
	}
	
	// Player stats - Resetting //
	g_iPlayerKills[client] = 0;
	g_iPlayerDeaths[client] = 0;
	g_iPlayerHeadshots[client] = 0;
	g_iPlayerShots[client] = 0;
	g_iPlayerHits[client] = 0;
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
	
	// Escaping name to fit DB
	int iNameLength = ((strlen(sPlayerName) * 2) + 1);
	char[] sEscapedName = new char[iNameLength];
	g_DB.Escape(sPlayerName, sEscapedName, iNameLength);
	
	
	char sQuery[MAX_QUERY_LENGTH];
	FormatEx(sQuery, MAX_QUERY_LENGTH, "INSERT INTO `players` (`steamid`, `name`, `lastconn`) VALUES ('%s', '%s', CURRENT_TIMESTAMP()) ON DUPLICATE KEY UPDATE `name` = '%s', `lastconn` = CURRENT_TIMESTAMP();", sSteamID, sEscapedName, sEscapedName);
	// Inserting player on DB 
	g_DB.Query(SQL_InsertPlayerCallback, sQuery, GetClientSerial(client), DBPrio_Normal); 
}

public void SQL_InsertPlayerCallback(Database db, DBResultSet results, const char[] error, any data)
{
	// Checking for Enabled CVar, if false does not execute this function
	if(!g_cvPluginEnabled.BoolValue)
	{
		return;
	}
	
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
	
	FormatEx(sQueryStats, sizeof(sQueryStats), 
	"SELECT kills, deaths, headshots, hits, shots, assists, timeplayed FROM `players` WHERE `steamid` = '%s';", 
	sSteamID);
	
	g_DB.Query(SQL_SelectPlayerCallback, sQueryStats, GetClientSerial(client), DBPrio_Normal);
	
	FormatEx(sQueryUpdate, sizeof(sQueryUpdate), 
	"UPDATE `players` SET `lastconn`= CURRENT_TIMESTAMP() WHERE `steamid` = '%s';", 
	sSteamID);
	
	g_DB.Query(SQL_UpdatePlayerLastConnectionCallback, sQueryUpdate, GetClientSerial(client), DBPrio_Normal);
	
}

public void SQL_SelectPlayerCallback(Database db, DBResultSet results, const char[] error, any data)
{
	// Checking for Enabled CVar, if false does not execute this function
	if(!g_cvPluginEnabled.BoolValue)
	{
		return;
	}
	
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
		g_iPlayerHeadshots[client] = results.FetchInt(STAT_HEADSHOTS);
		g_iPlayerShots[client] = results.FetchInt(STAT_SHOTS);
		g_iPlayerHits[client] = results.FetchInt(STAT_HITS);
		g_iPlayerAssists[client] = results.FetchInt(STAT_ASSISTS);
		g_iTimePlayed[client] = results.FetchInt(STAT_TIMEPLAYED);
	}
	
}

public void SQL_UpdatePlayerLastConnectionCallback(Database db, DBResultSet results, const char[] error, any data)
{
	// Checking for Enabled CVar, if false does not execute this function
	if(!g_cvPluginEnabled.BoolValue)
	{
		return;
	}
	
	if (results == null)
	{
		LogError("[SR] UpdatePlayerLastConnectionCallback cant use client data. Reason: %s", error);
		return;
	}
}

public void PlayerDeath_Callback(Event e, const char[] name, bool dontBroadcast)
{
	// Checking for Enabled CVar, if false does not execute this function
	if(!g_cvPluginEnabled.BoolValue)
	{
		return;
	}
	
	if (g_DB == null)
	{
		return;
	}
	
	// Getting values from event
	int client = GetClientOfUserId(GetEventInt(e, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(e, "attacker"));
	int assister = GetClientOfUserId(GetEventInt(e, "assister"));
	bool headshot = GetEventBool(e, "headshot");
	
	//Verifying if human and adding kill to attacker in the death event, verifying if headshot and incrementing HS counter accordingly
	if(!IsFakeClient(attacker))
	{
		g_iPlayerKills[attacker]++;
		
		if(headshot)
		{
			g_iPlayerHeadshots[attacker]++;
		}
	}
	
	// Verifying if human and adding death to player killed in the death event
	if(!IsFakeClient(client))
	{
		g_iPlayerDeaths[client]++;
	}
	
	// Verifying if human/not the world and adding assist to assister in the death event
	if(assister != 0)
	{
		if(!IsFakeClient(assister))
			g_iPlayerAssists[assister]++;
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
	FormatEx(sQuery, sizeof(sQuery),
	"UPDATE `players` SET `kills` = %d, `deaths` = %d, `headshots` = %d, `shots` = %d, `hits` = %d, `assists` = %d WHERE `steamid` = '%s';",
	g_iPlayerKills[client], 
	g_iPlayerDeaths[client], 
	g_iPlayerHeadshots[client], 
	g_iPlayerShots[client], 
	g_iPlayerHits[client], 
	g_iPlayerAssists[client], 
	sSteamID);
	
	g_DB.Query(SQL_UpdatePlayerCallback, sQuery, GetClientSerial(client), DBPrio_Normal);
	
}

public void SQL_UpdatePlayerCallback(Database db, DBResultSet results, const char[] error, any data)
{
	// Checking for Enabled CVar, if false does not execute this function
	if(!g_cvPluginEnabled.BoolValue)
	{
		return;
	}
	
	if (results == null)
	{
		LogError("[SR] UpdatePlayerCallback cant use client data. Reason: %s", error);
		return;
	}
}

void UpdatePlayerTimePlayed(int client)
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
	
	g_iTimePlayed[client] = RoundToNearest(GetClientTime(client));
	
	char sQuery[MAX_QUERY_LENGTH];
	FormatEx(sQuery, sizeof(sQuery),
	"UPDATE `players` SET `timeplayed` = %d WHERE `steamid` = '%s';", 
	g_iTimePlayed[client],
	sSteamID);
	
	g_DB.Query(SQL_UpdatePlayerTimePlayedCallback, sQuery, GetClientSerial(client), DBPrio_Normal);
	
}

public void SQL_UpdatePlayerTimePlayedCallback(Database db, DBResultSet results, const char[] error, any data)
{
	// Checking for Enabled CVar, if false does not execute this function
	if(!g_cvPluginEnabled.BoolValue)
	{
		return;
	}
	
	if (results == null)
	{
		LogError("[SR] UpdatePlayerTimePlayedCallback cant use client data. Reason: %s", error);
		return;
	}
}

public void RoundEnd_Callback(Event e, const char[] name, bool dontBroadcast)
{
	// Checking for Enabled CVar, if false does not execute this function
	if(!g_cvPluginEnabled.BoolValue)
	{
		return;
	}
	
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

public void PlayerHurt_Callback(Event e, const char[] name, bool dontBroadcast)
{
	// Checking for Enabled CVar, if false does not execute this function
	if(!g_cvPluginEnabled.BoolValue)
	{
		return;
	}
	
	if (g_DB == null)
	{
		return;
	}
	
	// Getting values from event
	int attacker = GetClientOfUserId(GetEventInt(e, "attacker"));
	
	if(attacker != 0)
		if(!IsFakeClient(attacker))
			g_iPlayerHits[attacker]++;


}

public void WeaponFire_Callback(Event e, const char[] name, bool dontBroadcast)
{
	// Checking for Enabled CVar, if false does not execute this function
	if(!g_cvPluginEnabled.BoolValue)
	{
		return;
	}
	
	if (g_DB == null)
	{
		return;
	}
	
	// Getting values from event
	int client = GetClientOfUserId(GetEventInt(e, "userid"));
	
	//Verifying if human and incrementing shots counter if true
	if(!IsFakeClient(client))
	{
		g_iPlayerShots[client]++;

	}
}

public void OnClientDisconnect(int client)
{
	// Checking for Enabled CVar, if false does not execute this function
	if(!g_cvPluginEnabled.BoolValue)
	{
		return;
	}
	
	if (IsFakeClient(client))
	{
		return;
	}

	if (g_DB == null)
	{
		return;
	}
	
	UpdatePlayer(client);
	UpdatePlayerTimePlayed(client);
}
