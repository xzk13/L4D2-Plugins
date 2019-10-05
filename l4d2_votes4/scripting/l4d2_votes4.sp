#pragma semicolon 1

#include <sourcemod>
#include <colors>
//#include <builtinvotes>
#include <sdktools>
#undef REQUIRE_PLUGIN
#define SCORE_DELAY_EMPTY_SERVER 3.0
#define ZOMBIECLASS_SMOKER 1
#define ZOMBIECLASS_BOOMER 2
#define ZOMBIECLASS_HUNTER 3
#define ZOMBIECLASS_SPITTER 4
#define ZOMBIECLASS_JOCKEY 5
#define ZOMBIECLASS_CHARGER 6
#define ZOMBIECLASS_TANK 8
#define MaxHealth 100
#define VOTE_NO "no"
#define VOTE_YES "yes"
#define L4D_MAXCLIENTS_PLUS1 (MaxClients+1)
#define MENU_TIME 20
new Votey = 0;
new Voten = 0;
new bool: game_l4d2 = false;
new String:VotensHp_ED[32];
new String:VotensAlltalk_ED[32];
new String:VotensAlltalk2_ED[32];
new String:VotensRestartmap_ED[32];
new String:VotensMap_ED[32];
new String:VotensMap2_ED[32];
new String:swapplayer[MAX_NAME_LENGTH];
new String:swapplayername[MAX_NAME_LENGTH];
new String:votesmaps[MAX_NAME_LENGTH];
new String:votesmapsname[64];
new Handle:g_hVoteMenu = INVALID_HANDLE;

new Handle:g_Cvar_Limits;
new Handle:VotensHpED;
new Handle:VotensAlltalkED;
new Handle:VotensAlltalk2ED;
new Handle:VotensRestartmapED;
new Handle:VotensMapED;
new Handle:VotensMap2ED;
new Handle:VotensED;
new Float:lastDisconnectTime;
static bool:ClientVoteMenu[MAXPLAYERS + 1];
#define L4D_TEAM_SPECTATE	1
new Handle:g_hCvarPlayerLimit;
#define MAX_CAMPAIGN_LIMIT 64
new g_iCount;
new String:g_sMapinfo[MAX_CAMPAIGN_LIMIT][MAX_NAME_LENGTH];
new String:g_sMapname[MAX_CAMPAIGN_LIMIT][64];

enum voteType
{
	hp,
    alltalk,
	alltalk2,
	restartmap,
	swap,
	map,
	map2,
	forcespectate,
}
new voteType:g_voteType = voteType:hp;

new forcespectateid;
static			g_iSpectatePenaltyCounter[MAXPLAYERS + 1];
#define FORCESPECTATE_PENALTY 60
//new Handle:g_hVote;
static g_votedelay;
#define VOTEDELAY_TIME 60
new MapRestartDelay;
new Handle:MapCountdownTimer;
#define READY_RESTART_MAP_DELAY 2
new bool:isMapRestartPending = false;

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("IsClientVoteMenu", Native_IsClientVoteMenu);
	CreateNative("ClientVoteMenuSet", Native_ClientVoteMenuSet);
	return APLRes_Success;
}
public Native_IsClientVoteMenu(Handle:plugin, numParams)
{
   new num1 = GetNativeCell(1);
   return ClientVoteMenu[num1];
}
public Native_ClientVoteMenuSet(Handle:plugin, numParams)
{
   new num1 = GetNativeCell(1);
   new num2 = GetNativeCell(2);
   if(num2 == 1)
	ClientVoteMenu[num1] = true;
   else
	ClientVoteMenu[num1] = false;
}
public Plugin:myinfo =
{
	name = "L4D2 Vote Menu",
	author = "fenghf,l4d2 modify by Harry Potter and JJ",
	description = "Votes Commands",
	version = "1.6",
	url = "http://bbs.3dmgame.com/l4d"
};

public OnPluginStart()
{
	decl String: game_name[64];
	GetGameFolderName(game_name, sizeof(game_name));
	if (!StrEqual(game_name, "left4dead", false) && !StrEqual(game_name, "left4dead2", false))
	{
		SetFailState("只能在left4dead1&2使用.");
	}
	if (StrEqual(game_name, "left4dead2", false))
	{
		game_l4d2 = true;
	}
	RegConsoleCmd("voteshp", Command_VoteHp);
	RegConsoleCmd("votesalltalk", Command_VoteAlltalk);
	RegConsoleCmd("votesalltalk2", Command_VoteAlltalk2);
	RegConsoleCmd("votesrestartmap", Command_VoteRestartmap);
	RegConsoleCmd("votesmapsmenu", Command_VotemapsMenu);
	RegConsoleCmd("votesmaps2menu", Command_Votemaps2Menu);
	RegConsoleCmd("votesswap", Command_Votesswap);
	RegConsoleCmd("sm_votes", Command_Votes, "打開菜單 open vote meun");
	RegConsoleCmd("sm_callvote", Command_Votes, "打開菜單 open vote meun");
	RegConsoleCmd("sm_callvotes", Command_Votes, "打開菜單 open vote meun");
	RegConsoleCmd("votes", Command_Votes, "打開菜單");
	RegConsoleCmd("votesforcespectate", Command_Votesforcespectate);
	
	g_Cvar_Limits = CreateConVar("sm_votes_s", "0.60", "百分比.", 0, true, 0.05, true, 1.0);
	VotensHpED = CreateConVar("l4d_VotenshpED", "1", " 啟用、關閉 回血功能", FCVAR_NOTIFY);
	VotensAlltalkED = CreateConVar("l4d_VotensalltalkED", "1", " 啟用、關閉 全語音功能", FCVAR_NOTIFY);
	VotensAlltalk2ED = CreateConVar("l4d_Votensalltalk2ED", "1", " 啟用、關閉 關閉全語音功能", FCVAR_NOTIFY);
	VotensRestartmapED = CreateConVar("l4d_VotensrestartmapED", "1", " 啟用、關閉 重新目前地圖", FCVAR_NOTIFY);
	VotensMapED = CreateConVar("l4d_VotensmapED", "1", " 啟用、關閉 換圖功能", FCVAR_NOTIFY);
	VotensMap2ED = CreateConVar("l4d_Votensmap2ED", "1", " 啟用、關閉 換第三方圖功能", FCVAR_NOTIFY);
	VotensED = CreateConVar("l4d_Votens", "1", " 啟用、關閉 插件", FCVAR_NOTIFY);
	
	HookEvent("round_start", event_Round_Start);
	g_hCvarPlayerLimit = CreateConVar("sm_vote_player_limit", "2", "Minimum # of players in game to start the vote", FCVAR_NOTIFY);
	
	RegAdminCmd("sm_restartmap", CommandRestartMap, ADMFLAG_CHANGEMAP, "sm_restartmap - changelevels to the current map");
}

public Action:CommandRestartMap(client, args)
{	
	if(!isMapRestartPending)
	{
		CPrintToChatAll("{default}[{olive}TS{default}] Map restart in {green}%d{default} seconds.", READY_RESTART_MAP_DELAY+1);
		RestartMapDelayed();
	}
	return Plugin_Handled;
}

