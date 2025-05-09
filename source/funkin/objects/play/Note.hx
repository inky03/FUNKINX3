package funkin.objects.play;

import funkin.shaders.RGBSwap;
import funkin.objects.play.Lane;
import funkin.backend.play.Scoring;
import funkin.backend.rhythm.Event;
import funkin.backend.FunkinSprite;
import funkin.backend.play.NoteStyle;
import funkin.objects.CharacterGroup;
import funkin.backend.FunkinStrip;

import flixel.math.FlxMatrix;
import flixel.graphics.frames.FlxFrame;
import flixel.graphics.tile.FlxDrawTrianglesItem.DrawData;

using funkin.backend.play.NoteStyle.NoteStyleUtil;

@:structInit class ChartNote implements ISpriteVars implements ITimeSortable {
	public var laneIndex:Int;
	public var kind:String = '';
	public var msTime:Float = 0;
	public var msLength:Float = 0;
	public var strumlineIndex:Int = 0;
	public var extraData:Map<String, Dynamic> = null;
	
	public inline function copy(?toNote:ChartNote):ChartNote {
		if (toNote == null) {
			return {strumlineIndex: strumlineIndex, laneIndex: laneIndex, msLength: msLength, msTime: msTime, kind: kind};
		} else {
			toNote.strumlineIndex = strumlineIndex;
			toNote.laneIndex = laneIndex;
			toNote.msLength = msLength;
			toNote.msTime = msTime;
			toNote.kind = kind;
			return toNote;
		}
	}
	
	public function setVar(k:String, v:Dynamic):Dynamic {
		if (extraData == null) extraData = new Map();
		extraData.set(k, v);
		return v;
	}
	public function getVar(k:String):Dynamic {
		if (extraData == null) return null;
		return extraData.get(k);
	}
	public function hasVar(k:String):Bool {
		if (extraData == null) return false;
		return extraData.exists(k);
	}
	public function removeVar(k:String):Bool {
		if (extraData == null) return false;
		return extraData.remove(k);
	}
	
	function set_kind(v:String):String { return kind = v; }
	function set_msTime(v:Float):Float { return msTime = v; }
	function set_msLength(v:Float):Float { return msLength = v; }
}

class Note extends FunkinSprite {
	public static var directionNames:Array<String> = ['left', 'down', 'up', 'right'];
	public static var directionColors:Array<Array<FlxColor>> = [
		[FlxColor.fromRGB(194, 75, 153), FlxColor.WHITE, FlxColor.fromRGB(60, 31, 86)],
		[FlxColor.fromRGB(0, 255, 255), FlxColor.WHITE, FlxColor.fromRGB(21, 66, 183)],
		[FlxColor.fromRGB(18, 250, 5), FlxColor.WHITE, FlxColor.fromRGB(10, 68, 71)],
		[FlxColor.fromRGB(249, 57, 63), FlxColor.WHITE, FlxColor.fromRGB(101, 16, 56)],
	];
	public static inline function getColors(data:Int):Array<FlxColor> { return directionColors[FlxMath.wrap(data, 0, directionColors.length - 1)]; }
	public static inline function getDirection(data:Int):String { return directionNames[FlxMath.wrap(data, 0, directionNames.length - 1)]; }
	
	public var conductorInUse:Conductor; // mostly charting stuff
	
	public var tail:NoteTail;
	public var rgbShader:RGBSwap;
	public var updateRGBShader:Bool = true;
	public var rgbEnabled(default, set):Bool;
	public var tailOffset(default, null):FlxPoint;
	
	public var lane:Lane;
	public var chartNote(default, set):ChartNote;
	
	public var preventDespawn:Bool = false;
	public var consumed:Bool = false;
	public var goodHit:Bool = false;
	public var lost:Bool = false;
	public var canHit:Bool = true;
	
	public var followVisible:Bool = true;
	public var followAlpha:Bool = true;
	public var followAngle:Bool = true;
	
	public var score:Score;
	public var held:Bool = false;
	public var hitTime:Float = -1;
	public var holdTime:Float = -1;
	public var defaultAlpha:Float = 1;
	public var defaultScale:Float = 1;
	public var clipDistance:Float = 0;
	public var scrollDistance:Float = 0;
	
