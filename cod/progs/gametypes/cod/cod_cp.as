cCodPlayer @codHead = null;
cGhost @ghostHead = null;
cStundDouble @stundDoubleHead = null;

class cStundDouble {
	cEntity @model;
	cEntity @sprite;
	cEntity @minimap;
	
	cStundDouble @next;
	cStundDouble @prev;
	
	cClient @owner;
	
	cStundDouble (cClient @owner) {
		if (@owner == null)
			return;
		
		@this.prev = null;
		@this.next = @stundDoubleHead;
		if(@this.next != null) {
			@this.next.prev = @this;
		}
		
		@stundDoubleHead = @this;
		
		@this.owner = owner;
		
		cVec3 vec = this.owner.getEnt().getOrigin();

		cVec3 mins, maxs;
		this.owner.getEnt().getSize(mins, maxs);

		@this.model = @G_SpawnEntity("stundDouble");
		this.model.type = ET_PLAYER;
		this.model.moveType = MOVETYPE_TOSS;
		this.model.mass = 250; // no longer arbritary
		this.model.takeDamage = 1;
		this.model.setOrigin(vec);
		// this.model.setVelocity(this.owner.getEnt().getVelocity());
		this.model.setSize(mins, maxs);
		this.model.setAngles(owner.getEnt().getAngles());
		this.model.team = owner.team;
		this.model.modelindex = this.owner.getEnt().modelindex;
		this.model.solid = SOLID_NOT;
		this.model.skinNum = this.owner.getEnt().skinNum;
		this.model.svflags = (owner.getEnt().svflags & ~uint(SVF_NOCLIENT)) | uint(SVF_BROADCAST);
		this.model.effects = EF_ROTATE_AND_BOB | EF_GODMODE;
		this.model.frame = this.owner.getEnt().frame;
		//this.model.light = COLOR_RGBA(106, 192, 210, 128);
		this.model.linkEntity();
		//this.model.addAIGoal(true);


		@this.sprite = @G_SpawnEntity("capture_indicator_sprite");
		this.sprite.type = ET_SPRITE;
		this.sprite.solid = SOLID_NOT;
		this.sprite.setOrigin(vec);
		this.sprite.team = owner.team;
		this.sprite.modelindex = G_ImageIndex("gfx/indicators/radar");
		this.sprite.frame = 100.0f; // radius in case of a ET_SPRITE
		this.sprite.svflags = (this.sprite.svflags & ~uint(SVF_NOCLIENT)) | uint(SVF_BROADCAST) | SVF_ONLYTEAM;
		this.sprite.linkEntity();
		
		
		@this.minimap = @G_SpawnEntity("capture_indicator_minimap");
		this.minimap.type = ET_MINIMAP_ICON;
		this.minimap.solid = SOLID_NOT;
		this.minimap.setOrigin(vec);
		this.minimap.team = owner.team;
		this.minimap.modelindex = G_ImageIndex("gfx/indicators/radar_1");
		this.minimap.frame = 32; // size in case of a ET_MINIMAP_ICON
		this.minimap.svflags = (this.minimap.svflags & ~uint(SVF_NOCLIENT)) | uint(SVF_BROADCAST) | SVF_ONLYTEAM;
		this.minimap.linkEntity();
	}
}


class cGhost {
	cEntity @model;
	cEntity @sprite;
	cEntity @minimap;
	
	cGhost @next;
	cGhost @prev;
	
	cClient @owner;
	cClient @target;
	
