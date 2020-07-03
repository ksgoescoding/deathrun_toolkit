/**
 * Internal Functions
 * ----------------------------------------------------------------------------------------------------
 */




/**
 * Player Allocation
 * ----------------------------------------------------------------------------------------------------
 */
 
 
/**
 * Check for players when an activator is needed or a team changed detected
 * during pre-round freeze time.
 * 
 * @noreturn
 */
void CheckForPlayers()
{
	// The number of activators we want
	int desired_activators = g_cActivators.IntValue;

	DebugMessage("Checking for players...");

	// Too few players on blue, enough on red
	if (g_bWatchForPlayerChanges && DTK_CountPlayers(Team_Blue) < desired_activators && DTK_CountPlayers() > desired_activators)
	{
		g_bWatchForPlayerChanges = false;		// Stop watching for new players
		DebugMessage("A blue player has left the team during freeze time.");
		RequestFrame(RedistributePlayers);		// Make some changes. We'll go back to watching when the changes are done.
			// Request frame prevents red team count from going up falsely due to switching too fast
		return;
	}
	
	// In freeze time with the required number of activators
	if (g_bWatchForPlayerChanges && DTK_CountPlayers(Team_Blue) == desired_activators)
	{
		DebugMessage("Team change detected but no action required");
		return;
	}

	// At round restart
	if (!g_bWatchForPlayerChanges && DTK_CountPlayers() > 1)
	{
		DebugMessage("We have enough players to start.");
		RedistributePlayers();
	}
	/*else if (!g_bWatchForPlayerChanges && DTK_CountPlayers(0, false) > 2 && desired_activators > 1)
	{
		CheckForPlayers();
	}*/
	else
	{
		DebugMessage("Not enough players to start a round. Gone into waiting mode");
		g_bWatchForPlayerChanges = true;
	}
}



/**
 * Select an activator and redistribute players to the right teams.
 * 
 * @noreturn
 */
void RedistributePlayers()
{
	DebugMessage("Redistributing the players");
	
	// Move all blue players to the red team
	for (int i = 1; i <= MaxClients; i++)
	{
		Player player = new Player(i);
		if (player.InGame && player.Team == Team_Blue)
			player.SetTeam(Team_Red);
	}
	
	if (g_cUsePointsSystem.BoolValue)	// Use queue points system if enabled
	{
		int prefers;
		
		for (int i = 1; i <= MaxClients; i++)
		//for (int i = 1; i <= MaxClients && prefers <= MINIMUM_ACTIVATORS; i++)
		{
			Player player = new Player(i);
			if (player.Flags & FLAGS_PREFERENCE)
				// If player.Flags has the FLAGS_PREFERENCE bit set, return true
				prefers += 1;
		}
		
		if (prefers <= MINIMUM_ACTIVATORS)
		{
			SelectActivatorTurn();
			PrintToChatAll("%t %t", "prefix", "not enough activators");
		}
		else
			SelectActivatorPoints();
	}					
	else
		SelectActivatorTurn();				// Use turn-based system if queue points are disabled
	
	g_bWatchForPlayerChanges = true;		// Go into watch mode to replace activator if needed
}



/**
 * select an activator by using the queue point system. 
 * 
 * @noreturn
 */
void SelectActivatorPoints()
{
	// First sort our player points array by points in descending order
	int points_order[TF2MAXPLAYERS-1][2];
		// 0 will be client index. 1 will be points.
		
	for (int i = 0; i < MaxClients; i++)
	{
		Player player = new Player(i + 1);
		points_order[i][0] = player.Index;
		points_order[i][1] = player.Points;
	}
	
	SortCustom2D(points_order, MaxClients, SortByPoints);
	
	// If we need activators and have enough on red to supply and not empty the team, move someone
	int i = 0;
	
	while (GetTeamClientCount(Team_Blue) < g_cActivators.IntValue && GetTeamClientCount(Team_Red) > 1)
	{
		Player player = new Player(points_order[i][0]);
		
		if (player.InGame && player.Team == Team_Red && (player.Flags & FLAGS_PREFERENCE))
			// If player.Flags has the FLAGS_PREFERENCE bit set return true
		{
			PrintToServer("%s The points-based activator selection system has selected %N", SERVERMSG_PREFIX, player.Index);
			if (g_bSCR && g_cSCR.BoolValue)
				SCR_SendEvent(SERVERMSG_PREFIX, "%N is now the activator", player.Index);
			player.SetTeam(Team_Blue);
			player.SetPoints(Points_Consumed);
			PrintToChat(player.Index, "%t %t", "prefix_notice", "queue points consumed");
			g_iHealthBarTarget = player.Index;
		}
		
		if (i == MaxClients - 1)
			i = 0;
		else
			i++;
	}
}