	public var healthLoss:Float = 6.0 / 100;
	public var healthGain:Float = 1.5 / 100;
	public var healthGainPerSecond:Float = 7.5 / 100; // hold bonus
	public var hitWindow:Float = Scoring.safeFrames * 1000 / 60;
	
	public var scrollMultiplier:Float = 1;
	public var directionOffset:Float = 0;
	public var hitPriority:Float = 1;
	public var multAlpha:Float = 1;
	public var ignore:Bool = false;
	
	public var isHoldTail(default, null):Bool = false;
	
	public var laneIndex:Int = 0;
	public var strumlineIndex:Int = 0;
	public var style(default, set):NoteStyle;
	public var kind(default, set):String = '';
	@:deprecated('noteKind is deprecated, use kind instead!') public var noteKind(get, set):String;
	@:deprecated('noteData is deprecated, use laneIndex instead!') public var noteData(get, set):Int;
	@:deprecated('player is deprecated, use strumlineIndex instead!') public var player(get, never):Bool;
	
	public var endMs(get, never):Float;
	public var endBeat(get, never):Float;
	public var msTime(default, set):Float = 0;
	public var beatTime(default, set):Float = 0;
	public var msLength(default, set):Float = 0;
	public var beatLength(default, set):Float = 0;
	public var isHoldNote(default, null):Bool = false;
	
	public var getScrollDistance:(note:Note, lane:Lane, distance:Float) -> Float = null;
	public var getScrollPosition:(note:Note, lane:Lane, distance:Float, ?point:FlxPoint) -> FlxPoint = null;
	
	function get_noteData():Int { return laneIndex; }
	function set_noteData(value:Int):Int { return laneIndex = value; }
	function get_player():Bool { return (strumlineIndex == 0); }
	function set_noteKind(newKind:String):String { return kind = newKind; }
	function get_noteKind():String { return kind; }
	
	var _scrollPoint:FlxPoint = FlxPoint.get();
	var forceDraw:Bool = false;
	
	public override function destroy():Void {
		_scrollPoint.put();
		tailOffset.put();
		tail?.destroy();
		tail = null;
		
		super.destroy();
	}
	public override function draw():Void {
		if (isHoldNote && tail != null)
			tail.draw();
		
		if (!goodHit || forceDraw)
			super.draw();
	}
	public override function kill():Void {
		super.kill();
		tail?.kill();
	}
	public override function revive():Void {
		super.revive();
		tail?.revive();
	}
	
	public function new(songNote:ChartNote, ?conductor:Conductor) {
		super();
		
		rgbShader = new RGBSwap();
		shader = rgbShader.shader;
		
		this.conductorInUse = conductor ?? FunkinState.getCurrentConductor();
		this.tailOffset = FlxPoint.get();
		
		this.chartNote = songNote;
	}
	public function set_chartNote(songNote:ChartNote):ChartNote {
		chartNote = songNote;
		
		if (songNote != null) {
			this.kind = songNote.kind;
			this.msTime = songNote.msTime;
			this.laneIndex = songNote.laneIndex;
			this.strumlineIndex = songNote.strumlineIndex;
			this.msLength = Math.max(songNote.msLength, 0);
			
			this.extraData.clear();
			if (songNote.extraData != null) {
				for (k => v in songNote.extraData)
					setVar(k, v);
			}
			
			if (tail != null)
				tail.chartNote = songNote;
		}
		
		return songNote;
	}
	public function updateChartNote():Void {
		chartNote.kind = kind;
		chartNote.msTime = msTime;
		chartNote.msLength = msLength;
		chartNote.laneIndex = laneIndex;
		chartNote.strumlineIndex = strumlineIndex;
	}
	
	public function reload(?style:NoteStyle):Void {
		clipDistance = 0;
		healthLoss = 6.0 / 100;
		healthGain = 1.5 / 100;
		healthGainPerSecond = 7.5 / 100;
		lost = goodHit = held = consumed = preventDespawn = ignore = false;
		followAngle = canHit = visible = true;
		holdTime = hitTime = -1;
		spriteOffset.set();
		tailOffset.set();
		multAlpha = 1;
		blend = NORMAL;
		
		this.style = style;
		tail?.reload(style);
	}
	public function updateTail():Void {
		isHoldNote = (msLength > 0);
		if (isHoldNote) {
			if (tail == null) {
				tail = new NoteTail(this);
			} else {
				tail.reloadNote(this);
			}
		}
	}
	public function toChartNote():ChartNote {
		return chartNote ?? {laneIndex: laneIndex, msTime: msTime, kind: kind, msLength: msLength, strumlineIndex: strumlineIndex};
	}
	
