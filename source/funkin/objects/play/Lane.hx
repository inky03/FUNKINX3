package funkin.objects.play;

import funkin.shaders.RGBSwap;
import funkin.objects.play.Note;
import funkin.backend.play.Scoring;
import funkin.backend.play.NoteEvent;
import funkin.backend.rhythm.Conductor;

import flixel.input.keyboard.FlxKey;
import flixel.util.FlxSignal.FlxTypedSignal;
import flixel.graphics.frames.FlxFramesCollection;

using StringTools;

class Lane extends FunkinSpriteGroup {
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
	public var conductorInUse:Conductor = FunkinState.getCurrentConductor();
	public var inputKeys:Array<FlxKey> = [];
	public var strumline:Strumline;
	
	public var cpu(default, set):Bool = false;
	public var allowInput:Bool = true;
	public var inputFilter:Note -> Bool;
	public var noteEvent:FlxTypedSignal<NoteEvent -> Void> = new FlxTypedSignal();
	var extraWindow:Float = 0; // antimash mechanic
	
	public var receptor:Receptor;
	public var noteCover:NoteCover;
	public var notes:FunkinTypedSpriteGroup<Note>;
	public var noteSparks:FunkinTypedSpriteGroup<NoteSpark>;
	public var noteSplashes:FunkinTypedSpriteGroup<NoteSplash>;
	public var queue:Array<ChartNote> = [];

	public var selfDraw:Bool = false;
	public var topMembers:Array<FlxSprite> = [];
	
	public function set_scrollSpeed(newSpeed:Float) {
		var cam = camera ?? FlxG.camera;
		spawnRadius = Note.distanceToMS(camera.height / camera.zoom, newSpeed) + 50;
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
		notes = new FunkinTypedSpriteGroup();
		noteSparks = new FunkinTypedSpriteGroup(0, 0, 5);
		noteSplashes = new FunkinTypedSpriteGroup(0, 0, 5);
		spawnRadius = Note.distanceToMS(FlxG.height, scrollSpeed);
		receptor.lane = this; //lol
		this.noteData = data;
		this.add(receptor);
		topMembers.push(notes);
		topMembers.push(noteCover);
		topMembers.push(noteSparks);
		topMembers.push(noteSplashes);

		noteCover.shader = splashRGB.shader;

		spark().alpha = .0001;
		splash().alpha = .0001;
	}
	