/**
 * Select an activator by using the fall-back turn-based system.
 * 
 * @noreturn
 */
void SelectActivatorTurn()
{
	static int iClientTurn = 1;
	
	//if (client > MaxClients)
		//client = 1;
	
	// If we need activators and have enough on red to supply and not empty the team, move someone
	while (GetTeamClientCount(Team_Blue) < g_cActivators.IntValue && GetTeamClientCount(Team_Red) > 1)
	{
		Player player = new Player(iClientTurn);
		
		if (player.InGame && player.Team == Team_Red)
		{
			PrintToServer("%s The turn-based activator selection system has selected %N", SERVERMSG_PREFIX, player.Index);
			if (g_bSCR && g_cSCR.BoolValue)
				SCR_SendEvent(SERVERMSG_PREFIX, "%N is now the activator", player.Index);
			player.SetTeam(Team_Blue);
			g_iHealthBarTarget = player.Index;
			DebugMessage("Set g_iHealthBarTarget to %d (%N)", player.Index, player.Index);
		}
		
		if (iClientTurn == MaxClients)
			iClientTurn = 1;
		else
			iClientTurn++;
	}	
}



/**
 * Apply the necessary attributes to a player after they spawn.
 * 
 * @noreturn
 */
void ApplyPlayerAttributes(Player player)
{
	if (g_iGame != Game_TF)
		return;
	
	/*int iRunSpeeds[] =
	{
		RunSpeed_NoClass,
		RunSpeed_Scout,
		RunSpeed_Sniper,
		RunSpeed_Soldier,
		RunSpeed_DemoMan,
		RunSpeed_Medic,
		RunSpeed_Heavy,
		RunSpeed_Pyro,
		RunSpeed_Spy,
		RunSpeed_Engineer
	};*/
	
	// Blue
	if (player.Team == Team_Blue)
	{
		if (g_cBlueSpeed.FloatValue != 0.0)
		{
			//DTK_AddPlayerAttribute(player.Index, "CARD: move speed bonus", g_cBlueSpeed.FloatValue / iRunSpeeds[player.Class]);
			player.SetSpeed(g_cBlueSpeed.IntValue);
		}
	}

	// Red
	if (player.Team == Team_Red)
	{
		// Set red speed
		if (g_cRedSpeed.FloatValue != 0.0)
		{
			//DTK_AddPlayerAttribute(player.Index, "CARD: move speed bonus", g_cRedSpeed.FloatValue / iRunSpeeds[player.Class]);
			player.SetSpeed(g_cRedSpeed.IntValue);
		}
		// set red scout speed
		else if (g_cRedScoutSpeed.FloatValue != 0.0 && player.Class == TFClass_Scout)
		{
			//DTK_AddPlayerAttribute(player.Index, "CARD: move speed bonus", g_cRedScoutSpeed.FloatValue / iRunSpeeds[player.Class]);
			player.SetSpeed(g_cRedScoutSpeed.IntValue);
		}
		
		// Disable double jump
		if (g_cRedScoutDoubleJump.BoolValue == false && player.Class == TFClass_Scout)
		{
			DTK_AddPlayerAttribute(player.Index, "no double jump", 1.0);
		}
		
		// Spy cloaking
		if (player.Class == TFClass_Spy)
		{
			if (g_cRedSpyCloakLimits.IntValue == 2)
			{
				DTK_AddPlayerAttribute(player.Index, "mult cloak meter consume rate", 8.0);
				DTK_AddPlayerAttribute(player.Index, "mult cloak meter regen rate", 0.25);
			}
		}

		// Demo man charging
		if (player.Class == TFClass_DemoMan)
		{
			switch (g_cRedDemoChargeLimits.IntValue)
			{
				case 0:
				{
					DTK_AddPlayerAttribute(player.Index, "charge time decreased", -1000.0);
					DTK_AddPlayerAttribute(player.Index, "charge recharge rate increased", 0.0);
				}
				case 2:
				{
					DTK_AddPlayerAttribute(player.Index, "charge time decreased", -0.95);
					DTK_AddPlayerAttribute(player.Index, "charge recharge rate increased", 0.2);
				}
			}
		}
	}
}