RestartMapDelayed()
{
	if (MapCountdownTimer == INVALID_HANDLE)
	{
		PrintHintTextToAll("Get Ready!\nMap restart in: %d",READY_RESTART_MAP_DELAY+1);
		isMapRestartPending = true;
		MapRestartDelay = READY_RESTART_MAP_DELAY;
		MapCountdownTimer = CreateTimer(1.0, timerRestartMap, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:timerRestartMap(Handle:timer)
{
	if (MapRestartDelay == 0)
	{
		MapCountdownTimer = INVALID_HANDLE;
		//EmitSoundToAll("buttons/blip2.wav", _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);
		RestartMapNow();
		return Plugin_Stop;
	}
	else
	{
		PrintHintTextToAll("Get Ready!\nMap restart in: %d", MapRestartDelay);
		EmitSoundToAll("buttons/blip1.wav", _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);
		MapRestartDelay--;
	}
	return Plugin_Continue;
}

RestartMapNow() 
{
	isMapRestartPending = false;
	
	decl String:currentMap[256];
	
	GetCurrentMap(currentMap, 256);
	
	ServerCommand("changelevel %s", currentMap);
	
}

public Action:event_Round_Start(Handle:event, const String:name[], bool:dontBroadcast)
{
	for(new i=1; i <= MaxClients; i++) ClientVoteMenu[i] = false; 
	
}

public OnClientPutInServer(client)
{
	g_iSpectatePenaltyCounter[client] = FORCESPECTATE_PENALTY;
	//CreateTimer(30.0, TimerAnnounce, client);
}
public OnMapStart()
{
	isMapRestartPending = false;
	
	ParseCampaigns();
	
	g_votedelay = 15;
	CreateTimer(1.0, Timer_VoteDelay, _, TIMER_REPEAT| TIMER_FLAG_NO_MAPCHANGE);

	
	for(new i = 1; i <= MaxClients; i++)
	{	
		g_iSpectatePenaltyCounter[i] = FORCESPECTATE_PENALTY;
	}
	PrecacheSound("ui/menu_enter05.wav");
	PrecacheSound("ui/beep_synthtone01.wav");
	PrecacheSound("ui/beep_error01.wav");
	
	VoteMenuClose();
}
/*
public Action:TimerAnnounce(Handle:timer, any:client)
{
	if (client&&IsClientConnected(client) && IsClientInGame(client)&& !IsFakeClient(client))
	{
		CPrintToChat(client, "{default}[{olive}TS{default}] 聊天框打{blue}!votes{default}投票、can type {blue}!votes {default}to vote menu.");
		CPrintToChat(client, "本Server提供{blue}非官方地圖{default}，如有興趣者麻煩請至{blue}gamemaps.com/l4d/{default}下載，謝謝。");
	}
}*/
public Action:Command_Votes(client, args) 
{ 
	if (client == 0)
	{
		PrintToServer("[votes] sm_votes cannot be used by server.");
		return Plugin_Handled;
	}
	if(GetClientTeam(client) == 1)
	{
		//ReplyToCommand(client, "[votes] 旁觀無權發起投票. (spectators can not call a vote)");	
		return Plugin_Handled;
	}
	ClientVoteMenu[client] = true;
	if(GetConVarInt(VotensED) == 1)
	{
		new VotensHpE_D = GetConVarInt(VotensHpED);
		new VotensAlltalkE_D = GetConVarInt(VotensAlltalkED);
		new VotensAlltalk2E_D = GetConVarInt(VotensAlltalk2ED);
		new VotensRestartmapE_D = GetConVarInt(VotensRestartmapED);		
		new VotensMapE_D = GetConVarInt(VotensMapED);
		new VotensMap2E_D = GetConVarInt(VotensMap2ED);
		
		if(VotensHpE_D == 0)
		{
			VotensHp_ED = "開啟";
		}
		else if(VotensHpE_D == 1)
		{
			VotensHp_ED = "禁用";
		}
		
		if(VotensAlltalkE_D == 0)
		{
			VotensAlltalk_ED = "開啟";
		}
		else if(VotensAlltalkE_D == 1)
		{
			VotensAlltalk_ED = "禁用";
		}
		
		if(VotensAlltalk2E_D == 0)
		{
			VotensAlltalk2_ED = "開啟";
		}
		else if(VotensAlltalk2E_D == 1)
		{
			VotensAlltalk2_ED = "禁用";
		}
		
		if(VotensRestartmapE_D == 0)
		{
			VotensRestartmap_ED = "開啟";
		}
		else if(VotensRestartmapE_D == 1)
		{
			VotensRestartmap_ED = "禁用";
		}
		
		if(VotensMapE_D == 0)
		{
			VotensMap_ED = "開啟";
		}
		else if(VotensMapE_D == 1)
		{
			VotensMap_ED = "禁用";
		}
		
		if(VotensMap2E_D == 0)
		{
			VotensMap2_ED = "開啟";
		}
		else if(VotensMap2E_D == 1)
		{
			VotensMap2_ED = "禁用";
		}
		new Handle:menu = CreatePanel();
		SetPanelTitle(menu, "菜單");
		if (VotensHpE_D == 0)
		{
			DrawPanelItem(menu, "禁用回血 Stop give hp");
		}
		else if (VotensHpE_D == 1)
		{
			DrawPanelItem(menu, "回血 Give hp");
		}
		if (VotensAlltalkE_D == 0)
		{ 
			DrawPanelItem(menu, "禁用全語音 Stop all talk");
		}
		else if (VotensAlltalkE_D == 1)
		{
			DrawPanelItem(menu, "全語音 All talk");
		}
		if (VotensAlltalk2E_D == 0)
		{
			DrawPanelItem(menu, "禁用關閉全語音 Stop turn off all talk");
		}
		else if (VotensAlltalk2E_D == 1)
		{
			DrawPanelItem(menu, "關閉全語音 Turn off all talk");
		}
		if (VotensRestartmapE_D == 0)
		{
			DrawPanelItem(menu, "禁用重新目前地圖 Stop restartmap");
		}
		else if (VotensRestartmapE_D == 1)
		{
			DrawPanelItem(menu, "重新目前地圖 Restartmap");
		}
		if (VotensMapE_D == 0)
		{
			DrawPanelItem(menu, "禁用換圖 Stop change maps");
		}
		else if (VotensMapE_D == 1)
		{
			DrawPanelItem(menu, "換圖 Change maps");
		}
		if (VotensMap2E_D == 0)
		{
			DrawPanelItem(menu, "禁用換第三方圖 Stop change addon maps");
		}
		else if (VotensMap2E_D == 1)
		{
			DrawPanelItem(menu, "換第三方圖 Change addon map");
		}
		DrawPanelItem(menu, "踢出玩家 Kick player");//不添加開啟關閉
		DrawPanelItem(menu, "強制玩家旁觀 Forcespectate player");//不添加開啟關閉
		DrawPanelText(menu, " \n");
		DrawPanelText(menu, "0. Exit");
		SendPanelToClient(menu, client,Votes_Menu, MENU_TIME);
		return Plugin_Handled;
	}
	else if(GetConVarInt(VotensED) == 0)
	{}
	return Plugin_Stop;
}
public Votes_Menu(Handle:menu, MenuAction:action, client, itemNum)
{
	if ( action == MenuAction_Select ) 
	{ 
		new VotensHpE_D = GetConVarInt(VotensHpED); 
		new VotensAlltalkE_D = GetConVarInt(VotensAlltalkED);
		new VotensAlltalk2E_D = GetConVarInt(VotensAlltalk2ED);
		new VotensRestartmapE_D = GetConVarInt(VotensRestartmapED);
		new VotensMapE_D = GetConVarInt(VotensMapED);
		new VotensMap2E_D = GetConVarInt(VotensMap2ED);
		switch (itemNum)
		{
			case 1: 
			{
				if (VotensHpE_D == 0)
				{
					FakeClientCommand(client,"sm_votes");
					CPrintToChat(client, "{default}[{olive}TS{default}] 禁用回血");
					return;
				}
				else if (VotensHpE_D == 1)
				{
					FakeClientCommand(client,"voteshp");
				}
			}
			case 2: 
			{
				if (VotensAlltalkE_D == 0)
				{
					FakeClientCommand(client,"sm_votes");
					CPrintToChat(client, "{default}[{olive}TS{default}] 禁用全語音");
					return;
				}
				else if (VotensAlltalkE_D == 1)
				{
					FakeClientCommand(client,"votesalltalk");
				}
			}
			case 3: 
			{
				if (VotensAlltalk2E_D == 0)
				{
					FakeClientCommand(client,"sm_votes");
					CPrintToChat(client, "{default}[{olive}TS{default}] 禁用關閉全語音");
					return;
				}
				else if (VotensAlltalk2E_D == 1)
				{
					FakeClientCommand(client,"votesalltalk2");
				}
			}
			case 4: 
			{
				if (VotensRestartmapE_D == 0)
				{
					FakeClientCommand(client,"sm_votes");
					CPrintToChat(client, "{default}[{olive}TS{default}] 禁用重新目前地圖");
					return;
				}
				else if (VotensRestartmapE_D == 1)
				{
					FakeClientCommand(client,"votesrestartmap");
				}
			}
			case 5: 
			{
				if (VotensMapE_D == 0)
				{
					FakeClientCommand(client,"sm_votes");
					CPrintToChat(client, "{default}[{olive}TS{default}] 禁用換圖");
					return ;
				}
				else if (VotensMapE_D == 1)
				{
					FakeClientCommand(client,"votesmapsmenu");
				}
			}
			case 6: 
			{
				if (VotensMap2E_D == 0)
				{
					FakeClientCommand(client,"sm_votes");
					CPrintToChat(client, "{default}[{olive}TS{default}] 禁用換第三方圖");
					return ;
				}
				else if (VotensMap2E_D == 1)
				{
					FakeClientCommand(client,"votesmaps2menu");
				}
			}
			case 7: 
			{
				FakeClientCommand(client,"votesswap");
			}
			case 8: 
			{
				FakeClientCommand(client,"votesforcespectate");
			}
		}
	}
	else if ( action == MenuAction_Cancel)
	{
		ClientVoteMenu[client] = false;
	}
}

public Action:Command_VoteHp(client, args)
{
	if(GetConVarInt(VotensED) == 1 
	&& GetConVarInt(VotensHpED) == 1)
	{
		/*
		if (IsVoteInProgress())
		{
			ReplyToCommand(client, "voting in progress");
			return Plugin_Handled;
		}
		*/
		if (!TestVoteDelay(client))
		{
			return Plugin_Handled;
		}	
		if(CanStartVotes(client))
		{
			CPrintToChatAll("{default}[{olive}TS{default}]{olive} %N {default}starts a vote: {blue}give hp",client);
			
			
			for(new i=1; i <= MaxClients; i++) ClientVoteMenu[i] = true;
			
			g_voteType = voteType:hp;
			decl String:SteamId[35];
			GetClientAuthId(client, AuthId_Steam2,SteamId, sizeof(SteamId));
			LogMessage("%N(%s) starts a vote: give hp!",  client, SteamId);//記錄在log文件
			g_hVoteMenu = CreateMenu(Handler_VoteCallback, MenuAction:MENU_ACTIONS_ALL);
			SetMenuTitle(g_hVoteMenu, "Sure to give hp?");
			AddMenuItem(g_hVoteMenu, VOTE_YES, "Yes");
			AddMenuItem(g_hVoteMenu, VOTE_NO, "No");
		
			SetMenuExitButton(g_hVoteMenu, false);
			VoteMenuToAll(g_hVoteMenu, 20);	
			
			EmitSoundToAll("ui/beep_synthtone01.wav");
		}
		else
		{
			return Plugin_Handled;
		}
		
		/*
		for(new i=1; i <= MaxClients; i++) ClientVoteMenu[i] = true;
		decl String:sBuffer[64];
		Format(sBuffer, sizeof(sBuffer), "Sure to give hp?");
		if (StartMatchVote(client, sBuffer))
		{
			CPrintToChatAll("{default}[{olive}TS{default}]{olive} %N {default}starts votes to {blue}give hp",client);
			g_voteType = voteType:hp;
			//caller is voting for
			//FakeClientCommand(client, "Vote Yes");
		}
		else
		{
			return Plugin_Handled;
		}
		*/
		
		return Plugin_Handled;	
	}
	else if(GetConVarInt(VotensED) == 0 && GetConVarInt(VotensHpED) == 0)
	{
		CPrintToChat(client, "{default}[{olive}TS{default}] This vote is prohibited");
	}
	return Plugin_Handled;
}
public Action:Command_VoteAlltalk(client, args)
{
	if(GetConVarInt(VotensED) == 1 
	&& GetConVarInt(VotensAlltalkED) == 1)
	{
		/*
		if (IsVoteInProgress())
		{
			ReplyToCommand(client, "voting in progress");
			return Plugin_Handled;
		}
		*/
		if (!TestVoteDelay(client))
		{
			return Plugin_Handled;
		}
		if(CanStartVotes(client))
		{
			CPrintToChatAll("{default}[{olive}TS{default}]{olive} %N {default}starts a vote: {blue}turn on alltalk",client);
			
			for(new i=1; i <= MaxClients; i++) ClientVoteMenu[i] = true;
			
			g_voteType = voteType:alltalk;
			decl String:SteamId[35];
			GetClientAuthId(client, AuthId_Steam2, SteamId, sizeof(SteamId));
			LogMessage("%N(%s) starts a vote: turn on Alltalk!",  client, SteamId);//紀錄在log文件
			g_hVoteMenu = CreateMenu(Handler_VoteCallback, MenuAction:MENU_ACTIONS_ALL);
			SetMenuTitle(g_hVoteMenu, "sure to tun on alltalk?");
			AddMenuItem(g_hVoteMenu, VOTE_YES, "Yes");
			AddMenuItem(g_hVoteMenu, VOTE_NO, "No");
		
			SetMenuExitButton(g_hVoteMenu, false);
			VoteMenuToAll(g_hVoteMenu, 20);
			
			EmitSoundToAll("ui/beep_synthtone01.wav");
		}
		else
		{
			return Plugin_Handled;
		}
		
		/*
		for(new i=1; i <= MaxClients; i++) ClientVoteMenu[i] = true;
		decl String:sBuffer[64];
		Format(sBuffer, sizeof(sBuffer), "Sure to tun on alltalk?");
		if (StartMatchVote(client, sBuffer))
		{
			g_voteType = voteType:alltalk;
			//caller is voting for
			//FakeClientCommand(client, "Vote Yes");
			CPrintToChatAll("{default}[{olive}TS{default}]{olive} %N {default}starts votes to {blue}turn on alltalk",client);
		}
		else
		{
			return Plugin_Handled;
		}
		*/
		return Plugin_Handled;	
	}
	else if(GetConVarInt(VotensED) == 0 && GetConVarInt(VotensAlltalkED) == 0)
	{
		CPrintToChat(client, "{default}[{olive}TS{default}] This vote is prohibited");
	}
	return Plugin_Handled;
}
public Action:Command_VoteAlltalk2(client, args)
{
	if(GetConVarInt(VotensED) == 1 
	&& GetConVarInt(VotensAlltalk2ED) == 1)
	{
		/*
		if (IsVoteInProgress())
		{
			ReplyToCommand(client, "voting in progress");
			return Plugin_Handled;
		}
		*/
		if (!TestVoteDelay(client))
		{
			return Plugin_Handled;
		}	
		
		if(CanStartVotes(client))
		{
			CPrintToChatAll("{default}[{olive}TS{default}]{olive} %N {default}starts a vote: {blue}turn off alltalk",client);
			
			for(new i=1; i <= MaxClients; i++) ClientVoteMenu[i] = true;
			
			g_voteType = voteType:alltalk2;
			decl String:SteamId[35];
			GetClientAuthId(client, AuthId_Steam2, SteamId, sizeof(SteamId));
			LogMessage("%N(%s) starts a vote: turn off Alltalk!",  client, SteamId);//紀錄在log文件
			g_hVoteMenu = CreateMenu(Handler_VoteCallback, MenuAction:MENU_ACTIONS_ALL);
			SetMenuTitle(g_hVoteMenu, "sure to trun off alltalk?");
			AddMenuItem(g_hVoteMenu, VOTE_YES, "Yes");
			AddMenuItem(g_hVoteMenu, VOTE_NO, "No");
		
			SetMenuExitButton(g_hVoteMenu, false);
			VoteMenuToAll(g_hVoteMenu, 20);
			
			EmitSoundToAll("ui/beep_synthtone01.wav");
		}
		else
		{
			return Plugin_Handled;
		}
		
		/*
		for(new i=1; i <= MaxClients; i++) ClientVoteMenu[i] = true;
		decl String:sBuffer[64];
		Format(sBuffer, sizeof(sBuffer), "Sure to trun off alltalk?");
		if (StartMatchVote(client, sBuffer))
		{
			CPrintToChatAll("{default}[{olive}TS{default}]{olive} %N {default}starts votes to {blue}turn off alltalk",client);
			g_voteType = voteType:alltalk2;
			//caller is voting for
			//FakeClientCommand(client, "Vote Yes");
		}
		else
		{
			return Plugin_Handled;
		}
		*/
		return Plugin_Handled;	
	}
	else if(GetConVarInt(VotensED) == 0 && GetConVarInt(VotensAlltalk2ED) == 0)
	{
		CPrintToChat(client, "{default}[{olive}TS{default}] This vote is prohibited");
	}
	return Plugin_Handled;
}
public Action:Command_VoteRestartmap(client, args)
{
	if(GetConVarInt(VotensED) == 1 
	&& GetConVarInt(VotensRestartmapED) == 1)
	{
		/*
		if (IsVoteInProgress())
		{
			ReplyToCommand(client, "voting in progress");
			return Plugin_Handled;
		}
		*/
		if (!TestVoteDelay(client))
		{
			return Plugin_Handled;
		}	

		if(CanStartVotes(client))
		{
			CPrintToChatAll("{default}[{olive}TS{default}]{olive} %N {default}starts a vote: {blue}restartmap",client);
			
			for(new i=1; i <= MaxClients; i++) ClientVoteMenu[i] = true;
			
			g_voteType = voteType:restartmap;
			decl String:SteamId[35];
			GetClientAuthId(client, AuthId_Steam2, SteamId, sizeof(SteamId));
			LogMessage("%N(%s) starts a vote: restartmap!",  client, SteamId);//紀錄在log文件
			g_hVoteMenu = CreateMenu(Handler_VoteCallback, MenuAction:MENU_ACTIONS_ALL);
			SetMenuTitle(g_hVoteMenu, "sure to restartmap?");
			AddMenuItem(g_hVoteMenu, VOTE_YES, "Yes");
			AddMenuItem(g_hVoteMenu, VOTE_NO, "No");
		
			SetMenuExitButton(g_hVoteMenu, false);
			VoteMenuToAll(g_hVoteMenu, 20);
			
			EmitSoundToAll("ui/beep_synthtone01.wav");
		}
		else
		{
			return Plugin_Handled;
		}
		
		/*
		for(new i=1; i <= MaxClients; i++) ClientVoteMenu[i] = true;
		decl String:sBuffer[64];
		Format(sBuffer, sizeof(sBuffer), "Sure to restartmap?");
		if (StartMatchVote(client, sBuffer))
		{
			CPrintToChatAll("{default}[{olive}TS{default}]{olive} %N {default}starts votes to {blue}restartmap",client);
			g_voteType = voteType:restartmap;
			//caller is voting for
			//FakeClientCommand(client, "Vote Yes");
		}
		else
		{
			return Plugin_Handled;
		}
		*/
		return Plugin_Handled;	
	}
	else if(GetConVarInt(VotensED) == 0 && GetConVarInt(VotensRestartmapED) == 0)
	{
		CPrintToChat(client, "{default}[{olive}TS{default}] This vote is prohibited");
	}
	return Plugin_Handled;
}
public Action:Command_Votesswap(client, args)
{
	if(client!=0) CreateVoteswapMenu(client);		
	return Plugin_Handled;
}

CreateVoteswapMenu(client)
{	
	new Handle:menu = CreateMenu(Menu_Votesswap);		
	new team = GetClientTeam(client);
	new String:name[MAX_NAME_LENGTH];
	new String:playerid[32];
	SetMenuTitle(menu, "plz choose player u want to kick");
	for(new i = 1;i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i)==team)
		{
			Format(playerid,sizeof(playerid),"%i",GetClientUserId(i));
			if(GetClientName(i,name,sizeof(name)))
			{
				AddMenuItem(menu, playerid, name);						
			}
		}		
	}
	SetMenuExitBackButton(menu, true);
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME);	
}
public Menu_Votesswap(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		new String:info[32] , String:name[32];
		GetMenuItem(menu, param2, info, sizeof(info), _, name, sizeof(name));
		swapplayer = info;
		swapplayername = name;
		
		DisplayVoteSwapMenu(param1);		
	}
	else if ( action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack) {
			FakeClientCommand(param1,"votes");
		}
		else
			ClientVoteMenu[param1] = false;
	}
}