	uint lastShotTime;
	uint activationTime;
	uint fragsOnCalling;
	
	
	cGhost(cClient @owner)  {
		if (@owner == null)
			return;
		
		@this.prev = null;
		@this.next = @ghostHead;
		if(@this.next != null) {
			@this.next.prev = @this;
		}
		
		@ghostHead = @this;
		
		@this.owner = owner;
		@target = owner;
		
		
		lastShotTime = 0;
		activationTime = 0;
		fragsOnCalling = owner.stats.frags;
		
		cVec3 vec = this.owner.getEnt().getOrigin();

		cVec3 mins, maxs;
		this.owner.getEnt().getSize(mins, maxs);

		@this.model = @G_SpawnEntity("ghost");
		this.model.type = ET_PLAYER;
		this.model.moveType = MOVETYPE_STOP;
		this.model.mass = 250; // no longer arbritary
		this.model.takeDamage = 1;
		this.model.setOrigin(vec);
		// this.model.setVelocity(this.owner.getEnt().getVelocity());
		this.model.setSize(mins, maxs);
		this.model.setAngles(owner.getEnt().getAngles());
		this.model.team = owner.team;
		this.model.modelindex = this.owner.getEnt().modelindex;
		this.model.solid = SOLID_NOT;
		this.model.skinNum = this.owner.getEnt().skinNum;
		this.model.svflags = (owner.getEnt().svflags & ~uint(SVF_NOCLIENT)) | uint(SVF_BROADCAST);
		this.model.effects = EF_ROTATE_AND_BOB | EF_GODMODE;
		this.model.frame = this.owner.getEnt().frame;
		this.model.light = COLOR_RGBA(106, 192, 210, 128);
		this.model.linkEntity();
		//this.model.addAIGoal(true);


		@this.sprite = @G_SpawnEntity("capture_indicator_sprite");
		this.sprite.type = ET_SPRITE;
		this.sprite.solid = SOLID_NOT;
		this.sprite.setOrigin(vec);
		this.sprite.team = owner.team;
		this.sprite.modelindex = G_ImageIndex("gfx/indicators/radar");
		this.sprite.frame = 100.0f; // radius in case of a ET_SPRITE
		this.sprite.svflags = (this.sprite.svflags & ~uint(SVF_NOCLIENT)) | uint(SVF_BROADCAST) | SVF_ONLYTEAM;
		this.sprite.linkEntity();
		
		
		@this.minimap = @G_SpawnEntity("capture_indicator_minimap");
		this.minimap.type = ET_MINIMAP_ICON;
		this.minimap.solid = SOLID_NOT;
		this.minimap.setOrigin(vec);
		this.minimap.team = owner.team;
		this.minimap.modelindex = G_ImageIndex("gfx/indicators/radar_1");
		this.minimap.frame = 32; // size in case of a ET_MINIMAP_ICON
		this.minimap.svflags = (this.minimap.svflags & ~uint(SVF_NOCLIENT)) | uint(SVF_BROADCAST) | SVF_ONLYTEAM;
		this.minimap.linkEntity();
	}
	
	void distroy() {
		
		this.model.freeEntity();
		this.sprite.freeEntity();
		this.minimap.freeEntity();

		if(@this.prev != null) {
			@this.prev.next = @this.next;
		}
		if(@this.next != null) {
			@this.next.prev = @this.prev;
		}
		
		if(@ghostHead == @this) {
			@ghostHead = @this.next;
		}

	}
}

class cCodPlayer {
	cClient @client;
	int counter;
	
	cCodPlayer @next;
	cCodPlayer @prev; // for faster removal
	
	bool deathStrikeLow;
	bool deathStrikeHigh;
	bool killStrikeLow;
	bool killStrikeHigh;
	
	cStundDouble @stundDouble;

	cCodPlayer(cClient @player) {
		if(@player == null) {
			return;
		}
		
		@this.prev = null;
		@this.next = @codHead;
		if(@this.next != null) {
			@this.next.prev = @this;
		}
		@codHead = @this;
		
		@this.client = player;
		
		this.reset();
	}
		
	void disconnect() {

		if(@this.prev != null) {
			@this.prev.next = @this.next;
		}
		if(@this.next != null) {
			@this.next.prev = @this.prev;
		}
		if(@codHead == @this) {
			@codHead = @this.next;
		}

	}
	
	void reset() {
		this.counter = 0;
		deathStrikeLow = false;
		deathStrikeHigh = false;
		killStrikeLow = false;
		killStrikeHigh = false;
		@stundDouble = null;
	}
	
	void resetKillStrike() {
		killStrikeLow = false;
		killStrikeHigh = false;
	}
	
	void resetDeathStrike() {
		deathStrikeLow = false;
		deathStrikeHigh = false;
	}
	
