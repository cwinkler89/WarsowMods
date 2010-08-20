// TODO: make people spec whoever is defrosting them

const uint COD_DEFROST_TIME = 8000;
const uint COD_INVERSE_HAZARD_DEFROST_SCALE = 3;
const uint COD_INVERSE_ATTACK_DEFROST_SCALE = 3;
const uint COD_DEFROST_ATTACK_DELAY = 2000;
//const uint COD_DEFROST_DECAY_DELAY = 500;
const float COD_DEFROST_RADIUS = 192.0f;

int prcYesIcon;
int prcShockIcon;
int prcShellIcon;
int[] defrosts(maxClients);
uint[] lastShotTime(maxClients);
int[] playerSTAT_PROGRESS_SELFdelayed(maxClients);
uint[] playerLastTouch(maxClients);
bool[] spawnNextRound(maxClients);
//cString[] defrostMessage(maxClients);
bool doRemoveRagdolls = false;

cVar CODAllowPowerups("COD_allowPowerups", "0", CVAR_ARCHIVE);
cVar CODAllowPowerupDrop("COD_powerupDrop", "1", CVAR_ARCHIVE);

// cVec3 doesn't have dot product ffs
float dot(const cVec3 &v1, const cVec3 &v2) {
	return v1.x * v2.x + v1.y * v2.y + v1.z * v2.z;
}

void COD_giveInventory(cClient @client) {
	client.inventoryClear();

	client.inventoryGiveItem(WEAP_GUNBLADE);
	client.inventorySetCount(AMMO_GUNBLADE, 3);
	//client.inventoryGiveItem(WEAP_MACHINEGUN);
	//client.inventorySetCount(AMMO_BULLETS, 50);

	client.armor = 50;
}

void COD_playerKilled(cEntity @target, cEntity @attacker, cEntity @inflicter) {
	if(@target.client == null) {
		return;
	}

	if((G_PointContents(target.getOrigin()) & CONTENTS_NODROP) == 0) {
		if(target.client.weapon > WEAP_GUNBLADE) {
			GENERIC_DropCurrentWeapon(target.client, true);
		}
		target.dropItem(AMMO_PACK_WEAK);

		if(CODAllowPowerupDrop.getBool()) {
			if(target.client.inventoryCount(POWERUP_QUAD) > 0) {
				target.dropItem(POWERUP_QUAD);
				target.client.inventorySetCount(POWERUP_QUAD, 0);
			}

			if(target.client.inventoryCount(POWERUP_SHELL) > 0) {
				target.dropItem(POWERUP_SHELL);
				target.client.inventorySetCount(POWERUP_SHELL, 0);
			}
		}
	}

	if(match.getState() != MATCH_STATE_PLAYTIME) {
		return;
	}

	cFrozenPlayer(target.client);

	GT_updateScore(target.client);
	if(@attacker != null && @attacker.client != null) {
		GT_updateScore(attacker.client);
	}
}

