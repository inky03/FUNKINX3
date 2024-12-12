package;

import Note;
import Scoring;
import Strumline;
import flixel.input.keyboard.FlxKey;
import flixel.util.FlxSignal.FlxTypedSignal;
import flixel.graphics.frames.FlxFramesCollection;

using StringTools;

class Lane extends FlxSpriteGroup {
	public var rgbShader:RGBSwap;
	public var splashRGB:RGBSwap;

	public var held(default, set):Bool = false;
	public var heldNote:Note = null;

	public var noteData:Int;
	public var oneWay:Bool = true;
	public var scrollSpeed(default, set):Float = 1;
	public var direction:Float = 90;
	public var spawnRadius:Float;
	public var hitWindow:Float = Scoring.safeFrames / 60 * 1000;
	public var conductorInUse:Conductor = MusicBeatState.getCurrentConductor();
	public var inputKeys:Array<FlxKey> = [];
	public var strumline:Strumline;
	
	public var cpu(default, set):Bool = false;
	public var allowInput:Bool = true;
	public var inputFilter:Note -> Bool;
	public var noteEvent:FlxTypedSignal<NoteEvent -> Void> = new FlxTypedSignal();
	var extraWindow:Float = 0; // antimash mechanic
	
	public var receptor:Receptor;
	public var noteCover:NoteCover;
	public var notes:FlxTypedSpriteGroup<Note>;
	public var noteSplashes:FlxTypedSpriteGroup<NoteSplash>;
	public var noteSparks:FlxTypedSpriteGroup<NoteSpark>;
	public var queue:Array<Note> = [];

	public var selfDraw:Bool = false;
	public var topMembers:Array<FlxSprite> = [];
	
	public function set_scrollSpeed(newSpeed:Float) {
		var cam = camera ?? FlxG.camera;
		spawnRadius = Note.distanceToMS(camera.height / camera.zoom, newSpeed);
		return scrollSpeed = newSpeed;
	}
	public function set_held(newHeld:Bool) {
		if (held == newHeld) return newHeld;
		if (newHeld) popCover();
		else noteCover.kill();
		return held = newHeld;
	}
	public function set_cpu(isCpu:Bool) {
		if (cpu == isCpu) return isCpu;
		if (receptor != null)
			receptor.autoReset = isCpu;
		return cpu = isCpu;
	}
	public function new(x:Float, y:Float, data:Int) {
		super(x, y);

		inputFilter = (note:Note) -> {
			var time:Float = note.msTime - conductorInUse.songPosition;
			return (time <= note.hitWindow + extraWindow) && (time >= -note.hitWindow);
		};
		
		var splashColors:Array<FlxColor> = NoteSplash.makeSplashColors(Note.directionColors[data][0]);
		rgbShader = new RGBSwap(Note.directionColors[data][0], FlxColor.WHITE, Note.directionColors[data][1]);
		splashRGB = new RGBSwap(splashColors[0], FlxColor.WHITE, splashColors[1]);

		noteCover = new NoteCover(data);
		receptor = new Receptor(0, 0, data);
		notes = new FlxTypedSpriteGroup<Note>();
		noteSparks = new FlxTypedSpriteGroup<NoteSpark>(0, 0, 5);
		noteSplashes = new FlxTypedSpriteGroup<NoteSplash>(0, 0, 5);
		spawnRadius = Note.distanceToMS(FlxG.height, scrollSpeed);
		receptor.lane = this; //lol
		this.noteData = data;
		this.add(receptor);
		topMembers.push(notes);
		topMembers.push(noteCover);
		topMembers.push(noteSparks);
		topMembers.push(noteSplashes);

		noteCover.shader = splashRGB.shader;
		updateHitbox();

		spark().alpha = .0001;
		splash().alpha = .0001;
	}
	
