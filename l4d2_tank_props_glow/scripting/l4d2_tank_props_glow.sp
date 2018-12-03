#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

#define TANK_ZOMBIE_CLASS   8
new bool:tankSpawned;

new iTankClient = -1;

new Handle:cvar_tankPropsGlow;

new Handle:hTankProps       = INVALID_HANDLE;
new Handle:hTankPropsHit    = INVALID_HANDLE;
new i_Ent[5000] = -1;

new Handle:g_hCvarRange;
new Handle:g_hCvarColor;
new Handle:g_hCvarTankOnly;
new Handle:g_hCvarTankSpec;
new g_iCvarRange,g_iCvarColor,bool:g_iCvarTankOnly,bool:g_iCvarTankSpec;

public Plugin:myinfo = {
    name        = "L4D2 Tank Hittable Glow",
    author      = "Harry Potter",
    version     = "1.3",
    description = "When a Tank punches a Hittable it adds a Glow to the hittable which all infected players can see."
};

public OnPluginStart() {
    cvar_tankPropsGlow = CreateConVar("l4d_tank_props_glow", "1", "Show Hittable Glow for inf team whilst the tank is alive", FCVAR_NOTIFY);
	g_hCvarColor =	CreateConVar(	"l4d2_tank_prop_glow_color",		"255 255 255",			"Three values between 0-255 separated by spaces. RGB Color255 - Red Green Blue.", FCVAR_NOTIFY);
	g_hCvarRange =	CreateConVar(	"l4d2_tank_prop_glow_range",		"4500",				"How near to props do players need to be to enable their glow.", FCVAR_NOTIFY);
	g_hCvarTankOnly =	CreateConVar(	"l4d2_tank_prop_glow_only",		"0",				"Only Tank can see the glow", FCVAR_NOTIFY);
	g_hCvarTankSpec =	CreateConVar(	"l4d2_tank_prop_glow_spectators",		"1",				"Spectators can see the glow too", FCVAR_NOTIFY);
	
	HookConVarChange(cvar_tankPropsGlow, TankPropsGlowAllow);
	HookConVarChange(g_hCvarColor, ConVarChanged_Glow);
	HookConVarChange(g_hCvarRange, ConVarChanged_Range);
	HookConVarChange(g_hCvarTankOnly, ConVarChanged_TankOnly);
	HookConVarChange(g_hCvarTankSpec, ConVarChanged_TankSpec);
	
	AutoExecConfig(true, "l4d2_tank_props_glow");
	
    PluginEnable();
}

PluginEnable() {
	SetConVarBool(FindConVar("sv_tankpropfade"), false);
    
    hTankProps = CreateArray();
    hTankPropsHit = CreateArray();
    
    HookEvent("round_start", TankPropRoundReset);
    HookEvent("round_end", TankPropRoundReset);
    HookEvent("tank_spawn", TankPropTankSpawn);
    HookEvent("player_death", TankPropTankKilled);
	
	g_iCvarColor = GetColor(g_hCvarColor);
	g_iCvarRange = GetConVarInt(g_hCvarRange);
	g_iCvarTankOnly = GetConVarBool(g_hCvarTankOnly);
	
}

PluginDisable() {
    SetConVarBool(FindConVar("sv_tankpropfade"), true);
    
    UnhookEvent("round_start", TankPropRoundReset);
    UnhookEvent("round_end", TankPropRoundReset);
    UnhookEvent("tank_spawn", TankPropTankSpawn);
    UnhookEvent("player_death", TankPropTankKilled);
	
	if(!tankSpawned) return;
	
	new entity;
	
	for ( new i = 0; i < GetArraySize(hTankPropsHit); i++ ) {
		if ( IsValidEdict(GetArrayCell(hTankPropsHit, i)) ) {
			entity = i_Ent[GetArrayCell(hTankPropsHit, i)];
			if(IsValidEntRef(entity))
				RemoveEdict(entity);
		}
	}
	tankSpawned = false;
	
    CloseHandle(hTankProps);
    CloseHandle(hTankPropsHit);
}

public TankPropsGlowAllow( Handle:cvar, const String:oldValue[], const String:newValue[] ) {
    if ( StringToInt(newValue) == 0 ) {
        PluginDisable();
    }
    else {
        PluginEnable();
    }
}

