package funkin.states;

import openfl.events.KeyboardEvent;
import flixel.input.keyboard.FlxKey;
import flixel.util.FlxSignal.FlxTypedSignal;

import funkin.backend.scripting.HScript;
import funkin.backend.play.ScoreHandler;
import funkin.backend.play.IPlayEvent;
import funkin.backend.play.SongEvent;
import funkin.backend.play.NoteEvent;
import funkin.backend.play.Scoring;
import funkin.backend.play.Chart;
import funkin.objects.CharacterGroup;
import funkin.objects.Character;
import funkin.objects.play.Note;
import funkin.objects.play.*;
import funkin.objects.*;

using StringTools;

class PlayState extends FunkinState {
	public var player1:CharacterGroup;
	public var player2:CharacterGroup;
	public var player3:CharacterGroup;
	
	public var stage:Stage;
	public var curStage:String;
	public var simpleBG:FunkinSprite;
	
	public var healthBar:Bar;
	public var scoreTxt:FlxText;
	public var iconP1:HealthIcon;
	public var iconP2:HealthIcon;
	
	public var playerStrumline:Strumline;
	public var opponentStrumline:Strumline;
	public var uiGroup:FunkinSpriteGroup;
	public var ratingGroup:FunkinTypedSpriteGroup<FunkinSprite>;
	public var strumlineGroup:FunkinTypedSpriteGroup<Strumline>;
	
	public var singAnimations:Array<String> = ['LEFT', 'DOWN', 'UP', 'RIGHT'];
	public var keybinds:Array<Array<FlxKey>> = [];
	public var heldKeys:Array<FlxKey> = [];
	public var pauseDisabled:Bool = false;
	public var inputDisabled:Bool = false;
	public var playCountdown:Bool = true;
	public var autoUpdateRPC:Bool = true;
	
	public var camHUD:FunkinCamera;
	public var camGame:FunkinCamera;
	public var camOther:FunkinCamera;
	public var camFocusTarget:FlxObject;
	public var spotlight(default, set):Null<FlxSprite>;
	
	public var camZoomRate:Int = -1; // 0: no bop - <0: every measure (always)
	public var camZooming:Bool = true;
	public var camZoomIntensity:Float = 1;
	public var hudZoomIntensity:Float = 2;
	
	public static var chart:Chart = null;
	public var notes:Array<ChartNote> = [];
	public var songName:String;
	public var simple:Bool;
	
	public var scoring:ScoreHandler = new ScoreHandler(EMI);
	@:isVar public var score(get, set):Float = 0;
	@:isVar public var misses(get, set):Int = 0;
	@:isVar public var combo(get, set):Int = 0;
	public var accuracy(get, null):Float = 0;
	public var ghostTapping:Bool;
	
	public var maxHealth(default, set):Float = 1;
	public var health(default, dynamic):Float = .5;
	public var totalNotes:Int = 0;
	public var totalHits:Int = 0;
	public var dead:Bool = false;
	public var gameOver:GameOverSubState;
	
	public var genericVocals:FunkinSound;
	public var music:FunkinSoundGroup;
	public var hitsound:FunkinSound;
	
	public var godmode:Bool;
	public var downscroll:Bool;
	public var middlescroll:Bool;
	
	public var songStarted:Bool = false;
	public var songFinished:Bool = false;
	
	public function new(chart:Chart, simple:Bool = false) {
		PlayState.chart = chart ?? PlayState.chart ?? new Chart('');
		PlayState.chart.instLoaded = false;
		this.simple = simple;
		scoring.onComboChange.add((newCombo:Int) -> {
			if (newCombo <= 0) {
				if (scoring.combo > 0)
					comboBroken(scoring.combo);
			} else {
				popCombo(newCombo);
				
				if (stage != null) {
					for (chara in stage.characters)
						chara.playComboAnimation(newCombo);
				}
			}
		});
		super();
	}
	