	public override function update(elapsed:Float) {
		var i:Int = 0;
		var early:Bool;
		var limit:Int = 50;
		while (i < queue.length) {
			var note:Note = queue[i];
			if (note == null) {
				Log.warning('note was null in lane $noteData!!');
				queue.remove(note);
				continue;
			}
			early = (note.msTime - conductorInUse.songPosition > spawnRadius);
			if (!early && (oneWay || (note.endMs - conductorInUse.songPosition) >= -spawnRadius)) {
				queue.remove(note);
				insertNote(note);
				limit --;
				if (limit < 0) break;
			} else
				i ++;
			if (early && oneWay) break;
		}
		
		updateNotes();

		super.update(elapsed);
		extraWindow = Math.max(extraWindow - elapsed * 200, 0);
		for (member in topMembers) member.update(elapsed);
	}
	public function updateNotes() {
		var i:Int = notes.length;
		while (i > 0) {
			i --;
			var note:Note = notes.members[i];
			if (note == null) continue;
			updateNote(note);
		}
	}
	public override function draw() {
		super.draw();
		if (selfDraw) drawTop();
	}
	public function drawTop() {
		@:privateAccess {
			final oldDefaultCameras = FlxCamera._defaultCameras;
			if (_cameras != null) FlxCamera._defaultCameras = _cameras;

			for (member in topMembers) {
				if (member != null && member.exists && member.visible)
					member.draw();
			}

			FlxCamera._defaultCameras = oldDefaultCameras;
		}
	}
	
	public function fireInput(key:FlxKey, pressed:Bool):Bool {
		if (!inputKeys.contains(key) || !allowInput) return false;
		if (pressed) {
			var note = getHighestNote(inputFilter);
			if (note != null) {
				hitNote(note);
			} else {
				ghostTapped();
			}
		} else {
			held = false;
			receptor.playAnimation('static', true);
			if (heldNote != null) {
				killSustainsOf(heldNote);
				heldNote = null;
			}
		}
		return true;
	}
	public function ghostTapped()
		noteEvent.dispatch(basicEvent(GHOST));
	public function basicEvent(type:NoteEventType, ?note:Note):NoteEvent
		return {lane: this, strumline: strumline, receptor: receptor, note: note, type: type};
	public function getHighestNote(?filter:Note -> Bool) {
		var highNote:Null<Note> = null;
		for (note in notes) {
			var valid:Bool = (filter == null ? true : filter(note));
			var canHit:Bool = (note.canHit && !note.isHoldPiece && valid);
			if (!canHit) continue;
			if (highNote == null || (note.hitPriority >= highNote.hitPriority || (note.hitPriority == highNote.hitPriority && note.msTime < highNote.msTime)))
				highNote = note;
		}
		return highNote;
	}
	public function getAllNotes() {
		var notes:Array<Note> = [];
		for (note in this.notes) notes.push(note);
		for (note in this.queue) notes.push(note);
		return notes;
	}
	public function resetLane() {
		clearNotes();
		receptor?.playAnimation('static');
		noteCover.kill();
		queue.resize(0);
		heldNote = null;
		held = false;
	}
	
	public function splash():NoteSplash {
		var splash:NoteSplash = noteSplashes.recycle(NoteSplash, () -> new NoteSplash(noteData));
		splash.camera = camera; //silly. freaking silly
		splash.alpha = alpha * .7;
		splash.shader = splashRGB.shader;
		splash.splashOnReceptor(receptor);
		return splash;
	}
	public function popCover():NoteCover {
		noteCover.popOnReceptor(receptor);
		return noteCover;
	}
	public function spark():NoteSpark {
		var spark:NoteSpark = noteSparks.recycle(NoteSpark, () -> new NoteSpark(noteData));
		spark.camera = camera;
		spark.shader = splashRGB.shader;
		spark.sparkOnReceptor(receptor);
		return spark;
	}
	