	public override function update(elapsed:Float) {
		var i:Int = 0;
		var early:Bool;
		var limit:Int = 50;
		while (i < queue.length) {
			var note:ChartNote = queue[i];
			if (note == null) {
				Log.warning('note was null in lane $noteData!!');
				queue.remove(note);
				continue;
			}
			early = (note.msTime - conductorInUse.songPosition > spawnRadius);
			if (!early && (oneWay || (note.msTime + note.msLength - conductorInUse.songPosition) >= -spawnRadius)) {
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
			if (note == null || !note.alive) continue;
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
	public function forEachNote(func:ChartNote -> Void, includeQueued:Bool = false) {
		if (includeQueued) {
			for (note in queue)
				func(note);
		}
		for (note in notes) {
			if (note.alive && note.chartNote != null)
				func(note.chartNote);
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
				var note:Note = heldNote;
				_noteEvent(basicEvent(RELEASED, note));
				killNote(note);
			}
		}
		return true;
	}
	public function ghostTapped()
		_noteEvent(basicEvent(GHOST));
	public function basicEvent(type:NoteEventType, ?note:Note):NoteEvent
		return {lane: this, strumline: strumline, receptor: receptor, note: note, type: type};
	function _noteEvent(event:NoteEvent) {
		strumline?.noteEvent.dispatch(event);
		noteEvent.dispatch(event);
	}
	public function getHighestNote(?filter:Note -> Bool) {
		var highNote:Null<Note> = null;
		for (note in notes) {
			if (!note.alive) continue;
			
			var valid:Bool = (filter == null ? true : filter(note));
			var canHit:Bool = (note.canHit && !note.goodHit && valid);
			if (!canHit) continue;
			if (highNote == null || (note.hitPriority > highNote.hitPriority || (note.hitPriority == highNote.hitPriority && note.msTime < highNote.msTime)))
				highNote = note;
		}
		return highNote;
	}
	public function getAllNotes() {
		var notes:Array<ChartNote> = [];
		
		for (note in this.queue)
			notes.push(note);
		for (note in this.notes) {
			if (note.alive && note.chartNote != null)
				notes.push(note.chartNote);
		}
		
		return notes;
	}
	public function resetLane() {
		clearNotes();
		receptor?.playAnimation('static');
		noteCover.kill();
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
		spark.alpha = alpha;
		spark.camera = camera;
		spark.shader = splashRGB.shader;
		spark.sparkOnReceptor(receptor);
		return spark;
	}
	
	public function queueNote(note:ChartNote, sorted:Bool = false):ChartNote {
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
	public function dequeueNote(note:ChartNote) {
		queue.remove(note);
	}
	public function clearNotes() {
		for (note in notes)
			note.kill();
		notes.clear();
		queue.resize(0);
	}
	public function updateNote(note:Note) {
		note.followLane(this, scrollSpeed);
		
		if (note.ignore)
			return;
		
		var killingNote:Bool = false;
		var songPos:Float = conductorInUse.songPosition;
		if ((cpu || (held && note.goodHit)) && songPos >= note.msTime && !note.lost && note.canHit) {
			if (!note.goodHit)
				hitNote(note, false);
			
			if (songPos >= note.endMs)
				note.consumed = killingNote = true;
			
			_noteEvent(basicEvent(HELD, note));
			
			if (killingNote) {
				_noteEvent(basicEvent(RELEASED, note));
				killNote(note);
				return;
			}
		}
		
		var canDespawn:Bool = !note.preventDespawn;
		if (note.lost || note.goodHit) {
			if (canDespawn && (note.endMs - conductorInUse.songPosition) < -spawnRadius)
				killNote(note, !oneWay);
		} else {
			if (conductorInUse.songPosition - hitWindow > note.msTime) {
				note.lost = true;
				_noteEvent(basicEvent(LOST, note));
			}
		}
		
		if (!oneWay && (note.msTime - conductorInUse.songPosition) > spawnRadius)
			killNote(note, true);
	}
	public function generateNote(songNote:ChartNote):Note {
		return new Note(songNote, conductorInUse);
	}
	public function insertNote(songNote:ChartNote, pos:Int = 0) {
		var note:Note = notes.recycle(Note, () -> generateNote(songNote));
		
		note.lane = this;
		note.chartNote = songNote;
		note.hitWindow = hitWindow;
		
		note.reload();
		note.shader = rgbShader.shader;
		note.scale.copyFrom(receptor.scale);
		note.updateHitbox();
		updateNote(note);
		
		notes.insert(pos, note);
		_noteEvent(basicEvent(SPAWNED, note));
	}
	public dynamic function hitNote(note:Note, kill:Bool = true) {
		note.goodHit = true;
		
		var event:NoteEvent = basicEvent(HIT, note);
		_noteEvent(event);
		
		if (kill && !note.isHoldNote && !note.ignore && !event.cancelled)
			killNote(note);
	}
	public function killNote(note:Note, requeue:Bool = false) {
		if (requeue)
			queue.push(note.chartNote);
		
		note.kill();
		_noteEvent(basicEvent(DESPAWNED, note));
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
		addAnimation('static', '$dirName receptor', 24, true);
		addAnimation('confirm', '$dirName confirm', 24, false);
		addAnimation('press', '$dirName press', 24, false);
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
		addAnimation('splash1', 'notesplash $dirName 1', 24, false);
		addAnimation('splash2', 'notesplash $dirName 2', 24, false);
		onAnimationComplete.add((anim:String) -> { kill(); });
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
		addAnimation('start', 'hold cover start $dir'.trim(), 24, false);
		addAnimation('loop', 'hold cover loop $dir'.trim(), 24, true);
		onAnimationComplete.add((anim:String) -> { playAnimation('loop'); });
		
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
		addAnimation('spark', 'hold cover spark ${dir}'.trim(), 24, false);
		onAnimationComplete.add((anim:String) -> { kill(); });
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