	override public function create() {
		super.create();
		
		godmode = false; // practice mode?
		downscroll = Options.data.downscroll;
		middlescroll = Options.data.middlescroll;
		ghostTapping = Options.data.ghostTapping;
		
		conductorInUse = new Conductor();
		conductorInUse.tempoChanges = chart.tempoChanges;
		barHit.add((t:Int) -> dispatchSongEvent({type: BAR_HIT, time: t}));
		beatHit.add((t:Int) -> dispatchSongEvent({type: BEAT_HIT, time: t}));
		stepHit.add((t:Int) -> dispatchSongEvent({type: STEP_HIT, time: t}));
		
		hitsound = FunkinSound.load(Paths.sound('gameplay/hitsounds/hitsound'), .7);
		music = new FunkinSoundGroup();
		songName = chart.name;
		
		@:privateAccess FlxG.cameras.defaults.resize(0);
		camOther = new FunkinCamera();
		camGame = new FunkinCamera();
		camHUD = new FunkinCamera();
		camHUD.bgColor.alpha = 0;
		camGame.bgColor.alpha = 0;
		camOther.bgColor.alpha = 0;
		FlxG.cameras.add(camGame, true);
		FlxG.cameras.add(camHUD, false);
		FlxG.cameras.add(camOther, false);
		
		camFocusTarget = new FlxObject(0, FlxG.height * .5);
		camGame.follow(camFocusTarget, LOCKON, 3);
		add(camFocusTarget);
		
		camGame.zoomFollowLerp = camHUD.zoomFollowLerp = 3;
		
		uiGroup = new FunkinSpriteGroup();
		uiGroup.cameras = [camHUD];
		uiGroup.zIndex = 75;
		add(uiGroup);
		strumlineGroup = new FunkinTypedSpriteGroup();
		strumlineGroup.cameras = [camHUD];
		strumlineGroup.zIndex = 100;
		add(strumlineGroup);
		ratingGroup = new FunkinTypedSpriteGroup();
		
		// the good stuff
		if (!simple) {
			var loadedEvents:Array<String> = [];
			var noteKinds:Array<String> = [];
			for (note in chart.notes) {
				notes.push(note.copy());
				var noteKind:String = note.kind;
				if (noteKind.trim() != '' && !noteKinds.contains(noteKind)) {
					hscripts.loadFromPaths('scripts/notekinds/$noteKind.hx');
					noteKinds.push(noteKind);
				}
			}
			for (event in chart.events) {
				var eventName:String = event.name;
				if (!loadedEvents.contains(eventName)) {
					loadedEvents.push(eventName);
					hscripts.loadFromPaths('scripts/events/$eventName.hx');
				}
			}
			
			hscripts.loadFromFolder('scripts/global');
			hscripts.loadFromFolder('scripts/songs/${chart.path}');
		}
		
		if (!simple) {
			stage = new Stage(chart);
			stage.setup(chart.stage);
			add(stage);
			
			Paths.library = stage.library;
			player1 = stage.getCharacter('bf');
			player2 = stage.getCharacter('dad');
			player3 = stage.getCharacter('gf');
			
			focusOnCharacter((player3 ?? player1).current);
		} else {
			camFocusTarget.setPosition(FlxG.width * .5, FlxG.height * .5);
			simpleBG = new FunkinSprite().loadTexture('mainmenu/bgGreen');
			simpleBG.setGraphicSize(simpleBG.width * 1.1);
			simpleBG.scrollFactor.set();
			simpleBG.zoomFactor = 0;
			simpleBG.updateHitbox();
			simpleBG.screenCenter();
			add(simpleBG);
		}
		camGame.zoomTarget = stage?.zoom ?? 1;
		camHUD.zoomTarget = 1;
		camGame.snapToTarget();
		
		chart.loadMusic('data/songs/${chart.path}/', false);
		if (!chart.instLoaded) chart.loadMusic('songs/${chart.path}/', false);
		if (chart.instLoaded) {
			music.add(chart.inst);
			music.syncBase = chart.inst;
			music.onSoundFinished.add((snd:FunkinSound) -> {
				if (snd == music.syncBase)
					finishSong();
			});
			conductorInUse.syncTracker = chart.inst;
		} else {
			Log.warning('chart instrumental not found...');
			Log.minor('verify paths:');
			Log.minor('- songs/${chart.path}/${Util.pathSuffix('Inst', chart.audioSuffix)}.ogg');
			Log.minor('- data/songs/${chart.path}/${Util.pathSuffix('Inst', chart.audioSuffix)}.ogg');
		}
		loadVocals(chart.path, chart.audioSuffix);
		
		var scrollDir:Float = (Options.data.downscroll ? 270 : 90);
		var strumlineBound:Float = (FlxG.width - 300) * .5;
		var strumlineY:Float = 50;
		
		keybinds = Options.data.keybinds['4k'];
		
		opponentStrumline = new Strumline(4, scrollDir, chart.scrollSpeed);
		opponentStrumline.fitToSize(strumlineBound, opponentStrumline.height * .7);
		opponentStrumline.noteEvent.add(opponentNoteEvent);
		opponentStrumline.setPosition(50, strumlineY);
		opponentStrumline.zIndex = 40;
		opponentStrumline.cpu = true;
		opponentStrumline.allowInput = false;
		
		playerStrumline = new Strumline(4, scrollDir, chart.scrollSpeed * 1.08);
		playerStrumline.fitToSize(strumlineBound, playerStrumline.height * .7);
		playerStrumline.setPosition(FlxG.width - playerStrumline.width - 50 - 75, strumlineY);
		playerStrumline.noteEvent.add(playerNoteEvent);
		playerStrumline.assignKeybinds(keybinds);
		playerStrumline.zIndex = 50;
		
		strumlineGroup.insert(0, playerStrumline);
		strumlineGroup.insert(0, opponentStrumline);
		
		if (middlescroll) {
			playerStrumline.screenCenter(X);
			opponentStrumline.fitToSize(playerStrumline.leftBound - 50 - opponentStrumline.leftBound, 0, Y);
		}
		for (note in notes) {
			var strumline:Strumline = strumlineGroup.members[note.strumlineIndex];
			strumline?.queueNote(note);
		}
		
		ratingGroup.setPosition(player3?.getMidpoint()?.x ?? FlxG.width * .5, player3?.getMidpoint()?.y ?? FlxG.height * .5);
		if (stage != null) {
			ratingGroup.zIndex = Util.getHighestZIndex(stage.characters, 50) + 5;
			stage.insertZIndex(ratingGroup);
		} else {
			ratingGroup.scrollFactor.set();
			ratingGroup.zoomFactor = 0;
			ratingGroup.zIndex = 50;
			add(ratingGroup);
		}
		
		// TODO: figure out how to display the correct icons in simple mode maybe? they just display the placeholder face
		healthBar = new Bar(0, FlxG.height - 50, (_) -> health, 'healthBar');
		healthBar.bounds.max = maxHealth;
		healthBar.y -= healthBar.height;
		healthBar.screenCenter(X);
		healthBar.zIndex = 10;
		uiGroup.add(healthBar);
		iconP1 = new HealthIcon(0, 0, player1?.healthIconData, true);
		iconP1.origin.x = 0;
		iconP1.zIndex = 20;
		uiGroup.add(iconP1);
		iconP2 = new HealthIcon(0, 0, player2?.healthIconData, false);
		iconP2.origin.x = iconP2.frameWidth;
		iconP2.zIndex = 15;
		uiGroup.add(iconP2);
		
		if (player1 != null) {
			player1.onCharacterChanged.add((name:String, char:Character) -> {
				matchIconData(iconP1, char);
				if (spotlight == player1.current)
					focusOnCharacter(char);
			});
			player2.onCharacterChanged.add((name:String, char:Character) -> {
				matchIconData(iconP2, char);
				if (spotlight == player2.current)
					focusOnCharacter(char);
			});
		}
		
		scoreTxt = new FlxText(0, FlxG.height - 25, FlxG.width, 'Score: idk');
		scoreTxt.setFormat(Paths.ttf('vcr'), 16, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		scoreTxt.y -= scoreTxt.height * .5;
		scoreTxt.borderSize = 1.25;
		scoreTxt.zIndex = 30;
		uiGroup.add(scoreTxt);
		
		for (i in 0...4)
			Paths.sound('gameplay/hitsounds/miss$i');
		Paths.sound('gameplay/hitsounds/hitsoundTail');
		Paths.sound('gameplay/hitsounds/hitsoundFail');
		
		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, keyPressEvent);
		FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, keyReleaseEvent);
		
