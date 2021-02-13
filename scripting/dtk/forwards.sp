
/**
 * SourceMod Forwards
 * ----------------------------------------------------------------------------------------------------
 */

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	char game_folder[32];
	
	GetGameFolderName(game_folder, sizeof(game_folder));
	
	if 		(StrEqual(game_folder, "tf"))				game.SetGame(Mod_TF);
	else if (StrEqual(game_folder, "open_fortress"))	game.SetGame(Mod_OF);
	else if (StrEqual(game_folder, "tf2classic"))		game.SetGame(Mod_TF2C);
	else	LogError("DTK is designed for TF2. Some things may not work!");
	
	MarkNativeAsOptional("Steam_SetGameDescription");
	MarkNativeAsOptional("SCR_SendEvent");
	
	if (late) game.AddFlag(GF_LateLoad);
	
	return APLRes_Success;
}




/**
 * OnAllPluginsLoaded
 */
public void OnAllPluginsLoaded()
{
	// Check for the existence of libraries that DTK can use
	if (!(g_bSteamTools = LibraryExists("SteamTools")))
		LogMessage("Library not found: SteamTools. Unable to change server game description");
	
	if (!(g_bTF2Attributes = LibraryExists("tf2attributes")))
		LogMessage("Library not found: TF2 Attributes. Unable to modify weapon attributes");
		
	if (!(g_bSCR = LibraryExists("Source-Chat-Relay")))
		LogMessage("Library not found: Source Chat Relay. Unable to send event messages to Discord");
}

public void OnLibraryAdded(const char[] name)
{
	LibraryChanged(name, true);
}

public void OnLibraryRemoved(const char[] name)
{
	LibraryChanged(name, false);
}

void LibraryChanged(const char[] name, bool loaded)
{
	if (StrEqual(name, "Steam Tools"))			g_bSteamTools 		= loaded;
	if (StrEqual(name, "tf2attributes"))		g_bTF2Attributes 	= loaded;
	if (StrEqual(name, "Source-Chat-Relay"))	g_bSCR 				= loaded;
}





/**
 * OnPluginStart
 */
