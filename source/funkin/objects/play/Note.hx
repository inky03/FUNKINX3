package funkin.objects.play;

import funkin.objects.play.Lane;
import funkin.backend.play.Scoring;
import funkin.backend.rhythm.Event;
import funkin.objects.CharacterGroup;

import flixel.graphics.frames.FlxFrame;
import flixel.addons.display.FlxTiledSprite;
import flixel.graphics.frames.FlxFramesCollection;

@:structInit class ChartNote implements ITimeSortable {
	public var laneIndex:Int;
	public var kind:String = '';
	public var msTime:Float = 0;
	public var msLength:Float = 0;
	public var player:Bool = true;
}

class Note extends FunkinSprite { // todo: pooling?? maybe?? how will this affect society
	public static var directionNames:Array<String> = ['left', 'down', 'up', 'right'];
	public static var directionColors:Array<Array<FlxColor>> = [
		[FlxColor.fromRGB(194, 75, 153), FlxColor.fromRGB(60, 31, 86)],
		[FlxColor.fromRGB(0, 255, 255), FlxColor.fromRGB(21, 66, 183)],
		[FlxColor.fromRGB(18, 250, 5), FlxColor.fromRGB(10, 68, 71)],
		[FlxColor.fromRGB(249, 57, 63), FlxColor.fromRGB(101, 16, 56)],
	];
	public var conductorInUse:Conductor; // mostly charting stuff
	
	public var tail:NoteTail;
	
	public var lane:Lane;
	public var score:Score;
	public var held:Bool = false;
	public var hitTime:Float = -1;
	public var holdTime:Float = -1;
	public var chartNote(default, set):ChartNote;
	
	public var preventDespawn:Bool = false;
	public var consumed:Bool = false;
	public var goodHit:Bool = false;
	public var lost:Bool = false;
	public var canHit:Bool = true;
	
	public var noteOffset:FlxPoint;
	public var clipDistance:Float = 0;
	public var scrollDistance:Float = 0;
	public var followAngle:Bool = true;
	
	public var healthLoss:Float = 6.0 / 100;
	public var healthGain:Float = 1.5 / 100;
	public var healthGainPerSecond:Float = 7.5 / 100; // hold bonus
	public var hitWindow:Float = Scoring.safeFrames * 1000 / 60;
	
	public var noteKind(default, set):String = '';
	public var scrollMultiplier:Float = 1;
	public var directionOffset:Float = 0;
	public var hitPriority:Float = 1;
	public var multAlpha:Float = 1;
	public var player:Bool = false;
	public var ignore:Bool = false;
	public var noteData:Int = 0;

	public var endMs(get, never):Float;
	public var endBeat(get, never):Float;
	public var msTime(default, set):Float = 0;
	public var beatTime(default, set):Float = 0;
	public var msLength(default, set):Float = 0;
	public var beatLength(default, set):Float = 0;
	public var isHoldNote(default, null):Bool = false;
	
	public override function destroy() {
		if (tail != null)
			tail.destroy();
		super.destroy();
		tail = null;
	}
	public override function draw() {
		if (isHoldNote && tail != null)
			tail.draw();
		
		if (!goodHit)
			super.draw();
	}
	
	public function new(songNote:ChartNote, ?conductor:Conductor) {
		super();
		
		this.conductorInUse = conductor ?? FunkinState.getCurrentConductor();
		
		this.chartNote = songNote;
		reload();
	}
	public function set_chartNote(songNote:ChartNote):ChartNote {
		if (songNote != null) {
			this.player = songNote.player;
			this.msTime = songNote.msTime;
			this.noteKind = songNote.kind;
			this.msLength = songNote.msLength;
			this.noteData = songNote.laneIndex;
		}
		this.msLength = Math.max(this.msLength, 0);
		
		return this.chartNote = songNote;
	}
	
	public function reload() {
		lost = goodHit = held = consumed = false;
		holdTime = hitTime = -1;
		clipDistance = 0;
		if (noteOffset == null) {
			noteOffset = FlxPoint.get();
		} else {
			noteOffset.set();
		}
		if (tail != null)
			tail.clipRect = null;
		
		loadAtlas('notes');
		reloadAnimations();
	}
	public function reloadTail() {
		isHoldNote = (msLength > 0);
		if (tail == null && isHoldNote) {
			tail = new NoteTail(this);
		}
	}
	public function reloadAnimations() {
		var dirName:String = directionNames[noteData];
		addAnimation('hit-$noteData', '$dirName note', 24, false);
		playAnimation('hit-$noteData', true);
		/*if (isHoldPiece) {
			addAnimation('tail-$noteData', '$dirName hold tail', 24, false);
			addAnimation('hold-$noteData', '$dirName hold piece', 24, false);
			playAnimation(this.isHoldTail ? 'tail' : 'hold', true);
		}*/
		updateHitbox();
	}
	public function toChartNote():ChartNote {
		return chartNote ?? {laneIndex: noteData, msTime: msTime, kind: noteKind, msLength: msLength, player: player};
	}
	
