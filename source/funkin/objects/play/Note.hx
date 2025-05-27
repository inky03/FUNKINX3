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

@:build(funkin.macros.FunkinMacro.buildReset())
class NoteObject extends FunkinSprite {
	public var lane:Lane;
	
	public var defaultAlpha:Float = 1;
	public var defaultScale:Float = 1;
	
	@resetVar public var updateModchart:Bool = true;
	@resetVar public var followReceptor:Bool = true;
	
	@resetVar public var direction:Float = 0;
	@resetVar public var distanceOffset:Float = 0;
	@resetVar public var scrollDistance:Float = 0;
	@resetVar public var scrollMultiplier:Float = 1;
	@:deprecated('directionOffset is deprecated, use direction instead!') public var directionOffset(get, set):Float;
	
	function get_directionOffset():Float { return direction; }
	function set_directionOffset(alpha:Float):Float { return direction = alpha; }
	
	public function followLane(lane:Lane) {}
	
	// modcharting stuff!!
	public var scrollPosition:FlxPoint = FlxPoint.get();
	
	@resetVar public var customModchart:(note:NoteObject, lane:Lane, distance:Float) -> Void = null;
	@resetVar public var customScrollDistance:(note:NoteObject, lane:Lane, timeDiff:Float) -> Float = null;
	
	public function genericScrollDistance(note:NoteObject, lane:Lane, timeDiff:Float):Float {
		var speed:Float = note.scrollMultiplier;
		if (lane != null) speed *= lane.scrollSpeed;
		
		return Note.msToDistance(timeDiff, speed) + note.distanceOffset;
	}
	public function genericModchart(note:NoteObject, lane:Lane, distance:Float):Void {
		var dir:Float = note.direction;
		if (lane != null) dir += lane.direction;
		var rad:Float = (dir / 180 * Math.PI);
		
		note.setPosition(note.scrollPosition.x + FlxMath.fastCos(rad) * distance, note.scrollPosition.y + FlxMath.fastSin(rad) * distance);
	}
}

@:build(funkin.macros.FunkinMacro.buildReset(true))
class Note extends NoteObject {
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
	
	public var chartNote(default, set):ChartNote;
	public var strumlineIndex:Int = 0;
	public var laneIndex:Int = 0;
	
	@resetVar public var preventDespawn:Bool = false;
	@resetVar public var consumed:Bool = false;
	@resetVar public var goodHit:Bool = false;
	@resetVar public var lost:Bool = false;
	@resetVar public var canHit:Bool = true;
	
	@resetVar public var followVisible:Bool = true;
	@resetVar public var followAlpha:Bool = true;
	@resetVar public var followAngle:Bool = true;
	@resetVar public var followScale:Bool = true;
	
	@resetVar public var score:Score = null;
	@resetVar public var held:Bool = false;
	@resetVar public var hitTime:Float = -1;
	@resetVar public var holdTime:Float = -1;
	
	@resetVar public var healthLoss:Float = 6.0 / 100;
	@resetVar public var healthGain:Float = 1.5 / 100;
	@resetVar public var healthGainPerSecond:Float = 7.5 / 100; // hold bonus
	@resetVar public var hitWindow:Float = Scoring.safeFrames * 1000 / 60;
	
	@resetVar public var hitPriority:Float = 1;
	@resetVar public var multAlpha:Float = 1;
	@resetVar public var ignore:Bool = false;
	
	public var isHoldTail(default, null):Bool = false;
	
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
	
	function get_noteData():Int { return laneIndex; }
	function set_noteData(value:Int):Int { return laneIndex = value; }
	function get_player():Bool { return (strumlineIndex == 0); }
	function set_noteKind(newKind:String):String { return kind = newKind; }
	function get_noteKind():String { return kind; }
	
	var renderingTail:Bool = false;
	var forceDraw:Bool = false;
	