/**
 * Remove a player's weapon and replace it with a new one.
 * 
 * @param	int	Client index.
 * @param	int	Weapon entity index.
 * @param	int	Chosen item definition index.
 * @param	char	Classname of chosen weapons.
 * @noreturn
 */
void ReplaceWeapon(int client, int weapon, int itemDefIndex, char[] classname)
{
	RemoveEdict(weapon);
	
	if (g_bTF2Items)
	{
		Handle item = TF2Items_CreateItem(OVERRIDE_ALL);
		TF2Items_SetClassname(item, classname);
		TF2Items_SetItemIndex(item, itemDefIndex);
		TF2Items_SetNumAttributes(item, 0);
		TF2Items_SetLevel(item, 0);
		TF2Items_SetQuality(item, 0);
		weapon = TF2Items_GiveNamedItem(client, item);
		EquipPlayerWeapon(client, weapon);
		CloseHandle(item);
	}
	else
	{
		weapon = CreateEntityByName(classname);
		if (weapon == -1)
		{
			LogError("Couldn't create %s for %N", classname, client);
		}
		else
		{
			SetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex", itemDefIndex);
			SetEntProp(weapon, Prop_Send, "m_iEntityLevel", 0);
			SetEntProp(weapon, Prop_Send, "m_iEntityQuality", 0);
			SetEntProp(weapon, Prop_Send, "m_bValidatedAttachedEntity", true);
			SetEntProp(weapon, Prop_Send, "m_bInitialized", 1);
			
			if (!DispatchSpawn(weapon))
			{
				LogError("Couldn't spawn %s for %N", classname, client);
			}
			else
			{
				Player player = new Player(client);
				player.Flags |= FLAGS_ARMED;
					// Give the player the FLAGS_ARMED bit
				EquipPlayerWeapon(client, weapon);
			}
		}
	}
	
	DebugMessage("Replaced a weapon belonging to %N with %s %d", client, classname, itemDefIndex);
}



/**
 * Check how many red players are alive and toggle team mate pushing if enabled.
 * 
 * @noreturn
 */
void CheckGameState()
{
	//if (!g_bIsRoundActive)
	//	return;
	
	if (!game.RoundActive)
		return;
	
	int iRedAlive = DTK_CountPlayers(Team_Red, LifeState_Alive);
	
	// Team pushing	
	int iPushRemaining = g_cTeamPushOnRemaining.IntValue;
	bool bAlwaysPush = g_cTeamMatePush.BoolValue;
	bool bPushingEnabled = g_cServerTeamMatePush.BoolValue;
	
	if (!bAlwaysPush && iPushRemaining != 0)
	{
		if (!bPushingEnabled && iRedAlive <= iPushRemaining)
		{
			g_cServerTeamMatePush.SetBool(true);
			PrintToChatAll("%t %t", "prefix", "team mate pushing enabled");
		}
		if (bPushingEnabled && iRedAlive > iPushRemaining)
		{
			g_cServerTeamMatePush.SetBool(false);
			PrintToChatAll("%t %s", "prefix", "Team mate pushing has been disabled");
		}
	}
	
	/*
		Is the round active?
		
		Count red players alive
		
		Pushing
			Is global pushing disabled?
				If push remain enabled?
					If less than or equal to cvar setting, apply pushing
					Else disable.
	*/

/*
	// Red glow
	int iGlowRemain = g_cRedGlowRemaining.IntValue;
	
	if (iRedAlive <= iGlowRemain && iGlowRemain != 0 && g_cRedGlow.BoolValue == false)
	{
		g_bIsRedGlowActive = true;
		
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == Team_Red)
			{
				SetEntProp(i, Prop_Send, "m_bGlowEnabled", 1, 1);
			}
		}
	}
*/
}



