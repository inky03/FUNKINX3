package funkin.states;

import funkin.objects.Character;

import openfl.media.Sound;

class GameOverSubState extends funkin.backend.states.FunkinSubState {
	public var cam:FunkinCamera;
	public var playState:PlayState;
	public var cameraZoom:Float = 1;
	public var started:Bool = false;
	public var confirmed:Bool = false;
	public var wasInstant:Bool = false;
	public var character:Character = null;
	public var deathAnimationPostfix:String = '';
	
	public var soundPath:String = 'gameplay/gameOver/gameOverStart';
	public var musicPath:String = 'gameplay/gameOver/gameOver';
	public var startMusicPath:String = 'gameplay/gameOver/gameOverStart';
	public var confirmMusicPath:String = 'gameplay/gameOver/gameOverEnd';
	
	public var sound:Sound;
	public var music:Sound;
	public var startMusic:Sound;
	public var confirmMusic:Sound;
	
	public function new(instant:Bool = true) {
		super();
		
		wasInstant = instant;
		playState = cast(FlxG.state, PlayState);
		character = playState.player1;
		FlxG.camera = cam = playState.camGame;
		
		playState.hscripts.run('death', [instant, this]);
		
		if (character != null) {
			cameraZoom = character.deathData?.cameraZoom ?? 1;
			soundPath = Util.pathSuffix(soundPath, character.findPathSuffix('sounds/$soundPath', '.ogg'));
			musicPath = Util.pathSuffix(musicPath, character.findPathSuffix('music/$musicPath', '.ogg'));
			startMusicPath = Util.pathSuffix(startMusicPath, character.findPathSuffix('music/$startMusicPath', '.ogg'));
			confirmMusicPath = Util.pathSuffix(confirmMusicPath, character.findPathSuffix('music/$confirmMusicPath', '.ogg'));
		}
		
		sound = Paths.sound(soundPath);
		music = Paths.music(musicPath);
		startMusic = Paths.music(startMusicPath);
		confirmMusic = Paths.music(confirmMusicPath);
		
		playState.hscripts.run('deathPost', [instant, this]);
	}
	public override function create() {
		FlxG.state.persistentDraw = false;
		FlxG.state.persistentUpdate = false;
		if (character != null) {
			add(character);
			focusOnCharacter(character);
			playState.stage.remove(character);
			var aniName:String = 'firstDeath$deathAnimationPostfix';
			if (character.animationExists(aniName, true)) {
				character.playAnimation(aniName);
				character.onAnimationComplete.add((anim:String) -> {
					if (anim == aniName)
						startGameOver();
				});
			} else {
				new FlxTimer().start(2.5, (_) -> { startGameOver(); });
			}
		}
		if (sound != null)
			FlxG.sound.play(sound);
		playState.hscripts.run('deathCreate', [wasInstant, this]);
	}
	public override function update(elapsed:Float) {
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
		if (FlxG.sound.music != null)
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
		character?.playAnimation('deathLoop$deathAnimationPostfix');
		
		if (confirmed) return;
		
		if (startMusic != null) {
			FlxG.sound.playMusic(startMusic, 1, false);
			FlxG.sound.music.onComplete = () -> {
				if (music != null)
					FlxG.sound.playMusic(music);
			};
		} else if (music != null) {
			FlxG.sound.playMusic(music);
		}
		
		started = true;
		playState.hscripts.run('deathStart', [this]);
	}
	public function endGameOver() {
		if (!started) {
			started = true;
			playState.hscripts.run('deathStart', [this]);
		}
		
		confirmed = true;
		character?.playAnimation('deathConfirm$deathAnimationPostfix');
		if (FlxG.sound.music != null) FlxG.sound.music.stop();
		if (confirmMusic != null)
			FlxG.sound.playMusic(confirmMusic, 1, false);
		new FlxTimer().start(.7, (_) -> {
			FlxG.camera.fade(FlxColor.BLACK, 2, false, () -> { FlxG.resetState(); });
		});
		
		playState.hscripts.run('deathConfirm', [this]);
	}
}