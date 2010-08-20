cFrozenPlayer @frozenHead = null;

class cFrozenPlayer {
	uint defrostTime;
	//uint lastTouch;

	cClient @client;

	cEntity @model;
	cEntity @sprite;
	cEntity @minimap;

	bool frozen;

	cFrozenPlayer @next;
	cFrozenPlayer @prev; // for faster removal

	cFrozenPlayer(cClient @player) {
		if(@player == null) {
			return;
		}

		@this.prev = null;
		@this.next = @frozenHead;
		if(@this.next != null) {
			@this.next.prev = @this;
		}
		@frozenHead = @this;

		this.defrostTime = 0;
		//this.lastTouch = 0;

		@this.client = player;
		cVec3 vec = this.client.getEnt().getOrigin();

		cVec3 mins, maxs;
		this.client.getEnt().getSize(mins, maxs);

		@this.model = @G_SpawnEntity("player_frozen");
		this.model.type = ET_PLAYER;
		this.model.moveType = MOVETYPE_TOSS;
		this.model.mass = 250; // no longer arbritary
		this.model.takeDamage = 1;
		this.model.setOrigin(vec);
		this.model.setVelocity(this.client.getEnt().getVelocity());
		this.model.setSize(mins, maxs);
		this.model.setAngles(player.getEnt().getAngles());
		this.model.team = player.team;
		this.model.modelindex = this.client.getEnt().modelindex;
		this.model.solid = SOLID_NOT;
		this.model.skinNum = this.client.getEnt().skinNum;
		this.model.svflags = (player.getEnt().svflags & ~uint(SVF_NOCLIENT)) | uint(SVF_BROADCAST);
		this.model.effects = EF_ROTATE_AND_BOB | EF_GODMODE;
		this.model.frame = this.client.getEnt().frame;
		this.model.light = COLOR_RGBA(106, 192, 210, 128);
		this.model.linkEntity();
		this.model.addAIGoal(true);

		@this.sprite = @G_SpawnEntity("capture_indicator_sprite");
		this.sprite.type = ET_SPRITE;
		this.sprite.solid = SOLID_NOT;
		this.sprite.setOrigin(vec);
		this.sprite.team = player.team;
		this.sprite.modelindex = G_ImageIndex("gfx/indicators/radar");
		this.sprite.frame = COD_DEFROST_RADIUS; // radius in case of a ET_SPRITE
		this.sprite.svflags = (this.sprite.svflags & ~uint(SVF_NOCLIENT)) | uint(SVF_BROADCAST) | SVF_ONLYTEAM;
		this.sprite.linkEntity();

		@this.minimap = @G_SpawnEntity("capture_indicator_minimap");
		this.minimap.type = ET_MINIMAP_ICON;
		this.minimap.solid = SOLID_NOT;
		this.minimap.setOrigin(vec);
		this.minimap.team = player.team;
		this.minimap.modelindex = G_ImageIndex("gfx/indicators/radar_1");
		this.minimap.frame = 32; // size in case of a ET_MINIMAP_ICON
		this.minimap.svflags = (this.minimap.svflags & ~uint(SVF_NOCLIENT)) | uint(SVF_BROADCAST) | SVF_ONLYTEAM;
		this.minimap.linkEntity();

		frozen = true;

		if(!COD_LastAlive(@this.client)) {
			doRemoveRagdolls = true;
		}
	}

	void defrost() {
		this.model.reachedAIGoal();

		// maybe it will fix bumping into invisible players
		//this.model.solid = SOLID_NOT;

		this.model.freeEntity();
		this.sprite.freeEntity();
		this.minimap.freeEntity();

		if(@this.prev != null) {
			@this.prev.next = @this.next;
		}
		if(@this.next != null) {
			@this.next.prev = @this.prev;
		}
		if(@frozenHead == @this) {
			@frozenHead = @this.next;
		}

		this.frozen = false;
	}