/**
 * Get the activator's current health and max health and pass them to the HealthBar methodmap.
 * 
 * @noreturn
 */
void SetHealthBar()
{
	if (healthbar.Index == -1 || healthbar.PlayerResource == -1)
		return;
	
	if (g_iHealthBarTarget == -1)
	{
		healthbar.SetHealth();
		g_bHealthBarActive = false;
		return;
	}
	
	Player player = new Player(g_iHealthBarTarget);
	
	int health = player.Health;						// Get the player's health
	int maxHealth = player.MaxHealth;				// Get the player's max health from the player resource entity
	
	/*
	if (health > maxHealth)
		maxHealth = health;
	
	float value = (float(health) / float(maxHealth)) * 255.0;									// Calculate the percentage of health to max health and convert it to a 0-255 scale
	
	if (value > 255.0)																			// Limit the values so they don't cause the bar to display at incorrect times
		value = 255.0;
	if (value < 0.0)
		value = 0.0;
	
	SetEntProp(healthbar.Index, Prop_Send, "m_iBossHealthPercentageByte", RoundToNearest(value));
	SetEntProp(healthbar.Index, Prop_Send, "m_iBossState", 0);											// Makes it default blue
	*/
	
	healthbar.SetHealth(health, maxHealth);
}



/**
 * Process a text string into a class number.
 * 
 * @param	char	Class name string.
 * @return	int	Class number.
 */
int ProcessClassString(const char[] string)
{
	int class;
	
	if (strncmp(string, "scout", 3, false) == 0)
	{
		class = view_as<int>(TFClass_Scout);
	}
	else if (strncmp(string, "soldier", 3, false) == 0)
	{
		class = view_as<int>(TFClass_Soldier);
	}
	else if (strncmp(string, "pyro", 3, false) == 0)
	{
		class = view_as<int>(TFClass_Pyro);
	}
	else if (strncmp(string, "demo", 3, false) == 0)
	{
		class = view_as<int>(TFClass_DemoMan);
	}
	else if (strncmp(string, "heavy", 3, false) == 0)
	{
		class = view_as<int>(TFClass_Heavy);
	}
	else if (strncmp(string, "engineer", 3, false) == 0)
	{
		class = view_as<int>(TFClass_Engineer);
	}
	else if (strncmp(string, "medic", 3, false) == 0)
	{
		class = view_as<int>(TFClass_Medic);
	}
	else if (strncmp(string, "spy", 3, false) == 0)
	{
		class = view_as<int>(TFClass_Spy);
	}
	else if (strncmp(string, "sniper", 3, false) == 0)
	{
		class = view_as<int>(TFClass_Sniper);
	}
	
	return class;
}




/**
 * Map Interaction
 * ----------------------------------------------------------------------------------------------------
 */


/**
 * Hook logic_cases
 * 
 * @noreturn
 */
void HookLogicCases()
{
	int i = -1;
	char sTargetname[MAX_NAME_LENGTH];
	
	// Hook deathrun settings logic_cases
	while ((i = FindEntityByClassname(i, "logic_case")) != -1)
	{
		GetEntPropString(i, Prop_Data, "m_iName", sTargetname, sizeof(sTargetname));
		if (StrContains(sTargetname, "deathrun_settings", false) != -1)
		{
			DebugMessage("Found logic_case named %s", sTargetname);
			HookSingleEntityOutput(i, "OnUser1", ProcessLogicCase2);
		}
	}
}


/**
 * Process data from a logic_case
 * 
 * @noreturn
 */
