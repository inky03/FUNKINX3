package funkin.objects.play;

import funkin.objects.play.Lane;
import funkin.backend.play.Scoring;
import funkin.backend.rhythm.Event;
import funkin.backend.FunkinSprite;
import funkin.objects.CharacterGroup;

import flixel.math.FlxMatrix;
import flixel.graphics.frames.FlxFrame;

@:structInit class ChartNote implements ISpriteVars implements ITimeSortable {
	public var laneIndex:Int;
	public var kind:String = '';
	public var msTime:Float = 0;
	public var msLength:Float = 0;
	public var player:Bool = true;
	public var extraData:Map<String, Dynamic> = null;
	
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
}

class Note extends FunkinSprite {
	public static var directionNames:Array<String> = ['left', 'down', 'up', 'right'];
	public static var directionColors:Array<Array<FlxColor>> = [
		[FlxColor.fromRGB(194, 75, 153), FlxColor.fromRGB(60, 31, 86)],
		[FlxColor.fromRGB(0, 255, 255), FlxColor.fromRGB(21, 66, 183)],
		[FlxColor.fromRGB(18, 250, 5), FlxColor.fromRGB(10, 68, 71)],
		[FlxColor.fromRGB(249, 57, 63), FlxColor.fromRGB(101, 16, 56)],
	];
	public var conductorInUse:Conductor; // mostly charting stuff
	
	public var tail:NoteTail;
	
	public var lane:Lane;
	public var score:Score;
	public var held:Bool = false;
	public var hitTime:Float = -1;
	public var holdTime:Float = -1;
	public var chartNote(default, set):ChartNote;
	
	public var preventDespawn:Bool = false;
	public var consumed:Bool = false;
	public var goodHit:Bool = false;
	public var lost:Bool = false;
	public var canHit:Bool = true;
	
	public var clipDistance:Float = 0;
	public var scrollDistance:Float = 0;
	public var followAngle:Bool = true;
	
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
	public var isHoldNote(default, null):Bool = false;
	
	public override function destroy() {
		if (tail != null)
			tail.destroy();
		super.destroy();
		tail = null;
	}
	public override function draw() {
		if (isHoldNote && tail != null)
			tail.draw();
		
		if (!goodHit)
			super.draw();
	}
	
	public function new(songNote:ChartNote, ?conductor:Conductor) {
		super();
		
		this.conductorInUse = conductor ?? FunkinState.getCurrentConductor();
		
		this.chartNote = songNote;
		reload();
	}
	public function set_chartNote(songNote:ChartNote):ChartNote {
		if (songNote != null) {
			this.player = songNote.player;
			this.msTime = songNote.msTime;
			this.noteKind = songNote.kind;
			this.msLength = songNote.msLength;
			this.noteData = songNote.laneIndex;
			
			this.extraData.clear();
			if (songNote.extraData != null) {
				for (k => v in songNote.extraData)
					setVar(k, v);
			}
		}
		this.msLength = Math.max(this.msLength, 0);
		
		return this.chartNote = songNote;
	}
	
	public function reload() {
		healthLoss = 6.0 / 100;
		healthGain = 1.5 / 100;
		healthGainPerSecond = 7.5 / 100;
		lost = goodHit = held = consumed = preventDespawn = ignore = false;
		followAngle = canHit = visible = true;
		holdTime = hitTime = -1;
		multAlpha = 1;
		clipDistance = 0;
		if (tail != null) {
			tail.loadAtlas('notes');
			tail.reload();
		}
		
		loadAtlas('notes');
		reloadAnimations();
	}
	public function updateTail() {
		isHoldNote = (msLength > 0);
		if (tail == null && isHoldNote)
			tail = new NoteTail(this);
	}
	public function reloadAnimations() {
		var dirName:String = directionNames[noteData];
		addAnimation('hit-$noteData', '$dirName note', 24, false);
		playAnimation('hit-$noteData', true);
		updateHitbox();
	}
	public function toChartNote():ChartNote {
		return chartNote ?? {laneIndex: noteData, msTime: msTime, kind: noteKind, msLength: msLength, player: player};
	}
	
