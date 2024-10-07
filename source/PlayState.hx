package;

import flixel.system.debug.stats.Stats;
import openfl.events.KeyboardEvent;
import flixel.input.keyboard.FlxKey;
import flixel.FlxState;

import Scoring.HitWindow;
import Song.SongEvent;
import Conductor;
import Character;
import Strumline;
import Scoring;
import Chloe;
import Lane;
import Note;
import Song;
import Bar;

class PlayState extends MusicBeatState {
	public var basicBG:FunkinSprite;
	public var player1:Character;
	public var player2:Character;
	public var player3:Character;
	
	public var healthBar:Bar;
	public var iconP1:HealthIcon;
	public var iconP2:HealthIcon;
	public var scoreTxt:FlxText;
	public var debugTxt:FlxText;
	public var opponentStrumline:Strumline;
	public var playerStrumline:Strumline;
	public var uiGroup:FlxSpriteGroup;
	public var ratingGroup:FlxTypedGroup<FunkinSprite>;
	
	public var singAnimations:Array<String> = ['LEFT', 'DOWN', 'UP', 'RIGHT'];
	public var hitWindows:Array<HitWindow> = Scoring.emiDefault();
	public var keybinds:Array<Array<FlxKey>> = [];
	private var heldKeys:Array<FlxKey> = [];
	
	public var camHUD:FlxCamera;
	public var camOther:FlxCamera;
	public var camFocus:FlxObject;
	public var camFocusTarget:FlxPoint;
	
	public static var song:Song;
	public var syncVocals:Array<FlxSound> = [];
	public var events:Array<SongEvent> = [];
	public var noteSpawnOffset:Float;
	
	public var maxHealth(default, set):Float = 1;
	public var health(default, set):Float = .5;
	public var score:Float = 0;
	public var misses:Int = 0;
	public var combo(default, set):Int = 0;
	public var accuracyMod:Float = 0;
	public var accuracyDiv:Float = 0;
	public var totalNotes:Int = 0;
	public var totalHits:Int = 0;
	public var percent:Float = 0;
	public var extraWindow:Float = 0; //mash mechanic

	public var hitsound:FlxSound;
	