stock void ProcessLogicCase(const char[] output, int caller, int activator, float delay)
{
	// Caller is the entity reference of the logic_case
	
	char caseValue[256];
	Player player = new Player(activator);
	
	// Class
	GetEntPropString(caller, Prop_Data, "m_nCase[3]", caseValue, sizeof(caseValue));
	if (caseValue[0] != '0')
	{
		int class = ProcessClassString(caseValue);
		player.SetClass(view_as<TFClassType>(class));
	}
	
	// Weapon slot
	GetEntPropString(caller, Prop_Data, "m_nCase[0]", caseValue, sizeof(caseValue));
	int slot = StringToInt(caseValue);
	
	// Weapon IDI
	GetEntPropString(caller, Prop_Data, "m_nCase[1]", caseValue, sizeof(caseValue));
	int itemDefIndex = StringToInt(caseValue);
	
	// Weapon classname
	char classname[64];
	GetEntPropString(caller, Prop_Data, "m_nCase[2]", classname, sizeof(classname));
	
	// Speed
	GetEntPropString(caller, Prop_Data, "m_nCase[4]", caseValue, sizeof(caseValue));
	if (caseValue[0] != '0') player.SetSpeed(StringToInt(caseValue));
	
	// Max health
	GetEntPropString(caller, Prop_Data, "m_nCase[5]", caseValue, sizeof(caseValue));
	if (caseValue[0] != '0') player.SetMaxHealth(StringToFloat(caseValue));
	
	// Health
	GetEntPropString(caller, Prop_Data, "m_nCase[6]", caseValue, sizeof(caseValue));
	if (caseValue[0] != '0') player.SetHealth(StringToInt(caseValue));
	
	// Move type
	GetEntPropString(caller, Prop_Data, "m_nCase[7]", caseValue, sizeof(caseValue));
	if (caseValue[0] != '0')
	{
		if (StrEqual(caseValue, "MOVETYPE_FLY", true))
		{
			SetEntityMoveType(player.Index, MOVETYPE_FLY);
		}
	}
	
	// Message
	char message[256];
	GetEntPropString(caller, Prop_Data, "m_nCase[8]", message, sizeof(message));
	if (message[0] != '0') PrintToChat(player.Index, "%t %s", "prefix_notice", message);
	
	// Melee-only
	GetEntPropString(caller, Prop_Data, "m_nCase[9]", caseValue, sizeof(caseValue));
	if (caseValue[0] == 'y')
	{
		player.MeleeOnly();
	}
	if (caseValue[0] == 'n')
	{
		player.MeleeOnly(false);
	}
	
	// Give weapon
	if (itemDefIndex != 0 && classname[0] != '0')
	{
		PrintToChatAll("Replacing weapon in slot %d to a %s", slot, classname);
		int weapon;
		if ((weapon = player.GetWeapon(slot)) != -1)
		{
			ReplaceWeapon(activator, weapon, itemDefIndex, classname);
		}
	}	
}


/**
 * Process data from a logic_case using string splitting and delimiters
 * 
 * @noreturn
 */
stock void ProcessLogicCase2(const char[] output, int caller, int activator, float delay)
{
	// Caller is the entity reference of the logic_case
	
	char caseValue[256];
	char caseNumber[12];
	
	for (int i = 0; i < 16; i++)
	{
		Format(caseNumber, sizeof(caseNumber), "m_nCase[%d]", i);
		GetEntPropString(caller, Prop_Data, caseNumber, caseValue, sizeof(caseValue));
		
		if (caseValue[0] != '\0')
		{
			char buffers[2][256];
			ExplodeString(caseValue, ":", buffers, 2, 256, true);
			ProcessMapInstruction(activator, buffers[0], buffers[1]);
		}
	}
}


/**
 * Process a map instruction
 * 
 * @noreturn
 */