	public function queueNote(note:Note, sorted:Bool = false):Note {
		if (!queue.contains(note)) {
			if (sorted) {
				for (i => otherNote in queue) {
					if (otherNote.msTime >= note.msTime) {
						queue.insert(i, note);
						return note;
					}
				}
			}
			queue.push(note);
		}
		return note;
	}
	public function clearNotes() {
		for (note in notes) note.kill();
		notes.clear();
	}
	public function updateNote(note:Note) {
		note.followLane(this, scrollSpeed);
		if (note.ignore) return;
		if ((cpu || (held && note.isHoldPiece)) && conductorInUse.songPosition >= note.msTime && !note.lost && note.canHit) {
			if (!note.goodHit)
				hitNote(note, false);
			var canKillNote:Bool = (conductorInUse.songPosition >= note.endMs);
			if (note.isHoldPiece) {
				var holdEvent:NoteEvent = basicEvent(canKillNote ? RELEASED : HELD, note);
				noteEvent.dispatch(holdEvent);
			}
			if (canKillNote) {
				killNote(note);
				return;
			}
		}
		var canDespawn:Bool = !note.preventDespawn;
		if (note.lost || note.goodHit || note.isHoldPiece) {
			if (canDespawn && (note.endMs - conductorInUse.songPosition) < -spawnRadius) {
				if (!oneWay) { // bye bye note
					queue.push(note);
				}
				killNote(note);
			}
		} else {
			if (conductorInUse.songPosition - hitWindow > note.msTime) {
				note.lost = true;
				noteEvent.dispatch(basicEvent(LOST, note));
			}
		}
	}
	public function insertNote(note:Note, pos:Int = -1) {
		if (notes.members.contains(note)) return;
		note.shader ??= rgbShader.shader;
		note.hitWindow = hitWindow;
		note.lane = this;

		note.scale.copyFrom(receptor.scale);
		note.updateHitbox();
		note.revive();
		updateNote(note);
		if (pos < 0) {
			pos = 0;
			for (note in notes) {
				if (note.isHoldPiece) pos ++;
				else break;
			}
		}
		notes.insert(pos, note);
		noteEvent.dispatch(basicEvent(SPAWNED, note));
	}
	public dynamic function hitNote(note:Note, kill:Bool = true) {
		note.goodHit = true;
		noteEvent.dispatch(basicEvent(HIT, note));
		if (kill && !note.ignore) killNote(note);
	}
	public function killNote(note:Note) {
		note.kill();
		notes.remove(note, true);
		noteEvent.dispatch(basicEvent(DESPAWNED, note));
	}
	public function killSustainsOf(note:Note) {
		for (child in note.children) {
			if (!child.alive)
				continue;
			child.lost = true;
			child.canHit = false;
			noteEvent.dispatch(basicEvent(RELEASED, child));
			killNote(child);
		}
	}
	
	public override function get_width()
		return receptor?.width ?? 0;
	public override function get_height()
		return receptor?.height ?? 0;
}

class Receptor extends FunkinSprite {
	public var lane:Lane;
	public var noteData:Int;
	public var rgbShader:RGBSwap;
	public var missColor:Array<FlxColor>;
	public var glowColor:Array<FlxColor>;
	public var rgbEnabled(default, set):Bool;
	public var autoReset:Bool = false;
	public var grayBeat:Null<Float>;
	
	public function new(x:Float, y:Float, data:Int) {
		super(x, y);
		loadAtlas('notes');
		
		this.noteData = data;

		rgbShader = new RGBSwap();
		rgbShader.green = 0xffffff;
		rgbShader.red = Note.directionColors[data][0];
		rgbShader.blue = Note.directionColors[data][1];
		glowColor = [rgbShader.red, rgbShader.blue];
		missColor = [makeGrayColor(rgbShader.red), FlxColor.fromRGB(32, 30, 49)];

		loadAtlas('notes');
		reloadAnimations();

		onAnimationComplete.add((anim:String) -> {
			if (anim != 'confirm') return;
			if (lane == null || (autoReset && !lane.held)) {
				playAnimation('static', true);
			}
		});
	}

	public function reloadAnimations() {
		animation.destroyAnimations();
		var dirName:String = Note.directionNames[noteData];
		animation.addByPrefix('static', '$dirName receptor', 24, true);
		animation.addByPrefix('confirm', '$dirName confirm', 24, false);
		animation.addByPrefix('press', '$dirName press', 24, false);
		playAnimation('static', true);
		updateHitbox();
	}

	public override function update(elapsed:Float) {
		super.update(elapsed);
		if (grayBeat != null && lane.conductorInUse.metronome.beat >= grayBeat)
			playAnimation('press');
	}
	
	public override function playAnimation(anim:String, forced:Bool = false, reversed:Bool = false, frame:Int = 0) {
		if (anim == 'static') {
			rgbEnabled = false;
		} else {
			var baseColor:Array<FlxColor> = (anim == 'press' ? missColor : glowColor);
			rgbShader.blue = baseColor[1];
			rgbShader.red = baseColor[0];
			rgbEnabled = true;
		}
		if (anim != 'confirm')
			grayBeat = null;
		super.playAnimation(anim, forced, reversed, frame);
		centerOffsets();
		centerOrigin();
	}

	public function set_rgbEnabled(newE:Bool) {
		shader = (newE ? rgbShader.shader : null);
		return rgbEnabled = newE;
	}

