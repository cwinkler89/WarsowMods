cCodPlayer @codHead = null;

class cCodPlayer {
	cClient @client;
	int counter;
	
	cCodPlayer @next;
	cCodPlayer @prev; // for faster removal
	
	uint deathStrike;
	uint killStrike;
	
	bool autoaim;

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
		deathStrike = 0;
		killStrike = 0;
		autoaim = false;
	}
	
	void addKill() {
		if (counter < 0) {
			counter = 0;
			deathStrike = 0;
		}

		counter+=1;
		
		float ratio = getFragToDeathRatio(this.client);
		
		
		if (counter >= (6 * ratio)) {
			G_Print(client.getName() + ": Killstrike HIGH\n");
			killStrike = 2;
		}
		else if (counter >= (3 * ratio)) {
			G_Print(client.getName() + ": Killstrike LOW\n");
			killStrike = 1;
		}
	}
	
	void addDeath() {
		if (counter > 0) {
			counter = 0;
			killStrike = 0;
		}

		counter -=1;
		
		float ratio = getFragToDeathRatio(this.client);
		
		if (counter <= ((-6) * ratio)) {
			G_Print(client.getName() + ": Deathstrike HIGH\n");
			deathStrike = 2;
		}
		else if (counter <= ((-5) * ratio)) {
			G_Print(client.getName() + ": Deathstrike LOW\n");
			deathStrike = 1;
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

float getFragToDeathRatio(cClient @client) {
	float frags = client.stats.frags;
	float deaths = client.stats.deaths;
	G_Print("getFragToDeathRatio for " + client.getName() + "\n");
	G_Print("frags: " + frags + "\n");
	G_Print("deaths: " + deaths + "\n");
	
	// compairing to 0.0 ineffektiv
	if (deaths <= 0.0f)
		deaths = 1;
		
	if (frags <= 0.0f)
		frags = 1;
	
	return (frags / deaths);
}