public void OnPluginStart()
{
	LoadTranslations("dtk.phrases");
	LoadTranslations("common.phrases");
	
	// Plugin ConVars
	g_ConVars[P_Version]			= CreateConVar("dtk_version", PLUGIN_VERSION);
	g_ConVars[P_Enabled]			= CreateConVar("dtk_enabled", "0", "Enable Deathrun Toolkit");
	g_ConVars[P_AutoEnable]			= CreateConVar("dtk_auto_enable", "1", "Allow the plugin to enable and disable itself based on a map's prefix");
	g_ConVars[P_Debug]				= CreateConVar("dtk_debug", "0", "Enable plugin debugging messages showing in server and client consoles");
	g_ConVars[P_Database]			= CreateConVar("dtk_database", "1", "Store player data in the database");
	g_ConVars[P_SCR]				= CreateConVar("dtk_source_chat_relay", "1", "Use Source Chat Relay if available");
	g_ConVars[P_MapInstructions]	= CreateConVar("dtk_map_instructions", "1", "Allow maps to change player properties and weapons");
	g_ConVars[P_Description]		= CreateConVar("dtk_game_description", "{plugin_name} | {plugin_version}", "Game description that appears in the server browser when the game mode is enabled. Leave blank to not change it at all");
	
	g_ConVars[P_ChatKillFeed]		= CreateConVar("dtk_kill_feed", "1", "Show clients what caused their death in chat");
	g_ConVars[P_RoundStartMessage]	= CreateConVar("dtk_round_start_message", "1", "Show round start messages");
	g_ConVars[P_BossBar]			= CreateConVar("dtk_boss_bar", "1", "Allow activator and entity health to be displayed as a boss health bar");
	g_ConVars[P_Activators]			= CreateConVar("dtk_activators", "1", "Cap on the number of activators. -1 = no cap");
	g_ConVars[P_LockActivator]		= CreateConVar("dtk_lock_activator", "1", "Prevent activators from suiciding or switching teams during rounds");
	//g_ConVars[P_Ghosts]				= CreateConVar("dtk_ghosts", "0", "When a player dies, make them ethereal and give them an outline visible to the dead");
	
	// Player Attributes
	g_ConVars[P_RedSpeed]			= CreateConVar("dtk_red_speed", "0", "Apply a flat run speed to all red players");
	g_ConVars[P_RedScoutSpeed]		= CreateConVar("dtk_red_speed_scout", "0", "Adjust the run speed of red scouts");
	g_ConVars[P_RedAirDash]			= CreateConVar("dtk_red_air_dash", "0", "Toggle red scout air dash");
	g_ConVars[P_RedMelee]			= CreateConVar("dtk_red_melee", "0", "Toggle red melee only");
	g_ConVars[P_BlueSpeed]			= CreateConVar("dtk_blue_speed", "0", "Apply a flat run speed to all blue players");
	g_ConVars[P_Buildings]			= CreateConVar("dtk_buildings", "12", "Restrict engineer buildings. Add up these values to make the convar value: Sentry = 1, Dispenser = 2, Tele Entrance = 4, Tele Exit = 8");
	
	// Server ConVars
	g_ConVars[S_Unbalance]			= FindConVar("mp_teams_unbalance_limit");
	g_ConVars[S_AutoBalance]		= FindConVar("mp_autoteambalance");
	g_ConVars[S_Scramble]			= FindConVar("mp_scrambleteams_auto");
	g_ConVars[S_Queue]				= FindConVar("tf_arena_use_queue");
	g_ConVars[S_WFPTime]			= FindConVar("mp_waitingforplayers_time");
	
	// Work-in-Progress Features
	g_ConVars[P_BlueBoost]			= CreateConVar("dtk_wip_blue_boost", "0", "Allow Blue player to sprint using the +speed input");
	g_ConVars[P_ActivatorRatio]		= CreateConVar("dtk_wip_activator_ratio", "0.2", "Activator ratio. Decimal fraction of the number of participants to become activators. e.g. 0.2 is one fifth of participants become an activator");
	
	if (!(game.IsGame(Mod_OF)))				g_ConVars[S_FirstBlood]	= FindConVar("tf_arena_first_blood");
	if (game.IsGame(Mod_OF))				g_ConVars[S_Pushaway] 	= FindConVar("of_teamplay_collision");
	if (game.IsGame(Mod_TF|Mod_TF2C))		g_ConVars[S_Pushaway] 	= FindConVar("tf_avoidteammates_pushaway");

	// Cycle through and hook each ConVar
	for (int i = 0; i < ConVars_Max; i++)
		if (g_ConVars[i] != null)
			g_ConVars[i].AddChangeHook(ConVar_ChangeHook);
	
	// Commands
	RegConsoleCmd("sm_drmenu", Command_NewMenu, "Opens the deathrun menu.");
	RegConsoleCmd("sm_dr", Command_NewMenu, "Opens the deathrun menu.");
	RegConsoleCmd("sm_drtoggle", Command_NewMenu, "Opens the deathrun menu.");
	RegConsoleCmd("sm_points", Command_ShowPoints, "Show how many deathrun queue points you have.");
	RegConsoleCmd("sm_pts", Command_ShowPoints, "Show how many deathrun queue points you have.");
	RegConsoleCmd("sm_reset", Command_ResetPoints, "Reset your deathrun queue points.");
	RegConsoleCmd("sm_prefs", Command_Preferences, "A shortcut command for setting your deathrun activator and points preference.");
	
	// Admin Commands
	RegAdminCmd("sm_setclass", AdminCommand_SetClass, ADMFLAG_SLAY, "Change a player's class using DTK's built in functions, which also apply the correct attributes");
	RegAdminCmd("sm_setspeed", AdminCommand_SetSpeed, ADMFLAG_SLAY, "Change a player's run speed using an attribute");
	RegAdminCmd("sm_draward", AdminCommand_AwardPoints, ADMFLAG_SLAY, "Award a poor person some deathrun queue points.");
	RegAdminCmd("sm_drresetdatabase", AdminCommand_ResetDatabase, ADMFLAG_CONVARS|ADMFLAG_CONFIG|ADMFLAG_RCON, "Reset the deathrun player database.");
	RegAdminCmd("sm_drresetuser", AdminCommand_ResetUser, ADMFLAG_CONVARS|ADMFLAG_CONFIG|ADMFLAG_RCON, "Deletes a player's data from the deathrun database table. They will be treated as a new player.");
	
	// Debug Commands
	RegAdminCmd("sm_drdata", AdminCommand_PlayerData, ADMFLAG_SLAY, "Print to console the values in the prefs and points arrays.");
	
	// Build Sound List
	g_hSounds = SoundList();
	
	// Late Loading
	if (game.HasFlag(GF_LateLoad))
	{
		// Initialise Player Data Array
		LogMessage("Plugin loaded late. Initialising the player data array");
		for (int i = 1; i <= MaxClients; i++)
		{
			if (Player(i).InGame)
			{
				Player(i).CheckArray();
				
				// Hook Player Damage Received
				if (GetFeatureStatus(FeatureType_Native, "SDKHook") == FeatureStatus_Available)
					SDKHook(i, SDKHook_OnTakeDamageAlive, Hook_OnTakeDamage);
			}
		}
	}
	
	// Announce Plugin Load
	PrintToServer("%s %s has loaded", PLUGIN_NAME, PLUGIN_VERSION);
	ChatMessageAll(Msg_Plugin, "%s has loaded", PLUGIN_SHORTNAME);
}