	public override function destroy():Void {
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
	
	public function reload(?style:NoteStyle, ?lane:Lane):Void {
		resetVars();
		
		spriteOffset.set();
		tailOffset.set();
		blend = NORMAL;
		
		this.style = style;
		
		if (tail != null) {
			tail.reload(style);
			
			var tailScaleMult:Float = tail.defaultScale / tail.defaultScale;
			tail.scale.set(scale.x * tailScaleMult, scale.y * tailScaleMult);
			
			if (lane != null)
				tail.renderDistance = Note.msToDistance(lane.spawnRadius, lane.scrollSpeed);
		}
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
	public override function followLane(lane:Lane) {
		var timeDiff:Float = msTime - conductorInUse.songPosition;
		var receptor:Receptor = lane?.receptor;
		
		copyReceptor(receptor);
		
		try {
			scrollDistance = (customScrollDistance ?? genericScrollDistance)(this, lane, timeDiff);
			if (updateModchart)
				(customModchart ?? genericModchart)(this, lane, scrollDistance);
		} catch (e:haxe.Exception) {
			Log.error('error on note modchart function -> ${e.details()}');
			
			customModchart = null;
			customScrollDistance = null;
			
			scrollDistance = genericScrollDistance(this, lane, timeDiff);
			if (updateModchart)
				genericModchart(this, lane, scrollDistance);
		}
		
		if (isHoldNote && tail != null) {
			tail.goodHit = goodHit;
			tail.followLane(lane);
			tail.updateHitbox();
		}
	}
	public function copyReceptor(receptor:Receptor) {
		if (receptor == null) return;
		
		if (followScale) { // maybe this is too many variables ...
			copyReceptorScale(receptor);
			updateHitbox();
		}
		if (followReceptor)
			scrollPosition.set(receptor.x + (receptor.width - width) * .5, receptor.y + (receptor.height - height) * .5);
		if (followAlpha)
			alpha = receptor.alpha * multAlpha * defaultAlpha;
		if (followVisible)
			visible = receptor.visible;
		if (followAngle)
			angle = receptor.angle;
	}
	public function copyReceptorScale(receptor:Receptor) {
		if (receptor == null) return;
		
		var scaleMult:Float = defaultScale / receptor.defaultScale;
		scale.set(receptor.scale.x * scaleMult, receptor.scale.y * scaleMult);
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
	public var renderDistance:Null<Float> = null;
	
	public var renderTriangles:Bool = true; // TODO
	public var clipToDistance:Null<Float> = null;
	public var adaptiveDirection:Bool = true;
	
	public var holdScale(default, null):FlxPoint;
	public var tailScale(default, null):FlxPoint;
	
	var holdStrip:NoteTailStrip;
	var tailStrip:NoteTailStrip;
	
	var drawData:Array<NoteTailDrawData> = [];
	var minBodyHeight:Float = 35;
	var drawItems:Int = 0;
	var zebra:Bool = false; // debug
	
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
	public override function reload(?style:NoteStyle, ?lane:Lane):Void {
		super.reload(style, lane);
		
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
			shader = parent.shader;
			alpha *= parent.alpha;
			color = parent.color;
		}
		holdStrip?.copyNote(this);
		tailStrip?.copyNote(this);
		
		for (camera in getCamerasLegacy()) {
			if (!camera.visible || !camera.exists)
				continue;
			
			drawComplex(camera);
			
			#if FLX_DEBUG
			FlxBasic.visibleCount++;
			#end
		}
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
		var receptor:Receptor = lane.receptor;
		
		copyNote(parent);
		copyReceptor(receptor);
		
		if (renderTriangles) {
			updateTriangles(lane);
		} else {
			// TODO: basic tile renderer (again)?
		}
	}
	public function copyNote(note:Note) {
		if (followParent && parent != null) {
			direction = parent.direction;
			followAlpha = parent.followAlpha;
			followVisible = parent.followVisible;
			scrollMultiplier = parent.scrollMultiplier;
			
			scale.copyFrom(parent.scale);
		}
	}
	public override function copyReceptor(receptor:Receptor) {
		if (receptor == null) return;
		
		if (followScale) {
			copyReceptorScale(receptor);
			updateHitbox();
		}
		if (followReceptor)
			scrollPosition.set(receptor.x + receptor.width * .5, receptor.y + receptor.height * .5);
		if (followAlpha)
			alpha = receptor.alpha * parent.multAlpha * multAlpha * defaultAlpha;
		if (followVisible)
			visible = (parent.visible && receptor.visible);
		if (followAngle)
			angle = direction + parent.direction + receptor.lane?.direction ?? 0 + 90;
	}
	public function updateTriangles(lane:Lane):Void {
		var render:NoteTailStrip = tailStrip;
		renderingTail = true;
		
		var distFunc = (customScrollDistance ?? parent.customScrollDistance ?? genericScrollDistance);
		var modchartFunc = (customModchart ?? parent.customModchart ?? genericModchart);
		var timeDiff:Float = endMs - conductorInUse.songPosition;
		var receptor:Receptor = lane.receptor;
		
		var scrollDistance:Float = 0;
		try {
			scrollDistance = distFunc(this, lane, timeDiff);
			if (updateModchart)
				modchartFunc(this, lane, scrollDistance);
		} catch (e:haxe.Exception) {
			Log.error('error on note modchart function -> ${e.details()}');
			
			customModchart = null;
			customScrollDistance = null;
			modchartFunc = genericModchart;
			distFunc = genericScrollDistance;
			
			scrollDistance = genericScrollDistance(this, lane, timeDiff);
			if (updateModchart)
				genericModchart(this, lane, timeDiff);
		}
		
		if (goodHit) clipToDistance = distFunc(this, lane, 0);
		
		var clipDistance:Float = distFunc(this, lane, msTime - conductorInUse.songPosition);
		if (clipToDistance != null) clipDistance = Math.max(clipDistance, clipToDistance);
		
		
		drawItems = 0;
		var rad:Float = (Math.PI / 180);
		var prevAngle:Float = angle * rad;
		var scaleY:Float = (lane?.scale.y ?? scale.y);
		
		while (scrollDistance > clipDistance) {
			var absSY:Float = Math.abs(scale.y);
			var height:Float = render.frameHeight * Math.max(absSY, renderingTail ? absSY : scaleY); // thats crazy bro
			if (!renderingTail && height < minBodyHeight) height = minBodyHeight;
			
			var prevScale:FlxPoint = FlxPoint.weak(scale.x, scale.y);
			var prevPosition:FlxPoint = FlxPoint.weak(x, y);
			
			scrollDistance -= height;
			modchartFunc(this, lane, scrollDistance);
			
			var curPosition:FlxPoint = FlxPoint.weak(x, y);
			
			if (renderDistance == null || scrollDistance < renderDistance) {
				if (adaptiveDirection) angle = (prevPosition.degreesTo(curPosition) + 180);
				var radAngle:Float = angle * rad;
				
				
				var data:NoteTailDrawData = (drawData[drawItems] ?? new NoteTailDrawData());
				
				data.clip = (scrollDistance <= clipDistance ? Math.abs(scrollDistance - clipDistance) / height : 0);
				data.copyPosition(prevPosition, curPosition);
				data.setScale(prevScale.x, scale.x);
				data.setAngle(prevAngle, radAngle);
				data.strip = render;
				
				drawData[drawItems ++] = data;
				
				
				prevAngle = radAngle;
			}
			
			renderingTail = false;
			render = holdStrip;
		}
	}
	
	public override function drawComplex(camera:FlxCamera):Void {
		updateShader(camera);
		
		if (renderTriangles) {
			for (i in 0 ... drawItems) {
				var data:NoteTailDrawData = drawData[i];
				var strip:NoteTailStrip = data?.strip;
				if (strip == null) break;
				
				if (zebra)
					strip.color = (i % 2 == 0 ? FlxColor.GRAY : FlxColor.WHITE);
				strip.updateRender(data);
				strip.draw();
			}
		}
	}
}

class NoteTailStrip extends FunkinStrip {
	public var defaultAnim:String;
	public var style(default, set):NoteStyle;
	public var parentTail(default, set):NoteTail;
	
	public var fast(default, set):Bool;
	var sinFunc:Float -> Float;
	var cosFunc:Float -> Float;
	var topUV:Float;
	
	public var laneIndex:Int;
	
	public function new(parent:NoteTail, defaultAnim:String = 'hold') {
		super();
		
		this.defaultAnim = defaultAnim;
		this.parentTail = parent;
		this.fast = true;
		
		indices = new DrawData<Int>(6, true, [0, 1, 2, 1, 2, 3]);
		uvtData = new DrawData<Float>(8, true, [0, 0, 0, 0, 0, 0, 0, 0]);
		vertices = new DrawData<Float>(8, true, [0, 0, 0, 0, 0, 0, 0, 0]);
	}
	
	override function set_frame(newFrame:FlxFrame):FlxFrame {
		super.set_frame(newFrame);
		
		if (dirty)
			prepareRender();
		
		return newFrame;
	}
	public function prepareRender():Void { // we don't need to update those every call...
		if (graphic == null || frame == null)
			return;
		
		var w:Float = graphic.width;
		
		var crop:Float = (antialiasing ? .5 : 0); // gets rid of blurry edges
		var leftUV:Float = (frame.frame.x / w);
		var rightUV:Float = (leftUV + frame.frame.width / w);
		var bottomUV:Float = ((frame.frame.y + frame.frame.height - crop) / graphic.height);
		
		uvtData[0] = uvtData[4] = leftUV; // left corners uv
		uvtData[2] = uvtData[6] = rightUV; // right corners uv
		uvtData[5] = uvtData[7] = bottomUV; // bottom corners uv
		topUV = ((frame.frame.y + crop) / graphic.height);
	}
	public function updateRender(drawData:NoteTailDrawData):Void {
		if (graphic == null)
			return;
		
		var clip:Float = drawData.clip;
		var angleTo:Float = drawData.angleTo;
		var angleFrom:Float = drawData.angleFrom;
		
		setPosition(drawData.xFrom, drawData.yFrom);
		var nextXOffset:Float = (drawData.xTo - drawData.xFrom) * (1 - clip);
		var nextYOffset:Float = (drawData.yTo - drawData.yFrom) * (1 - clip);
		
		// update vertices
		var width:Float = frameWidth * .5 * drawData.scaleFrom;
		var widthTo:Float = frameWidth * .5 * drawData.scaleTo;
		
		var sin:Float = sinFunc(angleTo) * widthTo;
		var cos:Float = cosFunc(angleTo) * widthTo;
		
		vertices[0] = -sin + nextXOffset; // top left
		vertices[1] = cos + nextYOffset;
		vertices[2] = sin + nextXOffset; // top right
		vertices[3] = -cos + nextYOffset;
		uvtData[1] = uvtData[3] = FlxMath.lerp(topUV, uvtData[5], clip); // top corners uv (for clipping)
		
		sin = sinFunc(angleFrom) * width;
		cos = cosFunc(angleFrom) * width;
		
		vertices[4] = -sin; // bottom left
		vertices[5] = cos;
		vertices[6] = sin; // bottom right
		vertices[7] = -cos;
	}
	public inline function copyNote(note:Note):Void {
		scrollFactor.copyFrom(note.scrollFactor);
		shader = note.shader;
		alpha = note.alpha;
		color = note.color;
	}
	
	function set_fast(yea:Bool):Bool {
		sinFunc = (yea ? FlxMath.fastSin : Math.sin);
		cosFunc = (yea ? FlxMath.fastCos : Math.cos);
		return fast = yea;
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
	public var scaleFrom:Float = 1;
	public var angleFrom:Float = 0;
	public var xFrom:Float = 0;
	public var yFrom:Float = 0;
	
	public var scaleTo:Float = 1;
	public var angleTo:Float = 0;
	public var xTo:Float = 0;
	public var yTo:Float = 0;
	
	public var clip:Float = 0;
	
	public var strip:NoteTailStrip;
	
	public function new() {}
	
	public function setAngle(from:Float, ?to:Float):NoteTailDrawData {
		angleFrom = from;
		angleTo = to ?? from;
		return this;
	}
	public function setScale(from:Float, ?to:Float):NoteTailDrawData {
		scaleFrom = from;
		scaleTo = to ?? from;
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