stock void ProcessMapInstruction(int client, const char[] instruction, const char[] properties)
{
	char buffers[16][256];
	Player player = new Player(client);
	ExplodeString(properties, ",", buffers, 16, 256, true);

	if (StrEqual(instruction, "weapon", false))
	{
		int weapon = player.GetWeapon(StringToInt(buffers[0]));
		if (weapon != -1)
		{
			ReplaceWeapon(player.Index, weapon, StringToInt(buffers[1]), buffers[2]);
		}
	}
	
	if (StrEqual(instruction, "weapon_attribute", false))
	{
		int weapon = player.GetWeapon(StringToInt(buffers[0]));
		if (weapon != -1)
		{
			int itemDefIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
			if (itemDefIndex == StringToInt(buffers[1]))
			{
				bool success = TF2Attrib_SetByName(weapon, buffers[2], StringToFloat(buffers[3]));
				if (success) PrintToServer("Set an attribute on a weapon belonging to %N (%s with value %f)", player.Index, buffers[2], StringToFloat(buffers[3]));
			}
		}
	}
	
	if (StrEqual(instruction, "class", false))
	{
		int class = ProcessClassString(buffers[0]);
		player.SetClass(view_as<TFClassType>(class));
	}
	
	if (StrEqual(instruction, "speed", false))
	{
		player.SetSpeed(StringToInt(buffers[0]));
	}
	
	if (StrEqual(instruction, "health", false))
	{
		player.SetHealth(StringToInt(buffers[0]));
	}
	
	if (StrEqual(instruction, "maxhealth", false))
	{
		player.SetMaxHealth(StringToFloat(buffers[0]));
	}
	
	if (StrEqual(instruction, "movetype", false))
	{
		if (StrEqual(buffers[0], "fly", false))
		{
			SetEntityMoveType(player.Index, MOVETYPE_FLY);
		}
		if (StrEqual(buffers[0], "walk", false))
		{
			SetEntityMoveType(player.Index, MOVETYPE_WALK);
		}
	}
	
	if (StrEqual(instruction, "message", false))
	{
		PrintToChat(player.Index, "%t %s", "prefix_notice", buffers[0]);
	}
	
	if (StrEqual(instruction, "meleeonly", false))
	{
		if (StrEqual(buffers[0], "yes", false))
		{
			player.MeleeOnly();
		}
		if (StrEqual(buffers[0], "no", false))
		{
			player.MeleeOnly(false);
		}
	}
}




/**
 * Communication
 * ----------------------------------------------------------------------------------------------------
 */


/**
 * Display a message to all clients in chat when the round begins.
 * 
 * @noreturn
 */
void RoundActiveMessage()
{
	static int phrase_number = 1; char phrase[20];
	Format(phrase, sizeof(phrase), "round has begun %d", phrase_number);
	
	if (!TranslationPhraseExists(phrase))
	{
		phrase_number = 1;
		RoundActiveMessage();
	}
	else
	{
		PrintToChatAll("%t %t", "prefix_strong", phrase);
		phrase_number++;
	}
}



/**
 * Display up to the next three activators at the end of a round.
 * 
 * @noreturn
 */
void DisplayNextActivators()
{
	// Count the number of willing activators
	int willing;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		Player player = new Player(i);
		if (player.Flags & FLAGS_PREFERENCE)
			// If player.Flags has the FLAGS_PREFERENCE bit set return true
			willing += 1;
	}
	
	// If we don't have enough willing activators, don't display the message
	if (willing <= MINIMUM_ACTIVATORS)
	{
		return;
	}
	
	// Create a temporary array to store client index[0] and points[1]
	int points_order[TF2MAXPLAYERS-1][2];
	
	// Populate with player data
	for (int i = 0; i < MaxClients; i++)
	{
		Player player = new Player(i + 1);
		points_order[i][0] = player.Index;
		points_order[i][1] = player.Points;
	}
	
	// Sort by points descending
	SortCustom2D(points_order, MaxClients, SortByPoints);
	
	// Get the top three players with points
	//int players[3], count, client;
	int players[3], count;
	
	for (int i = 0; i < MaxClients && count < 3; i++)
	{
		Player player = new Player(points_order[i][0]);
		//client = points_order[i][0];
	
		if (player.InGame && player.IsParticipating && points_order[i][1] > 0 && (player.Flags & FLAGS_PREFERENCE))
			// If player.Flags has the FLAGS_PREFERENCE bit set return true
		//if (IsClientInGame(client) && points_order[i][1] > 0 && (g_iFlags[client] & FLAGS_PREFERENCE) == FLAGS_PREFERENCE)
		{
			players[count] = player.Index;
			//players[count] = client;
			count++;
		}
	}
	
	// Display the message
	if (players[0] != 0)
	{
		char string1[MAX_NAME_LENGTH];
		char string2[MAX_NAME_LENGTH];
		char string3[MAX_NAME_LENGTH];
		
		Format(string1, sizeof(string1), "%N", players[0]);
		
		if (players[1] > 0)
			Format(string2, sizeof(string2), ", %N", players[1]);
		
		if (players[2] > 0)
			Format(string3, sizeof(string3), ", %N", players[2]);
		
		PrintToChatAll("%t %t", "prefix", "next activators", string1, string2, string3);
	}
}


/**
 * Sorting function used by SortCustom2D. Sorts players by queue points.
 * 
 * @return	int	
 */
