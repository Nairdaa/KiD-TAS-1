#if defined __tas_included
	#endinput
#endif
#define __tas_included

#include <sourcemod>
#include <sdkhooks>
#include <shavit>
#include <dhooks>

#include <string_test>
#include <convar_class>
#include <thelpers/thelpers>

public Plugin myinfo = 
{
	name = "Shavit - TAS", 
	author = "KiD Fearless", 
	description = "TAS module for shavits timer.", 
	version = "2.0", 
	url = "https://github.com/kidfearless/"
};

ConVar sv_cheats;
Convar g_cDefaultCheats;
bool g_bLate;

#include <kid_tas>

public void OnPluginStart()
{
	// thanks xutaxkamay for pointing my head back to rngfix after i gave up on it.
	LoadDHooks();

	RegConsoleCmd("sm_tasmenu", Command_TasMenu, "opens tas menu");
	RegConsoleCmd("sm_timescale", Command_TimeScale, "sets timescale");

	sv_cheats = FindConVar("sv_cheats");

	g_cDefaultCheats = new Convar("kid_tas_cheats_default", "2", "Default sv_cheats value, used for servers that set cheats on connect.");

	Convar.AutoExecConfig();

	if(g_bLate)
	{
		for(int i = 1; i <= MaxClients; ++i)
		{
			Client client = new Client(i);
			if(client.IsConnected && client.IsInGame && !client.IsFakeClient)
			{
				client.OnPutInServer();
			}
		}
	}
}

void LoadDHooks()
{
	// totally not ripped from rngfix :)
	Handle gamedataConf = LoadGameConfigFile("KiD-TAS.games");

	if(gamedataConf == null)
	{
		SetFailState("Failed to load KiD-TAS gamedata");
	}

	// CreateInterface
	// Thanks SlidyBat and ici
	StartPrepSDKCall(SDKCall_Static);
	if(!PrepSDKCall_SetFromConf(gamedataConf, SDKConf_Signature, "CreateInterface"))
	{
		SetFailState("Failed to get CreateInterface");
	}
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	Handle CreateInterface = EndPrepSDKCall();

	if(CreateInterface == null)
	{
		SetFailState("Unable to prepare SDKCall for CreateInterface");
	}

	char interfaceName[64];

	// ProcessMovement
	if(!GameConfGetKeyValue(gamedataConf, "IGameMovement", interfaceName, sizeof(interfaceName)))
	{
		SetFailState("Failed to get IGameMovement interface name");
	}

	Address IGameMovement = SDKCall(CreateInterface, interfaceName, 0);
	
	if(!IGameMovement)
	{
		SetFailState("Failed to get IGameMovement pointer");
	}

	int offset = GameConfGetOffset(gamedataConf, "ProcessMovement");
	if(offset == -1)
	{
		SetFailState("Failed to get ProcessMovement offset");
	}

	Handle processMovement = DHookCreate(offset, HookType_Raw, ReturnType_Void, ThisPointer_Ignore, DHook_ProcessMovementPre);
	DHookAddParam(processMovement, HookParamType_CBaseEntity);
	DHookAddParam(processMovement, HookParamType_ObjectPtr);
	DHookRaw(processMovement, false, IGameMovement);

	delete CreateInterface;
	delete gamedataConf;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLate = late;
	return APLRes_Success;
}

public void OnClientPutInServer(int client)
{
	Client.Create(client).OnPutInServer();
}

public Action Command_TasMenu(int client, int args)
{
	Client cl = new Client(client);
	if(cl.Enabled)
	{
		cl.OpenMenu();
	}
	else
	{
		ReplyToCommand(client, "You must be in TAS first");
	}
	return Plugin_Handled;
}

public Action Command_TimeScale(int client, int args)
{
	string arg;
	arg.GetCmdArg(1);

	float scale = arg.FloatValue();

	Client.Create(client).TimeScale = scale;

	return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	return Client.Create(client).OnTick(buttons, vel, angles, mouse);
}

public void OnPreThinkPost(int client)
{
	Client.Create(client).OnPreThinkPost();
}

public void OnPostThink(int client)
{
	Client.Create(client).OnPostThink();
}

public MRESReturn DHook_ProcessMovementPre(Handle hParams)
{
	int client = DHookGetParam(hParams, 1);
	return Client.Create(client).OnProcessMovement();
}

public int MenuHandler_TAS(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			Client client = new Client(param1);
			string info;
			info.GetMenuInfo(menu, param2);

			if(!client.Enabled)
			{
				return 0;
			}

			if (info.Equals("cp"))
			{
				FakeClientCommand(client.Index, "sm_cpmenu");
			}
			else
			{
				if (info.Equals("++"))
				{
					client.TimeScale += 0.1;
				}
				else if (info.Equals("--"))
				{
					client.TimeScale -= 0.1;
				}
				else if (info.Equals("jump"))
				{
					client.AutoJump = !client.AutoJump;
				}
				else if (info.Equals("as"))
				{
					client.AutoStrafe = !client.AutoStrafe;
				}
				else if(info.Equals("sh"))
				{
					client.StrafeHack = !client.StrafeHack;
				}


				client.OpenMenu();
			}
		}

		case MenuAction_End:
		{
			delete menu;
		}
	}

	return 0;
}

public void Shavit_OnLeaveZone(int client, int type, int track, int id, int entity, int data)
{
	if(type == Zone_Start)
	{
		Client.Create(client).OnLeaveStartZone();
	}
}

public void Shavit_OnStyleChanged(int client, int oldstyle, int newstyle, int track, bool manual)
{
	string_128 special;
	Shavit_GetStyleStrings(newstyle, sSpecialString, special.StringValue, special.Size());

	Client.Create(client).Enabled = special.Includes("TAS");
}

// Stocks
public float NormalizeAngle(float angle)
{
	float temp = angle;
	
	while (temp <= -180.0)
	{
		temp += 360.0;
	}
	
	while (temp > 180.0)
	{
		temp -= 360.0;
	}
	
	return temp;
}