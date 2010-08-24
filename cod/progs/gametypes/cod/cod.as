int prcYesIcon;
int prcShockIcon;
int prcShellIcon;

cVar CodAllowPowerups("cod_allowPowerups", "0", CVAR_ARCHIVE);
cVar CodAllowPowerupDrop("cod_powerupDrop", "1", CVAR_ARCHIVE);

void COD_giveInventory(cClient @client) {
	client.inventoryClear();

	client.inventoryGiveItem(WEAP_GUNBLADE);
	client.inventorySetCount(AMMO_GUNBLADE, 3);
	//client.inventoryGiveItem(WEAP_MACHINEGUN);
	//client.inventorySetCount(AMMO_BULLETS, 50);

	client.armor = 50;
}

cString @GT_ScoreboardMessage(int maxlen) {
	cString scoreboardMessage = "";
	cString entry;
	cTeam @team;
	cEntity @ent;
	int i, t, readyIcon;

	for(t = TEAM_ALPHA; t < GS_MAX_TEAMS; t++) {
		@team = @G_GetTeam(t);
		// &t = team tab, team tag, team score (doesn't apply), team ping (doesn't apply)
		entry = "&t " + t + " " + team.stats.score + " " + team.ping + " ";

		if(scoreboardMessage.len() + entry.len() < maxlen) {
			scoreboardMessage += entry;
		}

		for(i = 0; @team.ent(i) != null; i++) {
			@ent = @team.ent(i);

			readyIcon = ent.client.isReady() ? prcYesIcon : 0;

			int playerID = (ent.isGhosting() && (match.getState() == MATCH_STATE_PLAYTIME)) ? -(ent.playerNum() + 1) : ent.playerNum();

			if(gametype.isInstagib()) {
				// "Name Clan Score Dfrst Ping R"
				entry = "&p " + playerID + " " + ent.client.getClanName() + " "
					+ ent.client.stats.score + " " + ent.client.stats.deaths + " " +
					+ ent.client.ping + " " + readyIcon + " ";
			} else {
				int carrierIcon;
				if(ent.client.inventoryCount(POWERUP_QUAD) > 0) {
					carrierIcon = prcShockIcon;
				} else if(ent.client.inventoryCount(POWERUP_SHELL) > 0) {
					carrierIcon = prcShellIcon;
				} else {
					carrierIcon = 0;
				}

				// "Name Clan Score Frags Dfrst Ping C R"
				entry = "&p " + playerID + " " + ent.client.getClanName() + " "
					+ ent.client.stats.score + " " + ent.client.stats.frags + " " + ent.client.stats.deaths + " "
					+ ent.client.ping + " " + carrierIcon + " " + readyIcon + " ";
			}

			if(scoreboardMessage.len() + entry.len() < maxlen) {
				scoreboardMessage += entry;
			}
		}
	}

	return scoreboardMessage;
}


void GT_scoreEvent(cClient @client, cString &score_event, cString &args) {
	// Some game actions trigger score events. These are events not related to killing
	// oponents, like capturing a flag
	
	if(score_event == "dmg") {
		if(match.getState() == MATCH_STATE_PLAYTIME) {
			/*
			GT_updateScore(client);
			cCodPlayer @codPlayer = @getCodPlayer(client);
			
			if (@codPlayer != null) {
				codPlayer.update();
			}
			*/
			//G_Print("GT_scoreEvent called - dmg\n");
		}
	} else if(score_event == "kill") {
		
		// the target is saved in the args variable
		cEntity @target = G_GetEntity(args.getToken(0).toInt());
		
		if (@target != null && @target.client != null) {
			cCodPlayer @player = getCodPlayer(target.client);
			if (@player != null) {
				player.addDeath();
			}
		}
		
		// client is the attacker
		
		if (@client != null) {
			cCodPlayer @player = getCodPlayer(client);
			if (@player != null && @client != @target.client) {
				player.addKill();
			}
		}
		
	} else if(score_event == "disconnect") {
		cCodPlayer @codPlayer = @getCodPlayer(client);
		if (@codPlayer != null) {
			codPlayer.disconnect();
		}
	}
}