public Action:TankPropRoundReset( Handle:event, const String:name[], bool:dontBroadcast ) {
    tankSpawned = false;
    
    UnhookTankProps();
    ClearArray(hTankPropsHit);
}

public Action:TankPropTankSpawn( Handle:event, const String:name[], bool:dontBroadcast ) {
    if ( !tankSpawned ) {
        UnhookTankProps();
        ClearArray(hTankPropsHit);
        
        HookTankProps();
        
        tankSpawned = true;
    }    
}

public Action:PD_ev_EntityKilled(Handle:event, const String:name[], bool:dontBroadcast)
{
	decl client;
	if (tankSpawned && IsTank((client = GetEventInt(event, "entindex_killed"))))
	{
		CreateTimer(1.5, TankDeadCheck, client, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:TankPropTankKilled( Handle:event, const String:name[], bool:dontBroadcast ) {
    if ( !tankSpawned ) {
        return;
    }
    
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if ( client != iTankClient ) {
        return;
    }
    
    CreateTimer(0.5, TankDeadCheck);
}

public Action:TankDeadCheck( Handle:timer ) {
    if ( GetTankClient() == -1 ) {
        UnhookTankProps();
        tankSpawned = false;
    }
}

public PropDamaged(victim, attacker, inflictor, Float:damage, damageType) {
    if ( attacker == GetTankClient() || FindValueInArray(hTankPropsHit, inflictor) != -1 ) {
        if ( FindValueInArray(hTankPropsHit, victim) == -1 ) {
            PushArrayCell(hTankPropsHit, victim);			
			CreateTankPropGlow(victim);
        }
    }
}

CreateTankPropGlow(target)
{
	decl String:sModelName[64];
	GetEntPropString(target, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));
	
	i_Ent[target] = CreateEntityByName("prop_physics_override");
	SetEntityModel(i_Ent[target], sModelName);
	DispatchSpawn(i_Ent[target]);

	SetEntProp(i_Ent[target], Prop_Send, "m_CollisionGroup", 0);
	SetEntProp(i_Ent[target], Prop_Send, "m_nSolidType", 0);
	SetEntProp(i_Ent[target], Prop_Send, "m_nGlowRange", g_iCvarRange);
	SetEntProp(i_Ent[target], Prop_Send, "m_iGlowType", 2);
	SetEntProp(i_Ent[target], Prop_Send, "m_glowColorOverride", g_iCvarColor);
	AcceptEntityInput(i_Ent[target], "StartGlowing");

	SetEntityRenderMode(i_Ent[target], RENDER_TRANSCOLOR);
	SetEntityRenderColor(i_Ent[target], 0, 0, 0, 0);

	new Float:vPos[3];
	new Float:vAng[3];
	GetEntPropVector(target, Prop_Send, "m_vecOrigin", vPos);
	GetEntPropVector(target, Prop_Send, "m_angRotation", vAng);
	DispatchKeyValueVector(i_Ent[target], "origin", vPos);
	DispatchKeyValueVector(i_Ent[target], "angles", vAng);

	SetVariantString("!activator");
	AcceptEntityInput(i_Ent[target], "SetParent", target);

	HookSingleEntityOutput(target, "OnAwakened", OnAwakened);

	SDKHook(i_Ent[target], SDKHook_SetTransmit, OnTransmit);
	
}

public OnAwakened(const String:output[], caller, activator, Float:delay)
{
	SetEntPropEnt(caller, Prop_Data, "m_hPhysicsAttacker", activator);
	SetEntPropFloat(caller, Prop_Data, "m_flLastPhysicsInfluenceTime", GetGameTime());
}

public Action OnTransmit(entity, client)
{
	
	if ( GetClientTeam(client) == 3)
	{
		if(IsTank(client))
			return Plugin_Continue;
		else
		{
			if(g_iCvarTankOnly == false)
				return Plugin_Continue;
			else
				return Plugin_Handled;
		}
	}
	else if ( GetClientTeam(client) == 1 && g_iCvarTankSpec == true)
	{
		return Plugin_Continue;
	}
	
	return Plugin_Handled;
}

bool:IsTankProp( iEntity ) {
    if ( !IsValidEdict(iEntity) ) {
        return false;
    }
    
    decl String:className[64];
    
    GetEdictClassname(iEntity, className, sizeof(className));
    if ( StrEqual(className, "prop_physics") ) {
        if ( GetEntProp(iEntity, Prop_Send, "m_hasTankGlow", 1) ) {
            return true;
        }
    }
    else if ( StrEqual(className, "prop_car_alarm") ) {
        return true;
    }
    
    return false;
}

HookTankProps() {
    new iEntCount = GetMaxEntities();
    
    for ( new i = 1; i <= iEntCount; i++ ) {
        if ( IsTankProp(i) ) {
			SDKHook(i, SDKHook_OnTakeDamagePost, PropDamaged);
			PushArrayCell(hTankProps, i);
		}
    }
}

UnhookTankProps() {
    for ( new i = 0; i < GetArraySize(hTankProps); i++ ) {
        SDKUnhook(GetArrayCell(hTankProps, i), SDKHook_OnTakeDamagePost, PropDamaged);
    }
    
	new entity;
    for ( new i = 0; i < GetArraySize(hTankPropsHit); i++ ) {
        if ( IsValidEdict(GetArrayCell(hTankPropsHit, i)) ) {
			entity = i_Ent[GetArrayCell(hTankPropsHit, i)];
			if(IsValidEntRef(entity))
				RemoveEdict(entity);
        }
    }
    ClearArray(hTankProps);
	ClearArray(hTankPropsHit);
}

GetTankClient() {
    if ( iTankClient == -1 || !IsTank(iTankClient) ) {
        iTankClient = FindTank();
    }
    
    return iTankClient;
}

FindTank() {
    for ( new i = 1; i <= MaxClients; i++ ) {
        if ( IsTank(i) ) {
            return i;
        }
    }
    
    return -1;
}

bool:IsTank( client ) {
    if ( client < 0
    || !IsClientConnected(client)
    || !IsClientInGame(client)
    || GetClientTeam(client) != 3
    || !IsPlayerAlive(client) ) {
        return false;
    }
    
    new playerClass = GetEntProp(client, Prop_Send, "m_zombieClass");
    
    if ( playerClass == TANK_ZOMBIE_CLASS ) {
        return true;
    }
    
    return false;
}

public ConVarChanged_Glow( Handle:cvar, const String:oldValue[], const String:newValue[] ) {
	g_iCvarColor = GetColor(g_hCvarColor);

	if(!tankSpawned) return;

	new entity;

	for ( new i = 0; i < GetArraySize(hTankPropsHit); i++ ) {
		if ( IsValidEdict(GetArrayCell(hTankPropsHit, i)) ) {
			entity = i_Ent[GetArrayCell(hTankPropsHit, i)];
			if( IsValidEntRef(entity) )
			{
				SetEntProp(entity, Prop_Send, "m_iGlowType", 3);
				SetEntProp(entity, Prop_Send, "m_glowColorOverride", g_iCvarColor);
			}
		}
	}
}

public ConVarChanged_Range( Handle:cvar, const String:oldValue[], const String:newValue[] ) {
	g_iCvarRange = StringToInt(newValue);

	if(!tankSpawned) return;
   
    new entity;
	
	for ( new i = 0; i < GetArraySize(hTankPropsHit); i++ ) {
		if ( IsValidEdict(GetArrayCell(hTankPropsHit, i)) ) {
			entity = i_Ent[GetArrayCell(hTankPropsHit, i)];
			if( IsValidEntRef(entity) )
			{
				SetEntProp(entity, Prop_Send, "m_nGlowRange", g_iCvarRange);
			}
		}
	}
}

public ConVarChanged_TankOnly( Handle:cvar, const String:oldValue[], const String:newValue[] ) {
	g_iCvarTankOnly = GetConVarBool(g_hCvarTankOnly);
}

public ConVarChanged_TankSpec( Handle:cvar, const String:oldValue[], const String:newValue[] ) {
	g_iCvarTankSpec	= GetConVarBool(g_hCvarTankSpec);
}
GetColor(Handle:hCvar)
{
	decl String:sTemp[12];
	GetConVarString(hCvar, sTemp, sizeof(sTemp));
	
	if( StrEqual(sTemp, "") )
		return 0;

	decl String:sColors[3][4];
	new color = ExplodeString(sTemp, " ", sColors, 3, 4);

	if( color != 3 )
		return 0;

	color = StringToInt(sColors[0]);
	color += 256 * StringToInt(sColors[1]);
	color += 65536 * StringToInt(sColors[2]);

	return color;
}

bool IsValidEntRef(entity)
{
	if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE && entity!= -1 )
		return true;
	return false;
}