	function set_kind(newKind:String) {
		return kind = newKind;
	}
	function set_msTime(newTime:Float) {
		if (msTime == newTime) return newTime;
		@:bypassAccessor beatTime = conductorInUse.convertMeasure(newTime, MS, BEAT);
		return msTime = newTime;
	}
	function set_beatTime(newTime:Float) {
		if (beatTime == newTime) return newTime;
		@:bypassAccessor msTime = conductorInUse.convertMeasure(newTime, BEAT, MS);
		return beatTime = newTime;
	}
	function set_msLength(newLength:Float) {
		if (msLength == newLength) return newLength;
		msLength = newLength;
		@:bypassAccessor beatLength = conductorInUse.convertMeasure(msTime + newLength, MS, BEAT) - beatTime;
		updateTail();
		return newLength;
	}
	function set_beatLength(newLength:Float) {
		if (beatLength == newLength) return newLength;
		beatLength = newLength;
		@:bypassAccessor msLength = conductorInUse.convertMeasure(beatTime + newLength, BEAT, MS) - msTime;
		updateTail();
		return newLength;
	}
	function get_endMs()
		return msTime + msLength;
	function get_endBeat()
		return beatTime + beatLength;
	
	function set_style(newStyle:NoteStyle) {
		if (style == newStyle) return newStyle;
		
		style = newStyle;
		loadStyle(newStyle);
		if (tail != null)
			tail.style = newStyle;
		
		return newStyle;
	}
	public function set_rgbEnabled(newE:Bool) {
		shader = (newE ? rgbShader.shader : null);
		return rgbEnabled = newE;
	}
	public function loadStyle(newStyle:NoteStyleAsset) {
		var oldScale:Float = defaultScale;
		var style:NoteStyle = NoteStyle.fetch(newStyle);
		var asset:NoteStyleAssetData = style?.data.notes;
		
		NoteStyleUtil.loadNoteStyleAnimations(this, asset, style?.getDirectionName(laneIndex));
		defaultScale = asset?.scale ?? 1;
		defaultAlpha = asset?.alpha ?? 1;
		scale.x *= (defaultScale / oldScale);
		scale.y *= (defaultScale / oldScale);
		
		reloadAnimShader('hit', newStyle);
		playAnimation('hit', true);
		updateHitbox();
	}
	
	public static function distanceToMS(distance:Float, scrollSpeed:Float)
		return distance / (.45 * scrollSpeed);
	public static function msToDistance(ms:Float, scrollSpeed:Float)
		return ms * (.45 * scrollSpeed);
	public function followLane(lane:Lane) {
		var timeDiff:Float = msTime - conductorInUse.songPosition;
		var receptor:Receptor = lane.receptor;
		
		var scrollDistance:Float;
		var scrollPosition:FlxPoint;
		try {
			scrollDistance = (getScrollDistance ?? getScrollDistanceGeneric)(this, lane, timeDiff);
			scrollPosition = (getScrollPosition ?? getScrollPositionGeneric)(this, lane, scrollDistance);
		} catch (e:haxe.Exception) {
			Log.error('error while setting scroll distance or position -> ${e.details()}');
			scrollDistance = getScrollDistanceGeneric(this, lane, timeDiff);
			scrollPosition = getScrollPositionGeneric(this, lane, scrollDistance);
		}
		
		x = receptor.x + (receptor.width - width) * .5 + scrollPosition.x;
		y = receptor.y + (receptor.height - height) * .5 + scrollPosition.y;
		
		if (followAlpha)
			alpha = receptor.alpha * multAlpha * defaultAlpha;
		if (followVisible)
			visible = receptor.visible;
		if (followAngle)
			angle = lane.receptor.angle;
		
		if (isHoldNote && tail != null) {
			var tailScale:Float = (scale.x / defaultScale * tail.defaultScale);
			
			tail.setPosition(receptor.x + receptor.width * .5, receptor.y + receptor.height * .5);
			tail.scale.set(tailScale, tailScale);
			tail.goodHit = goodHit;
			tail.followLane(lane);
			tail.updateHitbox();
		}
	}
	