	public static function makeGrayColor(col:FlxColor) {
		var pCol:FlxColor = col;
		col.red = Std.int(FlxMath.bound(col.red - 40 - (col.blue - col.red) * .1 + Math.abs(col.red - col.blue) * .1 + Math.min(col.red - Math.pow(col.blue / 255, 2) * 255 * 3 + col.green * .4, 0) * .1, 0, 255));
		col.green = Std.int(FlxMath.bound(col.green + (col.red + col.blue) * .15 + (col.green - col.blue) * .3, 0, 255));
		col.blue = Std.int(FlxMath.bound(col.blue + (col.green - col.blue) * .04 + (col.red + col.blue) * .25 + Math.abs(col.red - (col.green - col.blue)) * .2 - (col.red - col.blue) * .3, 0, 255));

		col.saturation = FlxMath.bound(col.saturation + (pCol.blueFloat + pCol.greenFloat - (pCol.blueFloat - pCol.redFloat)) * .05 - (1 - pCol.brightness) * .1, 0, 1) * .52;
		col.brightness = FlxMath.bound(col.brightness - ((pCol.blueFloat + pCol.greenFloat - (pCol.blueFloat - pCol.redFloat)) * .04) + (1 - pCol.brightness) * .08, 0, 1) * .75;
		
		return col;
	}
}

class NoteSplash extends FunkinSprite {
	public var noteData:Int;

	public function new(data:Int) {
		super();
		loadAtlas('noteSplashes');
		
		this.noteData = data;
		var dirName:String = Note.directionNames[data];
		animation.addByPrefix('splash1', 'notesplash $dirName 1', 24, false);
		animation.addByPrefix('splash2', 'notesplash $dirName 2', 24, false);
		
		animation.finishCallback = (anim:String) -> {
			kill();
		}
	}
	
	public function splashOnReceptor(receptor:Receptor) { //lol
		setPosition(receptor.x + receptor.width * .5, receptor.y + receptor.height * .5);
		splash();
	}
	public function splash() {
		playAnimation('splash${FlxG.random.int(1, 2)}', true);
		animation.curAnim.frameRate = FlxG.random.int(22, 26);
		updateHitbox();
		spriteOffset.set(width * .5, height * .5);
	}

	public static function makeSplashColors(baseFill:FlxColor):Array<FlxColor> {
		var fill:FlxColor = baseFill;
		var f = 6.77; // literally just contrast
		var m = Math.pow(1 - (fill.saturation * fill.brightness), 2);
		fill.red = Std.int(FlxMath.lerp(FlxMath.bound(f * (fill.red - 128) + 128, 0, 255), fill.red, m));
		fill.green = Std.int(FlxMath.lerp(FlxMath.bound(f * (fill.green - 128) + 128, 0, 255), fill.green, m));
		fill.blue = Std.int(FlxMath.lerp(FlxMath.bound(f * (fill.blue - 128) + 128, 0, 255), fill.blue, m));
		fill.saturation = fill.saturation * Math.min(fill.brightness / .25, 1);
		fill.brightness = fill.brightness * .5 + .5;
		
		var ring:FlxColor = baseFill;
		ring.red = Std.int(ring.red * .65);
		ring.green = Std.int(ring.green * Math.max(.75 - ring.blue * .2, 0));
		ring.blue = Std.int(Math.min((ring.blue + 80) * ring.brightness, 255));
		ring.saturation = Math.min(1 - Math.pow(1 - ring.saturation * 1.4, 2), 1) * Math.min(ring.brightness / .125, 1);
		ring.brightness = ring.brightness * .75 + .25;

		return [fill, ring];
	}
}

class NoteCover extends FunkinSprite {
	public function new(data:Int) {
		super();
		loadAtlas('noteCovers');
		
		var dir:String = Note.directionNames[data];
		if (!hasAnimationPrefix('hold cover start $dir')) dir = '';
		animation.addByPrefix('start', 'hold cover start $dir'.trim(), 24, false);
		animation.addByPrefix('loop', 'hold cover loop $dir'.trim(), 24, true);
		
		animation.finishCallback = (anim:String) -> {
			playAnimation('loop');
		};
		kill();
	}
	
	public function popOnReceptor(receptor:Receptor) {
		setPosition(receptor.x + receptor.width * .5, receptor.y + receptor.height * .5);
		pop();
	}
	public function pop() {
		playAnimation('start', true);
		revive();
		updateHitbox();
		spriteOffset.set(width * .5 + 10, height * .5 - 46);
	}
}