/**
 * OnPluginEnd
 */
public void OnPluginEnd()
{
	// Save Player Data
	if (g_ConVars[P_Database].BoolValue && g_db != null)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (Player(i).InGame && !Player(i).IsBot)
				Player(i).SaveData();
		}
	}
	
	ChatMessageAll(Msg_Plugin, "%s has been unloaded", PLUGIN_SHORTNAME);
	g_ConVars[P_Enabled].SetBool(false);	// TODO What's this for?
}





/**
 * OnMapStart
 *
 * Also Called on Late Load
 */
public void OnMapStart()
{
	// Database Maintenance
	DBCreateTable();	// Create table and connection
	DBPrune();			// Prune old records
	
	// Round State Reset
	game.RoundState = Round_Waiting;
}




/**
 * OnConfigsExecuted
 *
 * Execute config_deathrun.cfg when all other configs have loaded.
 */
public void OnConfigsExecuted()
{
	if (g_ConVars[P_AutoEnable].BoolValue)
	{
		char mapname[32];
		GetCurrentMap(mapname, sizeof(mapname));
		
		if (StrContains(mapname, "dr_", false) != -1 || StrContains(mapname, "deathrun_", false) != -1)
			g_ConVars[P_Enabled].SetBool(true);
	}
	
	if (g_ConVars[P_Enabled].BoolValue)
	{
		PrecacheAssets(g_hSounds);
		ServerCommand("exec config_deathrun.cfg");
	}
}




/**
 * OnMapEnd
 */
public void OnMapEnd()
{
	delete g_db;
	
	if (g_ConVars[P_Enabled].BoolValue)
		g_ConVars[P_Enabled].SetBool(false);
}




/**
 * OnClientAuthorized
 */
public void OnClientAuthorized(int client, const char[] auth)
{
	Player(client).CheckPlayer();
}




/**
 * OnClientPutInServer
 */
public void OnClientPutInServer(int client)
{
	if (!g_ConVars[P_Enabled].BoolValue)
		return;
	
	// Hook Player Damage Received
	if (GetFeatureStatus(FeatureType_Native, "SDKHook") == FeatureStatus_Available)
		SDKHook(client, SDKHook_OnTakeDamageAlive, Hook_OnTakeDamage);
}




/**
 * OnClientDisconnect
 */
public void OnClientDisconnect(int client)
{
	// Save Player Data
	if (g_ConVars[P_Database].BoolValue && g_db != null && !Player(client).IsBot)
		Player(client).SaveData();

	if (!g_ConVars[P_Enabled].BoolValue)
		return;
	
	// Remove unneeded tf_glow entity
	//if (g_iGhost[client])
	//	MakeGhost(client, false);
	
	// Health Bar
	if (game.IsHealthBarActive && client == g_iBoss)
	{
		g_iBoss = -1;
		SetHealthBar();
	}
}




/**
 * OnPlayerRunCmdPost
 */
public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3], int weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2])
{
	if (!g_ConVars[P_Enabled].BoolValue)
		return;
	
	// Modulate player speeds
	ModulateSpeed(client);
	
	// Monitor and apply activator boosts
	ActivatorBoost(client, buttons, tickcount);
}





/**
 * Library Forwards
 * ----------------------------------------------------------------------------------------------------
 */

 /**
 * SteamTools Steam_FullyLoaded
 *
 * Called when SteamTools connects to Steam.
 * This forward is used to set the game description after a server restart.
 */
public int Steam_FullyLoaded()
{
	if (g_ConVars[P_Enabled].BoolValue)
		GameDescription(true);
}