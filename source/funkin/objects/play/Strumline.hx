package funkin.objects.play;

import funkin.objects.Character;
import funkin.objects.play.Note;
import funkin.backend.play.Scoring;
import funkin.backend.play.NoteEvent;
import funkin.backend.play.NoteStyle;

import flixel.util.FlxAxes;
import flixel.input.keyboard.FlxKey;
import flixel.util.FlxSignal.FlxTypedSignal;

class Strumline extends FunkinSpriteGroup {
	public var noteEvent:FlxTypedSignal<NoteEvent -> Void> = new FlxTypedSignal();
	public var laneSpacing(default, set):Float = 160;
	public var lanes:FunkinTypedSpriteGroup<Lane>;
	
	public var strumlineHeight(get, never):Float;
	public var strumlineWidth(get, never):Float;
	public var receptorHeight(get, never):Float;
	public var bottomBound(get, never):Float;
	public var rightBound(get, never):Float;
	public var leftBound(get, never):Float;
	public var topBound(get, never):Float;
	
	//all lane setters (getters are Not representative of all lanes)
	public var cpu(default, set):Bool; // todo: macro..?
	public var laneCount(default, set):Int;
	public var direction(default, set):Float;
	public var style(default, set):NoteStyle;
	public var scrollSpeed(default, set):Float;
	public var oneWay(default, set):Bool = true;
	public var allowInput(default, set):Bool = true;
	public var character(default, set):ICharacter = null;
	public var noteClass(default, set):Class<Note> = Note;
	public var hitWindow(default, set):Float = Scoring.safeFrames / 60 * 1000;
	
	//oh dear
	function set_cpu(isCpu:Bool) { for (lane in lanes) lane.cpu = isCpu; return cpu = isCpu; }
	function set_oneWay(isOneWay:Bool) { for (lane in lanes) lane.oneWay = isOneWay; return oneWay = isOneWay; }
	function set_style(newStyle:NoteStyle) { if (style == newStyle) return newStyle; loadStyle(newStyle); return style = newStyle; }
	function set_direction(newDir:Float) { for (lane in lanes) lane.direction = newDir; return direction = newDir; }
	function set_hitWindow(newWindow:Float) { for (lane in lanes) lane.hitWindow = newWindow; return hitWindow = newWindow; }
	function set_allowInput(isAllowed:Bool) { for (lane in lanes) lane.allowInput = isAllowed; return allowInput = isAllowed; }
	function set_character(newChara:ICharacter) { for (lane in lanes) lane.character = newChara; return character = newChara; }
	function set_noteClass(newClass:Class<Note>) { for (lane in lanes) lane.noteClass = newClass; return noteClass = newClass; }
	function set_scrollSpeed(newSpeed:Float) { for (lane in lanes) lane.scrollSpeed = newSpeed; return scrollSpeed = newSpeed; }
	function set_laneSpacing(newSpacing:Float) {
		recalculateLaneSpacing(newSpacing, laneSpacing);
		return laneSpacing = newSpacing;
	}
	function set_laneCount(newCount:Int) {
		while (lanes.length > 0 && lanes.length > newCount) {
			var lane:Lane = lanes.members.shift();
			lane.destroy();
		}
		for (i in laneCount...newCount) {
			var lane:Lane = new Lane(i * laneSpacing * scale.x, 0, i, direction, scrollSpeed, style);
			
			lane.allowInput = allowInput;
			lane.noteClass = noteClass;
			lane.hitWindow = hitWindow;
			lane.character = character;
			lane.strumline = this;
			lane.selfDraw = false;
			lane.oneWay = oneWay;
			lane.cpu = cpu;
			
			lane.scale.copyFrom(scale);
			lanes.add(lane);
		}
		return laneCount = newCount;
	}
	
	//more getters
	function get_leftBound() { return findMinXHelper(); }
	function get_rightBound() { return findMaxXHelper(); }
	function get_topBound() { return findMinYHelper(); }
	function get_bottomBound() { return findMaxYHelper(); }
	function get_strumlineWidth() { return width; }
	function get_strumlineHeight() { return height; }
	
	override function findMinX():Float { return (lanes.length > 0 ? findMinXHelper() : x); }
	override function findMaxX():Float { return (lanes.length > 0 ? findMaxXHelper() : x); }
	override function findMinY():Float { return (lanes.length > 0 ? findMinYHelper() : y); }
	override function findMaxY():Float { return (lanes.length > 0 ? findMaxYHelper() : y); }
	override function findMinXHelper():Float {
		var value:Float = Math.POSITIVE_INFINITY;
		for (lane in lanes) {
			var minX:Float = lane.receptor.x;
			if (minX < value) value = minX;
		}
		return value;
	}
	override function findMaxXHelper():Float {
		var value:Float = Math.NEGATIVE_INFINITY;
		for (lane in lanes) {
			var maxX:Float = lane.receptor.x + lane.receptor.width;
			if (maxX > value) value = maxX;
		}
		return value;
	}
	override function findMinYHelper():Float {
		var value:Float = Math.POSITIVE_INFINITY;
		for (lane in lanes) {
			var minY:Float = lane.receptor.y;
			if (minY < value) value = minY;
		}
		return value;
	}
	override function findMaxYHelper():Float {
		var value:Float = Math.NEGATIVE_INFINITY;
		for (lane in lanes) {
			var maxY:Float = lane.receptor.y + lane.receptor.height;
			if (maxY > value) value = maxY;
		}
		return value;
	}
	
