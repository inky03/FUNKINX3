package funkin.objects.play;

import funkin.objects.play.Lane;
import funkin.backend.play.Scoring;
import funkin.objects.CharacterGroup;

import flixel.graphics.frames.FlxFrame;
import flixel.addons.display.FlxTiledSprite;
import flixel.graphics.frames.FlxFramesCollection;

class Note extends FunkinSprite { // todo: pooling?? maybe?? how will this affect society
	public static var directionNames:Array<String> = ['left', 'down', 'up', 'right'];
	public static var directionColors:Array<Array<FlxColor>> = [
		[FlxColor.fromRGB(194, 75, 153), FlxColor.fromRGB(60, 31, 86)],
		[FlxColor.fromRGB(0, 255, 255), FlxColor.fromRGB(21, 66, 183)],
		[FlxColor.fromRGB(18, 250, 5), FlxColor.fromRGB(10, 68, 71)],
		[FlxColor.fromRGB(249, 57, 63), FlxColor.fromRGB(101, 16, 56)],
	];
	public var conductorInUse:Conductor; // mostly charting stuff

	public var children:Array<Note> = [];
	public var parent:Note;
	public var tail:Note;
	public var lane:Lane;
	
	public var score:Score;
	public var consumed:Bool = false;
	public var goodHit:Bool = false;
	public var lost:Bool = false;
	public var noteOffset:FlxPoint;
	public var clipDistance:Float = 0;
	public var scrollDistance:Float = 0;
	public var preventDespawn:Bool = false;
	public var followAngle:Bool = true;
	public var canHit:Bool = true;
	public var hitTime:Float = 0;
	public var held:Bool = false;
	
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
	
	public var isHoldPiece:Bool = false;
	public var isHoldTail:Bool = false;
	
	public override function destroy() {
		for (child in children) {
			lane?.dequeueNote(child);
			lane?.killNote(child);
			child.destroy();
		}
		lane?.dequeueNote(this);
		lane?.killNote(this);
		super.destroy();
	}
	public override function revive() {
		hitTime = 0;
		held = false;
		lost = false;
		goodHit = false;
		consumed = false;
		clipDistance = 0;
		if (!isHoldPiece) {
			canHit = true;
			for (child in children)
				child.canHit = false;
		}
		super.revive();
	}
	
	public function new(player:Bool, msTime:Float, noteData:Int, msLength:Float = 0, type:String = '', isHoldPiece:Bool = false, ?conductor:Conductor) {
		super();
		
		this.conductorInUse = conductor ?? FunkinState.getCurrentConductor();

		this.player = player;
		this.msTime = msTime;
		this.noteKind = type;
		this.noteData = noteData;
		this.msLength = Math.max(msLength, 0);
		
		this.isHoldPiece = isHoldPiece;
		this.isHoldTail = (isHoldPiece && msLength <= 0);
		noteOffset = FlxPoint.get();
		
		if (isHoldPiece) this.multAlpha = .6;
		
		loadAtlas('notes');
		reloadAnimations();
	}

	public function reloadAnimations() {
		animation.destroyAnimations();
		var dirName:String = directionNames[noteData];
		addAnimation('hit', '$dirName note', 24, false);
		playAnimation('hit', true);
		if (isHoldPiece) {
			addAnimation('tail', '$dirName hold tail', 24, false);
			addAnimation('hold', '$dirName hold piece', 24, false);
			playAnimation(this.isHoldTail ? 'tail' : 'hold', true);
		}
		updateHitbox();
	}
	public function toChartNote():funkin.backend.play.Chart.ChartNote {
		return {laneIndex: noteData, msTime: msTime, kind: noteKind, msLength: msLength, player: player};
	}
	
	public function set_noteKind(newKind:String) {
		return noteKind = newKind;
	}
	public function set_msTime(newTime:Float) {
		if (msTime == newTime) return newTime;
		@:bypassAccessor beatTime = conductorInUse.metronome.convertMeasure(newTime, MS, BEAT);
		return msTime = newTime;
	}
	public function set_beatTime(newTime:Float) {
		if (beatTime == newTime) return newTime;
		@:bypassAccessor msTime = conductorInUse.metronome.convertMeasure(newTime, BEAT, MS);
		return beatTime = newTime;
	}
	public function set_msLength(newLength:Float) {
		if (msLength == newLength) return newLength;
		@:bypassAccessor beatLength = conductorInUse.metronome.convertMeasure(msTime + newLength, MS, BEAT) - beatTime;
		return msLength = newLength;
	}
	public function set_beatLength(newLength:Float) {
		if (beatLength == newLength) return newLength;
		@:bypassAccessor msLength = conductorInUse.metronome.convertMeasure(beatTime + newLength, BEAT, MS) - msTime;
		return beatLength = newLength;
	}
	public function get_endMs()
		return msTime + (isHoldPiece ? msLength : 0);
	public function get_endBeat()
		return beatTime + (isHoldPiece ? beatLength : 0);
	
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
		if (isHoldPiece) {
			if (isHoldTail) {
				scale.y = scale.x; updateHitbox();
				scrollDistance -= height;
			} else {
				scrollDistance -= scale.y;
			}
			setOffset();
			origin.set(frameWidth * .5);
			holdOffsetX = (receptor.width - frameWidth) * .5;
			holdOffsetY = receptor.height * .5;
			angle = dir - 90;
		} else if (followAngle) {
			angle = lane.receptor.angle;
		}
		
		var xP:Float = 0;
		var yP:Float = scrollDistance;
		var rad:Float = dir / 180 * Math.PI;
		x = receptor.x + noteOffset.x + Math.sin(rad) * xP + Math.cos(rad) * yP + holdOffsetX;
		y = receptor.y + noteOffset.y + Math.sin(rad) * yP + Math.cos(rad) * xP + holdOffsetY;
		alpha = lane.alpha * receptor.alpha * multAlpha;

		if (isHoldPiece) { //handle in DISTANCE to support scroll direction
			if (canHit && lane.held)
				clipDistance = Math.max(0, -scrollDistance);

			var cropTop:Float = 0;
			var cropBottom:Float = frameHeight;
			var cropY:Float = clipDistance / scale.y;
			var cropHeight:Float = frameHeight;
			if (!isHoldTail) {
				final holdDist:Float = Note.msToDistance(msLength, scrollSpeed);
				cropTop ++;
				cropHeight --;
				scale.y = holdDist / (cropHeight - cropTop);
				tail = parent?.tail;
				if (tail != null)
					cropBottom += Math.min(0, (Note.msToDistance(tail.msTime - msTime, scrollSpeed) - tail.height) / scale.y - (cropHeight - cropTop));
				// if anyone can help me figure out how to make it clip exactly to the tail id appreciate it
			}
			clipRect ??= new FlxRect();
			clipto(Math.max(cropTop, cropY), Math.min(cropHeight, cropBottom));

			clipRect = clipRect; //refresh clip rect
		}
	}
	inline function clipto(ya:Float = 0, yb:Float = 0)
		clipRect.set(0, ya, frameWidth, yb - ya);
}