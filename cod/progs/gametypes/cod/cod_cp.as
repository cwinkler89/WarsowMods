cCodPlayer @codHead = null;

class cCodPlayer {
	cClient @client;
	int counter;
	
	cCodPlayer @next;
	cCodPlayer @prev; // for faster removal
	
	uint deathStrike;
	uint killStrike;

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
	}
	
	void addKill() {
		if (counter < 0) {
			counter = 0;
			deathStrike = 0;
		}

		counter+=1;
		
		
		if (counter >=7) {
			G_Print(client.getName() + ": Killstrike 7+\n");
		}
		else if (counter >=5) {
			G_Print(client.getName() + ": Killstrike 5\n");
		}
		else if (counter >=3) {
			G_Print(client.getName() + ": Killstrike 3\n");
			client.armor += 150;
		}
	}
	
	void addDeath() {
		if (counter > 0) {
			counter = 0;
			killStrike = 0;
		}

		counter -=1;
		
		if (counter <= -7) {
			G_Print(client.getName() + ": Deathstrike 7-\n");
			deathStrike = 3;
		}
		else if (counter <= -5) {
			G_Print(client.getName() + ": Deathstrike 5\n");
			deathStrike = 2;
		}
		else if (counter <= -3) {
			G_Print(client.getName() + ": Deathstrike 3\n");
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
