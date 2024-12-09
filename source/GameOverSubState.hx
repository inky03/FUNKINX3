class GameOverSubState extends MusicBeatSubState {
	public var cam:FunkinCamera;
	public var playState:PlayState;
	public var cameraZoom:Float = 1;
	public var confirmed:Bool = false;
	public var wasInstant:Bool = false;
	public var character:Character = null;
	public var soundPath:String = 'gameplay/gameOver/gameOverStart';
	public var musicPath:String = 'gameplay/gameOver/gameOver';
	public var confirmMusicPath:String = 'gameplay/gameOver/gameOverEnd';
	
	public function new(instant:Bool = true) {
		super();
		
		wasInstant = instant;
		playState = cast(FlxG.state, PlayState);
		character = playState.player1;
		FlxG.camera = cam = playState.camGame;
		playState.hscripts.run('death', [instant]);
		
		if (character != null) {
			cameraZoom = character.deathData?.cameraZoom ?? 1;
			soundPath = Util.pathSuffix(soundPath, character.findPathSuffix('sounds/$soundPath', '.ogg'));
			musicPath = Util.pathSuffix(musicPath, character.findPathSuffix('music/$musicPath', '.ogg'));
			confirmMusicPath = Util.pathSuffix(confirmMusicPath, character.findPathSuffix('music/$confirmMusicPath', '.ogg'));
		}
		
		Paths.music(confirmMusicPath);
		Paths.music(musicPath);
		Paths.sound(soundPath);
	}
	public override function create() {
		FlxG.state.persistentDraw = false;
		FlxG.state.persistentUpdate = false;
		if (character != null) {
			add(character);
			focusOnCharacter(character);
			playState.stage.remove(character);
			if (character.animationExists('firstDeath', true)) {
				character.playAnimation('firstDeath');
				character.onAnimationComplete.add((anim:String) -> {
					if (anim == 'firstDeath')
						startGameOver();
				});
			} else {
				new FlxTimer().start(2.5, (_) -> { startGameOver(); });
			}
		}
		FlxG.sound.play(Paths.sound(soundPath));
		playState.hscripts.run('deathPost', [wasInstant]);
	}
	public override function update(elapsed:Float) {
		elapsed = getRealElapsed();
		playState.hscripts.run('updatePre', [elapsed, false, true]);
		
		if (FlxG.keys.justPressed.ESCAPE && !confirmed) {
			FlxG.switchState(() -> new FreeplayState());
			return;
		}
		if (FlxG.keys.justPressed.ENTER) {
			if (!confirmed) {
				endGameOver();
				if (playState != null)
					playState.hscripts.run('deathConfirm');
			} else {
				// g
			}
		}
		super.update(elapsed);
		playState.hscripts.run('update', [elapsed, false, true]);
		playState.hscripts.run('updatePost', [elapsed, false, true]);
	}
	public override function destroy() {
		FlxG.sound.music.stop();
		remove(character);
		super.destroy();
	}
	
	public function focusOnCharacter(chara:Character, center:Bool = false) {
		if (chara != null) {
			playState.camFocusTarget.x = chara.getMidpoint().x + chara.deathData?.cameraOffsets[0] ?? 0;
			playState.camFocusTarget.y = chara.getMidpoint().y + chara.deathData?.cameraOffsets[1] ?? 0;
		}
	}
	public function startGameOver() {
		character?.playAnimation('deathLoop');
		var music = Paths.music(musicPath);
		if (music != null)
			FlxG.sound.playMusic(music);
	}
	public function endGameOver() {
		confirmed = true;
		character?.playAnimation('deathConfirm');
		var music = Paths.music(confirmMusicPath);
		if (music != null)
			FlxG.sound.playMusic(music, 1, false);
		else
			FlxG.sound.music.stop();
		new FlxTimer().start(.7, (_) -> {
			FlxG.camera.fade(FlxColor.BLACK, 2, false, () -> { FlxG.resetState(); });
		});
	}
}