package;

import flixel.system.debug.stats.Stats;
import openfl.events.KeyboardEvent;
import flixel.input.keyboard.FlxKey;
import flixel.FlxState;

import Scoring.HitWindow;
import Song.SongEvent;
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
	
	public var camHUD:FunkinCamera;
	public var camGame:FunkinCamera;
	public var camOther:FunkinCamera;
	public var camFocusTarget:FlxObject;
	
	public var camZoomRate:Int = -1; // 0: no bop - <0: every measure (always)
	public var camZoomIntensity:Float = 1;
	public var hudZoomIntensity:Float = 2;
	
	public static var song:Song = null;
	public var syncVocals:Array<FlxSound> = [];
	public var events:Array<SongEvent> = [];
	public var notes:Array<Note> = [];
	public var songName:String;
	
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

	public var hitsound:FlxSound;
	
	override public function create() {
		if (song == null) song = new Song(''); // lol!
		super.create();
		Main.watermark.visible = false;
		
		conductorInUse = new Conductor();
		conductorInUse.metronome.tempoChanges = song.tempoChanges;
		conductorInUse.metronome.setBeat(playCountdown ? -5 : -1);
		conductorInUse.syncTracker = song.instLoaded ? song.inst : null;
		
		hscripts.loadFromFolder('scripts/global');
		hscripts.loadFromFolder('scripts/songs/${song.path}');

		hitsound = FlxG.sound.load(Paths.sound('hitsound'));
		hitsound.volume = .7;

		stepHit.add(stepHitEvent);
		beatHit.add(beatHitEvent);
		barHit.add(barHitEvent);
		
		camHUD = new FunkinCamera();
		camGame = new FunkinCamera();
		camOther = new FunkinCamera();
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
		
		camFocusTarget = new FlxObject(0, FlxG.height * .5);
		camGame.follow(camFocusTarget, LOCKON, 3);
		add(camFocusTarget);

		camGame.zoomFollowLerp = camHUD.zoomFollowLerp = 3;

		curStage = song.stage;
		stage = new Stage(curStage, song);
		camGame.zoomTarget = stage.zoom;
		camHUD.zoomTarget = 1;
		add(stage);
		hscripts.set('stage', stage);

		player1 = stage.getCharacter('bf');
		player2 = stage.getCharacter('dad');
		player3 = stage.getCharacter('gf');

		// add stage character positions one day Smiles
		// update: i did ( it sucks i think )

		focusOnCharacter(player3 ?? player1);
		camGame.snapToTarget();
		
		songName = song.name;
		song.instLoaded = false;
		var songPaths:Array<String> = ['data/songs/${song.path}/', 'songs/${song.path}/'];
		for (path in songPaths) song.loadMusic(path, false);
		if (!song.instLoaded) {
			Log.warning('song instrumental not found...');
			Log.minor('verify paths:');
			for (path in songPaths)
				Log.minor('- $path${Util.pathSuffix('Inst', song.audioSuffix)}.ogg');
		}
		for (chara in [player1, player2, player3]) {
			if (chara == null) continue;
			chara.loadVocals(song.path, song.audioSuffix);
			syncVocals.push(chara.vocals);
		}
		if (player1 != null && !player1.vocalsLoaded && player1.character != song.player1) player1.loadVocals(song.path, song.audioSuffix, song.player1);
		if (player2 != null && !player2.vocalsLoaded && player2.character != song.player2) player2.loadVocals(song.path, song.audioSuffix, song.player2);
		if (player1 != null && player2 != null && !player1.vocalsLoaded && !player2.vocalsLoaded) {
			player1.loadVocals(song.path, song.audioSuffix, '');
			if (!player1.vocalsLoaded)
				Log.warning('song vocals not found...');
		}
		
		uiGroup = new FlxSpriteGroup();
		uiGroup.camera = camHUD;
		add(uiGroup);
		
		var scrollDir:Float = (Options.data.downscroll ? 270 : 90);
		var strumlineBound:Float = (FlxG.width - 300) * .5;
		var strumlineY:Float = 50;
		
		opponentStrumline = new Strumline(4, scrollDir, song.scrollSpeed);
		opponentStrumline.fitToSize(strumlineBound, opponentStrumline.height * .7);
		opponentStrumline.setPosition(50, strumlineY);
		opponentStrumline.zIndex = 40;
		opponentStrumline.cpu = true;
		opponentStrumline.allowInput = false;
		uiGroup.add(opponentStrumline);
		
		playerStrumline = new Strumline(4, scrollDir, song.scrollSpeed * 1.08);
		playerStrumline.fitToSize(strumlineBound, playerStrumline.height * .7);
		playerStrumline.setPosition(FlxG.width - playerStrumline.width - 50 - 75, strumlineY);
		playerStrumline.zIndex = 50;
		uiGroup.add(playerStrumline);

		if (Options.data.middlescroll) {
			playerStrumline.screenCenter(X);
			opponentStrumline.fitToSize(opponentStrumline.width * .7);
		}
		
		opponentStrumline.addEvent(opponentNoteEvent);
		playerStrumline.addEvent(playerNoteEvent);
		opponentStrumline.visible = false;
		playerStrumline.visible = false;

		keybinds = Options.data.keybinds['4k'];
		playerStrumline.assignKeybinds(keybinds);
		
		var noteKinds:Array<String> = [];
		for (note in song.generateNotes()) {
			var strumline:Strumline = (note.player ? playerStrumline : opponentStrumline);
			var lane:Lane = strumline.getLane(note.noteData);
			if (lane != null) lane.queue.push(note);
			if (note.noteKind.trim() != '' && !noteKinds.contains(note.noteKind)) noteKinds.push(note.noteKind);
			notes.push(note);
		}
		for (noteKind in noteKinds)
			hscripts.loadFromPaths('scripts/notekinds/$noteKind.hx');
		
		if (Options.data.middlescroll) {
			playerStrumline.center(X);
			opponentStrumline.fitToSize(playerStrumline.leftBound - 50 - opponentStrumline.leftBound, 0, Y);
		}
		
		ratingGroup = new FlxTypedSpriteGroup<FunkinSprite>();
		ratingGroup.setPosition(player3?.getMidpoint()?.x ?? FlxG.width * .5, player3?.getMidpoint()?.y ?? FlxG.height * .5);
		ratingGroup.zIndex = (player3?.zIndex ?? 0) + 10;
		add(ratingGroup);
		
		healthBar = new Bar(0, FlxG.height - 50, 'healthBar', (_) -> health);
		healthBar.bounds.max = maxHealth;
		healthBar.y -= healthBar.height;
		healthBar.screenCenter(X);
		healthBar.zIndex = 10;
		uiGroup.add(healthBar);
		iconP1 = new HealthIcon(0, 0, player1?.healthIcon ?? 'face');
		iconP1.origin.x = 0;
		iconP1.flipX = true; // fuck you
		iconP1.zIndex = 15;
		uiGroup.add(iconP1);
		iconP2 = new HealthIcon(0, 0, player2?.healthIcon ?? 'face');
		iconP2.origin.x = iconP2.width;
		iconP2.zIndex = 15;
		uiGroup.add(iconP2);
		
		scoreTxt = new FlxText(0, FlxG.height - 25, FlxG.width, 'Score: idk');
		scoreTxt.setFormat(Paths.ttf('vcr'), 16, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		scoreTxt.y -= scoreTxt.height * .5;
		scoreTxt.borderSize = 1.25;
		uiGroup.add(scoreTxt);
		updateRating();
		debugTxt = new FlxText(0, 12, FlxG.width, '');
		debugTxt.setFormat(Paths.ttf('vcr'), 16, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		uiGroup.add(debugTxt);

		if (Options.data.downscroll) {
			for (mem in uiGroup)
				mem.y = FlxG.height - mem.y - mem.height;
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
		
		hscripts.run('createPost');
		sortZIndex();
	}

	override public function update(elapsed:Float) {
		elapsed = getRealElapsed();
		hscripts.run('updatePre', [elapsed, paused]);

		if (FlxG.keys.justPressed.ESCAPE) {
			FlxG.switchState(() -> new FreeplayState());
			return;
		}
		
		if (FlxG.keys.pressed.SHIFT) {
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
				conductorInUse.metronome.setBeat(-5);
				resetScore();
			}
			if (FlxG.keys.justPressed.B) {
				playerStrumline.allowInput = !playerStrumline.allowInput;
				playerStrumline.cpu = !playerStrumline.cpu;
				updateScoreText();
			}
			if (FlxG.keys.justPressed.RIGHT) {
				conductorInUse.songPosition += 2000;
				song.inst.time = conductorInUse.songPosition + 2000;
				syncMusic(false, true);
			}
			if (FlxG.keys.justPressed.LEFT) {
				conductorInUse.songPosition -= 2000;
				song.inst.time = conductorInUse.songPosition - 2000;
				syncMusic(false, true);
			}
		}
		
		if (FlxG.keys.justPressed.Z) {
			var strumlineY:Float = 50;
			Options.data.downscroll = !Options.data.downscroll;
			if (Options.data.downscroll) strumlineY = FlxG.height - opponentStrumline.receptorHeight - strumlineY;
			for (strumline in [opponentStrumline, playerStrumline]) {
				strumline.direction += 180;
				strumline.y = strumlineY;
			}
		}
		if (FlxG.keys.justPressed.ENTER) {
			paused = !paused;
			var pauseVocals:Bool = (paused || conductorInUse.songPosition < 0);
			if (pauseVocals) {
				song.inst.pause();
				for (track in syncVocals) track.pause();
			} else {
				if (song.instLoaded) song.inst.play(true, conductorInUse.songPosition);
				for (track in syncVocals) track.play(true, conductorInUse.songPosition);
				syncMusic(false, true);
			}
			FlxTimer.globalManager.forEach((timer:FlxTimer) -> { if (!timer.finished) timer.active = !paused; });
			FlxTween.globalManager.forEach((tween:FlxTween) -> { if (!tween.finished) tween.active = !paused; });
		}
		
		DiscordRPC.update();
		super.update(elapsed);
		hscripts.run('update', [elapsed, paused]);

		if (paused) {
			hscripts.run('updatePost', [elapsed, true]);
			return;
		}

		iconP1.updateBop(elapsed);
		iconP2.updateBop(elapsed);
		iconP1.setPosition(healthBar.barCenter.x + 60 - iconP1.width * .5, healthBar.barCenter.y - iconP1.height * .5);
		iconP2.setPosition(healthBar.barCenter.x - 60 - iconP2.width * .5, healthBar.barCenter.y - iconP2.height * .5);
		
		syncMusic();
		
		var limit:Int = 50; //avoid lags
		while (events.length > 0 && conductorInUse.songPosition >= events[0].msTime && limit > 0) {
			var event:SongEvent = events.shift();
			triggerEvent(event);
			limit --;
		}
		
		hscripts.run('updatePost', [elapsed, false]);
		
		if (conductorInUse.songPosition >= song.songLength && !conductorInUse.paused) {
			finishSong();
		}
	}

	public function finishSong() {
		var result:Dynamic = hscripts.run('finishSong');
		if (result == HScript.STOP) {
			conductorInUse.paused = true;
			return;
		}
		FlxG.switchState(() -> new FreeplayState());
	}
	
	public function syncMusic(forceSongpos:Bool = false, forceTrackTime:Bool = false) {
		if (song.instLoaded && song.inst.playing) {
			if ((forceSongpos && conductorInUse.songPosition < song.inst.time) || Math.abs(song.inst.time - conductorInUse.songPosition) > 75)
				conductorInUse.songPosition = song.inst.time;
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
			return conductorInUse.songPosition;
	}

	public function pushedEvent(event:SongEvent) {
		hscripts.loadFromPaths('scripts/events/${event.name}.hx');
		
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
		hscripts.run('eventPushed', [event]);
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
				switch (params['ease']) {
					case 'CLASSIC':
					case 'INSTANT':
						camGame.snapToTarget();
					default:
						var duration:Float = Util.parseFloat(params['duration'], 4) * conductorInUse.stepCrochet * .001;
						if (duration <= 0) {
							camGame.snapToTarget();
							return;
						} else {
							var easeFunction:Null<Float -> Float> = Reflect.field(FlxEase, params['ease'] ?? 'linear');
							if (easeFunction == null) {
								Log.warning('FocusCamera event: ease function invalid');
								easeFunction = FlxEase.linear;
							}
							camGame.pauseFollowLerp = true;
							FlxTween.cancelTweensOf(camGame.scroll);
							FlxTween.tween(camGame.scroll, {x: camFocusTarget.x - FlxG.width * .5, y: camFocusTarget.y - FlxG.height * .5}, duration, {ease: easeFunction, onComplete: (_) -> {
								camGame.pauseFollowLerp = false;
							}});
						}
				}
			case 'ZoomCamera':
				var targetZoom:Float = Util.parseFloat(params['zoom'], 1);
				var direct:Bool = (params['mode'] ?? 'direct' == 'direct');
				targetZoom *= (direct ? FlxCamera.defaultZoom : (stage?.zoom ?? 1));
				camGame.zoomTarget = targetZoom;
				switch (params['ease']) {
					case 'INSTANT':
						camGame.zoom = targetZoom;
					default:
						var duration:Float = Util.parseFloat(params['duration'], 4) * conductorInUse.stepCrochet * .001;
						if (duration <= 0) {
							camGame.zoom = targetZoom;
						} else {
							var easeFunction:Null<Float -> Float> = Reflect.field(FlxEase, params['ease'] ?? 'linear');
							if (easeFunction == null) {
								Log.warning('FocusCamera event: ease function invalid');
								easeFunction = FlxEase.linear;
							}
							camGame.pauseZoomLerp = true;
							FlxTween.cancelTweensOf(camGame);
							FlxTween.tween(camGame, {zoom: targetZoom}, duration, {ease: easeFunction, onComplete: (_) -> {
								camGame.pauseZoomLerp = false;
							}});
						}
				}
			case 'SetCameraBop':
				var targetRate:Int = Util.parseInt(params['rate'], -1);
				var targetIntensity:Float = Util.parseFloat(params['intensity'], 1);
				hudZoomIntensity = targetIntensity * 2;
				camZoomIntensity = targetIntensity;
				camZoomRate = targetRate;
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
		hscripts.run('eventTriggered', [event]);
	}
	public function focusOnCharacter(chara:Character) {
		if (chara != null) {
			camFocusTarget.x = chara.getMidpoint().x + chara.cameraOffset.x;
			camFocusTarget.y = chara.getMidpoint().y + chara.cameraOffset.y;
		}
	}
	
	public function stepHitEvent(step:Int) {
		syncMusic(true);
		hscripts.run('stepHit', [step]);
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
		if (camZoomRate > 0 && beat % camZoomRate == 0)
			bopCamera();
		if (beat == 0) {
			if (song.instLoaded) song.inst.play(true);
			for (track in syncVocals) track.play(true);
			syncMusic(true, true);
		}
		hscripts.run('beatHit', [beat]);
	}
	public function popCountdown(image:String) {
		var pop = new FunkinSprite().loadTexture(image);
		pop.camera = camHUD;
		pop.screenCenter();
		add(pop);
		FlxTween.tween(pop, {alpha: 0}, conductorInUse.crochet * .001, {ease: FlxEase.cubeInOut, onComplete: (tween:FlxTween) -> {
			remove(pop);
			pop.destroy();
		}});
		hscripts.run('countdownTick', [image]);
	}
	public function barHitEvent(bar:Int) {
		if (camZoomRate < 0)
			bopCamera();
		hscripts.run('barHit', [bar]);
	}
	public function bopCamera() {
		camHUD.zoom += .015 * hudZoomIntensity;
		camGame.zoom += .015 * camZoomIntensity;
	}
	
	public function keyPressEvent(event:KeyboardEvent) {
		var key:FlxKey = event.keyCode;
		if (!heldKeys.contains(key)) heldKeys.push(key);
		
		if (inputDisabled || paused) return;
		if (FlxG.keys.checkStatus(key, JUST_PRESSED)) {
			var keybind:Int = Controls.keybindFromArray(keybinds, key);
			var oldTime:Float = conductorInUse.songPosition;
			conductorInUse.songPosition = getSongPos();

			hscripts.run('keyPressed', [key]);
			if (keybind >= 0) {
				hscripts.run('keybindPressed', [keybind]);
				playerStrumline.fireInput(key, true);
			}

			conductorInUse.songPosition = oldTime;
		}
	}
	public function keyReleaseEvent(event:KeyboardEvent) {
		var key:FlxKey = event.keyCode;
		heldKeys.remove(key);
		
		if (inputDisabled || paused) return;
		var keybind:Int = Controls.keybindFromArray(keybinds, key);

		hscripts.run('keyReleased', [key]);
		if (keybind >= 0) {
			hscripts.run('keybindReleased', [keybind]);
			playerStrumline.fireInput(key, false);
		}
	}

	public function playerNoteEvent(e:Lane.NoteEvent) {
		e.targetCharacter = player1;
		if (e.type == Lane.NoteEventType.GHOST && Options.data.ghostTapping) {
			e.playAnimation = false;
			e.applyRating = false;
			e.playSound = false;
		}

		hscripts.run('playerNoteEventPre', [e]);
		try e.dispatch()
		catch (e:haxe.Exception) Log.error('error dispatching note event -> ${e.message}');
		hscripts.run('playerNoteEvent', [e]);
	}
	public function opponentNoteEvent(e:Lane.NoteEvent) {
		e.targetCharacter = player2;
		e.applyRating = false;
		e.playSound = false;
		e.doSplash = false;
		e.doSpark = false;

		hscripts.run('opponentNoteEventPre', [e]);
		try e.dispatch()
		catch (e:haxe.Exception) Log.error('error dispatching note event -> ${e.message}');
		hscripts.run('opponentNoteEvent', [e]);
	}
	public dynamic function comboBroken(oldCombo:Int) {
		popCombo(0);
		var result:Dynamic = hscripts.run('comboBroken');
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
		for (i => num in nums) {
			var popNum:FunkinSprite = popRating('num$num', .5, 2);
			popNum.setPosition(popNum.x + (i + xOffset) * 43, popNum.y + 80);
			popNum.acceleration.y = FlxG.random.int(200, 300);
			popNum.velocity.y = -FlxG.random.int(140, 160);
			popNum.velocity.x = FlxG.random.float(-5, 5);
		}
	}
	public function popRating(ratingString:String, scale:Float = .7, beats:Float = 1) {
		var rating:FunkinSprite = new FunkinSprite(0, 0);
		rating.loadTexture(ratingString);
		rating.scale.set(scale, scale);
		rating.setOffset(rating.frameWidth * .5, rating.frameHeight * .5);

		rating.acceleration.y = 550;
		rating.velocity.y = -FlxG.random.int(140, 175);
		rating.velocity.x = FlxG.random.int(0, 10);

		ratingGroup.add(rating);
		FlxTween.tween(rating, {alpha: 0}, .2, {onComplete: (tween:FlxTween) -> {
			ratingGroup.remove(rating, true);
			rating.destroy();
		}, startDelay: conductorInUse.crochet * .001 * beats});
		return rating;
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
		updateScoreText();
	}
	public function updateScoreText() {
		var scoreStr:String = Util.thousandSep(Std.int(score));
		if (Options.data.xtendScore) {
			var accuracyString:String = 'NA';
			if (totalNotes > 0) accuracyString = Util.padDecimals(percent, 2);
			if (playerStrumline.cpu) accuracyString = 'BOT';
			scoreTxt.text = '$accuracyString% | Misses: $misses | Score: $scoreStr';
		} else {
			scoreTxt.text = 'Score: $scoreStr';
			if (playerStrumline.cpu) scoreTxt.text = '(BOT) ${scoreTxt.text}';
		}
		hscripts.run('updateScoreText');
	}
	public function set_combo(newCombo:Int) {
		if (combo > 0 && newCombo == 0) comboBroken(combo);
		return combo = newCombo;
	}
	
	override public function destroy() {
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, keyPressEvent);
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_UP, keyReleaseEvent);
		Main.watermark.visible = true;
		conductorInUse.paused = false;
		super.destroy();
	}
}