int SortByPoints(int[] a, int[] b, const int[][] array, Handle hndl)
{
	if (b[1] == a[1])
		return 0;
	else if (b[1] > a[1])
		return 1;
	else
		return -1;
}




/**
 * Server Environment
 * ----------------------------------------------------------------------------------------------------
 */



/**
 * Set server ConVars required for the game mode, or return them to defaults.
 * 
 * @param	int	Mode. 0 = default, 1 = game mode values.
 * @noreturn
 */
void SetServerCvars(bool set)
{
	if (set)
	{
		g_cTeamsUnbalanceLimit.IntValue = 0;
		g_cAutoBalance.IntValue = 0;
		g_cScramble.IntValue = 0;
		g_cArenaQueue.IntValue = 0;
		g_cHumansMustJoinTeam.SetString("red");
		g_cServerTeamMatePush.SetBool(g_cTeamMatePush.BoolValue);
		if (g_cArenaFirstBlood != null) g_cArenaFirstBlood.IntValue = 0;
	}
	else
	{
		g_cTeamsUnbalanceLimit.RestoreDefault();
		g_cAutoBalance.RestoreDefault();
		g_cScramble.RestoreDefault();
		g_cArenaQueue.RestoreDefault();
		g_cServerTeamMatePush.RestoreDefault();
		g_cRoundWaitTime.RestoreDefault();
		g_cHumansMustJoinTeam.RestoreDefault();
		if (g_cArenaFirstBlood != null) g_cArenaFirstBlood.RestoreDefault();
	}
}



/**
 * Set and remove event hooks and command listeners.
 * 
 * @param	bool	True to create, false to destroy.
 * @noreturn
 */
void EventsAndListeners(bool hook)
{
	if (hook)
	{
		// Hook some events
		HookEvent("teamplay_round_start", Event_RoundRestart, EventHookMode_PostNoCopy);	// Round restart
		HookEvent("teamplay_round_active", Event_RoundStart, EventHookMode_PostNoCopy);		// Round has begun
		HookEvent("arena_round_start", Event_RoundStart, EventHookMode_PostNoCopy);			// Round has begun (Arena)
		HookEvent("teamplay_round_win", Event_RoundEnd, EventHookMode_PostNoCopy);			// Round has ended
		HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);					// Player spawns
		HookEvent("player_changeclass", Event_ChangeClass, EventHookMode_Post);				// Player changes class
		HookEvent("player_healed", Event_PlayerHealed, EventHookMode_Post);					// Player healed
		HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);					// Player dies
		HookEvent("player_connect_client", Event_PlayerConnect, EventHookMode_Post);		// Player connects to the server for the first time
		HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Post);			// Player disconnects from the server
		
		if (g_iGame == Game_TF)
		{
			HookEvent("teams_changed", Event_TeamsChanged, EventHookMode_PostNoCopy);				// Used to monitor team switches
			HookEvent("post_inventory_application", Event_InventoryApplied, EventHookMode_Post);	// Used to modify weapons on receipt
		}
		else
		{
			HookEvent("player_team", Event_TeamsChanged, EventHookMode_PostNoCopy);					// Used to monitor team switches
			HookEvent("player_hurt", Event_PlayerDamaged, EventHookMode_Post);						// Used for the health bar in place of damage hooking
		}
		
		// Add some command listeners to restrict certain actions
		AddCommandListener(CommandListener_Suicide, "kill");
		AddCommandListener(CommandListener_Suicide, "explode");
		AddCommandListener(CommandListener_Suicide, "spectate");
		AddCommandListener(CommandListener_Suicide, "jointeam");
		AddCommandListener(CommandListener_Suicide, "autoteam");
		AddCommandListener(CommandListener_Build, "build");
	}
	
	else
	{
		// Unhook some events
		UnhookEvent("teamplay_round_start", Event_RoundRestart, EventHookMode_PostNoCopy);
		UnhookEvent("teamplay_round_active", Event_RoundStart, EventHookMode_PostNoCopy);
		UnhookEvent("arena_round_start", Event_RoundStart, EventHookMode_PostNoCopy);
		UnhookEvent("teamplay_round_win", Event_RoundEnd, EventHookMode_PostNoCopy);
		UnhookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
		UnhookEvent("player_changeclass", Event_ChangeClass, EventHookMode_Post);
		UnhookEvent("player_healed", Event_PlayerHealed, EventHookMode_Post);
		UnhookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
		UnhookEvent("player_connect_client", Event_PlayerConnect, EventHookMode_Post);
		UnhookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Post);
		
		if (g_iGame == Game_TF)
		{
			UnhookEvent("teams_changed", Event_TeamsChanged, EventHookMode_PostNoCopy);
			UnhookEvent("post_inventory_application", Event_InventoryApplied, EventHookMode_Post);
		}
		else
		{
			UnhookEvent("player_team", Event_TeamsChanged, EventHookMode_PostNoCopy);
			UnhookEvent("player_hurt", Event_PlayerDamaged, EventHookMode_Post);
		}
		
		// Remove the command listeners
		RemoveCommandListener(CommandListener_Suicide, "kill");
		RemoveCommandListener(CommandListener_Suicide, "explode");
		RemoveCommandListener(CommandListener_Suicide, "spectate");
		RemoveCommandListener(CommandListener_Suicide, "jointeam");
		RemoveCommandListener(CommandListener_Suicide, "autoteam");
		RemoveCommandListener(CommandListener_Build, "build");
	}
}



