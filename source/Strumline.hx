package;

import flixel.input.keyboard.FlxKey;
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
	public var laneCount(default, set):Int;
	public var hitWindow(default, set):Float;
	public var direction(default, set):Float;
	public var scrollSpeed(default, set):Float;
	
	//oh dear
	public function set_cpu(isCpu:Bool) { for (lane in lanes) lane.cpu = isCpu; return cpu = isCpu; }
	public function set_direction(newDir:Float) { for (lane in lanes) lane.direction = newDir; return direction = newDir; }
	public function set_hitWindow(newWindow:Float) { for (lane in lanes) lane.hitWindow = newWindow; return hitWindow = newWindow; }
	public function set_scrollSpeed(newSpeed:Float) { for (lane in lanes) lane.scrollSpeed = newSpeed; return scrollSpeed = newSpeed; }
	public function set_laneSpacing(newSpacing:Float) {
		var i:Int = 0;
		var diff:Float = newSpacing - laneSpacing;
		for (lane in lanes) {
			lane.x += i * diff;
			i ++;
		}
		return laneSpacing = newSpacing;
	}
	public function set_laneCount(newCount:Int) {
		while (lanes.length > 0 && lanes.length > newCount) {
			var lane = lanes.members[lanes.length - 1];
			lanes.remove(lane, true);
			lane.destroy();
		}
		for (i in laneCount...newCount) {
			var lane:Lane = new Lane(i * laneSpacing * scale.x, 0, i);
			lane.strumline = this;
			lanes.add(lane);
		}
		return laneCount = newCount;
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
	
	public function new(laneCount:Int = 4, direction:Float = 90, scrollSpeed:Float = 1) {
		super();
		this.lanes = new FlxTypedSpriteGroup<Lane>();
		this.add(lanes);
		this.laneCount = laneCount;
		this.direction = direction;
		this.scrollSpeed = scrollSpeed;
		this.addEvent(function (e:Lane.NoteEvent):Void {
			if (e.type == HIT) {
				var note:Note = e.note;
				var lane:Lane = e.lane;
				lane.receptor.playAnimation('confirm', true);
				if (!note.isHoldPiece) {
					if (note.msLength > 0) {
						for (child in note.children) child.canHit = true;
						lane.held = true;
					} else if (!lane.cpu) {
						lane.receptor.grayBeat = note.beatTime + 1;
					}
				}
				if (note.isHoldTail) {
					lane.held = false;
					if (!lane.cpu) {
						lane.spark();
						lane.receptor.playAnimation('press', true);
					}
				}
			}
		});
	}
	public function fadeIn() {
		var i:Int = 0;
		var targetY:Float = y;
		for (lane in lanes) {
			lane.alpha = 0;
			var targetX:Float = x + i * laneSpacing;
			var rad:Float = lane.direction / 180 * Math.PI;
			
			FlxTween.cancelTweensOf(lane);
			lane.x = targetX - Math.cos(rad) * 10;
			lane.y = targetY - Math.sin(rad) * 10;
			FlxTween.tween(lane, {x: targetX, y: targetY, alpha: 1}, 1, {ease: FlxEase.circOut, startDelay: .5 + i * .2});
			
			i ++;
		}
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
				lane.receptor.scale.x *= ratio;
				lane.receptor.scale.y *= ratio;
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
	public function assignKeys(keybinds:Array<Array<FlxKey>>) {
		var i = 0;
		for (keybindSet in keybinds) {
			var lane:Lane = getLane(i);
			if (lane != null)
				lane.inputKeys = keybindSet;
			i ++;
		}
	}
	
	public function clearAllNotes() {
		for (lane in lanes) {
			lane.clearNotes();
			lane.queue = [];
		}
	}
	
	public function getLane(noteData:Int) return lanes.members[noteData];

	public function addEvent(event:Lane.NoteEvent->Void) {
		for (lane in lanes)
			lane.noteEvent.add(event);
		return event;
	}
}