	public static function getScrollDistanceGeneric(note:Note, lane:Lane, timeDiff:Float):Float {
		return msToDistance(timeDiff, lane.scrollSpeed * note.scrollMultiplier);
	}
	public static function getScrollPositionGeneric(note:Note, lane:Lane, distance:Float, ?point:FlxPoint):FlxPoint {
		point ??= note._scrollPoint;
		
		var dir:Float = lane.direction + note.directionOffset;
		var rad:Float = (dir / 180 * Math.PI);
		
		return point.set(FlxMath.fastCos(rad) * distance, FlxMath.fastSin(rad) * distance);
	}
	
	public override function playAnimation(anim:String, forced:Bool = false, reversed:Bool = false, frame:Int = 0) {
		if (forced || this.anim.name != anim)
			reloadAnimShader(anim, style);
		
		super.playAnimation(anim, forced, reversed, frame);
	}
	public function reloadAnimShader(anim:String, style:NoteStyle) {
		if (updateRGBShader) {
			var animData:NoteStyleAnimData = style?.getAssetAnimation(style?.data.notes, anim);
			if (animData != null) {
				if (animData.disableRGB) {
					rgbEnabled = false;
				} else {
					var colors:Array<FlxColor> = style.getDirectionColorMod(laneIndex, animData.colorMod);
					rgbShader.set(colors[0], colors[1], colors[2]);
					rgbEnabled = true;
				}
			}
		}
	}
}

class NoteTail extends Note {
	public var parent(default, set):Note;
	
	public var followParent:Bool = true;
	
	public var renderTriangles:Bool = true; // TODO
	public var clipToDistance:Null<Float> = null;
	public var adaptiveDirection:Bool = true;
	
	public var holdScale(default, null):FlxPoint;
	public var tailScale(default, null):FlxPoint;
	
	var holdStrip:NoteTailStrip;
	var tailStrip:NoteTailStrip;
	
	var _tailScrollPoint:FlxPoint = FlxPoint.get();
	var drawData:Array<NoteTailDrawData> = [];
	var drawItems:Int = 0;
	
	public function new(parent:Note) {
		super(parent?.chartNote);
		
		rgbShader = new RGBSwap();
		shader = rgbShader.shader;
		
		holdScale = FlxPoint.get(1, 1);
		tailScale = FlxPoint.get(1, 1);
		
		holdStrip = new NoteTailStrip(this, 'hold');
		tailStrip = new NoteTailStrip(this, 'tail');
		
		this.isHoldTail = true;
		this.forceDraw = true;
		this.parent = parent;
	}
	public override function destroy() {
		holdStrip?.destroy();
		tailStrip?.destroy();
		
		holdScale.put();
		tailScale.put();
		_tailScrollPoint.put();
		
		drawData = null;
		drawItems = 0;
		
		super.destroy();
	}
	
	function set_parent(note:Note):Note {
		if (note != null)
			reloadNote(note);
		return parent = note;
	}
	
	public function reloadNote(note:Note):Void {
		conductorInUse = note.conductorInUse ?? FunkinState.getCurrentConductor();
		chartNote = note.chartNote;
		style = note.style;
		
		holdStrip?.reloadTail(this);
		tailStrip?.reloadTail(this);
	}
	public override function reload(?style:NoteStyle):Void {
		super.reload(style);
		
		clipToDistance = null;
	}
	public override function updateTail():Void {}
	public override function update(elapsed:Float):Void {
		super.update(elapsed);
		holdStrip?.update(elapsed);
		tailStrip?.update(elapsed);
	}
	public override function draw():Void {
		alpha = multAlpha * defaultAlpha;
		if (parent != null) {
			scrollFactor.copyFrom(parent.scrollFactor);
			initialZoom = parent.initialZoom;
			zoomFactor = parent.zoomFactor;
			shader = parent.shader;
			alpha *= parent.alpha;
			color = parent.color;
		}
		
		super.draw();
	}
	
