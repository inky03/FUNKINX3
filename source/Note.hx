package;

import Lane;
import Lane.Receptor;
import Scoring.HitWindow;
import Conductor.Metronome;
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
	public var conductorInUse:Conductor = Conductor.global; // mostly charting stuff

	public var children:Array<Note> = [];
	public var parent:Note;
	public var tail:Note;
	public var lane:Lane;
	
	public var ratingData:HitWindow;
	public var goodHit:Bool = false;
	public var lost:Bool = false;
	public var noteOffset:FlxPoint;
	public var clipHeight:Float = 0;
	public var scrollDistance:Float = 0;
	public var preventDespawn:Bool = false;
	
	public var healthLoss:Float = .0775 * .5;
	public var healthGain:Float = .033 * .5;
	public var hitWindow:Float = 10000 / 60;
	public var scrollMultiplier:Float = 1;
	public var directionOffset:Float = 0;
	public var hitPriority:Float = 1;
	public var noteKind:String = '';
	public var multAlpha:Float = 1;
	public var player:Bool = false;
	public var ignore:Bool = false;
	public var canHit:Bool = true;
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
		for (child in children)
			child.destroy();
		super.destroy();
	}
	public override function revive() {
		lost = false;
		goodHit = false;
		clipHeight = frameHeight;
		super.revive();
	}

	public function new(player:Bool, msTime:Float, noteData:Int, msLength:Float = 0, type:String = '', isHoldPiece:Bool = false, ?conductor:Conductor) {
		super();
		
		this.conductorInUse = conductor ?? MusicBeatState.getCurrentConductor();

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
		animation.addByPrefix('hit', '$dirName note', 24, false);
		playAnimation('hit', true);
		if (isHoldPiece) {
			animation.addByPrefix('hold', '$dirName hold piece', 24, false);
			animation.addByPrefix('tail', '$dirName hold tail', 24, false);
			playAnimation(this.isHoldTail ? 'tail' : 'hold', true);
		}
		updateHitbox();
		clipHeight = frameHeight;
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
	public function get_endMs() return msTime + (isHoldPiece ? msLength : 0);
	public function get_endBeat() return beatTime + (isHoldPiece ? beatLength : 0);
	
	public static function distanceToMS(distance:Float, scrollSpeed:Float) {
		return distance / (.45 * scrollSpeed);
	}
	public static function msToDistance(ms:Float, scrollSpeed:Float) {
		return ms * (.45 * scrollSpeed);
	}
	public dynamic function followLane(lane:Lane, scrollSpeed:Float) {
		var receptor:Receptor = lane.receptor;
		var speed:Float = scrollSpeed * scrollMultiplier;
		var dir:Float = lane.direction + directionOffset;

		var holdHeight:Float = 0;
		var holdOffsetX:Float = 0;
		var holdOffsetY:Float = 0;
		var cutHeight:Float = frameHeight;

		scrollDistance = Note.msToDistance(msTime - conductorInUse.songPosition, speed);
		if (isHoldPiece) {
			if (isHoldTail) {
				scale.y = scale.x; updateHitbox();
				scrollDistance -= height;
				holdHeight = height;
			} else {
				cutHeight = frameHeight - 1;
				holdHeight = Note.msToDistance(msLength, scrollSpeed);
				scale.y = holdHeight / cutHeight; updateHitbox();
			}
			setOffset();
			origin.set(frameWidth * .5);
			holdOffsetX = (receptor.width - frameWidth) * .5;
			holdOffsetY = receptor.height * .5;
			angle = dir - 90;
		}
		
		var xP:Float = 0;
		var yP:Float = scrollDistance;
		var rad:Float = dir / 180 * Math.PI;
		x = receptor.x + noteOffset.x + Math.sin(rad) * xP + Math.cos(rad) * yP + holdOffsetX;
		y = receptor.y + noteOffset.y + Math.sin(rad) * yP + Math.cos(rad) * xP + holdOffsetY;
		alpha = lane.alpha * receptor.alpha * multAlpha;
		
		if (isHoldPiece) { //handle in DISTANCE to support scroll direction
			var clip:Bool = (lane.held);
			if (clip) clipHeight = Math.min(Math.max(0, (holdHeight + scrollDistance) / scale.y), cutHeight);
			
			var clipBottom:Float = 0;
			if (parent != null && parent.tail != null) {
				var tail:Note = parent.tail;
				clipBottom = (isHoldTail ? 0 : Math.min(0, (Note.msToDistance(tail.msTime - msTime, scrollSpeed) - tail.height - holdHeight) / scale.y));
			}
			
			if (clipRect == null) clipRect = new FlxRect();
			clipRect.y = cutHeight - clipHeight;
			clipRect.width = frameWidth;
			clipRect.height = clipHeight + clipBottom;
			clipRect = clipRect; //refresh clip rect
		}
	}
}