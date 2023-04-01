#include <sourcemod>
#include <sdktools>

EngineVersion g_Game;


Handle hTimer;

ArrayList aGameModes;
char sCurrentGameName[52];
char sNextGameName[52];
int iCurrentGameTime;

int modeIndex;

bool isLoop = false;
bool isLastMode = false;
bool isH3busDM;

char CONFIG_PATH[255];

public void OnPluginStart()
{
	g_Game = GetEngineVersion();
	if (g_Game != Engine_CSGO)
	{
		SetFailState("This plugin is for CSGO.");
	}
	
	BuildPath(Path_SM, CONFIG_PATH, sizeof(CONFIG_PATH), "configs/multicfg-dm.cfg");
	
	aGameModes = CreateArray();
	
	LoadConfig();
	LoadGameModes();
	
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
}

public OnMapStart()
{
	hTimer = INVALID_HANDLE;
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (hTimer != INVALID_HANDLE)
	{
		KillTimer(hTimer, false);
		hTimer = INVALID_HANDLE;
	}
	
	modeIndex = 0;
	
	// First Load
	PrepareNextMode();
	ExecConfig(true);
	
	hTimer = CreateTimer(1.0, CycleControl, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action CycleControl(Handle timer)
{
	if(isLastMode)
		return Plugin_Stop;
	
	iCurrentGameTime--;
	
	if(iCurrentGameTime <= 0)
	{
		PrepareNextMode();
		
		ExecConfig(true);
	}
	
	if(iCurrentGameTime <= 10 && iCurrentGameTime > 0)
	{
		char sAdvertMessage[255];
		
		Format(sAdvertMessage, sizeof(sAdvertMessage), "<font color='#ff0000'>ShabiTV</font>\nChanging to <font color='#66ff66'>%s</font> in <font color='#66ff66'>%i</font> seconds", sNextGameName, iCurrentGameTime);		
	
		if(iCurrentGameTime >= 1)
		{
			PrintHintTextToAll(sAdvertMessage);
		}
	}
	
	return Plugin_Handled;
}

void ExecConfig(bool sound)
{
	char sCommand[255];
	char sConfigName[52];
	
	sConfigName = sCurrentGameName;
	
	if(!isH3busDM)
	{
		StrCat(sConfigName, sizeof(sConfigName), ".ini");
		Format(sCommand, sizeof(sCommand), "dm_load \"%s\" \" equip\"", sConfigName);
	}
	else
	{
		Format(sCommand, sizeof(sCommand), "dm_load \"Game Modes\" \"%s\" \"equip\"", sConfigName);
	}
	
	ServerCommand(sCommand);
	
	UpdateGameModeIndex();
	
}

void PrepareNextMode()
{	
	ArrayList aGameMode = new ArrayList(512);
	ArrayList aNextGameMode = new ArrayList(512);
	
	aGameMode = aGameModes.Get(modeIndex);
	
	if(modeIndex == (aGameModes.Length - 1))
		aNextGameMode = aGameModes.Get(0);
	else
		aNextGameMode = aGameModes.Get(modeIndex+1);
	
	iCurrentGameTime = aGameMode.Get(1);

	// sCurrentGameName = sNextGameName; <---- need a bit modification on initialisation to apply this
	aGameMode.GetString(0, sCurrentGameName, sizeof(sCurrentGameName));
	
	aNextGameMode.GetString(0, sNextGameName, sizeof(sNextGameName));
}

void LoadGameModes()
{
	KeyValues kvGameModes = new KeyValues("MultiCFG");
	if (!FileExists(CONFIG_PATH))
	{
		SetFailState("Unable to find multicfg-dm.cfg in %s", CONFIG_PATH);
		return;
	}
	
	kvGameModes.ImportFromFile(CONFIG_PATH);
	
	if (kvGameModes.JumpToKey("Game Modes"))
	{
		kvGameModes.GotoFirstSubKey();
		AddGameModeToArray(kvGameModes);
		
		while (kvGameModes.GotoNextKey())
		{
			AddGameModeToArray(kvGameModes);
		}
	}
	else
	{
		SetFailState("Unable to find Game Modes in %s", CONFIG_PATH);
		return;
	}
	
	delete kvGameModes;
}

void LoadConfig()
{
	KeyValues kvConfig = new KeyValues("MultiCFG");
	if (!FileExists(CONFIG_PATH))
	{
		SetFailState("Unable to find multicfg-dm.cfg in %s", CONFIG_PATH);
		return;
	}
	
	kvConfig.ImportFromFile(CONFIG_PATH);
	
	if (kvConfig.JumpToKey("Config"))
	{
		isLoop = view_as<bool>(KvGetNum(kvConfig, "Loop"));
		isH3busDM = view_as<bool>(KvGetNum(kvConfig, "H3busCompatibility"));
	}
	else
	{
		SetFailState("Unable to find Config in %s", CONFIG_PATH);
		return;
	}

	
	delete kvConfig;
}


void AddGameModeToArray(Handle kv)
{
	char sGameModeName[255];
	int sGameModeTime = 0;
	
	KvGetString(kv, "name", sGameModeName, sizeof(sGameModeName));
	sGameModeTime = KvGetNum(kv, "time");
	
	ArrayList aGameMode = new ArrayList(512);
	aGameMode.PushString(sGameModeName);
	aGameMode.Push(sGameModeTime);
	
	aGameModes.Push(aGameMode);
}

void UpdateGameModeIndex()
{
	if (modeIndex < aGameModes.Length)
	{
		if (modeIndex == (aGameModes.Length - 1))
		{
			if (isLoop)
				modeIndex = 0;
			else
				isLastMode = true;
		}
		else
		{
			modeIndex++;
		}
	}
}