	function get_receptorWidth() {
		var width:Float = 0;
		for (lane in lanes) width = Math.max(width, lane.receptor.width);
		return width;
	}
	function get_receptorHeight() {
		var height:Float = 0;
		for (lane in lanes) height = Math.max(height, lane.receptor.height);
		return height;
	}
	
	public function new(laneCount:Int = 4, direction:Float = 90, scrollSpeed:Float = 1, ?style:NoteStyleAsset = 'funkin', ?noteClass:Class<Note>) {
		super();
		this.lanes = new FunkinTypedSpriteGroup();
		this.add(lanes);
		
		this.allowInput = true;
		this.direction = direction;
		this.scrollSpeed = scrollSpeed;
		this.noteClass = noteClass ?? Note;
		
		this.laneCount = laneCount;
		
		this.style = NoteStyle.fetch(style);
	}
	public function loadStyle(newStyle:NoteStyleAsset) {
		var style:NoteStyle = NoteStyle.fetch(newStyle);
		
		laneSpacing = (style?.data.general.laneSpacing ?? laneSpacing);
		
		for (lane in lanes)
			lane.style = style;
	}
	public function recalculateLaneSpacing(newSpacing:Float, oldSpacing:Float) {
		var i:Int = 0;
		var diff:Float = newSpacing - oldSpacing;
		for (lane in lanes) {
			lane.startX += i * diff * scale.x;
			lane.x += i * diff * scale.x;
			i ++;
		}
	}
	public function resetLanePositions():Void {
		for (i => lane in lanes) {
			lane.setPosition(x + i * laneSpacing * scale.x, y);
			lane.startX = lane.x;
			lane.startY = lane.y;
		}
	}
	public function fadeIn() {
		var i:Int = 0;
		for (lane in lanes) {
			lane.alpha = 0;
			var rad:Float = lane.direction / 180 * Math.PI;
			
			FlxTween.cancelTweensOf(lane);
			lane.x = lane.startX - Math.cos(rad) * 10;
			lane.y = lane.startY - Math.sin(rad) * 10;
			FlxTween.tween(lane, {x: lane.startX, y: lane.startY, alpha: alpha}, 1, {ease: FlxEase.circOut, startDelay: .5 + i * .2});
			
			i ++;
		}
		visible = true;
	}
	public function drawSelf() { super.draw(); }
	public override function draw() {
		drawSelf();
		for (lane in lanes) { // draw on top
			if (!lane.selfDraw)
				@:privateAccess lane.drawThing(true);
		}
	}
	public function forEachLane(func:Lane -> Void) {
		for (lane in lanes)
			func(lane);
	}
	public function forEachNote(func:ChartNote -> Void, includeQueued:Bool = false) {
		for (lane in lanes)
			lane.forEachNote(func, includeQueued);
	}
	public function forEachActiveNote(func:Note -> Void) {
		for (lane in lanes)
			lane.forEachActiveNote(func);
	}
	public function getAllNotes() {
		var notes:Array<ChartNote> = [];
		for (lane in lanes) {
			for (note in lane.getAllNotes())
				notes.push(note);
		}
		return notes;
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
			// TODO: better way... ??
			recalculateLaneSpacing(laneSpacing * ratio, laneSpacing);
			scale.set(ratio, ratio);
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
	public function assignKeybinds(keybinds:Array<Array<FlxKey>>) {
		var i = 0;
		for (keybindSet in keybinds) {
			var lane:Lane = getLane(i);
			if (lane != null)
				lane.inputKeys = keybindSet;
			i ++;
		}
	}
	
	public function getNoteLane(note:ChartNote):Lane {
		return getLane(note.laneIndex % laneCount);
	}
	public inline function queueNote(note:ChartNote, ?laneIndex:Int, sort:Bool = false, checkExists:Bool = true):ChartNote {
		var lane:Lane = (laneIndex == null ? getNoteLane(note) : getLane(laneIndex));
		if (lane != null) {
			lane.queueNote(note, sort, checkExists);
			return note;
		}
		
		return null;
	}
	public function dequeueNote(note:ChartNote) {
		for (lane in lanes)
			lane.dequeueNote(note);
	}
	public function clearAllNotes() {
		for (lane in lanes)
			lane.clearNotes();
	}
	public function resetLanes() {
		for (lane in lanes)
			lane.resetLane();
	}
	
	public inline function getLane(index:Int):Lane { return lanes.members[index]; }
	
	public function fireInput(key:flixel.input.keyboard.FlxKey, pressed:Bool) {
		var fired:Bool = false;
		for (lane in lanes) {
			if (lane.fireInput(key, pressed))
				fired = true;
		}
		return fired;
	}
	
	override function set_x(value:Float):Float {
		if (exists && x != value) {
			var diff:Float = (value - x);
			transformChildren(xTransform, diff);
			for (lane in lanes)
				lane.startX += diff;
		}
		return x = value;
	}
	override function set_y(value:Float):Float {
		if (exists && y != value) {
			var diff:Float = (value - y);
			transformChildren(yTransform, diff);
			for (lane in lanes)
				lane.startY += diff;
		}
		return y = value;
	}
}