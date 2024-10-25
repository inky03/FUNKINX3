package;

import Conductor.MetronomeMeasure;
import openfl.events.KeyboardEvent;
import flixel.input.keyboard.FlxKey;

class CharterState extends MusicBeatState {
	public var quant:Int = 4;
	public var quantGraphic:FunkinSprite;
	public var scrollSpeed(default, set):Float = 1;
	public var measureLines:FlxTypedSpriteGroup<MeasureLine>;
	public var strumlines:FlxTypedSpriteGroup<Strumline>;
	public var keybinds:Array<Array<FlxKey>> = [];
	
	private var heldNotes:Array<Note> = [];
	private var heldKeys:Array<FlxKey> = [];
	private var quants:Array<Int> = [4, 8, 12, 16, 20, 24, 32, 48, 64, 96, 192];
	
	override public function create() {
		conductorInUse.songPosition = 0;
		
		measureLines = new FlxTypedSpriteGroup<MeasureLine>();
		strumlines = new FlxTypedSpriteGroup<Strumline>();
		add(measureLines);
		add(strumlines);
		
		for (key in [FlxKey.ONE, FlxKey.TWO, FlxKey.THREE, FlxKey.FOUR, FlxKey.FIVE, FlxKey.SIX, FlxKey.SEVEN, FlxKey.EIGHT])
			keybinds.push([key]);
		
		var strumlineSpacing:Float = 150;
		var xx:Float = 0;
		var h:Float = 0;
		for (i in 0...2) {
			var strumline = new Strumline(4);
			strumline.x = xx;
			strumline.cpu = false;
			strumlines.add(strumline);
			xx += strumline.strumlineWidth + strumlineSpacing;
			h = Math.max(h, strumline.strumlineHeight);
		}
		strumlines.y = FlxG.height * .5 - h * .5;
		
		strumlines.x = (FlxG.width - (xx - strumlineSpacing)) * .5;
		FlxG.camera.zoom = .5;
		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, keyPressEvent);
		FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, keyReleaseEvent);
		
		quantGraphic = new FunkinSprite().loadAtlas('charter/quant');
		quantGraphic.animation.addByPrefix('quant', 'quant', 0);
		quantGraphic.playAnimation('quant', true);
		quantGraphic.updateHitbox();
		quantGraphic.x = strumlines.x + xx - strumlineSpacing;
		quantGraphic.y = strumlines.y + (h - quantGraphic.height) * .5;
		add(quantGraphic);
		
		for (i in 0...10) {
			var test:MeasureLine = new MeasureLine(strumlines.x, strumlines.y, i, i * 4, 4, xx - strumlineSpacing, Note.msToDistance(conductorInUse.crochet, scrollSpeed));
			measureLines.add(test);
		}
	}
	
	override public function update(elapsed:Float) {
		if (FlxG.keys.justPressed.SPACE) paused = !paused;
		super.update(elapsed);
		
		FlxG.camera.zoom = FlxMath.lerp(FlxG.camera.zoom, .5, elapsed * 5);
		
		for (line in measureLines) {
			line.y = FlxG.height * .5 + Note.msToDistance(conductorInUse.metronome.convertMeasure(line.startTime, BEAT, MS) - conductorInUse.songPosition, scrollSpeed);
		}
		
		if (!paused)
			updateHolds();
	}
	
	override public function beatHit(beat:Int) {
		super.beatHit(beat);
		FlxG.camera.zoom += .003;
		FlxG.sound.play(Paths.sound('beatTick'));
	}
	override public function barHit(bar:Int) {
		super.barHit(bar);
		FlxG.camera.zoom += .006;
	}
	
	public function set_scrollSpeed(newSpeed:Float) {
		//well it has no code right now
		return scrollSpeed = newSpeed;
	}
	
	public function keyPressEvent(event:KeyboardEvent) {
		var key:FlxKey = event.keyCode;
		if (!heldKeys.contains(key)) heldKeys.push(key);
		
		var keybind:Int = Controls.keybindFromArray(keybinds, key);
		if (keybind >= 0 && FlxG.keys.checkStatus(key, JUST_PRESSED)) inputOn(keybind);
		
		var scrollMod:Int = 1;
		var leniency:Float = 1 / 256;
		var prevBeat:Float = conductorInUse.metronome.beat;
		var quantMultiplier:Float = (quant * .25);
		switch (key) {
			case FlxKey.LEFT | FlxKey.RIGHT:
				changeQuant(key == FlxKey.LEFT ? -1 : 1);
			case FlxKey.UP | FlxKey.DOWN:
				if (key == FlxKey.UP) scrollMod *= -1;
				var targetBeat:Float = prevBeat + scrollMod / quantMultiplier;
				if (Math.abs(prevBeat - Math.round(prevBeat * quantMultiplier) / quantMultiplier) < leniency * 2)
					conductorInUse.metronome.setBeat(Math.round(targetBeat * quantMultiplier) / quantMultiplier);
				else
					conductorInUse.metronome.setBeat((scrollMod > 0 ? Math.floor : Math.ceil)(targetBeat * quantMultiplier) / quantMultiplier);
				updateHolds();
			case FlxKey.PAGEUP | FlxKey.PAGEDOWN:
				if (key == FlxKey.PAGEUP) scrollMod *= -1;
				if (Math.abs(conductorInUse.metronome.bar - Std.int(conductorInUse.metronome.bar)) < (1 / quant - .0006))
					conductorInUse.metronome.setBar(conductorInUse.metronome.bar + scrollMod);
				conductorInUse.metronome.setBar((scrollMod == -1 ? Math.floor : Math.ceil)(conductorInUse.metronome.bar));
				updateHolds();
			case FlxKey.HOME:
				conductorInUse.metronome.setMS(0);
			default:
		}
		conductorInUse.metronome.setMS(Math.max(conductorInUse.metronome.ms, 0));
	}
	public function keyReleaseEvent(event:KeyboardEvent) {
		var key:FlxKey = event.keyCode;
		heldKeys.remove(key);
		
		var keybind:Int = Controls.keybindFromArray(keybinds, key);
		if (keybind >= 0) inputOff(keybind);
	}
	
	public function changeQuant(mod:Int) {
		var quantIndex:Int = FlxMath.wrap(quants.indexOf(quant) + mod, 0, quants.length - 1);
		quantGraphic.animation.curAnim.curFrame = Std.int(Math.min(quantIndex, quantGraphic.animation.curAnim.numFrames - 1));
		quant = quants[quantIndex];
	}
	public function inputOn(keybind:Int) {
		var strumlineId:Int = 0;
		var data:Int = keybind;
		for (strumline in strumlines) {
			if (data >= strumline.laneCount) {
				data -= strumline.laneCount;
				strumlineId ++;
			}
		}
		var quantMultiplier:Float = (quant * .25);
		var strumline:Strumline = strumlines.members[strumlineId];
		var lane = strumline.getLane(data);
		var matchingNote:Null<Note> = null;
		for (note in lane.notes) {
			if (note.isHoldPiece) continue;
			if (Math.abs(note.beatTime - conductorInUse.metronome.beat) <= 1 / quantMultiplier)
				matchingNote = note;
		}
		if (matchingNote == null) {
			FlxG.sound.play(Paths.sound('hitsound'), .7);
			var snappedBeat:Float = Math.round(conductorInUse.metronome.beat * quantMultiplier) / quantMultiplier;
			var note:Note = new Note(false, 0, data);
			note.extraData.set('keybind', keybind);
			note.beatTime = snappedBeat;
			note.preventDespawn = true;
			lane.insertNote(note);
			heldNotes.push(note);
		} else {
			for (child in matchingNote.children) lane.killNote(child);
			lane.killNote(matchingNote);
			matchingNote.destroy();
		}
	}
	public function inputOff(keybind:Int) {
		var i:Int = heldNotes.length;
		while (i > 0) {
			i --;
			var note:Note = heldNotes[i];
			if (note == null) {
				trace('WARNING: Note was null');
				heldNotes.remove(note);
				continue;
			}
			if (heldNotes.length == 0 || note.extraData.get('keybind') == keybind) {
				FlxG.sound.play(Paths.sound('hitsoundTail'), .7);
				for (child in note.children) child.preventDespawn = false;
				note.preventDespawn = false;
				heldNotes.remove(note);
			}
		}
	}
	public function updateHolds() {
		var quantMultiplier:Float = (quant * .25);
		var snappedBeat:Float = Math.round(conductorInUse.metronome.beat * quantMultiplier) / quantMultiplier;
		for (note in heldNotes) {
			var lane:Lane = note.lane;
			note.beatLength = snappedBeat - note.beatTime;
			if (note.beatLength > 0) {
				if (note.children.length == 0) {
					var piece:Note = new Note(false, note.msTime, note.noteData, note.msLength, note.noteKind, true);
					piece.preventDespawn = true;
					note.children.push(piece);
					piece.parent = note;
					var tail:Note = new Note(false, note.msTime, note.noteData, 0, note.noteKind, true);
					tail.preventDespawn = true;
					note.children.push(tail);
					tail.parent = note;
					note.tail = tail;
					
					lane.insertNote(tail);
					lane.insertNote(piece);
					
					piece.beatLength = note.beatLength; //What
					tail.beatTime = snappedBeat;
				} else {
					var piece:Note = note.children[0];
					piece.beatLength = note.beatLength;
					note.tail.beatTime = snappedBeat;
					
					lane.updateNote(note.tail);
					lane.updateNote(piece);
				}
			} else {
				while (note.children.length > 0) {
					var child:Note = note.children.shift();
					lane.killNote(child);
					child.destroy();
				}
			}
		}
	}
	
	override public function destroy() {
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, keyPressEvent);
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_UP, keyReleaseEvent);
		super.destroy();
	}
}

