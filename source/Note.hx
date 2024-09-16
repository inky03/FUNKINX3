package;

import Lane;
import Lane.Receptor;
import Scoring.HitWindow;
import flixel.graphics.frames.FlxFrame;
import flixel.graphics.frames.FlxFramesCollection;
import flixel.addons.display.FlxTiledSprite;

class Note extends FunkinSprite { // todo: pooling?? maybe?? how will this affect society
	public static var directionNames:Array<String> = ['left', 'down', 'up', 'right'];
	public static var directionColors:Array<Array<FlxColor>> = [
		[FlxColor.fromRGB(194, 75, 153), FlxColor.fromRGB(60, 31, 86)],
		[FlxColor.fromRGB(0, 255, 255), FlxColor.fromRGB(21, 66, 183)],
		[FlxColor.fromRGB(18, 250, 5), FlxColor.fromRGB(10, 68, 71)],
		[FlxColor.fromRGB(249, 57, 63), FlxColor.fromRGB(101, 16, 56)],
	];

	public var children:Array<Note> = [];
	public var parent:Note;
	public var tail:Note;
	public var lane:Lane;
	
	public var ratingData:HitWindow;
	public var goodHit:Bool = false;
	public var lost:Bool = false;
	public var clipHeight:Float;
	public var noteOffset:FlxPoint;
	public var scrollDistance:Float = 0;
	public var preventDespawn:Bool = false;
	
	public var healthLoss:Float = .0775 * .5;
	public var healthGain:Float = .033 * .5;
	public var hitWindow:Float = 10000 / 60;
	public var scrollMultiplier:Float = 1;
	public var directionOffset:Float = 0;
	public var hitPriority:Float = 1;
	public var noteKind:String = '';
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
	
	public var multAlpha:Float = 1;
	
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
	public function get_endMs() return msTime + (isHoldPiece ? msLength : 0);
	public function get_endBeat() return beatTime + (isHoldPiece ? beatLength : 0);
	public function new(player:Bool, msTime:Float, noteData:Int, msLength:Float = 0, type:String = '', isHoldPiece:Bool = false) {
		super();
		this.player = player;
		this.msTime = msTime;
		this.noteData = noteData;
		this.msLength = msLength;
		this.noteKind = type;
		this.isHoldPiece = isHoldPiece;
		this.isHoldTail = (isHoldPiece && msLength <= 0);
		noteOffset = FlxPoint.get();

		loadAtlas('notes');
		var dirName:String = Note.directionNames[noteData];
		
		animation.addByPrefix('main', '${dirName} note', 24, false);
		playAnimation('main');
		if (isHoldPiece) {
			animation.addByPrefix('hold', '${dirName} hold piece', 24, false);
			animation.addByPrefix('tail', '${dirName} hold tail', 24, false);
			playAnimation(this.isHoldTail ? 'tail' : 'hold');
			multAlpha = .6;
		}
		updateHitbox();
		clipHeight = frameHeight;
	}
	public function set_msTime(newTime:Float) {
		if (msTime == newTime) return newTime;
		Reflect.setField(this, 'beatTime', Conductor.convertMeasure(newTime, MS, BEAT));
		return msTime = newTime;
	}
	public function set_beatTime(newTime:Float) {
		if (beatTime == newTime) return newTime;
		Reflect.setField(this, 'msTime', Conductor.convertMeasure(newTime, BEAT, MS));
		return beatTime = newTime;
	}
	public function set_msLength(newLength:Float) {
		if (msLength == newLength) return newLength;
		Reflect.setField(this, 'beatLength', Conductor.convertMeasure(msTime + newLength, MS, BEAT) - beatTime);
		return msLength = newLength;
	}
	public function set_beatLength(newLength:Float) {
		if (beatLength == newLength) return newLength;
		Reflect.setField(this, 'msLength', Conductor.convertMeasure(beatTime + newLength, BEAT, MS) - msTime);
		return beatLength = newLength;
	}
	
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
		var prevDist:Float = scrollDistance;
		var holdHeight:Float = 0;
		var cutHeight:Float = frameHeight;
		scrollDistance = Note.msToDistance(msTime - Conductor.songPosition, speed);
		
