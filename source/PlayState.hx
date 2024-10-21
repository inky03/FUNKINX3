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

using StringTools;

class PlayState extends MusicBeatState {
	public var basicBG:FunkinSprite;
	public var player1:Character;
	public var player2:Character;
	public var player3:Character;

	public var stage:Stage;
	public var curStage:String;
	
	public var healthBar:Bar;
	public var iconP1:HealthIcon;
	public var iconP2:HealthIcon;
	public var scoreTxt:FlxText;
	public var debugTxt:FlxText;
	public var opponentStrumline:Strumline;
	public var playerStrumline:Strumline;
	public var uiGroup:FlxSpriteGroup;
	public var ratingGroup:FlxTypedSpriteGroup<FunkinSprite>;
	
	public var singAnimations:Array<String> = ['LEFT', 'DOWN', 'UP', 'RIGHT'];
	public var hitWindows:Array<HitWindow> = Scoring.emiDefault();
	public var keybinds:Array<Array<FlxKey>> = [];
	public var heldKeys:Array<FlxKey> = [];
	public var inputDisabled:Bool = false;
	public var playCountdown:Bool = true;
	
	public var camHUD:FlxCamera;
	public var camGame:FlxCamera;
	public var camOther:FlxCamera;
	public var camFocus:FlxObject;
	public var camFocusTarget:FlxPoint;
	
	public var camZoomIntensity:Float = 1;
	public var HUDZoomIntensity:Float = 1;
	public var defaultHUDZoom:Float = 1;
	public var defaultCamZoom:Float = 1;
	public var camZoomLerp:Bool = true;
	public var HUDZoomLerp:Bool = true;
	
	public static var song:Song = null;
	public var syncVocals:Array<FlxSound> = [];
	public var events:Array<SongEvent> = [];
	public var notes:Array<Note> = [];
	
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
		if (song == null) song = new Song(''); // lol!
		super.create();
		Main.watermark.visible = false;
		Conductor.metronome.tempoChanges = song.tempoChanges;
		
		HScriptBackend.loadFromFolder('scripts');
		HScriptBackend.loadFromFolder('data/${song.path}');
		HScriptBackend.run('create');
		
		Conductor.metronome.setBeat(playCountdown ? -5 : -1);
		syncTracker = song.instLoaded ? song.inst : null;

		hitsound = FlxG.sound.load(Paths.sound('hitsound'));
		hitsound.volume = .7;

		stepHit.add(stepHitEvent);
		beatHit.add(beatHitEvent);
		barHit.add(barHitEvent);
		
		camHUD = new FlxCamera();
		camGame = new FlxCamera();
		camOther = new FlxCamera();
		camHUD.bgColor.alpha = 0;
		camGame.bgColor.alpha = 0;
		camOther.bgColor.alpha = 0;
		FlxG.cameras.add(camGame, false);
		FlxG.cameras.add(camHUD, false);
		FlxG.cameras.add(camOther, false);
		
		@:privateAccess {
			FlxG.cameras.defaults.resize(0);
			FlxG.cameras.defaults.push(camGame);
		}
		
		camFocusTarget = new FlxPoint(0, FlxG.height * .5);
		camFocus = new FlxObject(camFocusTarget.x, camFocusTarget.y, 1, 1);
		camGame.follow(camFocus, LOCKON, 1);
		add(camFocus);

		curStage = song.stage;
		stage = new Stage(curStage, song);
		defaultCamZoom = stage.zoom;
		add(stage);
		HScriptBackend.set('stage', stage);

		player1 = stage.getCharacter('bf');
		player2 = stage.getCharacter('dad');
		player3 = stage.getCharacter('gf');

		// add stage character positions one day Smiles
		// update: i did ( it sucks i think )

		focusOnCharacter(player3 ?? player1);
		camFocus.setPosition(camFocusTarget.x, camFocusTarget.y);
		