	public override function loadStyle(newStyle:NoteStyleAsset) {
		var oldScale:Float = defaultScale;
		var style:NoteStyle = NoteStyle.fetch(newStyle);
		var asset:NoteStyleAssetData = style?.data.holds;
		
		defaultScale = asset?.scale ?? 1;
		defaultAlpha = asset?.alpha ?? 1;
		scale.x *= (defaultScale / oldScale);
		scale.y *= (defaultScale / oldScale);
		
		holdStrip?.loadStyle(style);
		tailStrip?.loadStyle(style);
	}
	
	public override function followLane(lane:Lane):Void {
		if (!renderTriangles) return; // TODO: basic renderer
		
		var distFunc = getScrollDistance ?? parent.getScrollDistance ?? Note.getScrollDistanceGeneric;
		var posFunc = getScrollPosition ?? parent.getScrollPosition ?? Note.getScrollPositionGeneric;
		var timeDiff:Float = endMs - conductorInUse.songPosition;
		
		var scrollDistance:Float;
		var scrollPosition:FlxPoint;
		var scrollNextPosition:FlxPoint;
		try {
			scrollDistance = distFunc(this, lane, timeDiff);
			scrollPosition = posFunc(this, lane, scrollDistance);
		} catch (e:haxe.Exception) {
			Log.error('error while setting scroll distance or position -> ${e.details()}');
			posFunc = Note.getScrollPositionGeneric;
			distFunc = Note.getScrollDistanceGeneric;
			scrollDistance = distFunc(this, lane, timeDiff);
			scrollPosition = posFunc(this, lane, scrollDistance);
		}
		
		if (followParent) {
			if (goodHit) clipToDistance = distFunc(this, lane, 0);
			
			if (parent != null) {
				directionOffset = parent.directionOffset;
				scrollMultiplier = parent.scrollMultiplier;
			}
		}
		
		var clipDistance:Float = distFunc(this, lane, msTime - conductorInUse.songPosition);
		if (clipToDistance != null) clipDistance = Math.max(clipDistance, clipToDistance);
		
		
		function prepareRender(strip:NoteTailStrip):NoteTailStrip {
			strip.scale.copyFrom(scale);
			strip.shader = shader;
			return strip;
		}
		
		drawItems = 0;
		prepareRender(tailStrip);
		prepareRender(holdStrip);
		var render:NoteTailStrip = tailStrip;
		var nextAngle:Float = (lane.direction + parent.directionOffset);
		var scrollAngle:Null<Float> = (adaptiveDirection ? null : nextAngle);
		while (scrollDistance > clipDistance) {
			var height:Float = render.frameHeight * render.scale.y;
			if (height < 5) break;
			
			scrollDistance -= height;
			scrollNextPosition = posFunc(this, lane, scrollDistance, _tailScrollPoint);
			if (adaptiveDirection) nextAngle = (scrollPosition.degreesTo(scrollNextPosition) * Math.PI / 180);
			
			
			var data:NoteTailDrawData = (drawData[drawItems] ?? new NoteTailDrawData());
			
			data.clip = (scrollDistance <= clipDistance ? Math.abs(scrollDistance - clipDistance) / height : 0);
			data.copyPosition(scrollPosition, scrollNextPosition);
			data.setAngle(scrollAngle ?? nextAngle, nextAngle);
			
			drawData[drawItems ++] = data;
			
			
			if (adaptiveDirection) scrollAngle = nextAngle;
			scrollPosition.copyFrom(scrollNextPosition);
			render = holdStrip;
		}
	}
	
	public override function drawComplex(camera:FlxCamera) {
		updateShader(camera);
		
		if (renderTriangles) {
			var render:NoteTailStrip = tailStrip;
			for (i in 0 ... drawItems) {
				var data:NoteTailDrawData = drawData[i];
				if (data == null || render == null) break;
				
				render.updateRender(x, y, data);
				render.draw();
				
				render = holdStrip;
			}
		}
	}
	
	public override function isSimpleRender(?camera:FlxCamera):Bool {
		return false; // lazy zzz
	}
}

class NoteTailStrip extends FunkinStrip {
	public var defaultAnim:String;
	public var style(default, set):NoteStyle;
	public var parentTail(default, set):NoteTail;
	
	public var laneIndex:Int;
	
