#pragma semicolon 1

#define PLUGIN_AUTHOR "Tak (Chaosxk)"
#define PLUGIN_VERSION "1.0"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma newdecls required

ConVar g_cEnabled, g_cDuration, g_cTrigger, g_cGlobal;
bool g_bMarkEnemies[MAXPLAYERS + 1];
int g_iLastButtons[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "[CS:GO] Mark Enemies",
	author = PLUGIN_AUTHOR,
	description = "Mark your enemies for your teammates.",
	version = PLUGIN_VERSION,
	url = "https://github.com/xcalvinsz/markenemies"
};

public void OnPluginStart()
{
	CreateConVar("sm_markenemies_version", PLUGIN_VERSION, "Version for Mark Enemies.", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_cEnabled = CreateConVar("sm_markenemies_enabled", "1", "Enables/Disables this plugin.");
	g_cDuration = CreateConVar("sm_markenemies_duration", "5.0", "How long should the mark last?");
	g_cTrigger = CreateConVar("sm_markenemies_trigger", "3", "When should enemies be marked? 1 - Use key, 2 - On damage, 3 - Both", _, true, 1.0, true, 3.0);
	g_cGlobal = CreateConVar("sm_markenemies_global", "1", "Enable for everyone on server, 0 - Off, 1 - On");
	
	RegAdminCmd("sm_markenemies", Command_MarkEnemies, ADMFLAG_GENERIC, "Enables mark enemies on players.");
	RegAdminCmd("sm_markenemiesme", Command_MarkEnemiesMe, ADMFLAG_GENERIC, "Enables mark enemies on yourself.");
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;
		OnClientPostAdminCheck(i);
	}
	
	AutoExecConfig(true, "markenemies");
}

public void OnClientPostAdminCheck(int client)
{
	g_bMarkEnemies[client] = false;
	g_iLastButtons[client] = 0;
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action Command_MarkEnemies(int client, int args)
{
	if (!g_cEnabled.BoolValue)
	{
		ReplyToCommand(client, "[SM] This plugin is disabled.");
		return Plugin_Handled;
	}
	
	if (args != 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_markenemies <client> <1:ON | 0:OFF>");
		return Plugin_Handled;
	}
	
	char arg1[64], arg2[4];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	bool button = !!StringToInt(arg2);
	
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	if ((target_count = ProcessTargetString(arg1, client, target_list, MAXPLAYERS, COMMAND_FILTER_CONNECTED, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToCommand(client, "[SM] Can not find client.");
		return Plugin_Handled;
	}
	
	for (int i = 0; i < target_count; i++)
	{
		if(1 <= target_list[i] <= MaxClients && IsClientInGame(target_list[i]))
		{
			g_bMarkEnemies[target_list[i]] = button;
		}
	}
	
	if (tn_is_ml)
		ShowActivity2(client, "[SM] ", "%N has %s %t to mark enemies", client, button ? "allowed" : "disallowed", target_name);
	else
		ShowActivity2(client, "[SM] ", "%N has %s %s to mark enemies", client, button ? "allowed" : "disallowed", target_name);
		
	return Plugin_Handled;
}

public Action Command_MarkEnemiesMe(int client, int args)
{
	if (!g_cEnabled.BoolValue)
	{
		ReplyToCommand(client, "[SM] This plugin is disabled.");
		return Plugin_Handled;
	}
	
	g_bMarkEnemies[client] = !g_bMarkEnemies[client];
	ReplyToCommand(client, "[SM] You can %s mark enemies.", g_bMarkEnemies[client] ? "now" : "no longer");
	return Plugin_Handled;
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (!g_cEnabled.BoolValue)
		return Plugin_Continue;
		
	if (!(1 <= attacker <= MaxClients))
		return Plugin_Continue;
		
	if (!g_bMarkEnemies[attacker] && !g_cGlobal.IntValue)
		return Plugin_Continue;
		
	if (g_cTrigger.IntValue == 1)
		return Plugin_Continue;
		
	if (!(1 <= victim <= MaxClients))
		return Plugin_Continue;
	
	SetClientGlow(victim);
	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (!g_cEnabled.BoolValue)
		return Plugin_Continue;
		
	if (!g_bMarkEnemies[client] && !g_cGlobal.IntValue)
		return Plugin_Continue;
	
	if (g_cTrigger.IntValue == 2)
		return Plugin_Continue;
		
	if ((buttons & IN_USE) && !(g_iLastButtons[client] & IN_USE))
	{
		//Pressing E (use) button in buy zone causes it to pop up
		//This will stop it while still allowing the B (buy) button to still work
		SetEntProp(client, Prop_Send, "m_bInBuyZone", 0);
		
		float fAngles[3], fPosition[3];
		GetClientEyePosition(client, fPosition);
		GetClientEyeAngles(client, fAngles);
		
		Handle trace = TR_TraceRayFilterEx(fPosition, fAngles, MASK_PLAYERSOLID, RayType_Infinite, TR_Filter, client);
		if (TR_DidHit(trace)) 
		{ 
			int target = TR_GetEntityIndex(trace);
			if (target > 0)
				SetClientGlow(target);
		} 
		delete trace;
	}
	g_iLastButtons[client] = buttons;
	return Plugin_Continue;
}

public bool TR_Filter(int target, int contentsMask, int client)
{
	return 1 <= target <= MaxClients && GetClientTeam(client) != GetClientTeam(target);
}

void SetClientGlow(int client)
{
	SetEntPropFloat(client, Prop_Send, "m_flDetectedByEnemySensorTime", GetGameTime() + g_cDuration.FloatValue);
}