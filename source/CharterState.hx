package;

import Conductor.MetronomeMeasure;
import openfl.events.KeyboardEvent;
import flixel.input.keyboard.FlxKey;

class CharterState extends MusicBeatState {
	public var quant:Float = 4;
	public var scrollSpeed(default, set):Float = 1;
	public var measureLines:FlxTypedSpriteGroup<MeasureLine>;
	public var strumlines:FlxTypedSpriteGroup<Strumline>;
	public var keybinds:Array<Array<FlxKey>> = [];
	private var heldKeys:Array<FlxKey> = [];
	
	override public function create() {
		Conductor.songPosition = 0;
		
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
		
		for (i in 0...10) {
			var test:MeasureLine = new MeasureLine(strumlines.x, strumlines.y, i, i * 4, 4, xx - strumlineSpacing, Note.msToDistance(Conductor.crochet, scrollSpeed));
			measureLines.add(test);
		}
	}
	
	override public function update(elapsed:Float) {
		if (FlxG.keys.justPressed.SPACE) paused = !paused;
		super.update(elapsed);
		
		FlxG.camera.zoom = FlxMath.lerp(FlxG.camera.zoom, .5, elapsed * 5);
		
		for (line in measureLines) {
			line.y = FlxG.height * .5 + Note.msToDistance(Conductor.convertMeasure(line.startTime, BEAT, MS) - Conductor.songPosition, scrollSpeed);
		}
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
		var prevBeat:Float = Conductor.metronome.beat;
		switch (key) {
			case FlxKey.UP | FlxKey.DOWN:
				if (key == FlxKey.UP) scrollMod *= -1;
				if (Math.abs(Conductor.metronome.beat - Std.int(Conductor.metronome.beat)) < 1 / quant)
					Conductor.metronome.setBeat(Conductor.metronome.beat + scrollMod / quant * 4);
				Conductor.metronome.setBeat((scrollMod == -1 ? Math.floor : Math.ceil)(Conductor.metronome.beat));
			case FlxKey.PAGEUP | FlxKey.PAGEDOWN:
				if (key == FlxKey.PAGEUP) scrollMod *= -1;
				if (Math.abs(Conductor.metronome.beat - Std.int(Conductor.metronome.beat)) < 1 / quant)
					Conductor.metronome.setBar(Conductor.metronome.bar + scrollMod);
				Conductor.metronome.setBar((scrollMod == -1 ? Math.floor : Math.ceil)(Conductor.metronome.bar));
			case FlxKey.HOME:
				Conductor.metronome.setMS(0);
			default:
		}
		Conductor.metronome.setMS(Math.max(Conductor.metronome.ms, 0));
	}
	public function keyReleaseEvent(event:KeyboardEvent) {
		var key:FlxKey = event.keyCode;
		heldKeys.remove(key);
		
		var keybind:Int = Controls.keybindFromArray(keybinds, key);
		if (keybind >= 0) inputOff(keybind);
	}
	
	public function inputOn(keybind:Int) {
		var strumlineId:Int = 0;
		for (strumline in strumlines) {
			if (keybind >= strumline.laneCount) {
				keybind -= strumline.laneCount;
				strumlineId ++;
			}
		}
		var strumline:Strumline = strumlines.members[strumlineId];
		var lane = strumline.getLane(keybind);
		var matchingNote:Null<Note> = null;
		for (note in lane.notes) {
			if (Math.abs(note.beatTime - Conductor.metronome.beat) < 1 / quant)
				matchingNote = note;
		}
		if (matchingNote == null) {
			var note:Note = new Note(false, 0, keybind);
			note.beatTime = Conductor.metronome.beat;
			lane.insertNote(note);
		} else {
			lane.notes.remove(matchingNote, true);
			matchingNote.destroy();
		}
	}
	public function inputOff(keybind:Int) {
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