/**
 * DTK's ConVar change hooks.
 * 
 * @param	ConVar	ConVar handle.
 * @param	char	Old ConVar value.
 * @param	char	New ConVar value.
 * @noreturn
 */
void ConVarChangeHook(ConVar convar, const char[] oldValue, const char[] newValue)
{
	char sName[64];
	convar.GetName(sName, sizeof(sName));
	
	PrintToServer("%s %s has been changed from %s to %s", SERVERMSG_PREFIX, sName, oldValue, newValue);
	
	/*
		Convars which need a change to take effect when changed
		
		Evaluate attributes:
			redspeed
			redscoutspeed
			bluespeed
			redscoutdoublejump
			reddemochargelimits
			redspycloaklimits
		
		Respawn weapons:
			alloweurekaeffect
			redmeleeonly
	
		Check game state:
			teampushonremaining
			redglowremaining (not anymore)
			redglow (not anymore)
		
		Special:
			useactivatorhealthbar
			teammatepush
	*/
	
	if (StrEqual(sName, "dtk_enabled", false))
	{
		if (g_bSteamTools) SetServerGameDescription();
	}
	
	if (StrContains(sName, "teampush", false) != -1)
	{
		CheckGameState();
	}
	if (StrContains(sName, "meleeonly", false) != -1)	// -1 returns true! Remember this
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			Player player = new Player(i);
			if (player.InGame && player.Team == Team_Red)
				player.MeleeOnly(convar.BoolValue);
		}
	}
}



/**
 * Ask the plugin to set the correct game description depending on whether DTK is enabled.
 * The function will use the correct default description for Team Fortress and Open Fortress if not.
 *
 * @noreturn
 */
void SetServerGameDescription()
{
	char sGameDesc[32];
	
	if (!g_cEnabled.BoolValue)
	{
		if (g_iGame == Game_TF) Format(sGameDesc, sizeof(sGameDesc), "Team Fortress");
		if (g_iGame == Game_OF) Format(sGameDesc, sizeof(sGameDesc), "Open Fortress");
	}
	else
	{
		Format(sGameDesc, sizeof(sGameDesc), "%s | %s", PLUGIN_SHORTNAME, PLUGIN_VERSION);
	}
	
	Steam_SetGameDescription(sGameDesc);
	PrintToServer("%s Set game description to '%s'", SERVERMSG_PREFIX, sGameDesc);
}



/**
 * If the debug message cvar is enabled, the plugin will spew some common actions to server console
 * to aid in tracking down bugs. This is a format class function.
 *
 * @param string		Formatting rules.
 * @param ...			Variable number of formatting arguments.
 * @noreturn
 */
stock void DebugMessage(const char[] string, any ...)
{
	if (!g_cDebugMessages.BoolValue)
		return;
	
	int len = strlen(string) + 255;
	char[] buffer = new char[len];
	VFormat(buffer, len, string, 2);
	
	PrintToServer("%s %s", DEBUG_PREFIX, buffer);
}