public DisplayVoteSwapMenu(client)
{
	/*
	if (IsVoteInProgress())
	{
		ReplyToCommand(client, "{default}[{olive}TS{default}] voting in progress");
		return;
	}
	*/
	if (!TestVoteDelay(client))
	{
		return;
	}
	
	if(CanStartVotes(client))
	{
		decl String:SteamId[35];
		GetClientAuthId(client, AuthId_Steam2, SteamId, sizeof(SteamId));
		LogMessage("%N(%s) starts a vote: kick %s",  client, SteamId,swapplayername);//紀錄在log文件
		CPrintToChatAll("{default}[{olive}TS{default}]{olive} %N {default}starts a votes: {blue}kick %s", client, swapplayername);
		
		for(new i=1; i <= MaxClients; i++) 
			ClientVoteMenu[i] = true;
		
		g_voteType = voteType:swap;
		
		g_hVoteMenu = CreateMenu(Handler_VoteCallback, MenuAction:MENU_ACTIONS_ALL); 
		SetMenuTitle(g_hVoteMenu, "kick player %s ?",swapplayername);
		AddMenuItem(g_hVoteMenu, VOTE_YES, "Yes");
		AddMenuItem(g_hVoteMenu, VOTE_NO, "No");
		SetMenuExitButton(g_hVoteMenu, false);
		VoteMenuToAll(g_hVoteMenu, 20);
		
		EmitSoundToAll("ui/beep_synthtone01.wav");
	}
	else
	{
		return;
	}
	/*
	for(new i=1; i <= MaxClients; i++) ClientVoteMenu[i] = true;
	decl String:sBuffer[64];
	Format(sBuffer, sizeof(sBuffer), "Sure to restartmap?");
	if (StartMatchVote(client, sBuffer))
	{
		CPrintToChatAll("{default}[{olive}TS{default}]{olive} %N {default}starts votes to {blue}kick %s", client, swapplayername);
		g_voteType = voteType:swap;
		//caller is voting for
		//FakeClientCommand(client, "Vote Yes");
	}
	else
	{
		return;
	}
	*/
}

