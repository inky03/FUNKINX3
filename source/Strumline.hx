package;

import flixel.util.FlxAxes;

class Strumline extends FlxSpriteGroup {
	public var laneSpacing(default, set):Float = 160;
	public var lanes:FlxTypedSpriteGroup<Lane>;
	
	public var strumlineHeight(get, never):Float;
	public var strumlineWidth(get, never):Float;
	public var receptorHeight(get, never):Float;
	public var bottomBound(get, never):Float;
	public var rightBound(get, never):Float;
	public var leftBound(get, never):Float;
	public var topBound(get, never):Float;
	
	//all lane setters (getters are Not representative of all lanes)
	public var cpu(default, set):Bool;
	public var hitWindow(default, set):Float;
	public var direction(default, set):Float;
	public var scrollSpeed(default, set):Float;
	public var onNoteDespawned(default, set):(note:Note, lane:Lane)->Void;
	public var onNoteSpawned(default, set):(note:Note, lane:Lane)->Void;
	public var onNoteLost(default, set):(note:Note, lane:Lane)->Void;
	public var onNoteHit(default, set):(note:Note, lane:Lane)->Void;
	
	public function set_cpu(isCpu:Bool) { for (lane in lanes) lane.cpu = isCpu; return cpu = isCpu; }
	public function set_direction(newDir:Float) { for (lane in lanes) lane.direction = newDir; return direction = newDir; }
	public function set_hitWindow(newWindow:Float) { for (lane in lanes) lane.hitWindow = newWindow; return hitWindow = newWindow; }
	public function set_scrollSpeed(newSpeed:Float) { for (lane in lanes) lane.scrollSpeed = newSpeed; return scrollSpeed = newSpeed; }
	//Oh god
	public function set_onNoteDespawned(newFunc:(note:Note, lane:Lane)->Void) { for (lane in lanes) lane.onNoteDespawned = newFunc; return onNoteDespawned = newFunc; }
	public function set_onNoteSpawned(newFunc:(note:Note, lane:Lane)->Void) { for (lane in lanes) lane.onNoteSpawned = newFunc; return onNoteSpawned = newFunc; }
	public function set_onNoteLost(newFunc:(note:Note, lane:Lane)->Void) { for (lane in lanes) lane.onNoteLost = newFunc; return onNoteLost = newFunc; }
	public function set_onNoteHit(newFunc:(note:Note, lane:Lane)->Void) { for (lane in lanes) lane.onNoteHit = newFunc; return onNoteHit = newFunc; }
	public function set_laneSpacing(newSpacing:Float) {
		var i:Int = 0;
		var diff:Float = newSpacing - laneSpacing;
		for (lane in lanes) {
			lane.x += i * diff;
			i ++;
		}
		return laneSpacing = newSpacing;
	}
	
	//getters
	public function get_leftBound() {
		var minX:Float = Math.POSITIVE_INFINITY;
		for (lane in lanes) minX = Math.min(minX, lane.receptor.x);
		return minX;
	}
	public function get_rightBound() {
		var maxX:Float = Math.NEGATIVE_INFINITY;
		for (lane in lanes) maxX = Math.max(maxX, lane.receptor.x + lane.receptor.width);
		return maxX;
	}
	public function get_topBound() {
		var minY:Float = Math.POSITIVE_INFINITY;
		for (lane in lanes) minY = Math.min(minY, lane.receptor.y);
		return minY;
	}
	public function get_bottomBound() {
		var maxY:Float = Math.NEGATIVE_INFINITY;
		for (lane in lanes) maxY = Math.max(maxY, lane.receptor.y + lane.receptor.height);
		return maxY;
	}
	public function get_strumlineWidth() {
		var minX:Float = Math.POSITIVE_INFINITY;
		var maxX:Float = Math.NEGATIVE_INFINITY;
		for (lane in lanes) {
			minX = Math.min(minX, lane.receptor.x);
			maxX = Math.max(maxX, lane.receptor.x + lane.receptor.width);
		}
		return (maxX - minX);
	}
	public function get_strumlineHeight() {
		var minY:Float = Math.POSITIVE_INFINITY;
		var maxY:Float = Math.NEGATIVE_INFINITY;
		for (lane in lanes) {
			minY = Math.min(minY, lane.receptor.y);
			maxY = Math.max(maxY, lane.receptor.y + lane.receptor.height);
		}
		return (maxY - minY);
	}
	public function get_receptorWidth() {
		var width:Float = 0;
		for (lane in lanes) height = Math.max(height, lane.receptor.height);
		return width;
	}
	public function get_receptorHeight() {
		var height:Float = 0;
		for (lane in lanes) height = Math.max(height, lane.receptor.height);
		return height;
	}
	public override function get_width() return strumlineWidth;
	public override function get_height() return strumlineHeight;
	
	public function new(noteCount:Int = 4, direction:Float = 90, scrollSpeed:Float = 1) {
		super();
		this.lanes = new FlxTypedSpriteGroup<Lane>();
		for (i in 0...noteCount) {
			var lane:Lane = new Lane(i * laneSpacing, 0, i);
			lane.strumline = this;
			lanes.add(lane);
		}
		this.add(lanes);
		this.direction = direction;
		this.scrollSpeed = scrollSpeed;
		this.onNoteHit = (note:Note, lane:Lane) -> {
			lane.playReceptor('confirm', !note.isHoldPiece);
			if (!note.isHoldPiece && note.msLength > 0) {
				for (child in note.children) child.canHit = true;
				lane.held = true;
			}
			if (note.isHoldTail) {
				lane.held = false;
				if (!lane.cpu) lane.spark();
			}
		};
	}
	
	public function fitToSize(targetWidth:Float = 0, targetHeight:Float = 0, center:FlxAxes = NONE) {
		var wRatio:Float = (targetWidth > 0 ? targetWidth / width : 1);
		var hRatio:Float = (targetHeight > 0 ? targetHeight / height : 1);
		var ratio:Float = Math.min(wRatio, hRatio);
		if (ratio != 1) {
			switch (center) {
				case X:
					x += (width - width * ratio) * .5;
				case Y:
					y += (height - height * ratio) * .5;
				case XY:
					x += (width - width * ratio) * .5;
					y += (height - height * ratio) * .5;
				default:
					//shrug
			}
			for (lane in lanes) {
				lane.receptor.setGraphicSize(lane.receptor.width * ratio);
				lane.receptor.updateHitbox();
				lane.receptor.spriteOffset.set(0, 0);
				lane.updateHitbox();
			}
			laneSpacing *= ratio;
			updateHitbox();
		}
	}
	public function center(axes:FlxAxes = XY) { //do Not inline that.
		switch (axes) {
			case X:
				x = (FlxG.width - strumlineWidth) * .5;
			case Y:
				y = (FlxG.height - receptorHeight) * .5;
			case XY:
				setPosition((FlxG.width - strumlineWidth) * .5, (FlxG.height - receptorHeight) * .5);
			default:
				//well, nothing..
		}
		return this;
	}
	
	public function clearNotes() {
		for (lane in lanes) lane.clearNotes();
	}
	
	public function getLane(noteData:Int) return lanes.members[noteData];
}