	public function set_noteKind(newKind:String) {
		return noteKind = newKind;
	}
	public function set_msTime(newTime:Float) {
		if (msTime == newTime) return newTime;
		@:bypassAccessor beatTime = conductorInUse.convertMeasure(newTime, MS, BEAT);
		return msTime = newTime;
	}
	public function set_beatTime(newTime:Float) {
		if (beatTime == newTime) return newTime;
		@:bypassAccessor msTime = conductorInUse.convertMeasure(newTime, BEAT, MS);
		return beatTime = newTime;
	}
	public function set_msLength(newLength:Float) {
		if (msLength == newLength) return newLength;
		msLength = newLength;
		@:bypassAccessor beatLength = conductorInUse.convertMeasure(msTime + newLength, MS, BEAT) - beatTime;
		updateTail();
		return newLength;
	}
	public function set_beatLength(newLength:Float) {
		if (beatLength == newLength) return newLength;
		beatLength = newLength;
		@:bypassAccessor msLength = conductorInUse.convertMeasure(beatTime + newLength, BEAT, MS) - msTime;
		updateTail();
		return newLength;
	}
	public function get_endMs()
		return msTime + msLength;
	public function get_endBeat()
		return beatTime + beatLength;
	
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
		x = receptor.x + Math.sin(rad) * xP + Math.cos(rad) * yP;
		y = receptor.y + Math.sin(rad) * yP + Math.cos(rad) * xP;
		alpha = lane.alpha * receptor.alpha * multAlpha;
		
		if (followAngle)
			angle = lane.receptor.angle;
		
		if (isHoldNote && tail != null) {
			var absDistance:Float = msToDistance(msTime - conductorInUse.songPosition, Math.abs(speed));
			var tailY:Float = height * .5;
			tail.offset.y = 0;
			tail.angle = dir - 90;
			tail.scale.x = scale.x;
			tail.scale.y = FlxMath.signOf(speed) * Math.abs(scale.x);
			tail.setPosition(x + (width - tail.width) * .5, y + tailY);
			tail.sustainHeight = msToDistance(msLength, Math.abs(speed));
			tail.updateHitbox();
			
			if (goodHit && absDistance < 0)
				tail.sustainClip = -absDistance;
		}
	}
}

class NoteTail extends FunkinSprite {
	public var parent(default, set):Note;
	public var noteData:Int;
	
	public var multAlpha:Float = .6;
	public var sustainClip:Float = 0;
	public var sustainHeight:Float = 0;
	
	var _tileMatrix:FlxMatrix = new FlxMatrix();
	
	public function new(parent:Note) {
		super();
		
		this.parent = parent;
		this.reload();
	}
	public override function destroy() {
		_tileMatrix = null;
		super.destroy();
	}
	
	function set_parent(note:Note):Note {
		if (parent == note) return note;
		noteData = note.noteData;
		return parent = note;
	}
	
	public function reload() {
		reloadAnimations();
		sustainClip = 0;
	}
	public function reloadAnimations() {
		var dirName:String = Note.directionNames[noteData];
		addAnimation('tail-$noteData', '$dirName hold tail', 24, false);
		addAnimation('hold-$noteData', '$dirName hold piece', 24, false);
		playAnimation('hold-$noteData', true);
	}
	public override function draw() {
		alpha = multAlpha;
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
	// this is kinda mediocre tbh
	public override function drawComplex(camera:FlxCamera) {
		if (sustainHeight <= sustainClip)
			return;
		
		updateShader(camera);
		
		var top:Float = 1;
		var bottom:Float = 0;
		var doTail:Bool = true;
		playAnimation('tail-$noteData', true);
		origin.set(frameWidth * .5, 0);
		cropFrame(top, bottom);
		getDrawMatrix();
		
		var totalHeight:Float = sustainHeight;
		var absScale:Float = Math.abs(scale.y);
		
		if (absScale < Math.max(Math.abs(scale.x), .05)) return; // TODO: add negative scale rendering (and flipY, i guess)
		
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
				var dist:Float = (sustainClip - totalHeight) / absScale;
				_frame = frame.clipTo(_rect.set(0, dist, frameWidth, frameHeight - dist - bottom), _frame);
				getDrawMatrix();
				cut = true;
			}
			
			_tileMatrix.copyFrom(_matrix);
			_tileMatrix.translate(-totalHeight * sin, totalHeight * cos * scaleSign);
			FunkinSprite.transformMatrixZoom(_tileMatrix, camera, zoomFactor, initialZoom);
			camera.drawPixels(_frame, framePixels, _tileMatrix, colorTransform, blend, antialiasing, shader);
			
			if (cut) break;
			
			if (doTail) {
				bottom = 1;
				doTail = false;
				playAnimation('hold-$noteData', true);
				origin.set(frameWidth * .5, 0);
				cropFrame(top, bottom);
				getDrawMatrix();
			}
		}
	}
	function cropFrame(cropTop:Float = 0, cropBottom:Float = 0) {
		_frame = frame.clipTo(_rect.set(0, cropTop, frameWidth, frameHeight - cropTop - cropBottom), _frame);
	}
	function getDrawMatrix() {
		_frame.prepareMatrix(_matrix, FlxFrameAngle.ANGLE_0, checkFlipX(), checkFlipY());
		
		_matrix.translate(-origin.x, -origin.y);
		_matrix.scale(scale.x, scale.y);
		
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
}