	public function new(parent:NoteTail, defaultAnim:String = 'hold') {
		super();
		
		this.defaultAnim = defaultAnim;
		this.parentTail = parent;
		
		indices = new DrawData<Int>(6, true, [0, 1, 2, 1, 2, 3]);
		uvtData = new DrawData<Float>(8, true, [0, 0, 0, 0, 0, 0, 0, 0]);
		vertices = new DrawData<Float>(8, true, [0, 0, 0, 0, 0, 0, 0, 0]);
	}
	
	public function updateRender(x:Float, y:Float, drawData:NoteTailDrawData):Void {
		if (graphic == null)
			return;
		
		final clip:Float = drawData.clip;
		final angleTo:Float = drawData.angleTo;
		final angleFrom:Float = drawData.angleFrom;
		
		setPosition(x + drawData.xFrom, y + drawData.yFrom);
		var nextXOffset:Float = drawData.xTo - drawData.xFrom;
		var nextYOffset:Float = drawData.yTo - drawData.yFrom;
		
		final w:Float = graphic.width;
		final h:Float = graphic.height;
		final crop:Float = (antialiasing ? .5 : 0); // get rid of transparent blurry edges
		
		var left:Float = frame.frame.x / w;
		var top:Float = (frame.frame.y + crop) / h;
		var right:Float = left + frame.frame.width / w;
		var bottom:Float = (frame.frame.y + frame.frame.height - crop) / h;
		
		if (clip > 0) {
			nextXOffset *= (1 - clip);
			nextYOffset *= (1 - clip);
			top = FlxMath.lerp(top, bottom, clip);
		}
		
		var pieceWidth:Float = frameWidth * scale.x * .5;
		
		// update vertices
		vertices[0] = Math.sin(angleTo) * pieceWidth + nextXOffset; // top left
		vertices[1] = Math.cos(angleTo) * -pieceWidth + nextYOffset;
		uvtData[0] = left;
		uvtData[1] = top;
		
		vertices[2] = Math.sin(angleTo) * -pieceWidth + nextXOffset; // top right
		vertices[3] = Math.cos(angleTo) * pieceWidth + nextYOffset;
		uvtData[2] = right;
		uvtData[3] = top;
		
		vertices[4] = Math.sin(angleFrom) * pieceWidth; // bottom left
		vertices[5] = Math.cos(angleFrom) * -pieceWidth;
		uvtData[4] = left;
		uvtData[5] = bottom;
		
		vertices[6] = Math.sin(angleFrom) * -pieceWidth; // bottom right
		vertices[7] = Math.cos(angleFrom) * pieceWidth;
		uvtData[6] = right;
		uvtData[7] = bottom;
	}
	
	function set_style(newStyle:NoteStyle) {
		if (style == newStyle) return newStyle;
		style = newStyle;
		loadStyle(newStyle);
		return newStyle;
	}
	function set_parentTail(note:NoteTail):NoteTail {
		reloadTail(note);
		return parentTail = note;
	}
	public function reloadTail(note:NoteTail):Void {
		scale.copyFrom(note.scale);
		laneIndex = note.laneIndex;
		style = note.style;
	}
	public function loadStyle(newStyle:NoteStyleAsset) {
		var style:NoteStyle = NoteStyle.fetch(newStyle);
		var asset:NoteStyleAssetData = style?.data.holds;
		
		NoteStyleUtil.loadNoteStyleAnimations(this, asset, style?.getDirectionName(laneIndex));
		
		playAnimation(defaultAnim, true);
		offset.set();
	}
}

class NoteTailDrawData {
	public var angleFrom:Float;
	public var xFrom:Float;
	public var yFrom:Float;
	
	public var angleTo:Float;
	public var xTo:Float;
	public var yTo:Float;
	
	public var clip:Float = 0;
	
	public function new() {}
	
	public function setAngle(from:Float, ?to:Float):NoteTailDrawData {
		angleFrom = from;
		angleTo = to ?? angleFrom;
		return this;
	}
	public function setPosition(x:Float, y:Float, ?xT:Float, ?yT:Float):NoteTailDrawData {
		xFrom = x;
		yFrom = y;
		if (xT != null) xTo = xT;
		if (yT != null) yTo = yT;
		return this;
	}
	public function copyPosition(point:FlxPoint, ?pointTo:FlxPoint):NoteTailDrawData {
		xFrom = point.x;
		yFrom = point.y;
		if (pointTo != null) {
			xTo = pointTo.x;
			yTo = pointTo.y;
		}
		return this;
	}
}