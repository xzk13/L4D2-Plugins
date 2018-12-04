#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

#define HUNTER       3
#define MAX_HUNTERSOUND         6
#define IS_VALID_CLIENT(%1)     (%1 > 0 && %1 <= MaxClients)
#define IS_INFECTED(%1)         (GetClientTeam(%1) == 3)
#define IS_VALID_INGAME(%1)     (IS_VALID_CLIENT(%1) && IsClientInGame(%1))
#define IS_VALID_INFECTED(%1)   (IS_VALID_INGAME(%1) && IS_INFECTED(%1))

new const String: sHunterSound[MAX_HUNTERSOUND + 1][] =
{
  "player/hunter/voice/idle/hunter_stalk_01.wav",
	"player/hunter/voice/idle/hunter_stalk_04.wav",
	"player/hunter/voice/idle/hunter_stalk_05.wav",
	"player/hunter/voice/idle/hunter_stalk_06.wav",
	"player/hunter/voice/idle/hunter_stalk_07.wav",
	"player/hunter/voice/idle/hunter_stalk_08.wav",
	"player/hunter/voice/idle/hunter_stalk_09.wav"
};

public Plugin:myinfo = 
{
    name = "Hunter Crouch Sounds",
    author = "High Cookie & Harry",
    description = "Forces silent but crouched hunters to emitt sounds",
    version = "1.2",
    url = ""
};

public OnPluginStart()
{
   HookEvent("player_spawn",Event_PlayerSpawn,              EventHookMode_Post);
}

public OnMapStart()
{
    for (new i = 0; i <= MAX_HUNTERSOUND; i++)
    {
        PrefetchSound(sHunterSound[i]);
        PrecacheSound(sHunterSound[i], true);
    }
}

public Action: Event_PlayerSpawn( Handle:event, const String:name[], bool:dontBroadcast )
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if ( !IS_VALID_INFECTED(client) ) { return Plugin_Continue; }
	
	new zClass = GetEntProp(client, Prop_Send, "m_zombieClass");
	if (zClass == HUNTER)
	{
		CreateTimer(2.0, HunterCrouchTracking, client, TIMER_REPEAT);
	}
	return Plugin_Continue;
}

public Action:HunterCrouchTracking(Handle:timer, any:client) 
{
	if ( !IsClientAndInGame(client) || 
	GetClientTeam(client) != 3 || 
	GetEntProp(client, Prop_Send, "m_zombieClass") != HUNTER || 
	!IsPlayerAlive(client)) 
	{
		return Plugin_Stop;
	}
	
	if (GetClientButtons(client) == IN_DUCK){ return Plugin_Continue; }
	if (HasTarget(client)) return Plugin_Continue;
	new ducked = GetEntProp(client, Prop_Send, "m_bDucked");
	if (ducked)
	{
		CreateTimer(0.2, HunterCrouchReallyCheck, client, _);
	}
	return Plugin_Continue;
}

public Action:HunterCrouchReallyCheck(Handle:timer, any:client) 
{
	if ( !IsClientAndInGame(client) || GetClientTeam(client) != 3 || GetEntProp(client, Prop_Send, "m_zombieClass") != HUNTER || !IsPlayerAlive(client))
	{
		return Plugin_Continue;
	}
	if (GetClientButtons(client) & IN_DUCK){ return Plugin_Continue; }
	if (HasTarget(client)) return Plugin_Continue;
	new ducked = GetEntProp(client, Prop_Send, "m_bDucked");
	if (ducked)
	{
		new rndPick = GetRandomInt(0, MAX_HUNTERSOUND);
		EmitSoundToAll(sHunterSound[rndPick], client, SNDCHAN_VOICE);
	}
	return Plugin_Continue;
}

bool:HasTarget(hunter)
{
	new target = GetEntDataEnt2(hunter, 16004);
	return (IsSurvivor(target) && IsPlayerAlive(target));
}

stock bool:IsSurvivor(client)
{
	return IsClientAndInGame(client) && GetClientTeam(client) == 2;
}

stock bool:IsClientAndInGame(index)
{
	return IsClient(index) && IsClientInGame(index);
}

stock bool:IsClient(index)
{
	return index > 0 && index <= MaxClients;
}
