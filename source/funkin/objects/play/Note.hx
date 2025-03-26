package funkin.objects.play;

import funkin.shaders.RGBSwap;
import funkin.objects.play.Lane;
import funkin.backend.play.Scoring;
import funkin.backend.rhythm.Event;
import funkin.backend.FunkinSprite;
import funkin.backend.play.NoteStyle;
import funkin.objects.CharacterGroup;

import flixel.math.FlxMatrix;
import flixel.graphics.frames.FlxFrame;

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
	
	function get_noteData():Int { return laneIndex; }
	function set_noteData(value:Int):Int { return laneIndex = value; }
	function get_player():Bool { return (strumlineIndex == 0); }
	function set_noteKind(newKind:String):String { return kind = newKind; }
	function get_noteKind():String { return kind; }
	
	public override function destroy():Void {
		tailOffset.put();
		if (tail != null)
			tail.destroy();
		super.destroy();
		tail = null;
	}
	public override function draw():Void {
		if (isHoldNote && tail != null)
			tail.draw();
		
		if (!goodHit)
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
		if (songNote != null) {
			this.kind = songNote.kind;
			this.msTime = songNote.msTime;
			this.laneIndex = songNote.laneIndex;
			this.strumlineIndex = songNote.strumlineIndex;
			this.msLength = songNote.msLength;
			
			this.extraData.clear();
			if (songNote.extraData != null) {
				for (k => v in songNote.extraData)
					setVar(k, v);
			}
		}
		this.msLength = Math.max(this.msLength, 0);
		
		return this.chartNote = songNote;
	}
	public function updateChartNote():Void {
		chartNote.kind = kind;
		chartNote.msTime = msTime;
		chartNote.msLength = msLength;
		chartNote.laneIndex = laneIndex;
		chartNote.strumlineIndex = strumlineIndex;
	}
	
	public function reload(?style:NoteStyle):Void {
		healthLoss = 6.0 / 100;
		healthGain = 1.5 / 100;
		healthGainPerSecond = 7.5 / 100;
		lost = goodHit = held = consumed = preventDespawn = ignore = false;
		followAngle = canHit = visible = true;
		holdTime = hitTime = -1;
		spriteOffset.set();
		tailOffset.set();
		multAlpha = 1;
		clipDistance = 0;
		
		this.style = style;
		if (tail != null)
			tail.reload(style);
	}
	public function updateTail():Void {
		isHoldNote = (msLength > 0);
		if (tail == null && isHoldNote)
			tail = new NoteTail(this);
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
		
		loadStyle(newStyle);
		if (tail != null)
			tail.style = newStyle;
		
		return style = newStyle;
	}
	public function set_rgbEnabled(newE:Bool) {
		shader = (newE ? rgbShader.shader : null);
		return rgbEnabled = newE;
	}
	public function loadStyle(newStyle:NoteStyleAsset) {
		var style:NoteStyle = NoteStyle.fetch(newStyle);
		var asset:NoteStyleAssetData = style?.data.notes;
		
		NoteStyleUtil.loadNoteStyleAnimations(this, asset, style?.getDirectionName(laneIndex));
		playAnimation('hit', true);
		updateHitbox();
		
		defaultScale = asset?.scale ?? 1;
		defaultAlpha = asset?.alpha ?? 1;
		reloadAnimShader('hit', newStyle);
	}
	
	public static function distanceToMS(distance:Float, scrollSpeed:Float)
		return distance / (.45 * scrollSpeed);
	public static function msToDistance(ms:Float, scrollSpeed:Float)
		return ms * (.45 * scrollSpeed);
	public dynamic function followLane(lane:Lane, scrollSpeed:Float) {
		var receptor:Receptor = lane.receptor;
		var speed:Float = scrollSpeed * scrollMultiplier;
		var dir:Float = lane.direction + directionOffset;
		
		scrollDistance = msToDistance(msTime - conductorInUse.songPosition, speed);
		
		var xP:Float = 0;
		var yP:Float = scrollDistance;
		var rad:Float = dir / 180 * Math.PI;
		x = receptor.x + (receptor.width - width) * .5 + Math.sin(rad) * xP + Math.cos(rad) * yP;
		y = receptor.y + (receptor.height - height) * .5 + Math.sin(rad) * yP + Math.cos(rad) * xP;
		
		if (followAlpha)
			alpha = receptor.alpha * multAlpha * defaultAlpha;
		if (followVisible)
			visible = receptor.visible;
		if (followAngle)
			angle = lane.receptor.angle;
		
		if (isHoldNote && tail != null) {
			tail.scale.x = scale.x * tail.defaultScale;
			tail.scale.y = FlxMath.signOf(speed) * Math.abs(scale.x) * tail.defaultScale;
			tail.updateHitbox();
			tail.offset.y = 0;
			
			var absDistance:Float = msToDistance(msTime - conductorInUse.songPosition, Math.abs(speed));
			tail.sustainHeight = msToDistance(msLength, Math.abs(speed));
			tail.setPosition(x - tailOffset.x + (width - tail.width) * .5, y - tailOffset.y + height * .5);
			tail.angle = dir - 90;
			
			if (goodHit && absDistance < 0)
				tail.sustainClip = -absDistance;
		}
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

class NoteTail extends FunkinSprite {
	public var rgbShader:RGBSwap;
	public var updateRGBShader:Bool = true;
	public var rgbEnabled(default, set):Bool;
	
	public var parent(default, set):Note;
	public var style(default, set):NoteStyle;
	public var laneIndex:Int;
	
	public var multAlpha:Float = 1;
	public var sustainClip:Float = 0;
	public var sustainHeight:Float = 0;
	
	public var defaultScale:Float = 1;
	public var defaultAlpha:Float = 1;
	
	public var holdScale(default, null):FlxPoint;
	public var tailScale(default, null):FlxPoint;
	
	var _tileMatrix:FlxMatrix = new FlxMatrix();
	
	public function new(parent:Note) {
		super();
		
		rgbShader = new RGBSwap();
		shader = rgbShader.shader;
		
		holdScale = FlxPoint.get(1, 1);
		tailScale = FlxPoint.get(1, 1);
		
		this.style = style;
		this.parent = parent;
	}
	public override function destroy() {
		holdScale.put();
		tailScale.put();
		
		_tileMatrix = null;
		super.destroy();
	}
	
	function set_parent(note:Note):Note {
		laneIndex = note.laneIndex;
		return parent = note;
	}
	
	public function reload(?style:NoteStyle) {
		this.style = style;
		sustainClip = 0;
	}
	public override function draw() {
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
	
	function set_style(newStyle:NoteStyle) {
		if (style == newStyle) return newStyle;
		loadStyle(newStyle);
		return style = newStyle;
	}
	public function set_rgbEnabled(newE:Bool) {
		shader = (newE ? rgbShader.shader : null);
		return rgbEnabled = newE;
	}
	public function loadStyle(newStyle:NoteStyleAsset) {
		var style:NoteStyle = NoteStyle.fetch(newStyle);
		var asset:NoteStyleAssetData = style?.data.holds;
		
		NoteStyleUtil.loadNoteStyleAnimations(this, asset, style?.getDirectionName(laneIndex));
		playAnimation('hold', true);
		updateHitbox();
		
		defaultScale = asset?.scale ?? 1;
		defaultAlpha = asset?.alpha ?? 1;
	}
	
	// this is kinda mediocre tbh
	public override function drawComplex(camera:FlxCamera) {
		if (sustainHeight <= sustainClip)
			return;
		
		updateShader(camera);
		
		var top:Float = 1;
		var bottom:Float = 0;
		var doTail:Bool = true;
		var sc:FlxPoint = tailScale;
		playAnimation('tail', true);
		origin.set(frameWidth * .5);
		cropFrame(top, bottom);
		getDrawMatrix(sc);
		
		var totalHeight:Float = sustainHeight;
		var absScale:Float = Math.abs(scale.y * tailScale.y);
		
		if (absScale < Math.max(Math.abs(scale.x), .05)) return; 
		
		var scaleSign:Int = FlxMath.signOf(scale.y);
		var rad:Float = angle / 180 * Math.PI;
		var sin:Float = Math.sin(rad);
		var cos:Float = Math.cos(rad);
		var cut:Bool = false;
		
		while (true) {
			var pieceHeight:Float = (frameHeight - top - bottom) * absScale;
			if (pieceHeight <= 0) return;
			
			totalHeight -= pieceHeight;
			if (totalHeight <= sustainClip) {
				var dist:Float = (sustainClip - totalHeight) / absScale; // pieceHeight * frameHeight;
				cropFrame(dist + top, bottom);
				getDrawMatrix(sc);
				cut = true;
			}
			
			_tileMatrix.copyFrom(_matrix);
			_tileMatrix.translate(-totalHeight * sin, totalHeight * cos * scaleSign - top * scale.y * holdScale.y);
			FunkinSprite.transformMatrixZoom(_tileMatrix, camera, zoomFactor, initialZoom);
			camera.drawPixels(_frame, framePixels, _tileMatrix, colorTransform, blend, antialiasing, shader);
			
			if (cut) break;
			
			if (doTail) {
				sc = holdScale;
				
				bottom = 1;
				doTail = false;
				playAnimation('hold', true);
				absScale = Math.abs(scale.y * holdScale.y);
				origin.set(frameWidth * .5);
				cropFrame(top, bottom);
				getDrawMatrix(sc);
				
				if (absScale < Math.max(Math.abs(scale.x), .05)) return; 
			}
		}
	}
	function cropFrame(cropTop:Float = 0, cropBottom:Float = 0) {
		_frame = frame.clipTo(_rect.set(0, cropTop, frameWidth, frameHeight - cropTop - cropBottom), _frame);
	}
	function getDrawMatrix(?scaleFactor:FlxPoint) {
		_frame.prepareMatrix(_matrix, FlxFrameAngle.ANGLE_0, checkFlipX(), checkFlipY());
		
		_matrix.translate(-origin.x, -origin.y);
		_matrix.scale(scale.x, scale.y);
		if (scaleFactor != null)
			_matrix.scale(scaleFactor.x, scaleFactor.y);
		
		if (bakedRotationAngle <= 0) {
			updateTrig();

			if (angle != 0)
				_matrix.rotateWithTrig(_cosAngle, _sinAngle);
		}
		
		transformSpriteOffset(_transPoint);
		getScreenPosition(_point, camera);
		_point.add(-offset.x, -offset.y);
		_point.add(-_transPoint.x, -_transPoint.y);
		_matrix.translate(_point.x + origin.x, _point.y + origin.y);
		
		if (isPixelPerfectRender(camera)) {
			_matrix.tx = Math.floor(_matrix.tx);
			_matrix.ty = Math.floor(_matrix.ty);
		}
	}
	public override function getScreenBounds(?newRect:FlxRect, ?camera:FlxCamera):FlxRect {
		if (newRect == null)
			newRect = FlxRect.get();
		
		if (camera == null)
			camera = getDefaultCamera();
		
		newRect.setPosition(x, y);
		if (pixelPerfectPosition)
			newRect.floor();
		_scaledOrigin.set(origin.x * Math.abs(scale.x), origin.y * Math.abs(scale.y));
		newRect.x += -Std.int(camera.scroll.x * scrollFactor.x) - offset.x + origin.x - _scaledOrigin.x;
		newRect.y += -Std.int(camera.scroll.y * scrollFactor.y) - offset.y + origin.y - _scaledOrigin.y;
		if (isPixelPerfectRender(camera))
			newRect.floor();
		newRect.setSize(frameWidth * Math.abs(scale.x), sustainHeight);
		if (scale.y < 0) newRect.y -= sustainHeight;
		return newRect.getRotatedBounds(angle, _scaledOrigin, newRect);
	}
	public override function isSimpleRender(?camera:FlxCamera):Bool {
		return false; // lazy zzz
	}
	
	public override function playAnimation(anim:String, forced:Bool = false, reversed:Bool = false, frame:Int = 0) {
		if (forced || this.anim.name != anim)
			reloadAnimShader(anim, style);
		
		super.playAnimation(anim, forced, reversed, frame);
	}
	public function reloadAnimShader(anim:String, style:NoteStyle) {
		if (updateRGBShader) {
			var animData:NoteStyleAnimData = style?.getAssetAnimation(style?.data.holds, anim);
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