public Action:Command_VotemapsMenu(client, args)
{
	if(GetConVarInt(VotensED) == 1 && GetConVarInt(VotensMapED) == 1)
	{
		if (!TestVoteDelay(client))
		{
			return Plugin_Handled;
		}
		new Handle:menu = CreateMenu(MapMenuHandler);
		
		SetMenuTitle(menu, "Plz choose maps");
		if(game_l4d2)
		{
			AddMenuItem(menu, "c1m1_hotel", "死亡都心");
			AddMenuItem(menu, "c6m1_riverbank", "短暫之時");
			AddMenuItem(menu, "c2m1_highway", "黑色嘉年華");
			AddMenuItem(menu, "c3m1_plankcountry", "沼澤瘧疾");
			AddMenuItem(menu, "c4m1_milltown_a", "大雨");
			AddMenuItem(menu, "c5m1_waterfront", "教區");
			AddMenuItem(menu, "c13m1_alpinecreek", "冷澗溪流");
			AddMenuItem(menu, "c8m1_apartment", "毫不留情");
			AddMenuItem(menu, "c9m1_alleys", "速成課程");
			AddMenuItem(menu, "c10m1_caves", "死亡喪鐘");
			AddMenuItem(menu, "c11m1_greenhouse", "靜寂時分");
			AddMenuItem(menu, "c12m1_hilltop", "血腥收穫");
			AddMenuItem(menu, "c7m1_docks", "犧牲");
		}
		else
		{
			AddMenuItem(menu, "l4d_vs_hospital01_apartment", "毫不留情 No Mercy");
			AddMenuItem(menu, "l4d_vs_airport01_greenhouse", "死亡機場 Dead Air");
			AddMenuItem(menu, "l4d_vs_smalltown01_caves", "死亡喪鐘 Death Toll");
			AddMenuItem(menu, "l4d_vs_farm01_hilltop", "嗜血豐收 Bloody Harvest");
			AddMenuItem(menu, "l4d_garage01_alleys", "速成課程 Crash Course");
			AddMenuItem(menu, "l4d_river01_docks", "犧牲 The Sacrifice");
		}
		SetMenuExitBackButton(menu, true);
		SetMenuExitButton(menu, true);
		DisplayMenu(menu, client, MENU_TIME);
		
		return Plugin_Handled;
	}
	else 
	if(GetConVarInt(VotensED) == 0 && GetConVarInt(VotensMapED) == 0)
	{
		CPrintToChat(client, "{default}[{olive}TS{default}] Change map vote is prohibited");
	}
	return Plugin_Handled;
}