void GT_playerRespawn(cEntity @ent, int old_team, int new_team) {
	// a player is being respawned. This can happen from several ways, as dying, changing team,
	// being moved to ghost state, be placed in respawn queue, being spawned from spawn queue, etc
	
	if (old_team != new_team) {
		cCodPlayer @player = getCodPlayer(ent.client);
		if (@player != null) {
			player.reset();
		}
		else {
			cCodPlayer(ent.client);
		}
	}
	
	if(ent.isGhosting()) {
		return;
	}

	COD_giveInventory(ent.client);

	// auto-select best weapon in the inventory
	if(ent.client.pendingWeapon == WEAP_NONE) {
		ent.client.selectWeapon(-1);
	}

	// add a teleportation effect
	ent.respawnEffect();
}


bool GT_UpdateBotStatus(cEntity @ent) {
	return GENERIC_UpdateBotStatus(ent);
}

cEntity @GT_SelectSpawnPoint(cEntity @self) {
	// select a spawning point for a player
	// TODO: make players spawn near where they were defrosted?
	return GENERIC_SelectBestRandomSpawnPoint(self, "info_player_deathmatch");
}

bool GT_Command(cClient @client, cString &cmdString, cString &argsString, int argc) {
	if(cmdString == "drop") {
		cString token;
		for(int i = 0; i < argc; i++) {
			token = argsString.getToken(i);
			if(token.len() == 0) {
				break;
			}

			if(token == "fullweapon") {
				GENERIC_DropCurrentWeapon(client, true);
				GENERIC_DropCurrentAmmoStrong(client);
			} else if(token == "weapon") {
				GENERIC_DropCurrentWeapon(client, true);
			} else if(token == "strong") {
				GENERIC_DropCurrentAmmoStrong(client);
			} else {
				GENERIC_CommandDropItem(client, token);
			}
		}
		return true;
	} else if(cmdString == "gametype") {
		cString response = "";
		cVar fs_game("fs_game", "", 0);
		cString manifest = gametype.getManifest();
		response += "\n";
		response += "Gametype " + gametype.getName() + " : " + gametype.getTitle() + "\n";
		response += "----------------\n";
		response += "Version: " + gametype.getVersion() + "\n";
		response += "Author: " + gametype.getAuthor() + "\n";
		response += "Mod: " + fs_game.getString() + (manifest.length() > 0 ? " (manifest: " + manifest + ")" : "") + "\n";
		response += "----------------\n";
		G_PrintMsg(client.getEnt(), response);
		return true;
	}
	else if (cmdString == "debug") {
		getCodPlayer(client).autoaim = true;
	}
	/*
	 else if(cmdString == "callvotevalidate") {
		cString votename = argsString.getToken(0);
		if(votename == "ftag_powerups") {
			cString voteArg = argsString.getToken(1);
			if(voteArg.len() < 1) {
				client.printMessage("Callvote " + votename + " requires at least one argument\n");
				return false;
			}

			if(voteArg != "0" && voteArg != "1") {
				client.printMessage("Callvote " + votename + " expects a 1 or a 0 as argument\n");
				return false;
			}

			int value = voteArg.toInt();

			if(value == 0 && !ftagAllowPowerups.getBool()) {
				client.printMessage("Powerups are already disabled\n");
				return false;
			}

			if(value == 1 && ftagAllowPowerups.getBool()) {
				client.printMessage("Powerups are already enabled\n");
				return false;
			}

			return true;
		}

		if(votename == "ftag_powerup_drop") {
			cString voteArg = argsString.getToken(1);
			if(voteArg.len() < 1) {
				client.printMessage("Callvote " + votename + " requires at least one argument\n");
				return false;
			}

			if(voteArg != "0" && voteArg != "1") {
				client.printMessage("Callvote " + votename + " expects a 1 or a 0 as argument\n");
				return false;
			}

			int value = voteArg.toInt();

			if(value == 0 && !ftagAllowPowerupDrop.getBool()) {
				client.printMessage("Powerup drop is already disabled\n");
				return false;
			}

			if(value == 1 && ftagAllowPowerupDrop.getBool()) {
				client.printMessage("Powerup drop is already enabled\n");
				return false;
			}

			return true;
		}

		client.printMessage("Unknown callvote " + votename + "\n");
		return false;

	} else if(cmdString == "callvotepassed") {
		cString votename = argsString.getToken(0);
		if(votename == "ftag_powerups") {
			ftagAllowPowerups.set(argsString.getToken(1).toInt() > 0 ? 1 : 0);

			// force restart to update
			match.launchState(MATCH_STATE_POSTMATCH);

			// if i do this, powerups spawn but are unpickable
			/*if(ftagAllowPowerups.getBool()) {
				gametype.spawnableItemsMask |= IT_POWERUP;
			} else {
				gametype.spawnableItemsMask &= ~IT_POWERUP;
			}
		} else if(votename == "ftag_powerup_drop") {
			ftagAllowPowerupDrop.set(argsString.getToken(1).toInt() > 0 ? 1 : 0);
		}
		return true;
	}
	*/
	return false;
}

