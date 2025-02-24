using StringTools;

function songEvent(e:SongEvent) {
	if (e.type == 'deathStart' && game.player1 != null && game.player1.current.loadedCharacter.startsWith('bf')) {
		var gameOver:GameOverSubState = e.subState;
		var quoteSound:String = 'jeffGameover/jeffGameover-${FlxG.random.int(1, 25)}';
		
		if (gameOver.confirmed) return;
		
		gameOver.musicVolume = .2;
		FunkinSound.playOnce(Paths.sound(quoteSound, 'week7'), 1, () -> {
			if (!gameOver.confirmed && FlxG.sound.music != null && FlxG.sound.music.playing)
				FlxG.sound.music.fadeIn(4, .2, 1);
			gameOver.musicVolume = 1;
		});
	}
}