public Action:Command_Votemaps2Menu(client, args)
{
	if(GetConVarInt(VotensED) == 1 && GetConVarInt(VotensMap2ED) == 1)
	{
		if (!TestVoteDelay(client))
		{
			return Plugin_Handled;
		}
		new Handle:menu = CreateMenu(MapMenuHandler);
	
		SetMenuTitle(menu, "▲ Vote Custom Maps <%d map%s>", g_iCount, ((g_iCount > 1) ? "s": "") );
		for (new i = 0; i < g_iCount; i++)
		{
			AddMenuItem(menu, g_sMapinfo[i], g_sMapname[i]);
		}
		
		SetMenuExitBackButton(menu, true);
		SetMenuExitButton(menu, true);
		DisplayMenu(menu, client, MENU_TIME);
		
		return Plugin_Handled;
	}
	else 
	if(GetConVarInt(VotensED) == 0 && GetConVarInt(VotensMap2ED) == 0)
	{
		CPrintToChat(client, "{default}[{olive}TS{default}] Change Custom map vote is prohibited");
	}
	return Plugin_Handled;
}

public MapMenuHandler(Handle:menu, MenuAction:action, client, itemNum)
{
	if ( action == MenuAction_Select ) 
	{
		new String:info[32] , String:name[64];
		GetMenuItem(menu, itemNum, info, sizeof(info), _, name, sizeof(name));
		votesmaps = info;
		votesmapsname = name;	
		DisplayVoteMapsMenu(client);		
	}
	else if ( action == MenuAction_Cancel)
	{
		if (itemNum == MenuCancel_ExitBack) {
			FakeClientCommand(client,"votes");
		}
		else
			ClientVoteMenu[client] = false;
	}
}
public DisplayVoteMapsMenu(client)
{
	/*
	if (IsVoteInProgress())
	{
		ReplyToCommand(client, "voting in progress");
		return;
	}
	*/
	if (!TestVoteDelay(client))
	{
		return;
	}
	if(CanStartVotes(client))
	{
	
		decl String:SteamId[35];
		GetClientAuthId(client, AuthId_Steam2, SteamId, sizeof(SteamId));
		LogMessage("%N(%s) starts a vote: change map %s",  client, SteamId,votesmapsname);//紀錄在log文件
		CPrintToChatAll("{default}[{olive}TS{default}]{olive} %N {default}starts a vote: {blue}change map %s", client, votesmapsname);
		
		for(new i=1; i <= MaxClients; i++) ClientVoteMenu[i] = true;
		
		g_voteType = voteType:map;
		
		g_hVoteMenu = CreateMenu(Handler_VoteCallback, MenuAction:MENU_ACTIONS_ALL);
		//SetMenuTitle(g_hVoteMenu, "Vote to change map %s %s",votesmapsname, votesmaps);
		SetMenuTitle(g_hVoteMenu, "Vote to change map: %s",votesmapsname);
		AddMenuItem(g_hVoteMenu, VOTE_YES, "Yes");
		AddMenuItem(g_hVoteMenu, VOTE_NO, "No");
		SetMenuExitButton(g_hVoteMenu, false);
		VoteMenuToAll(g_hVoteMenu, 20);
		
		EmitSoundToAll("ui/beep_synthtone01.wav");
	}
	else
	{
		return;
	}
	/*
	for(new i=1; i <= MaxClients; i++) ClientVoteMenu[i] = true;
	decl String:sBuffer[64];
	Format(sBuffer, sizeof(sBuffer), "Vote to change map: %s",votesmapsname);
	if (StartMatchVote(client, sBuffer))
	{
		CPrintToChatAll("{default}[{olive}TS{default}]{olive} %N {default}starts votes to {blue}change map %s", client, votesmapsname);
		g_voteType = voteType:map;
		//caller is voting for
		//FakeClientCommand(client, "Vote Yes");
	}
	else
	{
		return;
	}
	*/
}