float dot(const cVec3 &v1, const cVec3 &v2) {
	return v1.x * v2.x + v1.y * v2.y + v1.z * v2.z;
}

// Thinking function. Called each frame
void GT_ThinkRules() {
	if(match.scoreLimitHit() || match.timeLimitHit() || match.suddenDeathFinished()) {
		match.launchState(match.getState() + 1);
	}
	
	for(int i = 0; i < maxClients; i++) {
		cClient @client = @G_GetClient(i);
		
		if (client == null)
			continue;
			
		cCodPlayer @codPlayer = getCodPlayer(client);
		
		if (codPlayer != null && !codPlayer.client.getEnt().isGhosting()) {
			if (codPlayer.deathStrike > 0) {
				if (codPlayer.client.armor < 200)
					codPlayer.client.armor += (frameTime * 0.015f / getFragToDeathRatio(client));
				if (codPlayer.client.getEnt().health < 200)
					codPlayer.client.getEnt().health += (frameTime * 0.015f / getFragToDeathRatio(client));
			}
			if (codPlayer.deathStrike > 1) {
				// TODO: IMPLEMENT QUAD
			}
		}
		
		// AUTOAIM
		/*
		if (codPlayer != null && codPlayer.autoaim) {
			
			cVec3 origin = client.getEnt().getOrigin();
			cVec3 eye = origin + cVec3(0, 0, client.getEnt().viewHeight);
	
			cVec3 dir;
			// unit vector
			client.getEnt().getAngles().angleVectors(dir, null, null);
	
			cString msg;
	
			for(cCodPlayer @otherCodPlayer = @codHead; @otherCodPlayer != null; @otherCodPlayer = @otherCodPlayer.next) {
				
				if (@codPlayer == @otherCodPlayer)
					continue;
				
				if(client.team != otherCodPlayer.client.team) {
					// this compares the dot product of the vector from
					// player's eye and the model's center and the vector
					// from the player's eye to the model's top with the
					// dot product of the vector from the player's eye to
					// the model's center and the player's angle vector
					// it should work nicely from all angles and distances
					// TODO: it's actually stupid at close range since it
					// assumes you're looking at h1o
					
	
					cEntity @model = @otherCodPlayer.client.getEnt();
					cVec3 mid = model.getOrigin();
					// + (mins + maxs) * 0.5;
	
					// if(origin.distance(mid) <= FTAG_DEFROST_RADIUS) {
					// 	continue;
					// }
					
					cVec3 mins, maxs;
					model.getSize(mins, maxs);
	
					cVec3 top = mid + cVec3(0, 0, 20.0f);
	
					cVec3 eyemid = mid - eye;
					eyemid.normalize();
					cVec3 eyetop = top - eye;
					eyetop.normalize();
	
					if(dot(dir, eyemid) >= dot(eyetop, eyemid)) {
						//G_FireInstaShot( cVec3 &origin, cVec3 &angles, int range, int damage, int knockback, int stun, cEntity @owner );
						//G_FireInstaShot( eye, client.getEnt().getAngles(), 99, 1, 5, 100, codPlayer.client.getEnt() );
						//cEntity @G_FirePlasma( cVec3 &origin, cVec3 &angles, int speed, int radius, int damage, int knockback, int stun, cEntity @owner );
						G_FirePlasma( eye, client.getEnt().getAngles(), 550, 50, 1, 5, 110, codPlayer.client.getEnt() );
						msg += "!!! " + otherCodPlayer.client.getName() + " !!!";
					}
				}
			}
	
			int len = msg.len();
			if(len != 0) {
				G_ConfigString(CS_GENERAL + 2 + i, msg.substr(0, len - 2));
	
				client.setHUDStat(STAT_MESSAGE_SELF, CS_GENERAL + 2 + i);
			} else {
				client.setHUDStat(STAT_MESSAGE_SELF, 0);
			}
		}
		*/
	}
}