class MeasureLine extends FlxSpriteGroup {
	public var barText:FlxText;
	public var startTime:Float;
	public var ySpacing(default, set):Float;
	public var lineWidth(default, set):Float;
	public var measureBeats(default, set):Int;
	public var lines:FlxTypedSpriteGroup<FunkinSprite>; //this is getting outta hand
	
	public function new(x:Float = 0, y:Float = 0, bar:Int = 0, time:Float = 0, beats:Int = 4, width:Float = 160, spacing:Float = 160) {
		super(x, y);
		lines = new FlxTypedSpriteGroup<FunkinSprite>();
		measureBeats = beats;
		ySpacing = spacing;
		lineWidth = width;
		startTime = time;
		
		add(lines);
		
		barText = new FlxText(0, 0, 400, Std.string(bar));
		barText.setFormat(Paths.font('vcr.ttf'), 40, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		barText.y += -barText.height * .5 + 3;
		barText.x = -barText.width - 24;
		add(barText);
	}
	
	public function set_measureBeats(newBeats:Int) {
		if (measureBeats == newBeats) return newBeats;
		while (lines.length > 0 && lines.length >= newBeats) {
			var line = lines.members[0];
			lines.remove(line, true);
			line.destroy();
		}
		var isBar:Bool = true;
		for (i in 0...newBeats) {
			var line:FunkinSprite;
			if (i >= lines.length) {
				line = new FunkinSprite();
				line.makeGraphic(1, 1, -1);
				line.spriteOffset.y = .5;
				lines.add(line);
			} else
				line = cast lines.members[i];
			line.y = i * ySpacing;
			line.setGraphicSize(width, isBar ? 12 : 6);
			line.alpha = (isBar ? .8 : .5);
			line.updateHitbox();
			isBar = false;
		}
		return measureBeats = newBeats;
	}
	public function set_ySpacing(newSpacing:Float) {
		if (ySpacing == newSpacing) return newSpacing;
		var i:Int = 0;
		for (line in lines) {
			line.y = i * newSpacing;
			i ++;
		}
		return ySpacing = newSpacing;
	}
	public function set_lineWidth(newWidth:Float) {
		if (lineWidth == newWidth) return newWidth;
		for (line in lines) {
			line.setGraphicSize(newWidth, line.height);
			line.updateHitbox();
		}
		return lineWidth = newWidth;
	}
}