void COD_NewRound(cTeam @loser) {
	for(int i = 0; i < maxClients; i++) {
		cClient @client = @G_GetClient(i);

		if(@client == null) {
			break;
		}

		if(client.team == loser.team()) {
			client.respawn(false);

			if(spawnNextRound[i]) {
				spawnNextRound[i] = false;
			}

			continue;
		}/* else if(!client.getEnt().isGhosting()) {
			client.inventoryGiveItem(HEALTH_LARGE);
		}*/

		// respawn players who connected during the previous round
		if(spawnNextRound[i]) {
			client.respawn(false);

			spawnNextRound[i] = false;
		}
	}

	cTeam @winner = G_GetTeam(loser.team() == TEAM_ALPHA ? TEAM_BETA : TEAM_ALPHA);
	winner.stats.addScore(1);
	G_AnnouncerSound(null, G_SoundIndex("sounds/announcer/ctf/score_team0" + int(brandom(1, 2))), winner.team(), false, null);
	G_AnnouncerSound(null, G_SoundIndex("sounds/announcer/ctf/score_enemy0" + int(brandom(1, 2))), loser.team(), false, null);

	G_Items_RespawnByType(IT_WEAPON, 0, 0);

	COD_DefrostTeam(loser.team());
}
/*
void COD_ResetDefrostCounters() {
	for(int i = 0; i < maxClients; i++) {
		if(spawnNextRound[i]) {
			spawnNextRound[i] = false;
		}

		defrosts[i] = 0;
	}
}
*/
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
	} else if(cmdString == "callvotevalidate") {
		cString votename = argsString.getToken(0);
		if(votename == "COD_powerups") {
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

			if(value == 0 && !CODAllowPowerups.getBool()) {
				client.printMessage("Powerups are already disabled\n");
				return false;
			}

			if(value == 1 && CODAllowPowerups.getBool()) {
				client.printMessage("Powerups are already enabled\n");
				return false;
			}

			return true;
		}

		if(votename == "COD_powerup_drop") {
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

			if(value == 0 && !CODAllowPowerupDrop.getBool()) {
				client.printMessage("Powerup drop is already disabled\n");
				return false;
			}

			if(value == 1 && CODAllowPowerupDrop.getBool()) {
				client.printMessage("Powerup drop is already enabled\n");
				return false;
			}

			return true;
		}

		client.printMessage("Unknown callvote " + votename + "\n");
		return false;

	} else if(cmdString == "callvotepassed") {
		cString votename = argsString.getToken(0);
		if(votename == "COD_powerups") {
			CODAllowPowerups.set(argsString.getToken(1).toInt() > 0 ? 1 : 0);

			// force restart to update
			match.launchState(MATCH_STATE_POSTMATCH);

			// if i do this, powerups spawn but are unpickable
			/*if(CODAllowPowerups.getBool()) {
				gametype.spawnableItemsMask |= IT_POWERUP;
			} else {
				gametype.spawnableItemsMask &= ~IT_POWERUP;
			}*/
		} else if(votename == "COD_powerup_drop") {
			CODAllowPowerupDrop.set(argsString.getToken(1).toInt() > 0 ? 1 : 0);
		}
		return true;
	}
	return false;
}

bool GT_UpdateBotStatus(cEntity @ent) {
	// TODO: make bots defrost people
	return GENERIC_UpdateBotStatus(ent);
}

cEntity @GT_SelectSpawnPoint(cEntity @self) {
	// select a spawning point for a player
	// TODO: make players spawn near where they were defrosted?
	return GENERIC_SelectBestRandomSpawnPoint(self, "info_player_deathmatch");
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
					+ ent.client.stats.score + " " + defrosts[ent.client.playerNum()] + " " +
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
					+ ent.client.stats.score + " " + ent.client.stats.frags + " " + defrosts[ent.client.playerNum()] + " "
					+ ent.client.ping + " " + carrierIcon + " " + readyIcon + " ";
			}

			if(scoreboardMessage.len() + entry.len() < maxlen) {
				scoreboardMessage += entry;
			}
		}
	}

	return scoreboardMessage;
}

void GT_updateScore(cClient @client) {
	if(@client != null) {
		if(gametype.isInstagib()) {
			client.stats.setScore(client.stats.frags + defrosts[client.playerNum()]);
		} else {
			client.stats.setScore(int(client.stats.totalDamageGiven * 0.01) + defrosts[client.playerNum()]);
		}
	}
}

void GT_scoreEvent(cClient @client, cString &score_event, cString &args) {
	// Some game actions trigger score events. These are events not related to killing
	// oponents, like capturing a flag
	if(score_event == "dmg") {
		if(match.getState() == MATCH_STATE_PLAYTIME) {
			GT_updateScore(client);

			if(@client == null) {
				return; // ignore falldamage
			}

			cEntity @ent = G_GetEntity(args.getToken(0).toInt());
			if(@ent != null && @ent.client != null) {
				lastShotTime[ent.client.playerNum()] = levelTime;
			}
		}
	} else if(score_event == "kill") {
		cEntity @attacker = null;
		if(@client != null) {
			@attacker = @client.getEnt();
		}

		COD_playerKilled(G_GetEntity(args.getToken(0).toInt()), attacker, G_GetEntity(args.getToken(1).toInt()));
	} else if(score_event == "disconnect") {
		cFrozenPlayer @frozen = @COD_GetFrozenForPlayer(client);
		if(@frozen != null) {
			frozen.defrost();
		}

		/*if(playerIsFrozen[client.playerNum()]) {
		  playerFrozen[client.playerNum()].kill();
		  }*/
	}
}