	override public function create() {
		super.create();
		
		for (event in song.events) events.push(event);
		Conductor.metronome.tempoChanges = song.tempoChanges;
		Conductor.metronome.setBeat(-5);

		stepHit.add(stepHitEvent);
		beatHit.add(beatHitEvent);
		barHit.add(barHitEvent);
		
		camHUD = new FlxCamera();
		camOther = new FlxCamera();
		camHUD.bgColor.alpha = 0;
		camOther.bgColor.alpha = 0;
		FlxG.cameras.add(camHUD, false);
		FlxG.cameras.add(camOther, false);
		
		camFocusTarget = new FlxPoint(0, FlxG.height * .5);
		camFocus = new FlxObject(camFocusTarget.x, camFocusTarget.y, 1, 1);
		FlxG.camera.follow(camFocus, LOCKON, 1);
		add(camFocus);
		
		basicBG = new FunkinSprite().loadTexture('bg');
		basicBG.setPosition(-basicBG.width * .5, (FlxG.height - basicBG.height) * .5 + 75);
		basicBG.scrollFactor.set(.95, .95);
		basicBG.scale.set(2.25, 2.25);
		add(basicBG);

		player1 = new Character(250, 0, song.player1, 'bf');
		player2 = new Character(-250, 0, song.player2, 'dad');
		player3 = new Character(0, 0, song.player3, 'gf');
		player3.x -= player3.width * .5;
		player2.x -= player2.width;
		add(player3);
		add(player2);
		add(player1);
		
		song.loadMusic('data/${song.path}/', false);
		song.loadMusic('songs/${song.path}/', false);
		for (chara in [player1, player2, player3]) {
			chara.loadVocals(song.path, song.audioSuffix);
			syncVocals.push(chara.vocals);
		}
		if (!player1.vocalsLoaded && player1.character != song.player1) player1.loadVocals(song.path, song.audioSuffix, song.player1);
		if (!player2.vocalsLoaded && player2.character != song.player2) player2.loadVocals(song.path, song.audioSuffix, song.player2);
		if (!player1.vocalsLoaded && !player2.vocalsLoaded) {
			player1.loadVocals(song.path, song.audioSuffix, '');
		}
		
		uiGroup = new FlxSpriteGroup();
		uiGroup.camera = camHUD;
		add(uiGroup);
		
		var scrollDir:Float = (Settings.data.downscroll ? 270 : 90);
		var strumlineBound:Float = (FlxG.width - 300) * .5;
		var strumlineY:Float = 50;
		
		opponentStrumline = new Strumline(4, scrollDir, song.scrollSpeed);
		opponentStrumline.fitToSize(strumlineBound, opponentStrumline.height * .7);
		if (Settings.data.downscroll) strumlineY = FlxG.height - opponentStrumline.height - strumlineY;
		opponentStrumline.setPosition(50, strumlineY);
		opponentStrumline.camera = camHUD;
		add(opponentStrumline);
		
		playerStrumline = new Strumline(4, scrollDir, song.scrollSpeed * 1.08);
		playerStrumline.fitToSize(strumlineBound, playerStrumline.height * .7);
		playerStrumline.setPosition(FlxG.width - playerStrumline.width - 50 - 75, strumlineY);
		playerStrumline.camera = camHUD;
		playerStrumline.cpu = false;
		add(playerStrumline);
		
		opponentStrumline.fadeIn();
		playerStrumline.fadeIn();
		
		keybinds = Settings.data.keybinds['4k'];
		playerStrumline.assignKeys(Settings.data.keybinds['4k']);
		opponentStrumline.addEvent(opponentNoteEvent);
		playerStrumline.addEvent(playerNoteEvent);
		for (note in song.notes) {
			var strumline:Strumline = (note.player ? playerStrumline : opponentStrumline);
			var lane:Lane = strumline.getLane(note.noteData);
			if (lane != null)
				lane.queue.push(note);
		}
		
		if (Settings.data.middlescroll) {
			playerStrumline.center(X);
			opponentStrumline.fitToSize(playerStrumline.leftBound - 50 - opponentStrumline.leftBound, 0, Y);
		}
		
		ratingGroup = new FlxTypedGroup<FunkinSprite>();
		add(ratingGroup);
		
		healthBar = new Bar(0, FlxG.height - 50, 'healthBar', () -> return health);
		healthBar.bounds.max = maxHealth;
		healthBar.y -= healthBar.height;
		healthBar.screenCenter(X);
		uiGroup.add(healthBar);
		iconP1 = new HealthIcon(0, 0, player1.healthIcon);
		iconP1.origin.x = 0;
		iconP1.flipX = true; // fuck you
		uiGroup.add(iconP1);
		iconP2 = new HealthIcon(0, 0, player2.healthIcon);
		iconP2.origin.x = iconP2.width;
		uiGroup.add(iconP2);
		
		scoreTxt = new FlxText(0, FlxG.height - 25, FlxG.width, 'Score: idk');
		scoreTxt.setFormat(Paths.font('vcr.ttf'), 18, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		scoreTxt.y -= scoreTxt.height * .5;
		scoreTxt.borderSize = 1.25;
		uiGroup.add(scoreTxt);
		debugTxt = new FlxText(0, 12, FlxG.width, '');
		debugTxt.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		uiGroup.add(debugTxt);
		
		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, keyPressEvent);
		FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, keyReleaseEvent);
		
		noteSpawnOffset = Note.distanceToMS(720, playerStrumline.scrollSpeed);
		updateRating();

		hitsound = new FlxSound().loadEmbedded(Paths.sound('hitsound'));
		hitsound.volume = .7;
		