		song.instLoaded = false;
		song.loadMusic('data/${song.path}/', false);
		song.loadMusic('songs/${song.path}/', false);
		for (chara in [player1, player2, player3]) {
			if (chara == null) continue;
			chara.loadVocals(song.path, song.audioSuffix);
			syncVocals.push(chara.vocals);
		}
		if (player1 != null && !player1.vocalsLoaded && player1.character != song.player1) player1.loadVocals(song.path, song.audioSuffix, song.player1);
		if (player2 != null && !player2.vocalsLoaded && player2.character != song.player2) player2.loadVocals(song.path, song.audioSuffix, song.player2);
		if (player1 != null && player2 != null && !player1.vocalsLoaded && !player2.vocalsLoaded) {
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
		opponentStrumline.setPosition(50, strumlineY);
		opponentStrumline.camera = camHUD;
		opponentStrumline.zIndex = 40;
		add(opponentStrumline);
		
		playerStrumline = new Strumline(4, scrollDir, song.scrollSpeed * 1.08);
		playerStrumline.fitToSize(strumlineBound, playerStrumline.height * .7);
		playerStrumline.setPosition(FlxG.width - playerStrumline.width - 50 - 75, strumlineY);
		playerStrumline.camera = camHUD;
		playerStrumline.cpu = false;
		playerStrumline.zIndex = 50;
		add(playerStrumline);

		if (Settings.data.middlescroll) {
			playerStrumline.screenCenter(X);
			opponentStrumline.fitToSize(opponentStrumline.width * .7);
		}
		
		opponentStrumline.addEvent(opponentNoteEvent);
		playerStrumline.addEvent(playerNoteEvent);
		opponentStrumline.visible = false;
		playerStrumline.visible = false;

		keybinds = Settings.data.keybinds['4k'];
		playerStrumline.assignKeys(keybinds);
		
		var noteKinds:Array<String> = [];
		for (note in song.generateNotes()) {
			var strumline:Strumline = (note.player ? playerStrumline : opponentStrumline);
			var lane:Lane = strumline.getLane(note.noteData);
			if (lane != null) lane.queue.push(note);
			if (note.noteKind.trim() != '' && !noteKinds.contains(note.noteKind)) noteKinds.push(note.noteKind);
			notes.push(note);
		}
		for (noteKind in noteKinds) {
			HScriptBackend.loadFromPaths('notekinds/$noteKind.hx');
		}
		
		if (Settings.data.middlescroll) {
			playerStrumline.center(X);
			opponentStrumline.fitToSize(playerStrumline.leftBound - 50 - opponentStrumline.leftBound, 0, Y);
		}
		
		ratingGroup = new FlxTypedSpriteGroup<FunkinSprite>();
		ratingGroup.setPosition(player3?.getMidpoint()?.x ?? FlxG.width * .5, player3?.getMidpoint()?.y ?? FlxG.height * .5);
		ratingGroup.zIndex = (player3?.zIndex ?? 0) + 10;
		add(ratingGroup);
		
		healthBar = new Bar(0, FlxG.height - 50, 'healthBar', () -> return health);
		healthBar.bounds.max = maxHealth;
		healthBar.y -= healthBar.height;
		healthBar.screenCenter(X);
		healthBar.zIndex = 10;
		uiGroup.add(healthBar);
		iconP1 = new HealthIcon(0, 0, player1.healthIcon);
		iconP1.origin.x = 0;
		iconP1.flipX = true; // fuck you
		iconP1.zIndex = 15;
		uiGroup.add(iconP1);
		iconP2 = new HealthIcon(0, 0, player2.healthIcon);
		iconP2.origin.x = iconP2.width;
		iconP2.zIndex = 15;
		uiGroup.add(iconP2);
		
		scoreTxt = new FlxText(0, FlxG.height - 25, FlxG.width, 'Score: idk');
		scoreTxt.setFormat(Paths.font('vcr.ttf'), 18, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		scoreTxt.y -= scoreTxt.height * .5;
		scoreTxt.borderSize = 1.25;
		uiGroup.add(scoreTxt);
		updateRating();
		debugTxt = new FlxText(0, 12, FlxG.width, '');
		debugTxt.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		uiGroup.add(debugTxt);

		if (Settings.data.downscroll) {
			for (sprite in [opponentStrumline, playerStrumline, healthBar, iconP1, iconP2, scoreTxt]) {
				sprite.y = FlxG.height - sprite.y - sprite.height;
			}
		}

		for (event in song.events) {
			events.push(event);
			pushedEvent(event);
		}
		if (song.instLoaded) {
			song.inst.onComplete = finishSong;
		}
		for (i in 0...4) Paths.sound('missnote$i');
		
		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, keyPressEvent);
		FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, keyReleaseEvent);
		
		DiscordRPC.presence.details = '${song.name} [${song.difficulty.toUpperCase()}]';
		DiscordRPC.dirty = true;
		
