cCodPlayer @codHead = null;

class cCodPlayer {
	cClient @client;
	cStats statsOnLastDeath;
	
	cCodPlayer @next;
	cCodPlayer @prev; // for faster removal
	
	bool hasDeathStrike1;

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
		
		this.client = player;
		resetPlayer();
	}
		
	void disconnect() {

		this.model.freeEntity();
		this.sprite.freeEntity();
		this.minimap.freeEntity();

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
		statsOnLastDeath = client.stats;
		this.hasDeathStrike1 = false;
	}
	
	void update() {
		
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
