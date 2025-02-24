package funkin.states;

import funkin.objects.Character;
import funkin.objects.CharacterGroup;

import openfl.media.Sound;

class GameOverSubState extends FunkinState {
	public var cameraZoom:Float = 1;
	public var character:Character = null;
	public var deathAnimationPostfix:String = '';
	
	public var soundPath:String = 'gameplay/gameOver/gameOverStart';
	public var musicPath:String = 'gameplay/gameOver/gameOver';
	public var startMusicPath:String = 'gameplay/gameOver/gameOverStart';
	public var confirmMusicPath:String = 'gameplay/gameOver/gameOverEnd';
	public var musicVolume:Float = 1;
	
	public var sound:Sound;
	public var music:Sound;
	public var startMusic:Sound;
	public var confirmMusic:Sound;
	
	var cam:FunkinCamera;
	var playState:PlayState;
	var waitTimer:FlxTimer = null;
	public var started:Bool = false;
	public var confirmed:Bool = false;
	public var wasInstant:Bool = false;
	
	public function new(instant:Bool = true) {
		super();
		
		wasInstant = instant;
		playState = cast(FlxG.state, PlayState);
		character = playState.player1?.current;
		FlxG.camera = cam = playState.camGame;
		
		playState.hscripts.run('death', [instant, this]);
		playState.dispatchSongEvent({type: DEATH_INIT, character: character, subState: this});
		
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
		}
		
		playState.dispatchSongEvent({type: DEATH_FIRST, character: character, subState: this});
		playState.hscripts.run('deathCreate', [wasInstant, this]);
	}
	public override function update(elapsed:Float) {
		playState.hscripts.run('updatePre', [elapsed, false, true]);
		
		if (FlxG.keys.justPressed.ESCAPE && !confirmed) {
			FlxG.switchState(FreeplayState.new);
			return;
		}
		if (FlxG.keys.justPressed.ENTER && !confirmed) {
			endGameOver();
		}
		super.update(elapsed);
		
		playState.hscripts.run('update', [elapsed, false, true]);
		playState.hscripts.run('updatePost', [elapsed, false, true]);
	}
	public override function destroy() {
		if (FlxG.sound.music != null)
			FlxG.sound.music.stop();
		if (character != null)
			remove(character);
		super.destroy();
	}
	
	public function focusOnCharacter(chara:Character) {
		if (chara != null) {
			playState.camFocusTarget.x = chara.getMidpoint().x + chara.deathData?.cameraOffsets[0] ?? 0;
			playState.camFocusTarget.y = chara.getMidpoint().y + chara.deathData?.cameraOffsets[1] ?? 0;
		}
	}
	public function startGameOver() {
		playState.dispatchSongEvent({type: DEATH_START, character: character, subState: this});
	}
	public function endGameOver() {
		playState.dispatchSongEvent({type: DEATH_CONFIRM, character: character, subState: this});
	}
	
	public function firstDeathEvent() {
		if (character != null) {
			var aniName:String = 'firstDeath$deathAnimationPostfix';
			if (character.animationExists(aniName, true)) {
				character.playAnimation(aniName);
				character.onAnimationComplete.addOnce((anim:String) -> {
					if (!started && anim == aniName)
						startGameOver();
				});
			}
			new FlxTimer().start(2.5, (_) -> {
				if (!started && character.isAnimationFinished())
					startGameOver();
			});
		} else {
			new FlxTimer().start(2.5, (_) -> startGameOver());
		}
		if (sound != null)
			FunkinSound.playOnce(sound);
	}
	public function startDeathEvent() {
		character?.playAnimation('deathLoop$deathAnimationPostfix');
		
		if (confirmed) return;
		
		if (startMusic != null) {
			FlxG.sound.playMusic(startMusic, musicVolume, false);
			FlxG.sound.music.onComplete = () -> {
				if (music != null)
					FlxG.sound.playMusic(music, musicVolume);
			};
		} else if (music != null) {
			FlxG.sound.playMusic(music, musicVolume);
		}
		
		started = true;
		playState.hscripts.run('deathStart', [this]);
	}
	public function confirmDeathEvent() {
		confirmed = true;
		if (!started) {
			started = true;
			playState.dispatchSongEvent({type: DEATH_START, character: character, subState: this});
			playState.hscripts.run('deathStart', [this]);
		}
		
		character?.playAnimation('deathConfirm$deathAnimationPostfix');
		if (FlxG.sound.music != null) FlxG.sound.music.stop();
		if (confirmMusic != null)
			FlxG.sound.playMusic(confirmMusic, musicVolume, false);
		new FlxTimer().start(.7, (_) -> {
			FlxG.camera.fade(FlxColor.BLACK, 2, false, () -> { FlxG.resetState(); });
		});
		
		playState.hscripts.run('deathConfirm', [this]);
	}
}