bool GT_MatchStateFinished(int incomingMatchState) {
	// The game has detected the end of the match state, but it
	// doesn't advance it before calling this function.
	// This function must give permission to move into the next
	// state by returning true.
	if(match.getState() <= MATCH_STATE_WARMUP && incomingMatchState > MATCH_STATE_WARMUP && incomingMatchState < MATCH_STATE_POSTMATCH) {
		match.startAutorecord();
	}

	if(match.getState() == MATCH_STATE_POSTMATCH) {
		match.stopAutorecord();
	}

	return true;
}

void GT_MatchStateStarted() {
	// the match state has just moved into a new state. Here is the
	// place to set up the new state rules
	switch(match.getState()) {
		case MATCH_STATE_WARMUP:
			gametype.pickableItemsMask = gametype.spawnableItemsMask;
			gametype.dropableItemsMask = gametype.spawnableItemsMask;

			GENERIC_SetUpWarmup();

			for(int team = TEAM_PLAYERS; team < GS_MAX_TEAMS; team++) {
				gametype.setTeamSpawnsystem(team, SPAWNSYSTEM_INSTANT, 0, 0, false);
			}

			break;

		case MATCH_STATE_COUNTDOWN:
			gametype.pickableItemsMask = 0;
			gametype.dropableItemsMask = 0;

			GENERIC_SetUpCountdown();

			break;

		case MATCH_STATE_PLAYTIME:
			gametype.pickableItemsMask = gametype.spawnableItemsMask;
			gametype.dropableItemsMask = gametype.spawnableItemsMask;

			GENERIC_SetUpMatch();

			// set spawnsystem type to not respawn the players when they die
			for(int team = TEAM_PLAYERS; team < GS_MAX_TEAMS; team++) {
				gametype.setTeamSpawnsystem(team, SPAWNSYSTEM_INSTANT, 0, 0, false);
			}

			break;

		case MATCH_STATE_POSTMATCH:
			gametype.pickableItemsMask = 0;
			gametype.dropableItemsMask = 0;

			GENERIC_SetUpEndMatch();

			break;

		default:
			break;
	}
}

void GT_Shutdown() {
	// the gametype is shutting down cause of a match restart or map change
}

void GT_SpawnGametype() {
	// The map entities have just been spawned. The level is initialized for
	// playing, but nothing has yet started.
}

