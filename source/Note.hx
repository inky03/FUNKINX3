package;

import Lane;
import Lane.Receptor;
import Scoring.HitWindow;

class Note extends FunkinSprite { // todo: pooling?? maybe?? how will this affect society
	public static var colorNames:Array<String> = ['purple', 'blue', 'green', 'red'];
	public static var directionNames:Array<String> = ['left', 'down', 'up', 'right'];
	
	public var children:Array<Note> = [];
	public var parent:Note;
	public var tail:Note;
	
	public var ratingData:HitWindow;
	public var goodHit:Bool = false;
	public var lost:Bool = false;
	public var clipHeight:Float;
	public var noteOffset:FlxPoint;
	public var scrollDistance:Float = 0;
	
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
	public var msTime:Float = 0;
	public var msLength:Float = 0;
	public var endMs(get, never):Float;
	
	public var isHoldPiece:Bool = false;
	public var isHoldTail:Bool = false;
	
	public var multAlpha:Float = 1;
	
	public override function revive() {
		lost = false;
		goodHit = false;
		clipHeight = frameHeight;
		super.revive();
	}
	public function get_endMs() return msTime + (isHoldPiece ? msLength : 0);
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
		
		loadAtlas('NOTE_assets');
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
			}
			origin.set(width * .5, 0);
			scale.set(prevSX, isHoldTail ? prevSX : (holdHeight / frameHeight));
		}
		
		var xP:Float = 0;
		var yP:Float = scrollDistance;
		var rad:Float = dir / 180 * Math.PI;
		x = receptor.x + noteOffset.x + Math.sin(rad) * xP + Math.cos(rad) * yP;
		y = receptor.y + noteOffset.y + Math.sin(rad) * yP + Math.cos(rad) * xP;
		alpha = lane.alpha * receptor.alpha * multAlpha;
		
		if (isHoldPiece) { //handle in DISTANCE to support scroll direction
			var clip:Bool = (lane.held);
			if (clip) clipHeight = Math.min(Math.max(0, (holdHeight + scrollDistance) / scale.y), frameHeight);
			var tail:Note = parent.tail;
			var clipBottom:Float = (isHoldTail ? 0 : Math.min(0, (Note.msToDistance(tail.msTime - msTime, scrollSpeed) - tail.frameHeight * tail.scale.x /* lmao */ - holdHeight) / scale.y));
			
			if (clipRect == null) clipRect = new FlxRect();
			clipRect.y = frameHeight - clipHeight;
			clipRect.width = frameWidth;
			clipRect.height = clipHeight + clipBottom;
			clipRect = clipRect; //refresh clip rect
		}
	}
}