		if (isHoldPiece) { //im jumping off a building
			var prevSX:Float = scale.x;
			holdHeight = Note.msToDistance(msLength, scrollSpeed);
			angle = dir - 90;
			scale.set(1, 1);
			updateHitbox();
			noteOffset.x = (receptor.width - width) * .5;
			noteOffset.y = receptor.height * .5;
			if (isHoldTail) {
				scrollDistance -= frameHeight * prevSX;
				holdHeight = frameHeight * prevSX;
			} else
				cutHeight = frameHeight - 1;
			origin.set(width * .5, 0);
			scale.set(prevSX, isHoldTail ? prevSX : (holdHeight / cutHeight));
		}
		
		var xP:Float = 0;
		var yP:Float = scrollDistance;
		var rad:Float = dir / 180 * Math.PI;
		x = receptor.x + noteOffset.x + Math.sin(rad) * xP + Math.cos(rad) * yP;
		y = receptor.y + noteOffset.y + Math.sin(rad) * yP + Math.cos(rad) * xP;
		alpha = lane.alpha * receptor.alpha * multAlpha;
		
		if (isHoldPiece) { //handle in DISTANCE to support scroll direction
			var clip:Bool = (lane.held);
			if (clip) clipHeight = Math.min(Math.max(0, (holdHeight + scrollDistance) / scale.y), cutHeight);
			
			var clipBottom:Float = 0;
			if (parent != null && parent.tail != null) {
				var tail:Note = parent.tail;
				clipBottom = (isHoldTail ? 0 : Math.min(0, (Note.msToDistance(tail.msTime - msTime, scrollSpeed) - tail.frameHeight * tail.scale.x /* lmao */ - holdHeight) / scale.y));
			}
			
			if (clipRect == null) clipRect = new FlxRect();
			clipRect.y = cutHeight - clipHeight;
			clipRect.width = frameWidth;
			clipRect.height = clipHeight + clipBottom;
			clipRect = clipRect; //refresh clip rect
		}
	}
}

class NoteBody extends FunkinSprite {
	public function new() {
		super();
	}
}

class NoteTail extends FlxSpriteGroup {
	var hold:FlxTiledSprite;
	var tail:FunkinSprite;
	var holdHeight(default, set):Float;
	
	public function new(strumIndex:Int) {
		super();
		var dirName:String = Note.directionNames[strumIndex];
		
		tail = new FunkinSprite();
		tail.loadAtlas('NOTE_assets');
		tail.animation.addByPrefix('tail', '${dirName} hold tail', 24, false);
		tail.playAnimation('tail');
		tail.updateHitbox();
		add(tail);
		
		var pieceGraphic:FlxGraphic = null;
		if (tail.frames != null) {
			var pieceFrames:Array<FlxFrame> = tail.frames.getAllByPrefix('${dirName} hold piece');
			if (pieceFrames.length > 0) {
				pieceGraphic = FlxGraphic.fromFrame(pieceFrames[0]);
			}
		}
		hold = new FlxTiledSprite(pieceGraphic, pieceGraphic.width, pieceGraphic.height, false, true);
		add(hold);
		
		hold.origin.set(hold.width * .5, 0);
		tail.origin.set(tail.width * .5, 0);
		origin.set(width * .5, 0);
		holdHeight = 500;
	}
	public function set_holdHeight(newHeight:Float) {
		if (holdHeight == newHeight) return newHeight;
		hold.height = newHeight - tail.offset.y;
		refreshTailPos();
		return holdHeight = newHeight;
	}
	public override function set_angle(newAngle:Float) {
		if (angle == newAngle) return newAngle;
		super.set_angle(newAngle);
		hold.angle = newAngle;
		tail.angle = newAngle;
		refreshTailPos();
		return newAngle;
	}
	public function refreshTailPos() {
		var rad:Float = angle / 180 * Math.PI;
		var target:Float = hold.height;
		tail.x = Math.sin(rad) * target;
		tail.y = Math.cos(rad) * target;
	}
	public override function draw() {
		hold.draw();
		tail.draw();
	}
}