void GT_InitGametype() {
	// Important: This function is called before any entity is spawned, and
	// spawning entities from it is forbidden. ifyou want to make any entity
	// spawning at initialization do it in GT_SpawnGametype, which is called
	// right after the map entities spawning.
	gametype.setTitle("CoD Remix");
	gametype.setVersion("0.1");
	gametype.setAuthor("ChriZzZ");

	gametype.spawnableItemsMask = IT_WEAPON | IT_AMMO | IT_ARMOR | IT_POWERUP | IT_HEALTH;
	if(!CodAllowPowerups.getBool()) {
		gametype.spawnableItemsMask &= ~IT_POWERUP;
	}
	if(gametype.isInstagib()) {
		gametype.spawnableItemsMask &= ~uint(G_INSTAGIB_NEGATE_ITEMMASK);
	}
	gametype.respawnableItemsMask = gametype.spawnableItemsMask;
	gametype.dropableItemsMask = gametype.spawnableItemsMask;
	gametype.pickableItemsMask = gametype.spawnableItemsMask | gametype.dropableItemsMask;

	gametype.isTeamBased = true;
	gametype.isRace = false;
	gametype.hasChallengersQueue = false;
	gametype.maxPlayersPerTeam = 0;

	gametype.ammoRespawn = 20;
	gametype.armorRespawn = 25;
	gametype.weaponRespawn = 15;
	gametype.healthRespawn = 25;
	gametype.powerupRespawn = 90;
	gametype.megahealthRespawn = 20;
	gametype.ultrahealthRespawn = 60;
	gametype.readyAnnouncementEnabled = true;

	gametype.scoreAnnouncementEnabled = true;
	gametype.countdownEnabled = true;
	gametype.mathAbortDisabled = false;
	gametype.shootingDisabled = false;
	gametype.infiniteAmmo = false;
	gametype.canForceModels = true;
	gametype.canShowMinimap = true;
	gametype.teamOnlyMinimap = true;

	gametype.spawnpointRadius = 256;
	if(gametype.isInstagib()) {
		gametype.spawnpointRadius *= 2;
	}

	// set spawnsystem type to instant while players join
	for(int t = TEAM_PLAYERS; t < GS_MAX_TEAMS; t++) {
		gametype.setTeamSpawnsystem(t, SPAWNSYSTEM_INSTANT, 0, 0, false);
	}

	// define the scoreboard layout
	if(gametype.isInstagib()) {
		G_ConfigString(CS_SCB_PLAYERTAB_LAYOUT, "%n 112 %s 52 %i 52 %i 52 %l 48 %p 18");
		G_ConfigString(CS_SCB_PLAYERTAB_TITLES, "Name Clan Score Deaths Ping R");
	} else {
		G_ConfigString(CS_SCB_PLAYERTAB_LAYOUT, "%n 112 %s 52 %i 52 %i 52 %i 52 %l 48 " + "%p 18 " + "%p 18");
		G_ConfigString(CS_SCB_PLAYERTAB_TITLES, "Name Clan Score Frags Deaths Ping " + "C " + " R");
	}

	
	// precache images that can be used by the scoreboard
	prcYesIcon = G_ImageIndex("gfx/hud/icons/vsay/yes");
	prcShockIcon = G_ImageIndex("gfx/hud/icons/powerup/quad");
	prcShellIcon = G_ImageIndex("gfx/hud/icons/powerup/warshell");
	

	// add commands
	G_RegisterCommand("drop");
	G_RegisterCommand("debug");
	G_RegisterCommand("gametype");

	// add callvotes
	G_RegisterCallvote("COD_powerups", "1 or 0", "Enables or disables powerups in Freeze Tag.");
	G_RegisterCallvote("COD_powerup_drop", "1 or 0", "Enables or disables powerup dropping in Freeze Tag.");

	if(!G_FileExists("configs/server/gametypes/" + gametype.getName() + ".cfg")) {
		cString config;
		// the config file doesn't exist or it's empty, create it
		config = "// '" + gametype.getTitle() + "' gametype configuration file\n"
			+ "// This config will be executed each time the gametype is started\n"
			+ "\n// " + gametype.getTitle() + " specific settings\n"
			+ "set cod_allowPowerups \"1\"\n"
			+ "set cod_powerupDrop \"1\"\n"
			+ "\n// map rotation\n"
			+ "set g_maplist \"wdm1 wdm2 wdm3 wdm4 wdm5 wdm6 wdm7 wdm8 wdm9 wdm10 wdm11 wdm12 wdm13 wdm14 wdm15 wdm16 wdm17\" // list of maps in automatic rotation\n"
			+ "set g_maprotation \"1\"   // 0 = same map, 1 = in order, 2 = random\n"
			+ "\n// game settings\n"
			+ "set g_scorelimit \"15\"\n"
			+ "set g_timelimit \"0\"\n"
			+ "set g_warmup_enabled \"1\"\n"
			+ "set g_warmup_timelimit \"1.5\"\n"
			+ "set g_match_extendedtime \"0\"\n"
			+ "set g_allow_falldamage \"1\"\n"
			+ "set g_allow_selfdamage \"1\"\n"
			+ "set g_allow_teamdamage \"1\"\n"
			+ "set g_allow_stun \"1\"\n"
			+ "set g_teams_maxplayers \"0\"\n"
			+ "set g_teams_allow_uneven \"0\"\n"
			+ "set g_countdown_time \"5\"\n"
			+ "set g_maxtimeouts \"3\" // -1 = unlimited\n"
			+ "set g_challengers_queue \"0\"\n"
			+ "\necho \"" + gametype.getName() + ".cfg executed\"\n";
		G_WriteFile("configs/server/gametypes/" + gametype.getName() + ".cfg", config);
		G_Print("Created default config file for '" + gametype.getName() + "'\n");
		G_CmdExecute("exec configs/server/gametypes/" + gametype.getName() + ".cfg silent");
	}
	G_Print("Gametype '" + gametype.getTitle() + "' initialized\n");
}
