#pragma semicolon 1
#include <sourcemod>
#include <regex>

#define PLUGIN_VERSION	"0.0.2"
#define ERR_INVALID_MAP	"Setting a workshop map (%s) as default map won't work, \
							please set a regular one like 'de_dust'"

new Handle:g_cvarEnabled = INVALID_HANDLE;
new Handle:g_cvarFallbackMap = INVALID_HANDLE;
new Handle:g_cvarHibernateDelay = INVALID_HANDLE;
new Handle:g_cvarIngameOnly = INVALID_HANDLE;
new Handle:g_RegexWorkshopMap = INVALID_HANDLE;


public Plugin:myinfo =
{
	name = "[CS:GO] Server Hibernate Fix",
	author = "Nefarius",
	description = "Switches to defined map if server is empty",
	version = PLUGIN_VERSION,
	url = "http://nefarius.at/"
}

public OnPluginStart()
{
	g_RegexWorkshopMap = CompileRegex("^workshop[\\\\|\\/]\\d*[\\\\|\\/]");
	
	CreateConVar("sm_shf_version", PLUGIN_VERSION, 
		"Version of Server Hibernate Fix", 
		FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_UNLOGGED|FCVAR_DONTRECORD|FCVAR_REPLICATED|FCVAR_NOTIFY);
	g_cvarEnabled = CreateConVar("sm_shf_enabled", "1", 
		"Enables or disables plugin functionality <1 = Enabled/Default, 0 = Disabled>", 
		0, true, 0.0, true, 1.0);
	g_cvarFallbackMap = CreateConVar("sm_shf_default_map", "de_dust",
		"Defines the default map to fall back to before server hibernates");
	HookConVarChange(g_cvarFallbackMap, OnConvarChanged);
	g_cvarIngameOnly = CreateConVar("sm_shf_ingame_clients_only", "0", 
		"Trigger action if clients are <1 = Ingame, 0 = Connected/Default>", 
		0, true, 0.0, true, 1.0);
		
	g_cvarHibernateDelay = FindConVar("sv_hibernate_postgame_delay");
	if (g_cvarHibernateDelay == INVALID_HANDLE)
		SetFailState("'sv_hibernate_postgame_delay' not found! Is this CS:GO?");
	
	AutoExecConfig(true, "shf");
}

public OnPluginEnd()
{
	if (g_RegexWorkshopMap != INVALID_HANDLE)
		CloseHandle(g_RegexWorkshopMap);
}

public OnMapStart()
{
	if (g_cvarHibernateDelay != INVALID_HANDLE)
		SetConVarInt(g_cvarHibernateDelay, 10);
}

public OnClientDisconnect_Post(client)
{
	if (!GetConVarBool(g_cvarEnabled))
		return;
	
	if (GetRealClientCount(GetConVarBool(g_cvarIngameOnly)) == 0)
	{
		decl String:map[PLATFORM_MAX_PATH];
		GetConVarString(g_cvarFallbackMap, map, sizeof(map));
		
		if (MatchRegex(g_RegexWorkshopMap, map) > 0)
			SetFailState(ERR_INVALID_MAP, map);
		
		LogMessage("Server is empty, changing map to '%s'", map);
		if (IsMapValid(map))
			ForceChangeLevel(map, "Server is empty");
		else
			LogError("Couldn't change to '%s', does it exist?", map);
	}
}

stock GetRealClientCount(bool:inGameOnly = true)
{
	new clients = 0;
	
	for (new i = 1; i <= GetMaxClients(); i++)
	{
		if (((inGameOnly) ? IsClientInGame(i) : IsClientConnected(i)) && !IsFakeClient(i))
		{
			clients++;
		}
	}
	
	return clients;
}

public OnConvarChanged(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	if (MatchRegex(g_RegexWorkshopMap, newVal) > 0)
	{
		ResetConVar(cvar);
		LogError(ERR_INVALID_MAP, newVal);
	}
}