		HScriptBackend.run('createPost');
		sortZIndex();
	}

	override public function update(elapsed:Float) {
		if (FlxG.keys.justPressed.ESCAPE) {
			FlxG.switchState(() -> new FreeplayState());
			return;
		}
		
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
			for (note in notes) {
				var strumline:Strumline = (note.player ? playerStrumline : opponentStrumline);
				var lane:Lane = strumline.getLane(note.noteData);
				lane.queue.push(note);
			}
			for (event in song.events) events.push(event);
			song.inst.time = 0;
			song.inst.pause();
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
				song.inst.time = Conductor.songPosition + 2000;
				syncMusic(false, true);
			}
			if (FlxG.keys.justPressed.LEFT) {
				Conductor.songPosition -= 2000;
				song.inst.time = Conductor.songPosition - 2000;
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
				song.inst.pause();
				for (track in syncVocals) track.pause();
			} else {
				if (song.instLoaded) song.inst.play(true, Conductor.songPosition);
				for (track in syncVocals) track.play(true, Conductor.songPosition);
				syncMusic(false, true);
			}
			FlxTimer.globalManager.forEach((timer:FlxTimer) -> { if (!timer.finished) timer.active = !paused; });
			FlxTween.globalManager.forEach((tween:FlxTween) -> { if (!tween.finished) tween.active = !paused; });
		}
		
		DiscordRPC.update();
		super.update(elapsed);
		HScriptBackend.run('update', [elapsed, paused]);

		if (paused) {
			HScriptBackend.run('updatePost', [elapsed, paused]);
			return;
		}
		
		iconP1.updateBop(elapsed);
		iconP2.updateBop(elapsed);
		iconP1.setPosition(healthBar.barCenter.x + 60 - iconP1.width * .5, healthBar.barCenter.y - iconP1.height * .5);
		iconP2.setPosition(healthBar.barCenter.x - 60 - iconP2.width * .5, healthBar.barCenter.y - iconP2.height * .5);
		
		extraWindow = Math.max(extraWindow - elapsed * 200, 0);
		
		syncMusic();
		if (camZoomLerp) camHUD.zoom = FlxMath.lerp(camHUD.zoom, defaultHUDZoom, elapsed * 3);
		if (HUDZoomLerp) camGame.zoom = FlxMath.lerp(camGame.zoom, defaultCamZoom, elapsed * 3);
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
		
		HScriptBackend.run('updatePost', [elapsed]);
		
		if (Conductor.songPosition >= song.songLength && !conductorPaused) {
			finishSong();
		}
	}

	public function finishSong() {
		var result:Dynamic = HScriptBackend.run('finishSong');
		if (result == HScript.STOP) {
			conductorPaused = true;
			return;
		}
		FlxG.switchState(() -> new FreeplayState());
	}
	
	public function syncMusic(forceSongpos:Bool = false, forceTrackTime:Bool = false) {
		if (song.instLoaded && song.inst.playing) {
			if ((forceSongpos && Conductor.songPosition < song.inst.time) || Math.abs(song.inst.time - Conductor.songPosition) > 75)
				Conductor.songPosition = song.inst.time;
			if (forceTrackTime) {
				for (track in syncVocals) {
					if (Math.abs(song.inst.time - track.time) > 75)
						track.time = song.inst.time;
				}
			}
		}
	}
	public function getSongPos() {
		if (song.instLoaded && song.inst.playing)
			return song.inst.time;
		else
			return Conductor.songPosition;
	}

	public function pushedEvent(event:SongEvent) {
		HScriptBackend.loadFromPaths('events/${event.name}.hx');
		
		var params:Map<String, Dynamic> = event.params;
		switch (event.name) {
			case 'PlayAnimation':
				var focusChara:Null<Character> = null;
				switch (params['target']) {
					case 'girlfriend', 'gf': focusChara = player3;
					case 'boyfriend', 'bf': focusChara = player1;
					case 'dad': focusChara = player2;
				} if (focusChara != null) focusChara.preloadAnimAsset(params['anim']);
		}
		HScriptBackend.run('eventPushed', [event]);
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
					focusOnCharacter(focusChara);
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
						focusChara.animReset = focusChara.specialAnim ? 0 : 8;
					}
				}
		}
		HScriptBackend.run('eventTriggered', [event]);
	}
	public function focusOnCharacter(chara:Character) {
		if (chara != null) {
			camFocusTarget.x = chara.getMidpoint().x + chara.cameraOffset.x;
			camFocusTarget.y = chara.getMidpoint().y + chara.cameraOffset.y;
		}
	}
	
	public function stepHitEvent(step:Int) {
		syncMusic(true);
		HScriptBackend.run('stepHit', [step]);
	}
	public function beatHitEvent(beat:Int) {
		try {
			iconP1.bop();
			iconP2.bop();
			stage.beatHit(beat);
		} catch (e:Dynamic) {}

		if (playCountdown) {
			switch (beat) {
				case -4:
					FlxG.sound.play(Paths.sound('intro3'));
					opponentStrumline.fadeIn();
					playerStrumline.fadeIn();
				case -3:
					popCountdown('ready');
					FlxG.sound.play(Paths.sound('intro2'));
				case -2:
					popCountdown('set');
					FlxG.sound.play(Paths.sound('intro1'));
				case -1:
					popCountdown('go');
					FlxG.sound.play(Paths.sound('introGo'));
				default:
			}
		}
		if (beat == 0) {
			if (song.instLoaded) song.inst.play(true);
			for (track in syncVocals) track.play(true);
			syncMusic(true, true);
		}
		HScriptBackend.run('beatHit', [beat]);
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
		HScriptBackend.run('countdownTick', [image]);
	}
	public function barHitEvent(bar:Int) {
		camHUD.zoom += .03 * HUDZoomIntensity;
		camGame.zoom += .015 * camZoomIntensity;
		HScriptBackend.run('barHit', [bar]);
	}
	
	public function keyPressEvent(event:KeyboardEvent) {
		var key:FlxKey = event.keyCode;
		if (!heldKeys.contains(key)) heldKeys.push(key);
		
		if (inputDisabled || paused) return;
		var keybind:Int = Controls.keybindFromArray(keybinds, key);
		if (keybind >= 0 && FlxG.keys.checkStatus(key, JUST_PRESSED)) inputOn(keybind);
	}
	public function keyReleaseEvent(event:KeyboardEvent) {
		var key:FlxKey = event.keyCode;
		heldKeys.remove(key);
		
		if (inputDisabled || paused) return;
		var keybind:Int = Controls.keybindFromArray(keybinds, key);
		if (keybind >= 0) inputOff(keybind);
	}
	public function inputOn(keybind:Int) { // todo: lanes have the INPUTS and not PLAYSTATE
		HScriptBackend.run('keyPressed', [keybind]);
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
			lane.ghostTapped();
			extraWindow = Math.min(extraWindow + 15, 200);
		}
		Conductor.songPosition = oldTime;
	}
	public function inputOff(keybind:Int) {
		HScriptBackend.run('keyReleased', [keybind]);
		var lane:Lane = playerStrumline.getLane(keybind);
		lane.receptor.playAnimation('static', true);
		lane.held = false;
	}
	public function playerNoteEvent(e:Lane.NoteEvent) {
		e.targetCharacter = player1;
		if (e.type == Lane.NoteEventType.GHOST && Settings.data.ghostTapping) {
			e.playAnimation = false;
			e.applyRating = false;
			e.playSound = false;
		}

		HScriptBackend.run('playerNoteEventPre', [e]);
		try e.dispatch()
		catch (e:haxe.Exception) Sys.println('error dispatching note event -> ${e.message}');
		HScriptBackend.run('playerNoteEvent', [e]);
	}
	public function opponentNoteEvent(e:Lane.NoteEvent) {
		e.targetCharacter = player2;
		e.applyRating = false;
		e.playSound = false;
		e.doSplash = false;
		e.doSpark = false;

		HScriptBackend.run('opponentNoteEventPre', [e]);
		try e.dispatch()
		catch (e:haxe.Exception) Sys.println('error dispatching note event -> ${e.message}');
		HScriptBackend.run('opponentNoteEvent', [e]);
	}
	public dynamic function comboBroken(oldCombo:Int) {
		popCombo(0);
		var result:Dynamic = HScriptBackend.run('comboBroken');
		if (result != HScript.STOP && oldCombo >= 10 && player3 != null) player3.playAnimationSteps('sad', true, 8);
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
			popNum.setPosition(popNum.x + (i + xOffset) * 43, popNum.y + 80);
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
		var rating:FunkinSprite = new FunkinSprite(0, 0);
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
		HScriptBackend.run('updateScore');
	}
	public function set_combo(newCombo:Int) {
		if (combo > 0 && newCombo == 0) comboBroken(combo);
		return combo = newCombo;
	}
	
	override public function destroy() {
		HScriptBackend.run('destroy');
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, keyPressEvent);
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_UP, keyReleaseEvent);
		Main.watermark.visible = true;
		super.destroy();
	}
}