	public function set_noteKind(newKind:String) {
		return noteKind = newKind;
	}
	public function set_msTime(newTime:Float) {
		if (msTime == newTime) return newTime;
		@:bypassAccessor beatTime = conductorInUse.convertMeasure(newTime, MS, BEAT);
		return msTime = newTime;
	}
	public function set_beatTime(newTime:Float) {
		if (beatTime == newTime) return newTime;
		@:bypassAccessor msTime = conductorInUse.convertMeasure(newTime, BEAT, MS);
		return beatTime = newTime;
	}
	public function set_msLength(newLength:Float) {
		if (msLength == newLength) return newLength;
		msLength = newLength;
		@:bypassAccessor beatLength = conductorInUse.convertMeasure(msTime + newLength, MS, BEAT) - beatTime;
		reloadTail();
		return newLength;
	}
	public function set_beatLength(newLength:Float) {
		if (beatLength == newLength) return newLength;
		beatLength = newLength;
		@:bypassAccessor msLength = conductorInUse.convertMeasure(beatTime + newLength, BEAT, MS) - msTime;
		reloadTail();
		return newLength;
	}
	public function get_endMs()
		return msTime + msLength;
	public function get_endBeat()
		return beatTime + beatLength;
	
	public static function distanceToMS(distance:Float, scrollSpeed:Float)
		return distance / (.45 * scrollSpeed);
	public static function msToDistance(ms:Float, scrollSpeed:Float)
		return ms * (.45 * scrollSpeed);
	public dynamic function followLane(lane:Lane, scrollSpeed:Float) {
		var receptor:Receptor = lane.receptor;
		var speed:Float = scrollSpeed * scrollMultiplier;
		var dir:Float = lane.direction + directionOffset;

		var holdOffsetX:Float = 0;
		var holdOffsetY:Float = 0;

		scrollDistance = Note.msToDistance(msTime - conductorInUse.songPosition, speed);
		
		var xP:Float = 0;
		var yP:Float = scrollDistance;
		var rad:Float = dir / 180 * Math.PI;
		x = receptor.x + noteOffset.x + Math.sin(rad) * xP + Math.cos(rad) * yP + holdOffsetX;
		y = receptor.y + noteOffset.y + Math.sin(rad) * yP + Math.cos(rad) * xP + holdOffsetY;
		alpha = lane.alpha * receptor.alpha * multAlpha;
		
		if (followAngle)
			angle = lane.receptor.angle;
		
		if (isHoldNote && tail != null) {
			var tailY:Float = height * .5;
			tail.setGraphicSize(35, Note.msToDistance(msLength, speed) - tailY);
			tail.angle = dir - 90;
			tail.updateHitbox();
			tail.setPosition(x + (width - tail.width) * .5, y + tailY);
			
			if (goodHit && scrollDistance < 0)
				clipDistance = -scrollDistance;
			
			if (clipDistance > 0) {
				if (tail.clipRect == null)
					tail.clipRect = new FlxRect(0, 0, tail.frameWidth);
				
				var clipDist:Float = (clipDistance / tail.height) * tail.frameHeight;
				tail.clipRect.height = tail.frameHeight - clipDist;
				tail.clipRect.y = clipDist;
				
				tail.clipRect = tail.clipRect;
			}
		}
	}
	inline function clipto(ya:Float = 0, yb:Float = 0)
		clipRect.set(0, ya, frameWidth, yb - ya);
}

class NoteTail extends FunkinSprite {
	public var parent:Note;
	
	public var multAlpha:Float = .6;
	
	public function new(parent:Note) {
		super();
		
		makeGraphic(1, FlxG.height, FlxColor.WHITE);
		origin.set(frameWidth * .5, 0);
		this.parent = parent;
	}
	public override function draw() {
		alpha = multAlpha;
		if (parent != null)
			alpha *= parent.alpha;
		
		super.draw();
	}
}