	void use(cEntity @activator) {
		if(!this.frozen) {
			return;
		}

		if(@activator == @this.client.getEnt()) {
			// defrost slowly if they're in a sticky situation
			this.defrostTime += frameTime / COD_INVERSE_HAZARD_DEFROST_SCALE;

			if(this.defrostTime > COD_DEFROST_TIME) {
				cTeam @team = @G_GetTeam(this.client.team);
				for(int i = 0; @team.ent(i) != null; i++) {
					cEntity @ent = @team.ent(i);
					if(@ent == @this.client.getEnt()) {
						G_CenterPrintMsg(team.ent(i), "You were defrosted!");
					} else {
						G_CenterPrintMsg(team.ent(i), this.client.getName() + " was defrosted!");
					}
				}

				G_PrintMsg(null, this.client.getName() + " was defrosted\n");

				this.client.respawn(false);
				this.defrost();
			}

			return;
		}

		if(@activator.client == null || activator.client.team != this.client.team) {
			return;
		}

		playerLastTouch[activator.client.playerNum()] = levelTime;

		if(lastShotTime[activator.client.playerNum()] + COD_DEFROST_ATTACK_DELAY >= levelTime) {
			this.defrostTime += frameTime / COD_INVERSE_ATTACK_DEFROST_SCALE;
		} else {
			this.defrostTime += frameTime;
		}

		if(this.defrostTime > COD_DEFROST_TIME) {
			cTeam @team = @G_GetTeam(this.client.team);
			for(int i = 0; @team.ent(i) != null; i++) {
				cEntity @ent = @team.ent(i);

				if(@ent == @this.client.getEnt()) {
					G_CenterPrintMsg(team.ent(i), "You were defrosted!");
				} else {
					G_CenterPrintMsg(team.ent(i), this.client.getName() + " was defrosted!");
				}
			}

			G_PrintMsg(null, this.client.getName() + " was defrosted by " + activator.client.getName() + "\n");

			defrosts[activator.client.playerNum()]++;

			this.client.respawn(false);
			this.defrost();
		}

		// defrost pie
		float frac = float(this.defrostTime) / float(COD_DEFROST_TIME);
		if(frac < 1) {
			if(lastShotTime[activator.client.playerNum()] + COD_DEFROST_ATTACK_DELAY >= levelTime) {
				playerSTAT_PROGRESS_SELFdelayed[activator.client.playerNum()] = -int(frac * 100);
			} else {
				playerSTAT_PROGRESS_SELFdelayed[activator.client.playerNum()] = int(frac * 100);
			}
		} else {
			playerSTAT_PROGRESS_SELFdelayed[activator.client.playerNum()] = 0;
		}

		/*G_Print(defrostMessage[activator.client.playerNum()] + " -> ");
		defrostMessage[activator.client.playerNum()] += " " + this.client.getName() + ",";
		G_Print(defrostMessage[activator.client.playerNum()]+"\n");*/
	}

	void think() {
		this.model.effects |= EF_GODMODE; // doesn't work without this
		this.sprite.setOrigin(this.model.getOrigin());
		this.minimap.setOrigin(this.model.getOrigin());

		cTrace tr;
		cVec3 center, mins, maxs, origin;
		//bool decay = true;
		cEntity @target = G_GetEntity(0);
		cEntity @stop = G_GetClient(maxClients - 1).getEnt();
		origin = this.sprite.getOrigin();

		while(true) {
			@target = @G_FindEntityInRadius(target, stop, origin, COD_DEFROST_RADIUS);
			if(@target == null || @target.client == null) {
				break;
			}

			if(target.client.state() < CS_SPAWNED || target.isGhosting()) {
				continue;
			}

			// check if the player is visible from the indicator
			target.getSize(mins, maxs);
			center = target.getOrigin() + 0.5 * (maxs + mins);
			mins = maxs = 0;
			if(!tr.doTrace(origin, mins, maxs, center, target.entNum(), MASK_SOLID)) {
				this.use(target);
				//decay = false;
			}
		}

		/*if(decay && this.defrostTime > 0 && this.lastTouch < levelTime - COD_DEFROST_DECAY_DELAY) {
			this.defrostTime -= this.defrostTime < frameTime ? this.defrostTime : frameTime;
		}*/

		this.model.getSize(mins, maxs);

		int point = G_PointContents(this.model.getOrigin() + cVec3(0, 0, mins.z));
		if((point & CONTENTS_LAVA) != 0 || (point & CONTENTS_SLIME) != 0 || (point & CONTENTS_NODROP) != 0) {
			this.use(@this.client.getEnt()); // presumably they are in a pit/slime/lava
		}

		if(@this.next != null) {
			this.next.think();
		}
	}
}

bool COD_LastAlive(cClient @client) {
	cTeam @team = @G_GetTeam(client.team);
	for(int i = 0; @team.ent(i) != null; i++) {
		if(!team.ent(i).isGhosting() && !COD_PlayerFrozen(team.ent(i).client)) {
			return false;
		}
	}

	return true;
}

void COD_DefrostAllPlayers() {
	for(cFrozenPlayer @frozen = @frozenHead; @frozen != null; @frozen = @frozen.next) {
		frozen.defrost();
	}
}

void COD_DefrostTeam(int team) {
	for(cFrozenPlayer @frozen = @frozenHead; @frozen != null; @frozen = @frozen.next) {
		if(frozen.client.team == team) {
			frozen.defrost();
		}
	}
}

bool COD_PlayerFrozen(cClient @client) {
	return @COD_GetFrozenForPlayer(client) != null;
}

cFrozenPlayer @COD_GetFrozenForPlayer(cClient @client) {
	for(cFrozenPlayer @frozen = @frozenHead; @frozen != null; @frozen = @frozen.next) {
		if(@frozen.client == @client) {
			return frozen;
		}
	}

	return null;
}