public Action:Command_Votesforcespectate(client, args)
{
	if(client!=0) CreateVoteforcespectateMenu(client);		
	return Plugin_Handled;
}

CreateVoteforcespectateMenu(client)
{	
	new Handle:menu = CreateMenu(Menu_Votesforcespectate);		
	new team = GetClientTeam(client);
	new String:name[MAX_NAME_LENGTH];
	new String:playerid[32];
	SetMenuTitle(menu, "plz choose player u want to forcespectate");
	for(new i = 1;i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i)==team)
		{
			Format(playerid,sizeof(playerid),"%d",i);
			if(GetClientName(i,name,sizeof(name)))
			{
				AddMenuItem(menu, playerid, name);				
			}
		}		
	}
	SetMenuExitBackButton(menu, true);
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME);	
}
public Menu_Votesforcespectate(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		new String:info[32] , String:name[32];
		GetMenuItem(menu, param2, info, sizeof(info), _, name, sizeof(name));
		forcespectateid = StringToInt(info);
		swapplayername = name;
		
		DisplayVoteforcespectateMenu(param1);		
	}
	else if ( action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack) {
			FakeClientCommand(param1,"votes");
		}
		else
			ClientVoteMenu[param1] = false;
	}
}

public DisplayVoteforcespectateMenu(client)
{
	/*
	if (IsVoteInProgress())
	{
		ReplyToCommand(client, "{default}[{olive}TS{default}] voting in progress");
		return;
	}
	*/
	if (!TestVoteDelay(client))
	{
		return;
	}
	
	if(CanStartVotes(client))
	{
		decl String:SteamId[35];
		GetClientAuthId(client, AuthId_Steam2, SteamId, sizeof(SteamId));
		LogMessage("%N(%s) starts a vote: forcespectate player %s",  client, SteamId,swapplayername);//紀錄在log文件
		
		new iTeam = GetClientTeam(client);
		CPrintToChatAll("{default}[{olive}TS{default}]{olive} %N {default}starts a vote: {blue}forcespectate player %s{default}, only their team can vote", client, swapplayername);
		
		for(new i=1; i <= MaxClients; i++) 
			if (IsClientConnected(i) && IsClientInGame(i) && GetClientTeam(i) == iTeam)
				ClientVoteMenu[i] = true;
		
		g_voteType = voteType:forcespectate;
		
		g_hVoteMenu = CreateMenu(Handler_VoteCallback, MenuAction:MENU_ACTIONS_ALL); 
		SetMenuTitle(g_hVoteMenu, "forcespectate player %s?",swapplayername);
		AddMenuItem(g_hVoteMenu, VOTE_YES, "Yes");
		AddMenuItem(g_hVoteMenu, VOTE_NO, "No");
		SetMenuExitButton(g_hVoteMenu, false);
		DisplayVoteMenuToTeam(g_hVoteMenu, 20,iTeam);
		
		for (new i=1; i<=MaxClients; i++)
			if(IsClientConnected(i)&&IsClientInGame(i)&&!IsFakeClient(i)&&GetClientTeam(i) == iTeam)
				EmitSoundToClient(i,"ui/beep_synthtone01.wav");
	}
	else
	{
		return;
	}
	/*
	for(new i=1; i <= MaxClients; i++) ClientVoteMenu[i] = true;
	new iTeam = GetClientTeam(client);
	decl String:sBuffer[64];
	Format(sBuffer, sizeof(sBuffer), "Forcespectate player %s?",swapplayername);
	if (StartMatchVote(client, sBuffer,iTeam))
	{
		CPrintToChatAll("{default}[{olive}TS{default}]{olive} %N {default}starts a vote :{blue}forcespectate player %s{default}, only their team can vote", client, swapplayername);
		g_voteType = voteType:forcespectate;
		//caller is voting for
		//FakeClientCommand(client, "Vote Yes");
	}
	else
	{
		return;
	}
	*/
}

stock bool:DisplayVoteMenuToTeam(Handle:hMenu,iTime, iTeam)
{
    new iTotal = 0;
    new iPlayers[MaxClients];
    
    for (new i = 1; i <= MaxClients; i++)
    {
        if (!IsClientConnected(i) || !IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) != iTeam)
        {
            continue;
        }
        
        iPlayers[iTotal++] = i;
    }
    
    return VoteMenu(hMenu, iPlayers, iTotal, iTime, 0);
}    
public Handler_VoteCallback(Handle:menu, MenuAction:action, param1, param2)
{
	//==========================
	if(action == MenuAction_Select)
	{
		switch(param2)
		{
			case 0: 
			{
				Votey += 1;
				//CPrintToChatAll("[{olive}TS{default}] %N {blue}has voted{default}.", param1);
			}
			case 1: 
			{
				Voten += 1;
				//CPrintToChatAll("[{olive}TS{default}] %N {blue}has voted{default}.", param1);
			}
		}
	}
	else if ( action == MenuAction_Cancel)
	{
		if (param1>0 && param1 <=MaxClients && IsClientConnected(param1) && IsClientInGame(param1) && !IsFakeClient(param1))
		{
			//CPrintToChatAll("[{olive}TS{default}] %N {blue}abandons the vote{default}.", param1);
		}
	}
	//==========================
	decl String:item[64], String:display[64];
	new Float:percent, Float:limit, votes, totalVotes;

	GetMenuVoteInfo(param2, votes, totalVotes);
	GetMenuItem(menu, param1, item, sizeof(item), _, display, sizeof(display));
	
	if (strcmp(item, VOTE_NO) == 0 && param1 == 1)
	{
		votes = totalVotes - votes;
	}
	percent = GetVotePercent(votes, totalVotes);

	limit = GetConVarFloat(g_Cvar_Limits);
	
	CheckVotes();
	if (action == MenuAction_End)
	{
		VoteMenuClose();
	}
	else if (action == MenuAction_VoteCancel && param1 == VoteCancel_NoVotes)
	{
		CPrintToChatAll("{default}[{olive}TS{default}] No votes");
		g_votedelay = VOTEDELAY_TIME;
		EmitSoundToAll("ui/beep_error01.wav");
		CreateTimer(2.0, VoteEndDelay);
		CreateTimer(1.0, Timer_VoteDelay, _, TIMER_REPEAT| TIMER_FLAG_NO_MAPCHANGE);
	}	
	else if (action == MenuAction_VoteEnd)
	{
		if ((strcmp(item, VOTE_YES) == 0 && FloatCompare(percent,limit) < 0 && param1 == 0) || (strcmp(item, VOTE_NO) == 0 && param1 == 1))
		{
			g_votedelay = VOTEDELAY_TIME;
			CreateTimer(1.0, Timer_VoteDelay, _, TIMER_REPEAT| TIMER_FLAG_NO_MAPCHANGE);
			EmitSoundToAll("ui/beep_error01.wav");
			CPrintToChatAll("{default}[{olive}TS{default}] {red}Vote fail.{default} At least {red}%d%%%%{default} to agree.(agree {green}%d%%%%{default}, total {green}%i {default}votes)", RoundToNearest(100.0*limit), RoundToNearest(100.0*percent), totalVotes);
			CreateTimer(2.0, VoteEndDelay);
		}
		else
		{
			g_votedelay = VOTEDELAY_TIME;
			CreateTimer(1.0, Timer_VoteDelay, _, TIMER_REPEAT| TIMER_FLAG_NO_MAPCHANGE);
			EmitSoundToAll("ui/menu_enter05.wav");
			CPrintToChatAll("{default}[{olive}TS{default}] {blue}Vote pass.{default}(agree {green}%d%%%%{default}, total {green}%i {default}votes)", RoundToNearest(100.0*percent), totalVotes);
			CreateTimer(2.0, VoteEndDelay);
			CreateTimer(3.0,COLD_DOWN,_);
		}
	}
	return 0;
}