class NoteSpark extends FunkinSprite {
	public function new(data:Int) {
		super(data);
		loadAtlas('noteCovers');
		
		var dir:String = Note.directionNames[data];
		if (!hasAnimationPrefix('hold cover $dir')) dir = '';
		animation.addByPrefix('spark', 'hold cover spark ${dir}'.trim(), 24, false);
		animation.finishCallback = (anim:String) -> {
			kill();
		}
	}
	
	public function sparkOnReceptor(receptor:Receptor) {
		setPosition(receptor.x + receptor.width * .5, receptor.y + receptor.height * .5);
		spark();
	}
	public function spark() {
		playAnimation('spark', true);
		updateHitbox();
		spriteOffset.set(width * .5 + 10, height * .5 - 46);
	}
}

@:structInit class NoteEvent {
	public var note:Note;
	public var lane:Lane;
	public var receptor:Receptor;
	public var type:NoteEventType;
	public var strumline:Strumline;
	public var cancelled:Bool = false;
	public var animSuffix:String = '';

	public var spark:NoteSpark = null;
	public var splash:NoteSplash = null;
	public var scoring:Scoring.Score = null;
	public var targetCharacter:Character = null;

	public var perfect:Bool = false; // release event
	public var doSpark:Bool = true; // many vars...
	public var doSplash:Bool = true;
	public var playSound:Bool = true;
	public var applyRating:Bool = true;
	public var playAnimation:Bool = true;
	public var animateReceptor:Bool = true;

	public function cancel() cancelled = true;
	public function dispatch() { // hahaaa
		if (cancelled) return;
		var game:PlayState;
		if (Std.isOfType(FlxG.state, PlayState)) {
			game = cast FlxG.state;
		} else {
			throw(new haxe.Exception('note event can\'t be dispatched outside of PlayState!!'));
			return;
		}
		switch (type) {
			case HIT:
				if (targetCharacter != null)
					targetCharacter.volume = 1;

				note.hitTime = lane.conductorInUse.songPosition;
				if (!note.isHoldPiece) {
					// if (lane.heldNote != null)
					// 	lane.hitSustainsOf(lane.heldNote);
					lane.heldNote = note;

					if (playSound)
						game.hitsound.play(true);
					
					if (applyRating) {
						scoring ??= game.scoring.judgeNoteHit(note, note.msTime - lane.conductorInUse.songPosition);
						game.scoring.countRating(scoring.rating);
						
						var rating:FunkinSprite = game.popRating(scoring.rating);
						rating.velocity.y = -FlxG.random.int(140, 175);
						rating.velocity.x = FlxG.random.int(0, 10);
						rating.acceleration.y = 550;
						note.ratingData = scoring;
						applyExtraWindow(6);

						game.score += scoring.score;
						game.health += note.healthGain * scoring.healthMod;
						game.accuracyMod += scoring.accuracyMod;
						game.accuracyDiv ++;
						game.totalNotes ++;
						game.totalHits ++;
						if (scoring.hitWindow != null && scoring.hitWindow.breaksCombo)
							game.combo = 0; // maybe add the ghost note here?
						else
							game.popCombo(++ game.combo);
						game.updateRating();
					}
					if (doSplash && (scoring.hitWindow == null || scoring.hitWindow.splash))
						splash = lane.splash();
				}
				if (playAnimation && targetCharacter != null) {
					var anim:String = 'sing${game.singAnimations[note.noteData]}';
					var suffixAnim:String = anim + targetCharacter.animSuffix;
					if (!targetCharacter.animationExists(suffixAnim)) suffixAnim = anim;
					if (!note.isHoldPiece || (targetCharacter.currentAnimation != suffixAnim && !targetCharacter.animationIsLooping(suffixAnim))) {
						targetCharacter.playAnimationSoft(anim + animSuffix, true);
					}
					targetCharacter.timeAnimSteps();
				}

				if (animateReceptor) lane.receptor.playAnimation('confirm', true);
				if (!note.isHoldPiece) {
					if (note.msLength > 0) {
						lane.held = true;
						for (child in note.children) {
							child.canHit = true;
							lane.updateNote(child);
						}
					} else if (!lane.cpu && animateReceptor) {
						lane.receptor.grayBeat = note.beatTime + 1;
					}
				}
			case HELD | RELEASED:
				var perfectRelease:Bool = true;
				final released:Bool = (type == RELEASED);
				final songPos:Float = lane.conductorInUse.songPosition;
				perfect = (released && songPos >= note.endMs - Scoring.holdLeniencyMS);
				if (applyRating) {
					perfectRelease = perfect;
				}
				/*   ... ill do this later
				if (applyRating) {
					if (note.isHoldPiece && note.endMs > note.msTime) {
						var prevHitTime:Float;
						if (!note.held && note.hitTime <= note.msTime + Scoring.holdLeniencyMS)
							prevHitTime = note.msTime;
						else
							prevHitTime = Math.max(note.hitTime, note.msTime);

						perfectRelease = (released && songPos >= note.endMs - Scoring.holdLeniencyMS);
						var nextHitTime:Float;
						if (perfectRelease)
							nextHitTime = note.endMs;
						else
							nextHitTime = Math.min(songPos, note.endMs);
						if (!note.held) trace('started hitting ${Math.round(note.msTime)} -> ${Math.round(prevHitTime)} / ${Math.round(note.endMs)}');
						if (released) trace('released ${Math.round(nextHitTime)} / ${Math.round(note.endMs)} (last : ${Math.round(prevHitTime)})');

						final secondDiff:Float = Math.max(0, (nextHitTime - prevHitTime) * .001);
						final scoreGain:Float = game.scoring.holdScorePerSecond * secondDiff;
						scoring ??= {score: scoreGain, healthMod: secondDiff};
						note.hitTime = nextHitTime;
					}
					if (scoring != null) {
						game.health += scoring.healthMod * note.healthGainPerSecond;
						game.score += scoring.score;
						game.updateRating();
					}
				} else {
					note.hitTime = songPos;
				} */
				if (released && note.isHoldTail) {
					if (lane.held && (lane.heldNote == null || lane.heldNote == note.parent)) {
						lane.heldNote = null;
						lane.held = false;
						if (!lane.cpu && animateReceptor)
							lane.receptor.playAnimation('press', true);
					}
					if (perfectRelease) {
						if (doSpark)
							spark = lane.spark();
						if (playSound)
							FlxG.sound.play(Paths.sound('gameplay/hitsounds/hitsoundTail'), .7);
					} else {
						if (playSound)
							FlxG.sound.play(Paths.sound('gameplay/hitsounds/hitsoundFail'), .7);
					}
				}
				note.held = true;
			case GHOST:
				if (animateReceptor)
					lane.receptor.playAnimation('press', true);
				if (playSound) {
					FlxG.sound.play(Paths.sound('gameplay/hitsounds/miss${FlxG.random.int(1, 3)}'), FlxG.random.float(0.25, 0.3));
					FlxG.sound.play(Paths.sound('gameplay/hitsounds/hitsoundFail'), .7);
				}
				if (playAnimation && targetCharacter != null) {
					targetCharacter.specialAnim = false;
					targetCharacter.playAnimationSteps('sing${game.singAnimations[lane.noteData]}miss', true);
				}

				applyExtraWindow(15);
				if (applyRating) {
					game.score -= 10;
					game.health -= .01;
					game.updateRating();
				}
			case LOST:
				if (targetCharacter != null) {
					targetCharacter.volume = 0;
					if (playAnimation) {
						targetCharacter.specialAnim = false;
						targetCharacter.playAnimationSteps('sing${game.singAnimations[note.noteData]}miss', true);
					}
				}
				if (playSound)
					FlxG.sound.play(Paths.sound('gameplay/hitsounds/miss${FlxG.random.int(1, 3)}'), FlxG.random.float(0.5, 0.6));

				if (applyRating) {
					var rating:FunkinSprite = game.popRating('sadmiss');
					rating.velocity.y = -FlxG.random.int(80, 95);
					rating.velocity.x = FlxG.random.int(-6, 6);
					rating.acceleration.y = 240;
					
					scoring ??= game.scoring.judgeNoteMiss(note);
					game.health -= note.healthLoss;
					game.accuracyDiv ++;
					game.totalNotes ++;
					game.misses ++;
					game.combo = 0;
					game.updateRating();
					game.score += scoring.score;
					game.accuracyMod += scoring.accuracyMod;
					game.health += note.healthGain * scoring.healthMod;
				}
			default:
		}
	}
	function applyExtraWindow(window:Float) {
		@:privateAccess {
		var extraWin:Float = Math.min(lane.extraWindow + window, 200);
		if (strumline != null) {
			for (lane in strumline.lanes)
				lane.extraWindow = extraWin;
		} else {
			lane.extraWindow = extraWin;
		}
		}
	}
}

enum NoteEventType {
	SPAWNED;
	DESPAWNED;

	HIT;
	HELD;
	RELEASED;

	LOST;
	GHOST;
}