void GT_playerRespawn(cEntity @ent, int old_team, int new_team) {
	// a player is being respawned. This can happen from several ways, as dying, changing team,
	// being moved to ghost state, be placed in respawn queue, being spawned from spawn queue, etc
	if(old_team == TEAM_SPECTATOR) {
		spawnNextRound[ent.client.playerNum()] = true;
	} else if(old_team == TEAM_ALPHA || old_team == TEAM_BETA) {
		cFrozenPlayer @frozen = @COD_GetFrozenForPlayer(ent.client);

		if(@frozen != null) {
			frozen.defrost();
		}
	}

	if(ent.isGhosting()) {
		return;
	}

	if(gametype.isInstagib()) {
		ent.client.inventoryGiveItem(WEAP_INSTAGUN);
		ent.client.inventorySetCount(AMMO_INSTAS, 1);
		ent.client.inventorySetCount(AMMO_WEAK_INSTAS, 1);
	} else {
		COD_giveInventory(ent.client);
	}

	// auto-select best weapon in the inventory
	if(ent.client.pendingWeapon == WEAP_NONE) {
		ent.client.selectWeapon(-1);
	}

	// add a teleportation effect
	ent.respawnEffect();
}

// Thinking function. Called each frame
void GT_ThinkRules() {
	if(match.scoreLimitHit() || match.timeLimitHit() || match.suddenDeathFinished()) {
		match.launchState(match.getState() + 1);
	}

	//GENERIC_Think();

	// print count of players alive
	cTeam @team;
	int[] alive(GS_MAX_TEAMS);
	alive[TEAM_SPECTATOR] = 0;
	alive[TEAM_PLAYERS] = 0;
	alive[TEAM_ALPHA] = 0;
	alive[TEAM_BETA] = 0;
	for(int t = TEAM_ALPHA; t < GS_MAX_TEAMS; t++) {
		@team = @G_GetTeam(t);
		for(int i = 0; @team.ent(i) != null; i++) {
			if(!team.ent(i).isGhosting()) {
				alive[t]++;
			}
		}
	}

	G_ConfigString(CS_GENERAL, "- " + alive[TEAM_ALPHA] + " -");
	G_ConfigString(CS_GENERAL + 1, "- " + alive[TEAM_BETA] + " -");

	for(int i = 0; i < maxClients; i++) {
		cClient @client = @G_GetClient(i);
		if(match.getState() != MATCH_STATE_PLAYTIME) {
			client.setHUDStat(STAT_MESSAGE_ALPHA, 0);
			client.setHUDStat(STAT_MESSAGE_BETA, 0);
		} else {
			client.setHUDStat(STAT_MESSAGE_ALPHA, CS_GENERAL);
			client.setHUDStat(STAT_MESSAGE_BETA, CS_GENERAL + 1);
		}
	}

	if(match.getState() >= MATCH_STATE_POSTMATCH) {
		return;
	}

	for(int i = 0; i < maxClients; i++) {
		//defrostMessage[i] = "Defrosting:";
		cClient @client = @G_GetClient(i);

		if(@client == null || COD_PlayerFrozen(@client)) {
			continue;
		}

		GENERIC_ChargeGunblade(client);

		cEntity @ent = client.getEnt();
		if(ent.health > ent.maxHealth) {
			ent.health -= (frameTime * 0.001f);
		}

		client.setHUDStat(STAT_PROGRESS_SELF, playerSTAT_PROGRESS_SELFdelayed[i]);
		if(playerLastTouch[i] < levelTime) {
			playerSTAT_PROGRESS_SELFdelayed[i] = 0;
		}

		/* check if player is looking at a frozen player and
		   show something like "Player (50%)" if they are */

		cVec3 origin = client.getEnt().getOrigin();
		cVec3 eye = origin + cVec3(0, 0, client.getEnt().viewHeight);

		cVec3 dir;
		// unit vector
		client.getEnt().getAngles().angleVectors(dir, null, null);

		cString msg;

		for(cFrozenPlayer @frozen = @frozenHead; @frozen != null; @frozen = @frozen.next) {
			if(client.team == frozen.client.team) {
				/* this compares the dot product of the vector from
				   player's eye and the model's center and the vector
				   from the player's eye to the model's top with the
				   dot product of the vector from the player's eye to
				   the model's center and the player's angle vector

				   it should work nicely from all angles and distances

				   TODO: it's actually stupid at close range since it
				   assumes you're looking at h1o
				 */

				cEntity @model = @frozen.model;
				cVec3 mid = model.getOrigin()/* + (mins + maxs) * 0.5*/;

				if(origin.distance(mid) <= COD_DEFROST_RADIUS) {
					continue;
				}

				cVec3 mins, maxs;
				model.getSize(mins, maxs);

				cVec3 top = mid + cVec3(0, 0, COD_DEFROST_RADIUS);

				cVec3 eyemid = mid - eye;
				eyemid.normalize();
				cVec3 eyetop = top - eye;
				eyetop.normalize();

				if(dot(dir, eyemid) >= dot(eyetop, eyemid)) {
					msg += frozen.client.getName() + " (" + ((frozen.defrostTime * 100) / COD_DEFROST_TIME) + "%), ";
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

	/*for(int i = 0; i < maxClients; i++) {
	  if(defrostMessage[i].len() > 11) {
	  G_ConfigString(CS_GENERAL + 1 + i, defrostMessage[i].substr(1, 6));
	  G_GetClient(i).setHUDStat(STAT_MESSAGE_SELF, CS_GENERAL + 1 + i);
	  } else {
	  G_GetClient(i).setHUDStat(STAT_MESSAGE_SELF, 0);
	  }
	  }*/

	// if everyone on a team is frozen then start a new round
	if(match.getState() == MATCH_STATE_PLAYTIME) {
		int count;
		for(int i = TEAM_ALPHA; i < GS_MAX_TEAMS; i++) {
			@team = @G_GetTeam(i);
			count = 0;

			for(int j = 0; @team.ent(j) != null; j++) {
				if(!team.ent(j).isGhosting()) {
					count++;
				}
			}

			if(count == 0) {
				COD_NewRound(team);
				break;
			}
		}
	}

	if(@frozenHead != null) {
		frozenHead.think();
	}

	if(doRemoveRagdolls) {
		G_RemoveDeadBodies();
		doRemoveRagdolls = false;
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

			COD_ResetDefrostCounters();

			// set spawnsystem type to not respawn the players when they die
			for(int team = TEAM_PLAYERS; team < GS_MAX_TEAMS; team++) {
				gametype.setTeamSpawnsystem(team, SPAWNSYSTEM_HOLD, 0, 0, true);
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
	if(!CODAllowPowerups.getBool()) {
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
	gametype.readyAnnouncementEnabled = false;

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
		G_ConfigString(CS_SCB_PLAYERTAB_TITLES, "Name Clan Score Dfrst Ping R");
	} else {
		G_ConfigString(CS_SCB_PLAYERTAB_LAYOUT, "%n 112 %s 52 %i 52 %i 52 %i 52 %l 48 " + "%p 18 " + "%p 18");
		G_ConfigString(CS_SCB_PLAYERTAB_TITLES, "Name Clan Score Frags Dfrst Ping " + "C " + " R");
	}

	// precache images that can be used by the scoreboard
	prcYesIcon = G_ImageIndex("gfx/hud/icons/vsay/yes");
	prcShockIcon = G_ImageIndex("gfx/hud/icons/powerup/quad");
	prcShellIcon = G_ImageIndex("gfx/hud/icons/powerup/warshell");

	// add commands
	G_RegisterCommand("drop");
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
			+ "set COD_allowPowerups \"1\"\n"
			+ "set COD_powerupDrop \"1\"\n"
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