public Action:Timer_forcespectate(Handle:timer, any:client)
{
	static bClientJoinedTeam = false;		//did the client try to join the infected?
	
	if (!IsClientInGame(client) || IsFakeClient(client)) return Plugin_Stop; //if client disconnected or is fake client
	
	if (g_iSpectatePenaltyCounter[client] != 0)
	{
		if (GetClientTeam(client) == 3||GetClientTeam(client) == 2)
		{
			ChangeClientTeam(client, 1);
			CPrintToChat(client, "{default}[{olive}TS{default}] You have been voted to be forcespectated! Wait {green}%ds {default}to rejoin team again.", g_iSpectatePenaltyCounter[client]);
			bClientJoinedTeam = true;	//client tried to join the infected again when not allowed
		}
		g_iSpectatePenaltyCounter[client]--;
		return Plugin_Continue;
	}
	else if (g_iSpectatePenaltyCounter[client] == 0)
	{
		if (GetClientTeam(client) == 3||GetClientTeam(client) == 2)
		{
			ChangeClientTeam(client, 1);
			bClientJoinedTeam = true;
		}
		if (GetClientTeam(client) == 1 && bClientJoinedTeam)
		{
			CPrintToChat(client, "{default}[{olive}TS{default}] You can rejoin both team now.");	//only print this hint text to the spectator if he tried to join the infected team, and got swapped before
		}
		bClientJoinedTeam = false;
		g_iSpectatePenaltyCounter[client] = FORCESPECTATE_PENALTY;
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

//====================================================
public AnyHp()
{
	//CPrintToChatAll("{default}[{olive}TS{default}] All players{blue}");
	new flags = GetCommandFlags("give");	
	SetCommandFlags("give", flags & ~FCVAR_CHEAT);
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
		{
			FakeClientCommand(i, "give health");
			SetEntityHealth(i, MaxHealth);
			//CPrintToChatAll("[{olive}ALL{default}]Players {red}%N {default}give hp",i);
		}
		else
		if (IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i)) 
		{
			new class = GetEntProp(i, Prop_Send, "m_zombieClass");
			if (class == ZOMBIECLASS_SMOKER)
			{
				SetEntityHealth(i, 250);
				//CPrintToChatAll("\x03[所有人]玩家 \x04%N \x03Smoker回血",i);//请勿使用提示,否则知道有那些特感
			}
			else
			if (class == ZOMBIECLASS_BOOMER)
			{
				SetEntityHealth(i, 50);
				//CPrintToChatAll("\x03[所有人]玩家 \x04%N \x03Boomer回血",i);//请勿使用提示,否则知道有那些特感
			}
			else
			if (class == ZOMBIECLASS_HUNTER)
			{
				SetEntityHealth(i, 250);
				//CPrintToChatAll("\x03[所有人]玩家 \x04%N \x03Hunter回血",i);//请勿使用提示,否则知道有那些特感
			}
			else
            if (class == ZOMBIECLASS_SPITTER)
			{
				SetEntityHealth(i, 100);
				//CPrintToChatAll("\x03[所有人]玩家 \x04%N \x03Spitter 回血",i);//请勿使用提示,否则知道有那些特感
			}
			else
			if (class == ZOMBIECLASS_JOCKEY)
			{
				decl String:game_name[64];
				GetGameFolderName(game_name, sizeof(game_name));
				if (!StrEqual(game_name, "left4dead2", false))
				{
					SetEntityHealth(i, 6000);
					//CPrintToChatAll("\x03[所有人]玩家 \x04%N \x03Tank 回血",i);//请勿使用提示,否则知道有那些特感
				}
				else
				{
					SetEntityHealth(i, 325);
					//CPrintToChatAll("\x03[所有人]玩家 \x04%N \x03Jockey回血",i);//请勿使用提示,否则知道有那些特感
				}
			}
			else
			if (class == ZOMBIECLASS_CHARGER)
			{
				SetEntityHealth(i, 600);
				//CPrintToChatAll("\x03[所有人]玩家 \x04%N \x03Charger回血",i);//请勿使用提示,否则知道有那些特感
			}
			else
			if (class == ZOMBIECLASS_TANK)
			{
				SetEntityHealth(i, 6000);
				//CPrintToChatAll("\x03[所有人]玩家 \x04%N \x03Tank回血",i);//请勿使用提示,否则知道有那些特感
			}
		}
	}
	SetCommandFlags("give", flags|FCVAR_CHEAT);
}
//================================
CheckVotes()
{
	PrintHintTextToAll("Agree: \x04%i\nDisagree: \x04%i", Votey, Voten);
}
public Action:VoteEndDelay(Handle:timer)
{
	Votey = 0;
	Voten = 0;
	for(new i=1; i <= MaxClients; i++) ClientVoteMenu[i] = false;
}
public Action:Changelevel_Map(Handle:timer)
{
	ServerCommand("changelevel %s", votesmaps);
}
//===============================
VoteMenuClose()
{
	Votey = 0;
	Voten = 0;
	CloseHandle(g_hVoteMenu);
	g_hVoteMenu = INVALID_HANDLE;
}
Float:GetVotePercent(votes, totalVotes)
{
	return FloatDiv(float(votes),float(totalVotes));
}
bool:TestVoteDelay(client)
{
	
 	new delay = CheckVoteDelay();
 	
 	if (delay > 0)
 	{
 		if (delay > 60)
 		{
 			CPrintToChat(client, "{default}[{olive}TS{default}] You must wait for {red}%i {default}sec then start a new vote!", delay % 60);
 		}
 		else
 		{
 			CPrintToChat(client, "{default}[{olive}TS{default}] You must wait for {red}%i {default}sec then start a new vote!", delay);
 		}
 		return false;
 	}
	
	delay = GetVoteDelay();
 	if (delay > 0)
 	{
 		CPrintToChat(client, "{default}[{olive}TS{default}] You must wait for {red}%i {default}sec then start a new vote!", delay);
 		return false;
 	}
	return true;
}

bool:CanStartVotes(client)
{
	
 	if(g_hVoteMenu  != INVALID_HANDLE || IsVoteInProgress())
	{
		CPrintToChat(client, "{default}[{olive}TS{default}] A vote is already in progress!");
		return false;
	}
	new iNumPlayers;
	new playerlimit = GetConVarInt(g_hCvarPlayerLimit);
	//list of players
	for (new i=1; i<=MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || !IsClientConnected(i))
		{
			continue;
		}
		iNumPlayers++;
	}
	if (iNumPlayers < playerlimit)
	{
		CPrintToChat(client, "{default}[{olive}TS{default}] Vote cannot be started. Not enough {red}%d {default}players.",playerlimit);
		return false;
	}
	return true;
}
//=======================================
public OnClientDisconnect(client)
{
	if (IsClientInGame(client) && IsFakeClient(client)) return;

	new Float:currenttime = GetGameTime();
	
	if (lastDisconnectTime == currenttime) return;
	
	CreateTimer(SCORE_DELAY_EMPTY_SERVER, IsNobodyConnected, currenttime);
	lastDisconnectTime = currenttime;
}

