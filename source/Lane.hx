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

	public var noteData:Int;
	public var cpu:Bool = true;
	public var held(default, set):Bool = false;
	public var scrollSpeed(default, set):Float = 1;
	public var direction:Float = 90;
	public var spawnRadius:Float;
	public var hitWindow:Float = Scoring.safeFrames / 60 * 1000;
	public var inputKeys:Array<FlxKey> = [];
	public var strumline:Strumline;
	
	public var noteEvent:FlxTypedSignal<NoteEvent->Void>;
	
	public var receptor:Receptor;
	public var noteCover:NoteCover;
	public var notes:FlxTypedSpriteGroup<Note>;
	public var noteSplashes:FlxTypedSpriteGroup<NoteSplash>;
	public var noteSparks:FlxTypedSpriteGroup<NoteSpark>;
	public var queue:Array<Note> = [];
	
	public function set_scrollSpeed(newSpeed:Float) {
		spawnRadius = Note.distanceToMS(FlxG.height, newSpeed);
		return scrollSpeed = newSpeed;
	}
	public function set_held(newHeld:Bool) {
		if (held == newHeld) return newHeld;
		if (newHeld) popCover();
		else noteCover.kill();
		return held = newHeld;
	}
	public function new(x:Float, y:Float, data:Int) {
		super(x, y);

		rgbShader = new RGBSwap();
		rgbShader.green = 0xffffff;
		rgbShader.red = Note.directionColors[data][0];
		rgbShader.blue = Note.directionColors[data][1];

		var splashCol:Array<FlxColor> = NoteSplash.makeSplashColors(rgbShader.red);
		splashRGB = new RGBSwap();
		splashRGB.green = 0xffffff;
		splashRGB.red = splashCol[0];
		splashRGB.blue = splashCol[1];

		noteCover = new NoteCover(data);
		receptor = new Receptor(0, 0, data);
		notes = new FlxTypedSpriteGroup<Note>();
		noteSparks = new FlxTypedSpriteGroup<NoteSpark>(0, 0, 5);
		noteSplashes = new FlxTypedSpriteGroup<NoteSplash>(0, 0, 5);
		spawnRadius = Note.distanceToMS(FlxG.height, scrollSpeed);
		receptor.lane = this; //lol
		this.noteData = data;
		this.add(receptor);
		this.add(notes);
		this.add(noteCover);
		this.add(noteSparks);
		this.add(noteSplashes);
		noteEvent = new FlxTypedSignal<NoteEvent->Void>();

		noteCover.shader = rgbShader.shader;
	}
	
	public override function update(elapsed:Float) {
		super.update(elapsed);
		
		var i:Int = 0;
		var early:Bool;
		var limit:Int = 50;
		while (i < queue.length) {
			var note:Note = queue[i];
			if (note == null) {
				trace('WARNING: Note was null!! (lane ${noteData})');
				queue.remove(note);
				continue;
			}
			early = (note.msTime - Conductor.songPosition > spawnRadius);
			if (!early && (note.endMs - Conductor.songPosition) >= -spawnRadius) {
				queue.remove(note);
				insertNote(note);
				limit --;
				if (limit < 0) break;
			} else
				i ++;
			if (early) break;
		}
		
		i = notes.length;
		while (i > 0) {
			i --;
			var note:Note = notes.members[i];
			updateNote(note);
		}
	}
	
	public function input(key:FlxKey) {
		if (inputKeys.contains(key)) {
			
		}
	}
	public function getHighestNote(filter:Null<(note:Note)->Bool> = null) {
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
	
	public function splash() {
		var splash:NoteSplash = noteSplashes.recycle(NoteSplash, () -> new NoteSplash(noteData));
		splash.camera = camera; //silly. freaking silly
		splash.shader = splashRGB.shader;
		splash.splashOnReceptor(receptor);
	}
	public function popCover() {
		noteCover.popOnReceptor(receptor);
	}
	public function spark() {
		var spark:NoteSpark = noteSparks.recycle(NoteSpark, () -> new NoteSpark(noteData));
		spark.camera = camera;
		spark.shader = splashRGB.shader;
		spark.sparkOnReceptor(receptor);
	}
	
	public function clearNotes() {
		for (note in notes) note.kill();
		notes.clear();
	}
	public function updateNote(note:Note) {
		note.followLane(this, scrollSpeed);
		if (note.ignore) return;
		if (Conductor.songPosition >= note.msTime && !note.lost && note.canHit && (cpu || held)) {
			if (!note.goodHit) hitNote(note, false);
			if (cpu) {
				receptor.animation.finishCallback = (anim:String) -> {
					receptor.playAnimation('static', true);
					receptor.animation.finishCallback = null;
				}
			}
			if (Conductor.songPosition >= note.endMs) {
				killNote(note);
				return;
			}
		}
		var canDespawn:Bool = !note.preventDespawn;
		if (note.lost || note.goodHit || note.isHoldPiece) {
			if (canDespawn && (note.endMs - Conductor.songPosition) < -spawnRadius) {
				queue.push(note);
				killNote(note);
			}
		} else {
			if (Conductor.songPosition - hitWindow > note.msTime) {
				note.lost = true;
				noteEvent.dispatch({note: note, lane: this, type: LOST});
				// onNoteLost.dispatch(note, this);
			}
			if (canDespawn && (note.msTime - Conductor.songPosition) > spawnRadius) {
				queue.push(note);
				killNote(note);
			}
		}
	}
	public function insertNote(note:Note, pos:Int = -1) {
		if (notes.members.contains(note)) return;
		note.shader = rgbShader.shader;
		note.hitWindow = hitWindow;
		note.goodHit = false;
		note.lane = this;
		if (!note.isHoldPiece) {
			note.canHit = true;
			for (child in note.children) child.canHit = false;
		}
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
		noteEvent.dispatch({note: note, lane: this, type: SPAWNED});
	}
	public dynamic function hitNote(note:Note, kill:Bool = true) {
		note.goodHit = true;
		noteEvent.dispatch({note: note, lane: this, type: HIT});
		if (kill && !note.ignore) killNote(note);
	}
	public function killNote(note:Note) {
		notes.remove(note, true);
		note.kill();
		noteEvent.dispatch({note: note, lane: this, type: DESPAWNED});
	}
}

class Receptor extends FunkinSprite {
	public var lane:Lane;
	public var noteData:Int;
	public var rgbShader:RGBSwap;
	public var missColor:Array<FlxColor>;
	public var glowColor:Array<FlxColor>;
	public var rgbEnabled(default, set):Bool;
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
	}

	public function reloadAnimations() {
		animation.destroyAnimations();
		var dirName:String = Note.directionNames[noteData];
		animation.addByPrefix('static', '$dirName receptor', 24, true);
		animation.addByPrefix('confirm', '$dirName confirm', 24, false);
		animation.addByPrefix('press', '$dirName press', 24, false);
		playAnimation('static', true);
	}

	public override function update(elapsed:Float) {
		super.update(elapsed);
		if (grayBeat != null && Conductor.metronome.beat >= grayBeat)
			playAnimation('press');
	}
	
	public override function playAnimation(anim:String, forced:Bool = false) {
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
		super.playAnimation(anim, forced);
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
		alpha = .7;
		
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

typedef NoteEvent = {
	var note:Note;
	var lane:Lane;
	var type:NoteEventType;
}

enum NoteEventType {
	SPAWNED;
	DESPAWNED;
	HIT;
	LOST;
}