		DiscordRPC.presence.details = '${song.name} [${song.difficulty.toUpperCase()}]';
		DiscordRPC.dirty = true;
	}

	override public function update(elapsed:Float) {
		DiscordRPC.update();
		if (FlxG.keys.justPressed.Q) {
			Conductor.songPosition -= 350;
		}
		if (FlxG.keys.justPressed.R) {
			opponentStrumline.fadeIn();
			playerStrumline.fadeIn();
			
			opponentStrumline.clearAllNotes();
			playerStrumline.clearAllNotes();
			events = [];
			for (lane in opponentStrumline.lanes) lane.held = false;
			for (note in song.notes) {
				var strumline:Strumline = (note.player ? playerStrumline : opponentStrumline);
				var lane:Lane = strumline.getLane(note.noteData);
				lane.queue.push(note);
			}
			for (event in song.events) events.push(event);
			song.instTrack.time = 0;
			song.instTrack.pause();
			for (track in syncVocals) {
				track.time = 0;
				track.pause();
			}
			resetMusic();
			Conductor.metronome.setBeat(-5);
			resetScore();
		}
		if (FlxG.keys.pressed.SHIFT) {
			if (FlxG.keys.justPressed.B) {
				playerStrumline.cpu = !playerStrumline.cpu;
			}
			if (FlxG.keys.justPressed.RIGHT) {
				Conductor.songPosition += 2000;
				song.instTrack.time = Conductor.songPosition + 2000;
				syncMusic(false, true);
			}
			if (FlxG.keys.justPressed.LEFT) {
				Conductor.songPosition -= 2000;
				song.instTrack.time = Conductor.songPosition - 2000;
				syncMusic(false, true);
			}
		}
		
		if (FlxG.keys.justPressed.Z) {
			var strumlineY:Float = 50;
			Settings.data.downscroll = !Settings.data.downscroll;
			if (Settings.data.downscroll) strumlineY = FlxG.height - opponentStrumline.receptorHeight - strumlineY;
			for (strumline in [opponentStrumline, playerStrumline]) {
				strumline.direction += 180;
				strumline.y = strumlineY;
			}
		}
		if (FlxG.keys.justPressed.ENTER) {
			paused = !paused;
			var pauseVocals:Bool = (paused || Conductor.songPosition < 0);
			if (pauseVocals) {
				song.instTrack.pause();
				for (track in syncVocals) track.pause();
			} else {
				if (song.instLoaded) song.instTrack.play(true, Conductor.songPosition);
				for (track in syncVocals) track.play(true, Conductor.songPosition);
				syncMusic(false, true);
			}
		}
		
		debugTxt.text = 'BPM: ${Conductor.bpm}  |  Time Signature: ${Conductor.timeSignature.toString()}\nBeat: $curBeat | Measure: $curBar${playerStrumline.cpu ? '\nBOTPLAY ENABLED' : ''}';
		
		super.update(elapsed);
		iconP1.updateBop(elapsed);
		iconP2.updateBop(elapsed);
		iconP1.setPosition(healthBar.barCenter.x + 60 - iconP1.width * .5, healthBar.barCenter.y - iconP1.height * .5);
		iconP2.setPosition(healthBar.barCenter.x - 60 - iconP2.width * .5, healthBar.barCenter.y - iconP2.height * .5);
		
		if (paused) return;
		
		extraWindow = Math.max(extraWindow - elapsed * 200, 0);
		
		syncMusic();
		camHUD.zoom = FlxMath.lerp(camHUD.zoom, 1, elapsed * 3);
		FlxG.camera.zoom = FlxMath.lerp(FlxG.camera.zoom, 1, elapsed * 3);
		camFocus.setPosition(
			Util.smoothLerp(camFocus.x, camFocusTarget.x, elapsed * 3),
			Util.smoothLerp(camFocus.y, camFocusTarget.y, elapsed * 3)
		);
		
		var limit:Int = 50; //avoid lags
		while (events.length > 0 && Conductor.songPosition >= events[0].msTime && limit > 0) {
			var event:SongEvent = events.shift();
			triggerEvent(event);
			limit --;
		}
		
		if (Conductor.songPosition >= song.songLength || FlxG.keys.justPressed.ESCAPE) {
			FlxG.switchState(() -> new FreeplayState());
		}
	}
	
	public function syncMusic(forceSongpos:Bool = false, forceTrackTime:Bool = false) {
		if (song.instLoaded && song.instTrack.playing) {
			var disparity:Float = Math.abs(song.instTrack.time - Conductor.songPosition);
			if ((forceSongpos && Conductor.songPosition < song.instTrack.time) || disparity > 100)
				Conductor.songPosition = song.instTrack.time;
			if (forceTrackTime || disparity > 100) {
				for (track in syncVocals) track.time = song.instTrack.time;
			}
		}
	}
	public function getSongPos() {
		if (song.instLoaded && song.instTrack.playing)
			return song.instTrack.time;
		else
			return Conductor.songPosition;
	}
	
	public function triggerEvent(event:SongEvent) {
		var params:Map<String, Dynamic> = event.params;
		switch (event.name) {
			case 'FocusCamera':
				var focusCharaInt:Int;
				var focusChara:Null<Character> = null;
				if (params.exists('char')) focusCharaInt = Util.parseInt(params['char']);
				else focusCharaInt = Util.parseInt(params['value']);
				switch (focusCharaInt) {
					case 0: // player focus
						focusChara = player1;
					case 1: // opponent focus
						focusChara = player2;
					case 2: // gf focus
						focusChara = player3;
				}

				if (focusChara != null) {
					camFocusTarget.x = focusChara.getMidpoint().x + focusChara.cameraOffset.x;
					camFocusTarget.y = focusChara.getMidpoint().y + focusChara.cameraOffset.y;
				} else {
					camFocusTarget.x = 0;
					camFocusTarget.y = 0;
				}
				if (params.exists('x')) camFocusTarget.x += Util.parseFloat(params['x']);
				if (params.exists('y')) camFocusTarget.y += Util.parseFloat(params['y']);
			case 'PlayAnimation':
				var focusChara:Null<Character> = null;
				switch (params['target']) {
					case 'girlfriend', 'gf': focusChara = player3;
					case 'boyfriend', 'bf': focusChara = player1;
					case 'dad': focusChara = player2;
				}
				if (focusChara != null) {
					var anim:String = params['anim'];
					focusChara.playAnimation(anim, true);
					if (focusChara.animation.exists(anim)) {
						focusChara.specialAnim = params['force'] ?? false;
						focusChara.animReset = 0;
					}
				}
		}
	}
	
	public function stepHitEvent(step:Int) {
		syncMusic(true);
	}
	public function beatHitEvent(beat:Int) {
		iconP1.bop();
		iconP2.bop();
		player1.dance(beat);
		player2.dance(beat);
		player3.dance(beat);
		switch (beat) {
			case -4:
				FlxG.sound.play(Paths.sound('intro3'));
			case -3:
				popCountdown('ready');
				FlxG.sound.play(Paths.sound('intro2'));
			case -2:
				popCountdown('set');
				FlxG.sound.play(Paths.sound('intro1'));
			case -1:
				popCountdown('go');
				FlxG.sound.play(Paths.sound('introGo'));
			case 0:
				if (song.instLoaded) song.instTrack.play(true);
				for (track in syncVocals) track.play(true);
				syncMusic(true, true);
			default:
		}
	}
	public function popCountdown(image:String) {
		var pop = new FunkinSprite().loadTexture(image);
		pop.camera = camHUD;
		pop.screenCenter();
		add(pop);
		FlxTween.tween(pop, {alpha: 0}, Conductor.crochet * .001, {ease: FlxEase.cubeInOut, onComplete: (tween:FlxTween) -> {
			remove(pop);
			pop.destroy();
		}});
	}
	public function barHitEvent(bar:Int) {
		FlxG.camera.zoom += .015;
		camHUD.zoom += .03;
	}
	
	public function keyPressEvent(event:KeyboardEvent) {
		var key:FlxKey = event.keyCode;
		if (!heldKeys.contains(key)) heldKeys.push(key);
		
		var keybind:Int = Controls.keybindFromArray(keybinds, key);
		if (keybind >= 0 && FlxG.keys.checkStatus(key, JUST_PRESSED)) inputOn(keybind);
	}
	public function keyReleaseEvent(event:KeyboardEvent) {
		var key:FlxKey = event.keyCode;
		heldKeys.remove(key);
		
		var keybind:Int = Controls.keybindFromArray(keybinds, key);
		if (keybind >= 0) inputOff(keybind);
	}
	public function inputOn(keybind:Int) { // todo: lanes have the INPUTS and not PLAYSTATE
		var oldTime:Float = Conductor.songPosition;
		Conductor.songPosition = getSongPos();
		var lane:Lane = playerStrumline.getLane(keybind);
		var note = lane.getHighestNote((note:Note) -> {
			var time:Float = note.msTime - Conductor.songPosition;
			return (time <= note.hitWindow + extraWindow) && (time >= -note.hitWindow);
		});
		if (note != null) {
			lane.hitNote(note);
			extraWindow = Math.min(extraWindow + 6, 200);
		} else {
			lane.receptor.playAnimation('press', true);
			extraWindow = Math.min(extraWindow + 15, 200);
		}
		Conductor.songPosition = oldTime;
	}
	public function inputOff(keybind:Int) {
		var lane:Lane = playerStrumline.getLane(keybind);
		lane.receptor.playAnimation('static', true);
		lane.held = false;
	}
	public function playerNoteEvent(e:Lane.NoteEvent) {
		var note:Note = e.note;
		var lane:Lane = e.lane;
		switch (e.type) {
			case HIT:
				player1.volume = 1;
				if (note.isHoldPiece) {
					var anim:String = 'sing${singAnimations[note.noteData]}';
					if (player1.animation.name != anim && !player1.animationIsLooping(anim))
						player1.playAnimationSoft(anim, true);
					if (note.isHoldTail)
						FlxG.sound.play(Paths.sound('hitsoundTail'), .7);
				} else {
					hitsound.play(true);
					player1.playAnimationSoft('sing${singAnimations[note.noteData]}', true);
					
					var window:HitWindow = Scoring.judgeLegacy(hitWindows, note.hitWindow, note.msTime - Conductor.songPosition);
					window.count ++;
					
					note.ratingData = window;
					popRating(window.rating);
					score += window.score;
					health += note.healthGain * window.health;
					accuracyMod += window.accuracyMod;
					accuracyDiv ++;
					totalNotes ++;
					totalHits ++;
					if (window.breaksCombo) combo = 0; // maybe add the ghost note here?
					else popCombo(++ combo);
					if (note.ratingData.splash) lane.splash();
				}
				player1.timeAnimSteps(player1.singForSteps);
				updateRating();
			case LOST:
				popRating('sadmiss');
				player1.volume = 0;
				player1.playAnimationSoft('sing${singAnimations[note.noteData]}miss', true);
				health -= note.healthLoss;
				accuracyDiv ++;
				totalNotes ++;
				misses ++;
				combo = 0;
				score -= 10;
				updateRating();
			default:
		}
	}
	public function opponentNoteEvent(e:Lane.NoteEvent) {
		var note:Note = e.note;
		var lane:Lane = e.lane;
		switch (e.type) {
			case HIT:
				player2.volume = 1;
				if (note.isHoldPiece) {
					var anim:String = 'sing${singAnimations[note.noteData]}';
					if (player2.animation.name != anim && !player2.animationIsLooping(anim))
						player2.playAnimationSoft(anim, true);
				} else {
					player2.playAnimationSoft('sing${singAnimations[note.noteData]}', true);
				}
				player2.timeAnimSteps(player2.singForSteps);
			case LOST:
				player2.volume = 0;
			default:
		}
	}
	public dynamic function comboBroken(oldCombo:Int) {
		popCombo(0);
	}
	public function popCombo(combo:Int) {
		var tempCombo:Int = combo;
		var nums:Array<Int> = [];
		while (tempCombo >= 1) {
			nums.unshift(tempCombo % 10);
			tempCombo = Std.int(tempCombo / 10);
		}
		while (nums.length < 3) nums.unshift(0);
		
		var xOffset:Float = -nums.length * .5 + .5;
		var i:Int = 0;
		for (num in nums) {
			var popNum:FunkinSprite = popRating('num$num', .5, 2);
			popNum.setPosition(popNum.x + (i + xOffset) * 43, FlxG.height * .5 + 80);
			popNum.acceleration.y = FlxG.random.int(200, 300);
			popNum.velocity.y = -FlxG.random.int(140, 160);
			popNum.velocity.x = FlxG.random.float(-5, 5);

			i ++;
		}
	}
	
	public function set_maxHealth(newHealth:Float) {
		health = Math.min(health, newHealth);
		healthBar.bounds.max = newHealth;
		healthBar.updateBars();
		return maxHealth = newHealth;
	}
	public function set_health(newHealth:Float) {
		newHealth = FlxMath.bound(newHealth, 0, maxHealth);
		if (newHealth >= healthBar.bounds.max - .15) {
			if (iconP1.animation.name != 'winning') iconP1.playAnimation('winning');
			if (iconP2.animation.name != 'losing') iconP2.playAnimation('losing');
		} else if (newHealth <= healthBar.bounds.min + .15) {
			if (iconP1.animation.name != 'losing') iconP1.playAnimation('losing');
			if (iconP2.animation.name != 'winning') iconP2.playAnimation('winning');
		} else {
			if (iconP1.animation.name != 'neutral') iconP1.playAnimation('neutral');
			if (iconP2.animation.name != 'neutral') iconP2.playAnimation('neutral');
		}
		return health = newHealth;
	}
	public function resetScore() {
		score = accuracyMod = accuracyDiv = misses = totalHits = totalNotes = combo = 0;
		health = .5;
		updateRating();
	}
	public function updateRating() {
		percent = (accuracyMod / Math.max(1, accuracyDiv)) * 100;
		updateScore();
	}
	public function popRating(ratingString:String, scale:Float = .7, beats:Float = 1) {
		var rating:FunkinSprite = new FunkinSprite(0, FlxG.height * .5);
		rating.loadTexture(ratingString);
		rating.scale.set(scale, scale);
		rating.updateHitbox();
		rating.setOffset(rating.frameWidth * .5, rating.frameHeight * .5);

		rating.acceleration.y = 550;
		rating.velocity.y = -FlxG.random.int(140, 175);
		rating.velocity.x = FlxG.random.int(0, 10);

		ratingGroup.add(rating);
		FlxTween.tween(rating, {alpha: 0}, .2, {onComplete: (tween:FlxTween) -> {
			ratingGroup.remove(rating, true);
			rating.destroy();
		}, startDelay: Conductor.crochet * .001 * beats});
		return rating;
	}
	public function updateScore() {
		var accuracyString:String = 'NA';
		if (totalNotes > 0) accuracyString = '${Util.padDecimals(percent, 2)}%';
		scoreTxt.text = 'Score: ${Util.thousandSep(Std.int(score))} (${accuracyString}) | Misses: ${misses}';
	}
	public function set_combo(newCombo:Int) {
		if (combo > 0 && newCombo == 0) comboBroken(combo);
		return combo = newCombo;
	}
	
	override public function destroy() {
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, keyPressEvent);
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_UP, keyReleaseEvent);
		super.destroy();
	}
}