		refreshRPCTitle();
		
		for (event in chart.events)
			dispatchSongEvent({type: PUSH_EVENT, chartEvent: event});
		
		if (downscroll)
			flipUI();
		
		hscripts.run('createPost');
		
		uiGroup.sortZIndex();
		stage?.sortZIndex();
		updateScoreText();
		sortZIndex();
		
		if (playCountdown) {
			for (strumline in strumlineGroup)
				strumline.visible = false;
			
			for (tick in ['THREE', 'TWO', 'ONE', 'GO']) {
				Paths.sound('gameplay/countdown/funkin/intro$tick');
				Paths.image(tick);
			}
		}
		beginCountdown();
		update(0);
	}
	function flipUI() {
		for (mem in uiGroup)
			mem.y = FlxG.height - mem.y - mem.height;
		for (mem in strumlineGroup)
			mem.y = FlxG.height - mem.y - mem.height;
	}
	function matchIconData(?icon:HealthIcon, ?char:Character) {
		if (icon == null || char == null) return;
		
		icon.iconData = char.healthIconData;
		
		iconP1.origin.x = 0;
		iconP2.origin.x = iconP2.frameWidth;
	}
	
	public function loadVocals(path:String, audioSuffix:String = '') {
		var thingArray:Array<Array<Dynamic>> = [[player1, chart.player1], [player2, chart.player2], [player3, chart.player3]];
		var pushedSounds:Array<openfl.media.Sound> = []; // dont add the same sound twice lol
		var vocalsSounds:Array<FunkinSound> = [];
		
		for (obj in thingArray) {
			for (item in obj) { // yeah, this is a little convoluted now...
				if (item == null) continue;
				
				if (Std.isOfType(item, CharacterGroup)) {
					var char:Character = cast(item, CharacterGroup).current;
					if (char?.loadVocals(chart.path, chart.audioSuffix)) {
						@:privateAccess var snd:openfl.media.Sound = char.vocals._sound;
						if (pushedSounds.contains(snd)) continue;
						vocalsSounds.push(char.vocals);
						pushedSounds.push(snd);
						break;
					}
				} else {
					var sound:openfl.media.Sound = Character.getVocals(chart.path, chart.audioSuffix, item);
					if (sound != null && !pushedSounds.contains(sound)) {
						vocalsSounds.push(FunkinSound.load(sound));
						pushedSounds.push(sound);
						break;
					}
				}
			}
		}
		if (vocalsSounds.length == 0) {
			var sound:openfl.media.Sound = Character.getVocals(chart.path, chart.audioSuffix, '');
			if (sound != null) {
				genericVocals = FunkinSound.load(sound);
				vocalsSounds.push(genericVocals);
			} else {
				Log.warning('song vocals not found...');
			}
		}
		for (sound in vocalsSounds) {
			sound.volume = 0;
			sound.play().stop();
			sound.volume = 1;
			music.add(sound);
		}
	}

	override public function update(elapsed:Float) {
		if (FlxG.keys.justPressed.ESCAPE) {
			FlxG.switchState(FreeplayState.new);
			return;
		} else if (FlxG.keys.justPressed.SEVEN) {
			// FlxG.switchState(() -> new CharterState(chart));
			return;
		}
		
		if (FlxG.keys.pressed.SHIFT) {
			if (FlxG.keys.justPressed.R) {
				for (strumline in strumlineGroup) {
					strumline.visible = false;
					strumline.resetLanes();
				}
				
				events.resize(0);
				for (note in notes) {
					var strumline:Strumline = strumlineGroup.members[note.strumlineIndex];
					strumline?.queueNote(note);
				}
				for (event in chart.events)
					events.push(event);
				music.pause();
				music.time = 0;
				resetConductor();
				beginCountdown();
				resetScore();
				
				refreshRPCTitle();
				refreshRPCTime();
			}
			if (FlxG.keys.justPressed.B) {
				playerStrumline.allowInput = !playerStrumline.allowInput;
				playerStrumline.cpu = !playerStrumline.cpu;
				updateScoreText();
			}
			if (FlxG.keys.justPressed.RIGHT) {
				conductorInUse.songPosition += 3000;
				chart.inst.time = conductorInUse.songPosition;
				syncMusic(false, true);
			}
			if (FlxG.keys.justPressed.LEFT) {
				conductorInUse.songPosition -= 3000;
				chart.inst.time = conductorInUse.songPosition;
				syncMusic(false, true);
			}
			if (FlxG.keys.justPressed.Z) {
				downscroll = !downscroll;
				for (strumline in strumlineGroup)
					strumline.direction += 180;
				
				flipUI();
			}
		} else if (!dead) {
			if (FlxG.keys.justPressed.ENTER && !pauseDisabled) {
				paused = !paused;
				var pauseVocals:Bool = (paused || conductorInUse.songPosition < 0);
				if (pauseVocals) {
					music.pause();
				} else {
					music.play(true, conductorInUse.songPosition);
					syncMusic(false, true);
				}
				FlxTimer.globalManager.forEach((timer:FlxTimer) -> { if (!timer.finished) timer.active = !paused; });
				FlxTween.globalManager.forEach((tween:FlxTween) -> { if (!tween.finished) tween.active = !paused; });

				refreshRPCTitle();
				refreshRPCTime();
			}
			
			if (FlxG.keys.justPressed.R && !paused)
				die();
		}
		
		hscripts.run('update', [elapsed, paused, false]); // last argument is for Game over screen
		
		if (paused) {
			hscripts.run('updatePost', [elapsed, true, false]);
			return;
		}
		
		if (iconP1.autoUpdatePosition) {
			iconP1.offset.x = 0;
			iconP1.setPosition(healthBar.barCenter.x + 60 - iconP1.width * .5, healthBar.barCenter.y - iconP1.height * .5);
		}
		if (iconP2.autoUpdatePosition) {
			iconP2.offset.x = iconP2.frameWidth;
			iconP2.setPosition(healthBar.barCenter.x - 60 + iconP2.width * .5, healthBar.barCenter.y - iconP2.height * .5);
		}
		super.update(elapsed);
		
		syncMusic();
		
		hscripts.run('updatePost', [elapsed, false, false]);
		
		if (!chart.instLoaded && !songFinished && conductorInUse.songPosition >= chart.songLength && !conductorInUse.paused)
			finishSong();
	}
	override public function draw() {
		hscripts.run('draw');
		super.draw();
		hscripts.run('drawPost');
	}
	
	public function stepHitEvent(step:Int) {
		syncMusic(true);
		hscripts.run('stepHit', [step]);
	}
	public function beatHitEvent(beat:Int) {
		if (playCountdown) {
			switch (beat) {
				case -4:
					dispatchSongEvent({type: START_COUNTDOWN, countdown: 'THREE'});
					dispatchSongEvent({type: TICK_COUNTDOWN, countdown: 'THREE'});
				case -3:
					dispatchSongEvent({type: TICK_COUNTDOWN, countdown: 'TWO'});
				case -2:
					dispatchSongEvent({type: TICK_COUNTDOWN, countdown: 'ONE'});
				case -1:
					dispatchSongEvent({type: TICK_COUNTDOWN, countdown: 'GO'});
				default:
			}
		}
		if (beat >= 0 && !songStarted)
			dispatchSongEvent({type: SONG_START});
		
		if (DiscordRPC.supported && music.playing && DiscordRPC.presence.endTimestamp.toInt() == 0)
			refreshRPCTime();
		if (camZoomRate > 0 && beat % camZoomRate == 0)
			bopCamera();
		
		iconP1.bop();
		iconP2.bop();
		if (stage != null)
			stage.beatHit(beat);
		
		hscripts.run('beatHit', [beat]);
	}
	public function barHitEvent(beat:Int) {
		if (camZoomRate < 0)
			bopCamera();
		
		hscripts.run('barHit', [beat]);
	}
	
	public function syncMusic(forceSongpos:Bool = false, forceTrackTime:Bool = false) {
		var syncBase:FlxSound = conductorInUse.syncTracker;
		if (syncBase != null && syncBase.playing && !conductorInUse.paused) {
			if ((forceSongpos && conductorInUse.songPosition < syncBase.time) || Math.abs(syncBase.time - conductorInUse.songPosition) > 75)
				conductorInUse.songPosition = syncBase.time;
			if (forceTrackTime) {
				if (Math.abs(music.getDisparity(syncBase.time)) > 75)
					music.syncToBase();
				refreshRPCTime();
			}
		}
	}
	
	public function focusOnCharacter(chara:Character, center:Bool = false) {
		if (chara != null) {
			camFocusTarget.x = chara.getMidpoint().x + chara.cameraOffset.x + (center ? 0 : chara.stageCameraOffset.x);
			camFocusTarget.y = chara.getMidpoint().y + chara.cameraOffset.y + (center ? 0 : chara.stageCameraOffset.y);
			spotlight = chara;
		}
	}
	function set_spotlight(?newSprite:FlxSprite):Null<FlxSprite> {
		if (spotlight == newSprite) return newSprite;
		
		dispatchSongEvent({type: CHANGE_SPOTLIGHT, sprite: newSprite});
		return spotlight = newSprite;
	}
	
	// TODO: ok, maybe these could be in a single function
	public function refreshRPCTime() {
		if (!DiscordRPC.supported || !autoUpdateRPC)
			return;
		
		if (music.playing) {
			var beginTime:Float = Date.now().getTime() - music.time;
			var endTime:Float = beginTime + chart.songLength;
			DiscordRPC.presence.endTimestamp = Std.int(endTime * .001);
			DiscordRPC.presence.startTimestamp = Std.int(beginTime * .001);
			// trace('PLAYING SONG FROM ' + Std.int(beginTime * .001) + ' to ' + Std.int(endTime * .001));
		} else {
			DiscordRPC.presence.startTimestamp = DiscordRPC.presence.endTimestamp = 0;
		}
		DiscordRPC.dirty = true;
	}
	public function refreshRPCTitle() {
		if (!DiscordRPC.supported || !autoUpdateRPC)
			return;
		
		var detailsText:String = '${chart.name} on ${chart.difficulty.toUpperCase()}';
		if (paused)
			detailsText += ' (Paused)';
		DiscordRPC.details = detailsText;
		refreshRPCDetails();
	}
	public function refreshRPCDetails() {
		if (!DiscordRPC.supported || !autoUpdateRPC)
			return;
		
		var detailsString:String;
		if (dead) {
			detailsString = 'Dead!';
		} else if (scoring != null) {
			var scoreStr:String = Std.string(Std.int(scoring.score));
			scoreStr = scoreStr.lpad('0', 6);
			
			if (playerStrumline.cpu) {
				detailsString = 'Botplay';
			} else {
				var accuracyString:String = '';
				var missString:String = '';
				if (totalNotes > 0)
					accuracyString = ' (${Util.padDecimals(accuracy, 2)}%)';
				if (scoring.misses > 0)
					missString = ' ${scoring.misses} ${scoring.misses == 1 ? 'miss' : 'misses'}';

				detailsString = '$scoreStr$accuracyString$missString';
			}
			
		} else {
			detailsString = '';
		}
		
		DiscordRPC.state = detailsString;
	}
	
	inline public function dispatchSongEvent(e:SongEvent) dispatchPlayEvent('songEvent', e);
	public function dispatchPlayEvent(funcName:String, e:IPlayEvent) {
		runAllHScript('${funcName}Pre', [e]);
		
		try e.dispatch()
		catch (e:haxe.Exception) Log.error('error dispatching event -> ${e.message}');
		
		runAllHScript(funcName, [e]);
	}
	public function beginCountdown() {
		songStarted = false;
		conductorInUse.beat = (playCountdown ? -5 : -1);
	}
	public function finishSong() {
		songFinished = true;
		dispatchSongEvent({type: SONG_FINISH});
	}
	public function popCountdown(image:String):FunkinSprite {
		if (Paths.image(image) == null)
			return null;
		
		var pop = new FunkinSprite().loadTexture(image);
		pop.camera = camHUD;
		pop.screenCenter();
		add(pop);
		FlxTween.tween(pop, {alpha: 0}, conductorInUse.crochet * .001, {ease: FlxEase.cubeInOut, onComplete: (tween:FlxTween) -> {
			remove(pop);
			pop.destroy();
		}});
		return pop;
	}
	public function bopCamera() {
		if (!camZooming)
			return;
		if (!camHUD.pauseZoomLerp)
			camHUD.zoom += .015 * hudZoomIntensity;
		if (!camGame.pauseZoomLerp)
			camGame.zoom += .015 * camZoomIntensity;
	}
	function runAllHScript(func:String, ?args:Array<Dynamic>):Bool {
		var canContinue = true;
		
		canContinue = (canContinue && !HScript.stopped(hscripts.run(func, args)));
		for (chara in stage.characters) {
			if (chara == null || !chara.exists || !chara.alive) continue;
			
			var current:Character = chara.current;
			if (current != null)
				canContinue = (canContinue && !HScript.stopped(current.hscripts.run(func, args)));
		}
		
		return canContinue;
	}
	
	public function keyPressEvent(event:KeyboardEvent) {
		var key:FlxKey = event.keyCode;
		var justPressed:Bool = !heldKeys.contains(key);
		if (justPressed)
			heldKeys.push(key);
		
		if (HScript.stopped(hscripts.run('keyPressed', [key, justPressed])) || inputDisabled || paused) return;
		if (justPressed) {
			var keybind:Int = Controls.keybindFromArray(keybinds, key);
			var oldTime:Float = conductorInUse.songPosition;
			var newTimeMaybe:Float = conductorInUse.syncTracker?.time ?? oldTime;
			if (conductorInUse.syncTracker != null && conductorInUse.syncTracker.playing)
				conductorInUse.songPosition = newTimeMaybe; // too rigged? (Math.abs(newTimeMaybe) < Math.abs(oldTime) ? newTimeMaybe : oldTime);
			
			if (keybind >= 0) {
				if (!HScript.stopped(hscripts.run('keybindPressed', [keybind, key]))) {
					for (strumline in strumlineGroup)
						strumline.fireInput(key, true);
				}
			}
			
			conductorInUse.songPosition = oldTime;
		}
	}
	public function keyReleaseEvent(event:KeyboardEvent) {
		var key:FlxKey = event.keyCode;
		heldKeys.remove(key);
		
		if (HScript.stopped(hscripts.run('keyReleased', [key])) || inputDisabled || paused) return;
		var keybind:Int = Controls.keybindFromArray(keybinds, key);

		if (keybind >= 0) {
			var result:Dynamic = hscripts.run('keybindReleased', [keybind, key]);
			for (strumline in strumlineGroup)
				strumline.fireInput(key, false);
		}
	}

	public function playerNoteEvent(e:NoteEvent) {
		e.targetCharacter = player1;
		e.doSplash = true;
		e.doSpark = true;
		
		if (e.type == NoteEventType.GHOST && ghostTapping) {
			e.playAnimation = false;
		} else {
			e.playSound = true;
			e.applyRating = true;
		}
		
		dispatchPlayEvent('playerNoteEvent', e);
	}
	public function opponentNoteEvent(e:NoteEvent) {
		e.targetCharacter = player2;
		e.applyRating = false;
		e.playSound = false;
		e.doSplash = false;
		e.doSpark = false;
		
		dispatchPlayEvent('opponentNoteEvent', e);
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
		var rating:FunkinSprite = ratingGroup.recycle(FunkinSprite, () -> new FunkinSprite());
		
		@:privateAccess ratingGroup.preAdd(rating);
		rating.loadTexture(ratingString);
		rating.scale.set(scale, scale);
		rating.offset.set(rating.frameWidth * .5, rating.frameHeight * .5);
		
		rating.revive();
		FlxTween.tween(rating, {alpha: 0}, .2, {onComplete: (tween:FlxTween) -> {
			ratingGroup.remove(rating, true);
			rating.kill();
		}, startDelay: conductorInUse.crochet * .001 * beats});
		return rating;
	}
	
	public function set_maxHealth(newHealth:Float) {
		healthBar.bounds.max = newHealth;
		healthBar.updateBars();
		health = health;
		return maxHealth = newHealth;
	}
	public dynamic function set_health(newHealth:Float) {
		newHealth = Util.clamp(newHealth, 0, maxHealth);
		switch (newHealth) {
			case (_ <= .15) => true:
				if (iconP1.autoUpdateState) iconP1.state = LOSING;
				if (iconP2.autoUpdateState) iconP2.state = WINNING;
			case (_ >= maxHealth - .15) => true:
				if (iconP1.autoUpdateState) iconP1.state = WINNING;
				if (iconP2.autoUpdateState) iconP2.state = LOSING;
			default:
				if (iconP1.autoUpdateState) iconP1.state = NEUTRAL;
				if (iconP2.autoUpdateState) iconP2.state = NEUTRAL;
		}
		if (newHealth <= 0 && !godmode && !dead)
			die(false);
		return health = newHealth;
	}
	public function die(instant:Bool = true) {
		if (HScript.stopped(hscripts.run('deathPre', [instant])))
			return;
		
		conductorInUse.paused = true;
		inputDisabled = true;
		dead = true;
		if (player1 != null) {
			focusOnCharacter(player1.current);
			player1.bop = false;
		}
		FlxTween.cancelTweensOf(camGame.scroll);
		FlxTween.cancelTweensOf(camGame);
		camGame.pauseFollowLerp = false;
		camGame.zoomOffset = 0;
		refreshRPCDetails();
		
		gameOver = new GameOverSubState(instant);
		function actuallyDie() {
			music.stop();
			camGame.zoomTarget = gameOver.cameraZoom * (stage?.zoom ?? 1);
			camGame.zoomFollowLerp = camGame.followLerp = 3;
			camGame.pauseZoomLerp = false;
			openSubState(gameOver);
		}
		
		if (instant) {
			actuallyDie();
		} else {
			camGame.followLerp = 10;
			camGame.pauseZoomLerp = true;
			
			final deathDuration:Float = .4;
			music.fadeOut(deathDuration);
			
			FlxTween.tween(camGame, {zoom: camGame.zoom + .3}, deathDuration, {ease: FlxEase.elasticOut, onComplete: (_) -> { actuallyDie(); }});
		}
	}
	
	function get_accuracy():Float { return scoring?.accuracy ?? 0; }
	function get_misses():Int { return scoring?.misses ?? 0; }
	function get_score():Float { return scoring?.score ?? 0; }
	function get_combo():Int { return scoring?.combo ?? 0; }
	
	function set_misses(newMisses:Int):Int {
		if (scoring != null)
			return scoring.misses = newMisses;
		return 0;
	}
	function set_score(newScore:Float):Float {
		if (scoring != null)
			return scoring.score = newScore;
		return 0;
	}
	function set_combo(newCombo:Int):Int {
		if (scoring != null)
			return scoring.combo = newCombo;
		return 0;
	}
	
	public function resetScore() {
		totalHits = totalNotes = 0;
		scoring?.reset();
		health = .5;
		updateScoreText();
	}
	public function updateScoreText() {
		if (HScript.stopped(hscripts.run('updateScoreText')))
			return;
		
		refreshRPCDetails();
		if (scoring != null) {
			var floorScore:Int = Std.int(scoring.score);
			var scoreStr:String = Util.thousandSep(floorScore);
			
			if (Options.data.xtendScore) {
				var accuracyString:String;
				
				if (playerStrumline.cpu) {
					accuracyString = 'BOT';
				} else {
					accuracyString = 'NA';
					if (totalNotes > 0)
						accuracyString = Util.padDecimals(accuracy, 2);
				}
				
				scoreTxt.text = '$accuracyString% | Misses: ${scoring.misses} | Score: $scoreStr';
			} else {
				scoreTxt.text = 'Score: $scoreStr';
				if (playerStrumline.cpu)
					scoreTxt.text = 'BOT ${scoreTxt.text}';
			}
		} else {
			scoreTxt.text = '';
		}
	}
	public dynamic function comboBroken(oldCombo:Int) {
		popCombo(0);
		
		if (stage != null) {
			for (chara in stage.characters)
				chara.playComboDropAnimation(scoring.combo);
		}
	}
	
	override public function destroy() {
		Paths.library = '';
		
		DiscordRPC.details = DiscordRPC.state = '';
		DiscordRPC.presence.startTimestamp = DiscordRPC.presence.endTimestamp = 0;
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, keyPressEvent);
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_UP, keyReleaseEvent);
		conductorInUse.paused = false;
		super.destroy();
	}
}