public Action:IsNobodyConnected(Handle:timer, any:timerDisconnectTime)
{
	if (timerDisconnectTime != lastDisconnectTime) return Plugin_Stop;

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && !IsFakeClient(i))
			return  Plugin_Stop;
	}	
	
	return  Plugin_Stop;
}

/*
bool:StartMatchVote(client, const String:cfgname[],iTeam = 4)
{
	if (GetClientTeam(client) == L4D_TEAM_SPECTATE)
	{
		PrintToChat(client, "Match voting isn't allowed for spectators.");
		return false;
	}
	//if (LGO_IsMatchModeLoaded())
	//{
	//	PrintToChat(client, "Match vote cannot be started. Match is already running.");
	//	return false;
	//}
	if (IsNewBuiltinVoteAllowed())
	{
		new iNumPlayers;
		new playerlimit = GetConVarInt(g_hCvarPlayerLimit);
		//list of players
		for (new i=1; i<=MaxClients; i++)
		{
			if (!IsClientInGame(i) || IsFakeClient(i) || !IsClientConnected(i))
			{
				continue;
			}
			iNumPlayers++;
		}
		if (iNumPlayers < playerlimit)
		{
			CPrintToChat(client, "{default}[{olive}TS{default}] Match vote cannot be started. Not enough {red}%d {default}players.",playerlimit);
			return false;
		}
		new String:sBuffer[64];
		g_hVote = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
		Format(sBuffer, sizeof(sBuffer), "%s", cfgname);
		SetBuiltinVoteArgument(g_hVote, sBuffer);
		SetBuiltinVoteInitiator(g_hVote, client);
		SetBuiltinVoteResultCallback(g_hVote, MatchVoteResultHandler);
		if(iTeam == 4)
		{
			DisplayBuiltinVoteToAll(g_hVote,20);
			EmitSoundToAll("ui/beep_synthtone01.wav");
		}
		else
		{
			DisplayBuiltinVoteToTeam(g_hVote,iTeam,20);
			for (new i=1; i<=MaxClients; i++)
				if(IsClientConnected(i)&&IsClientInGame(i)&&!IsFakeClient(i)&&GetClientTeam(i) == iTeam)
					EmitSoundToClient(i,"ui/beep_synthtone01.wav");
		}
		return true;
	}
	CPrintToChat(client, "{default}[{olive}TS{default}] A vote is already in progress!");
	return false;
}

public VoteActionHandler(Handle:vote, BuiltinVoteAction:action, param1, param2)
{
	switch (action)
	{
		case BuiltinVoteAction_End:
		{
			g_hVote = INVALID_HANDLE;
			CloseHandle(vote);
		}
		case BuiltinVoteAction_Cancel:
		{
			DisplayBuiltinVoteFail(vote, BuiltinVoteFailReason:param1);
		}
	}
}

public MatchVoteResultHandler(Handle:vote, num_votes, num_clients, const client_info[][2], num_items, const item_info[][2])
{
	for(new i=1; i <= MaxClients; i++) ClientVoteMenu[i] = false;
	g_votedelay = VOTEDELAY_TIME;
	CreateTimer(1.0, Timer_VoteDelay, _, TIMER_REPEAT| TIMER_FLAG_NO_MAPCHANGE); 
	for (new i=0; i<num_items; i++)
	{
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
		{
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2))
			{
				EmitSoundToAll("ui/menu_enter05.wav");
				DisplayBuiltinVotePass(vote, "vote pass");
				CreateTimer(3.0,COLD_DOWN,_);
				return;
			}
		}
	}
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
	EmitSoundToAll("ui/beep_error01.wav");
}
*/
public Action:COLD_DOWN(Handle:timer,any:client)
{
	switch (g_voteType)
	{
		case (voteType:hp):
		{
			AnyHp();
			//DisplayBuiltinVotePass(vote, "vote to give hp pass");
			LogMessage("vote to give hp pass");	
		}
		case (voteType:alltalk):
		{
			ServerCommand("sv_alltalk 1");
			//DisplayBuiltinVotePass(vote, "vote to turn on alltalk pass");
			LogMessage("vote to turn on alltalk pass");
		}
		case (voteType:alltalk2):
		{
			ServerCommand("sv_alltalk 0");
			//DisplayBuiltinVotePass(vote, "vote to turn off alltalk pass");
			LogMessage("vote to turn off alltalk pass");
		}
		case (voteType:restartmap):
		{
			ServerCommand("sm_restartmap");
			//DisplayBuiltinVotePass(vote, "vote to restartmap pass");
			LogMessage("vote to restartmap pass");
		}
		case (voteType:map):
		{
			CreateTimer(5.0, Changelevel_Map);
			CPrintToChatAll("[{olive}TS{default}] {green}5{default} sec to change map {blue}%s",votesmapsname);
			//CPrintToChatAll("{blue}%s",votesmaps);
			//DisplayBuiltinVotePass(vote, "Vote to change map pass");
			LogMessage("Vote to change map %s %s pass",votesmaps,votesmapsname);
		}
		case (voteType:swap):
		{
			CPrintToChatAll("[{olive}TS{default}] {blue}%s{default} has been kicked!", swapplayername);
			ServerCommand("sm_kick \"%s\" ", swapplayername);
			//DisplayBuiltinVotePass(vote, "Vote to kick player pass");						
			LogMessage(" Vote to kick %s pass",swapplayername);
		}
		case (voteType:forcespectate):
		{
			CPrintToChatAll("[{olive}TS{default}] {blue}%s{default} has been forcespectated!", swapplayername);
			ChangeClientTeam(forcespectateid, 1);
			//DisplayBuiltinVotePass(vote, "Vote to forcespectate player pass");									
			LogMessage(" Vote to forcespectate %s pass",swapplayername);
			CreateTimer(1.0, Timer_forcespectate, forcespectateid, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE); // Start unpause countdown
		}
	}
}

public Action:Timer_VoteDelay(Handle:timer, any:client)
{
	g_votedelay--;
	if(g_votedelay<=0)
	{
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

GetVoteDelay()
{
	return g_votedelay;
}

ParseCampaigns()
{
	new Handle: g_kvCampaigns = CreateKeyValues("VoteCustomCampaigns");

	new String:sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/VoteCustomCampaigns.txt");

	if ( !FileToKeyValues(g_kvCampaigns, sPath) ) 
	{
		SetFailState("<VCC> File not found: %s", sPath);
		CloseHandle(g_kvCampaigns);
		return;
	}
	
	if (!KvGotoFirstSubKey(g_kvCampaigns))
	{
		SetFailState("<VCC> File can't read: you dumb noob!");
		CloseHandle(g_kvCampaigns);
		return;
	}
	
	for (new i = 0; i < MAX_CAMPAIGN_LIMIT; i++)
	{
		KvGetString(g_kvCampaigns,"mapinfo", g_sMapinfo[i], sizeof(g_sMapinfo));
		KvGetString(g_kvCampaigns,"mapname", g_sMapname[i], sizeof(g_sMapname));
		
		if ( !KvGotoNextKey(g_kvCampaigns) )
		{
			g_iCount = ++i;
			break;
		}
	}
}