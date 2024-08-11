package;

import Strumline;
import Scoring;
import Note;

class Lane extends FlxSpriteGroup {
	public var noteData:Int;
	public var cpu:Bool = true;
	public var held(default, set):Bool = false;
	public var scrollSpeed(default, set):Float = 1;
	public var direction:Float = 90;
	public var spawnRadius:Float;
	public var hitWindow:Float = Scoring.safeFrames / 60 * 1000;
	public var strumline:Strumline;
	
	public dynamic function onNoteDespawned(note:Note, lane:Lane) {}
	public dynamic function onNoteSpawned(note:Note, lane:Lane) {}
	public dynamic function onNoteLost(note:Note, lane:Lane) {}
	public dynamic function onNoteHit(note:Note, lane:Lane) {}
	
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
		if (newHeld) popCover();
		else noteCover.visible = false;
		return held = newHeld;
	}
	public function new(x:Float, y:Float, data:Int) {
		super(x, y);
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
	}
	
	public override function update(elapsed:Float) {
		super.update(elapsed);
		
		var i:Int = 0;
		var limit:Int = 50;
		while (i < queue.length) {
			var note:Note = queue[i];
			if (note == null) {
				trace('WARNING: Note was null!! (lane ${noteData})');
				queue.remove(note);
				continue;
			}
			if ((note.msTime - Conductor.songPosition) <= spawnRadius && (note.endMs - Conductor.songPosition) >= -spawnRadius) {
				queue.remove(note);
				insertNote(note);
				limit --;
				if (limit < 0) break;
			} else
				i ++;
		}
		
		i = notes.length;
		while (i > 0) {
			i --;
			var note:Note = notes.members[i];
			note.followLane(this, scrollSpeed);
			if (note.ignore) continue;
			if (Conductor.songPosition >= note.msTime && !note.lost && note.canHit && (cpu || held)) {
				if (!note.goodHit) hitNote(note, false);
				playReceptor('confirm', !note.isHoldPiece);
				if (cpu) {
					receptor.animation.finishCallback = (anim:String) -> {
						playReceptor('static', true);
						receptor.animation.finishCallback = null;
					}
				}
				if (Conductor.songPosition >= note.endMs) {
					killNote(note);
					continue;
				}
			}
			if (note.lost || note.goodHit || note.isHoldPiece) {
				if ((note.endMs - Conductor.songPosition) < -spawnRadius) {
					queue.push(note);
					killNote(note);
				}
			} else {
				if (Conductor.songPosition - hitWindow > note.msTime) {
					note.lost = true;
					onNoteLost(note, this);
				}
				if ((note.msTime - Conductor.songPosition) > spawnRadius) {
					queue.push(note);
					killNote(note);
				}
			}
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
		splash.splashOnReceptor(receptor);
	}
	public function popCover() {
		noteCover.popOnReceptor(receptor);
	}
	public function spark() {
		var spark:NoteSpark = noteSparks.recycle(NoteSpark, () -> new NoteSpark(noteData));
		spark.camera = camera;
		spark.sparkOnReceptor(receptor);
	}
	
	public function clearNotes() {
		for (note in notes) note.kill();
		notes.clear();
	}
	public function insertNote(note:Note, pos:Int = 0) {
		if (notes.members.contains(note)) return;
		note.hitWindow = hitWindow;
		note.goodHit = false;
		if (!note.isHoldPiece) {
			note.canHit = true;
			for (child in note.children) child.canHit = false;
		}
		note.scale.copyFrom(receptor.scale);
		note.updateHitbox();
		note.revive();
		notes.insert(pos, note);
		note.followLane(this, scrollSpeed);
	}
	public dynamic function hitNote(note:Note, kill:Bool = true) {
		note.goodHit = true;
		onNoteHit(note, this);
		if (kill) killNote(note);
	}
	public function killNote(note:Note) {
		notes.remove(note, true);
		note.kill();
		onNoteDespawned(note, this);
	}
	
	public function playReceptor(anim:String, forced:Bool = false) if (receptor != null) receptor.playAnimation(anim, forced);
}

class Receptor extends FunkinSprite {
	public var lane:Lane;
	public var noteData:Int;
	
	public function new(x:Float, y:Float, data:Int) {
		super(x, y);
		loadAtlas('NOTE_assets');
		
		this.noteData = data;
		var dirName:String = Note.directionNames[data];
		animation.addByPrefix('static', '${dirName} receptor', 24, true);
		animation.addByPrefix('confirm', '${dirName} confirm', 24, false);
		animation.addByPrefix('press', '${dirName} press', 24, false);
		playAnimation('static', true);
	}
	
	public override function playAnimation(anim:String, forced:Bool = false) {
		super.playAnimation(anim, forced);
		centerOffsets();
		centerOrigin();
	}
}

class NoteSplash extends FunkinSprite {
	public function new(data:Int) {
		super();
		loadAtlas('noteSplashes');
		
		animation.addByPrefix('splash1', 'note impact 1 ${Note.colorNames[data]}', 24, false);
		animation.addByPrefix('splash2', 'note impact 2 ${Note.colorNames[data]}', 24, false);
		
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
		updateHitbox();
		spriteOffset.set(width * .5, height * .5);
	}
}

class NoteCover extends FunkinSprite {
	public function new(data:Int) {
		super();
		loadAtlas('holdCoverRed');
		
		animation.addByPrefix('start', 'holdCoverStartRed', 24, false);
		animation.addByPrefix('loop', 'holdCoverRed', 24, true);
		animation.finishCallback = (anim:String) -> {
			playAnimation('loop');
		};
		visible = false;
	}
	
	public function popOnReceptor(receptor:Receptor) {
		setPosition(receptor.x + receptor.width * .5, receptor.y + receptor.height * .5);
		pop();
	}
	public function pop() {
		playAnimation('start', true);
		visible = true;
		updateHitbox();
		spriteOffset.set(width * .5 + 10, height * .5 - 46);
	}
}

class NoteSpark extends FunkinSprite {
	public function new(data:Int) {
		super(data);
		loadAtlas('holdCoverRed');
		
		animation.addByPrefix('spark', 'holdCoverEndRed', 24, false);
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