	void addKill() {
		if (counter < 0) {
			counter = 0;
			deathStrikeLow = false;
			deathStrikeHigh = false;
		}
		
		updateGhosts();

		counter+=1;
		
		if (counter >=  (playerHasPositiveFragToDeathDifference(client) ? 4 : 3) && !killStrikeHigh) {
			if (!killStrikeHigh) {
				G_Print(client.getName() + ": Killstrike HIGH\n");
				killStrikeHigh = true;
				castDouble();
			}
		}
		else if (counter >= (playerHasPositiveFragToDeathDifference(client) ? 3 : 2)) {
			G_Print(client.getName() + ": Killstrike LOW\n");
			killStrikeLow = true;
			
			client.getEnt().health += 50;
			
			client.inventoryGiveItem(WEAP_MACHINEGUN);
			client.inventoryGiveItem(WEAP_RIOTGUN);
			client.inventoryGiveItem(WEAP_GRENADELAUNCHER);
			client.inventoryGiveItem(WEAP_ROCKETLAUNCHER);
			client.inventoryGiveItem(WEAP_PLASMAGUN);
			client.inventoryGiveItem(WEAP_LASERGUN);
			client.inventoryGiveItem(WEAP_ELECTROBOLT);
			
			if (playerHasPositiveFragToDeathDifference(client)) {
				client.inventoryGiveItem(AMMO_STRONG_BULLETS);
				client.inventoryGiveItem(AMMO_SHELLS);
				client.inventoryGiveItem(AMMO_GRENADES);
				client.inventoryGiveItem(AMMO_ROCKETS);
				client.inventoryGiveItem(AMMO_PLASMA);
				client.inventoryGiveItem(AMMO_LASERS);
				client.inventoryGiveItem(AMMO_BOLTS);
			}
			
		}
	}
	
	void addDeath() {
		if (counter > 0) {
			counter = 0;
			killStrikeLow = false;
			killStrikeHigh = false;
		}

		counter -=1;
		
		if (counter <= (playerHasPositiveFragToDeathDifference(client) ? -4 : -3)) {
			G_Print(client.getName() + ": Deathstrike HIGH\n");
			deathStrikeHigh = true;
			callGhost();
		}
		else if (counter <= (playerHasPositiveFragToDeathDifference(client) ? -3 : -2)) {
			G_Print(client.getName() + ": Deathstrike LOW\n");
			deathStrikeLow = true;
		}
	}
	
	void callGhost() {
		cGhost(client);
	}
	
	void castDouble() {
		@stundDouble = cStundDouble(client);
	}
	
	void swapWithDouble() {
		if (@stundDouble != null) {
			cVec3 tempOrigin = client.getEnt().getOrigin();
			cVec3 tempAngles = client.getEnt().getAngles();
			
			client.getEnt().setAngles(stundDouble.model.getAngles());
			client.getEnt().setOrigin(stundDouble.model.getOrigin());
			
			stundDouble.model.setAngles(tempAngles);
			stundDouble.model.setOrigin(tempOrigin);
			
			stundDouble.sprite.setOrigin(tempOrigin);
			stundDouble.minimap.setOrigin(tempOrigin);
			
		}
	}
}

cCodPlayer @getCodPlayer(cClient @player) {
	for(cCodPlayer @codPlayer = @codHead; @codPlayer != null; @codPlayer = @codPlayer.next) {
		if(@codPlayer.client == @player) {
			return codPlayer;
		}
	}
	
	return null;
}

int getFragToDeathDifference(cClient @client) {
	return client.stats.frags - client.stats.deaths;
}

bool playerHasPositiveFragToDeathDifference(cClient @client) {
	return getFragToDeathDifference(client) >= 0;
}

void updateGhosts() {
	for(	cGhost @ghost = @ghostHead;
		 	@ghost != null;
		 	@ghost = @ghost.next
		) {
		
		if (ghost.owner.stats.frags >
			ghost.fragsOnCalling + (playerHasPositiveFragToDeathDifference(ghost.owner) ? 2 : 4)) {
			
			ghost.distroy();
		}
		
	}
		
}