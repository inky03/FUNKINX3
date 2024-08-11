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
import Rating;
import Chloe;
import Lane;
import Note;
import Song;
import Bar;

class PlayState extends MusicBeatState {
	public var player1:Character;
	public var player2:Character;
	
	public var healthBar:Bar;
	public var scoreTxt:FlxText;
	public var opponentStrumline:Strumline;
	public var playerStrumline:Strumline;
	public var ratingGroup:FlxTypedGroup<Rating>;
	
	public var singAnimations:Array<String> = ['LEFT', 'DOWN', 'UP', 'RIGHT'];
	public var hitWindows:Array<HitWindow> = Scoring.emiDefault();
	public var keybinds:Array<Array<FlxKey>> = [];
	private var heldKeys:Array<FlxKey> = [];
	
	public var camHUD:FlxCamera;
	public var camOther:FlxCamera;
	public var camFocus:FlxObject;
	public var camFocusTarget:FlxPoint;
	
	public var song:Song;
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
	
	override public function create() {
		super.create();
		
		//FlxG.drawFramerate = 240;
		//FlxG.updateFramerate = 240;
		
		paused = true; //setup the freaking song
		
		var tempNotes:Array<Note> = [];
		song = Song.loadLegacySong('esculent', 'hard');
		for (event in song.events) events.push(event);
		Conductor.metronome.tempoChanges = song.tempoChanges;
		Conductor.metronome.setBeat(-5);
		
		camHUD = new FlxCamera();
		camOther = new FlxCamera();
		camHUD.bgColor.alpha = 0;
		camOther.bgColor.alpha = 0;
		FlxG.cameras.add(camHUD, false);
		FlxG.cameras.add(camOther, false);
		
		camFocusTarget = new FlxPoint(FlxG.width * .5, FlxG.height * .5);
		camFocus = new FlxObject(camFocusTarget.x, camFocusTarget.y, 1, 1);
		FlxG.camera.follow(camFocus, LOCKON, 1);
		add(camFocus);
		
		keybinds = Settings.data.keybinds['4k'];
		
		var strumlineBound:Float = (FlxG.width - 300) * .5;
		var strumlineY:Float = 50;
		
		player1 = new Character(700, 300);
		player1.loadAtlas('characters/BOYFRIEND');
		player1.animation.addByPrefix('idle', 'BF idle dance', 24, false);
		for (ani in singAnimations) {
			player1.animation.addByPrefix('sing${ani}', 'BF NOTE ${ani}0', 24, false);
			player1.animation.addByPrefix('sing${ani}miss', 'BF NOTE ${ani} MISS', 24, false);
		}
		player1.offsets.set('idle', FlxPoint.get(-5, 0));
		player1.offsets.set('singLEFT', FlxPoint.get(5, -6));
		player1.offsets.set('singDOWN', FlxPoint.get(-20, -51));
		player1.offsets.set('singUP', FlxPoint.get(-46, 27));
		player1.offsets.set('singRIGHT', FlxPoint.get(-48, -7));
		player1.offsets.set('singLEFTmiss', FlxPoint.get(7, 19));
		player1.offsets.set('singDOWNmiss', FlxPoint.get(-15, -19));
		player1.offsets.set('singUPmiss', FlxPoint.get(-46, 27));
		player1.offsets.set('singRIGHTmiss', FlxPoint.get(-44, 19));
		player1.dance(0);
		add(player1);
		
		var scrollDir:Float = (Settings.data.downscroll ? 270 : 90);
		
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
		
		var playerHit = playerStrumline.onNoteHit;
		playerStrumline.onNoteHit = (note:Note, lane:Lane) -> {
			noteHit(note);
			playerHit(note, lane);
		}
		playerStrumline.onNoteLost = (note:Note, lane:Lane) -> {
			noteMissed(note);
		};
		for (note in song.notes) {
			var strumline:Strumline = (note.player ? playerStrumline : opponentStrumline);
			var lane:Lane = strumline.getLane(note.noteData);
			lane.queue.push(note);
		}
		
		if (Settings.data.middlescroll) {
			playerStrumline.center(X);
			opponentStrumline.fitToSize(playerStrumline.leftBound - 50 - opponentStrumline.leftBound, -1, Y);
		}
		
		ratingGroup = new FlxTypedGroup<Rating>();
		add(ratingGroup);
		
		healthBar = new Bar(0, FlxG.height - 50, 'healthBar', () -> return health);
		healthBar.bounds.max = maxHealth;
		healthBar.y -= healthBar.height;
		healthBar.screenCenter(X);
		healthBar.camera = camHUD;
		add(healthBar);
		scoreTxt = new FlxText(0, FlxG.height - 25, FlxG.width, 'Score: idk', 20);
		scoreTxt.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		scoreTxt.y -= scoreTxt.height * .5;
		scoreTxt.borderSize = 1.25;
		scoreTxt.camera = camHUD;
		add(scoreTxt);
		
		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, keyPressEvent);
		FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, keyReleaseEvent);
		
		noteSpawnOffset = Note.distanceToMS(720, playerStrumline.scrollSpeed);
		updateRating();
	}

	override public function update(elapsed:Float) {
		//DEBUG CONTROL
		if (FlxG.keys.justPressed.Q) {
			Conductor.songPosition -= 350;
		}
		if (FlxG.keys.justPressed.R) {
			opponentStrumline.fadeIn();
			playerStrumline.fadeIn();
			
			opponentStrumline.clearAllNotes();
			playerStrumline.clearAllNotes();
			events = [];
			for (note in song.notes) {
				var strumline:Strumline = (note.player ? playerStrumline : opponentStrumline);
				var lane:Lane = strumline.getLane(note.noteData);
				lane.queue.push(note);
			}
			for (event in song.events) events.push(event);
			for (track in [song.instTrack, song.vocalTrack]) {
				track.time = 0;
				track.pause();
				//track.play(true);
			}
			resetMusic();
			Conductor.metronome.setBeat(-5);
			resetScore();
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
			for (track in [song.instTrack, song.vocalTrack]) {
				if (paused || Conductor.songPosition < 0)
					track.pause();
				else
					track.play(true, Conductor.songPosition);
			}
		}
		
		super.update(elapsed);
		if (paused) return;
		
		extraWindow = Math.max(extraWindow - elapsed * 200, 0);
		
		syncMusic();
		camHUD.zoom = FlxMath.lerp(camHUD.zoom, 1, elapsed * 3);
		FlxG.camera.zoom = FlxMath.lerp(FlxG.camera.zoom, 1, elapsed * 3);
		camFocus.setPosition(
			FlxMath.lerp(camFocus.x, camFocusTarget.x, 1 - Math.exp(-elapsed * 3)),
			FlxMath.lerp(camFocus.y, camFocusTarget.y, 1 - Math.exp(-elapsed * 3)),
		);
		
		var limit:Int = 50; //avoid lags
		while (events.length > 0 && Conductor.songPosition >= events[0].msTime && limit > 0) {
			var event:SongEvent = events.shift();
			triggerEvent(event);
			limit --;
		}
	}
	
	public function syncMusic(forceSongpos:Bool = false) {
		if (song.instLoaded && song.instTrack.playing) {
			if (song.vocalsLoaded && Math.abs(song.instTrack.time - song.vocalTrack.time) > 100)
				song.vocalTrack.time = song.instTrack.time;
			if ((forceSongpos && Conductor.songPosition < song.instTrack.time) || Math.abs(song.instTrack.time - Conductor.songPosition) > 100)
				Conductor.songPosition = song.instTrack.time;
		}
	}
	public function getSongPos() {
		if (song.instLoaded && song.instTrack.playing)
			return song.instTrack.time;
		else
			return Conductor.songPosition;
	}
	
	public function triggerEvent(event:SongEvent) {
		var values:Array<Dynamic> = event.values;
		switch (event.event) {
			case 'Focus':
				camFocusTarget.x = FlxG.width * .5 + (values[0] == 0 ? 180 : -180);
		}
	}
	
	override public function stepHit(step:Int) {
		super.stepHit(step);
		syncMusic(true);
	}
	override public function beatHit(beat:Int) {
		super.beatHit(beat);
		player1.dance(beat);
		switch (beat) {
			case -4:
				FlxG.sound.play(Paths.sound('intro3'));
			case -3:
				FlxG.sound.play(Paths.sound('intro2'));
			case -2:
				FlxG.sound.play(Paths.sound('intro1'));
			case -1:
				FlxG.sound.play(Paths.sound('introGo'));
			case 0:
				if (song.instLoaded) song.instTrack.play(true);
				if (song.vocalsLoaded) song.vocalTrack.play(true);
				syncMusic();
			default:
		}
	}
	override public function barHit(bar:Int) {
		super.barHit(bar);
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
	public function inputOn(keybind:Int) {
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
			if (note.ratingData.splash) lane.splash();
		} else {
			lane.playReceptor('press', true);
			extraWindow = Math.min(extraWindow + 15, 200);
		}
		Conductor.songPosition = oldTime;
	}
	public function inputOff(keybind:Int) {
		var lane:Lane = playerStrumline.getLane(keybind);
		lane.playReceptor('static', true);
		lane.held = false;
	}
	public function noteHit(note:Note) {
		if (note.isHoldPiece) {
			var anim:String = 'sing${singAnimations[note.noteData]}';
			if (player1.animation.name != anim)
				player1.playAnimation(anim, true);
			player1.timeAnimSteps(player1.singForSteps);
			if (note.isHoldTail)
				FlxG.sound.play(Paths.sound('hitsoundTail'), .7);
		} else {
			FlxG.sound.play(Paths.sound('hitsound'), .7);
			player1.playAnimation('sing${singAnimations[note.noteData]}', true);
			
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
			if (window.breaksCombo) combo = 0;
			else popCombo(++ combo);
		}
		updateRating();
	}
	public function noteMissed(note:Note) {
		popRating('sadmiss');
		player1.playAnimation('sing${singAnimations[note.noteData]}miss', true);
		health -= note.healthLoss;
		accuracyDiv ++;
		totalNotes ++;
		misses ++;
		combo = 0;
		score -= 10;
		updateRating();
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
			var popNum:ComboNumber = new ComboNumber(FlxG.width * .5 + (i + xOffset) * 43, FlxG.height * .5 + 80, num, Conductor.crochet * .002);
			popNum.scale.set(.5, .5);
			popNum.updateHitbox();
			popNum.setOffset(popNum.frameWidth * .5, popNum.frameHeight * .5);
			popNum.onComplete = (tween:FlxTween) -> {
				ratingGroup.remove(popNum, true);
				popNum.destroy();
			};
			ratingGroup.add(popNum);
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
	public function popRating(rating:String) {
		var rating:Rating = new Rating(FlxG.width * .5, FlxG.height * .5, rating, Conductor.crochet * .001);
		rating.scale.set(.7, .7);
		rating.updateHitbox();
		rating.setOffset(rating.frameWidth * .5, rating.frameHeight * .5);
		rating.onComplete = (tween:FlxTween) -> {
			ratingGroup.remove(rating, true);
			rating.destroy();
		};
		ratingGroup.add(rating);
	}
	public function updateScore() {
		var accuracyString:String = 'NA';
		if (totalNotes > 0) accuracyString = '${Util.padDecimals(percent, 2)}%';
		scoreTxt.text = 'Score: ${Std.int(score)} (${accuracyString}) | Misses: ${misses}';
	}
	public function set_combo(newCombo:Int) {
		if (combo > 0) comboBroken(combo);
		return combo = newCombo;
	}
	
	override public function destroy() {
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, keyPressEvent);
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_UP, keyReleaseEvent);
		super.destroy();
	}
}