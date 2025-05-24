package funkin.backend;

import flixel.math.FlxMatrix;
import flixel.util.FlxAxes;
import flixel.util.FlxSignal;
import flixel.util.FlxDestroyUtil;
import flixel.system.FlxAssets;
import flxanimate.animate.FlxSymbol;
import flixel.graphics.frames.FlxFrame;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.frames.FlxFramesCollection;
import flixel.animation.FlxAnimationController;
import flixel.animation.FlxAnimation;

import funkin.backend.FunkinAnimate;

class FunkinSprite extends FlxSprite implements ISpriteVars implements IZoomFactor implements IFunkinSpriteAnim {
	public var onAnimationFrame:FlxTypedSignal<Int -> String -> Void> = new FlxTypedSignal();
	public var onAnimationComplete:FlxTypedSignal<String -> Void> = new FlxTypedSignal();
	public var onAnimationLoop:FlxTypedSignal<String -> Void> = new FlxTypedSignal();
	public var currentAnimation(get, never):Null<String>;

	public var animationList:Map<String, AnimationInfo> = new Map();
	public var extraData:Map<String, Dynamic> = new Map();
	public var offsets:Map<String, FlxPoint> = new Map();
	public var smooth(default, set):Bool = true;
	public var spriteOffset:FlxPoint;
	public var animOffset:FlxPoint;
	public var rotateOffsets:Bool = false;
	public var scaleOffsets:Bool = true;
	
	public var zoomFactor(default, set):Float = 1;
	public var initialZoom(default, set):Float = 1;

	var renderType:SpriteRenderType = SPARROW;
	public var isAnimate(get, never):Bool;
	public var anim(default, null):FunkinSpriteAnimHandler;
	public var animate:FunkinAnimate;
	
	var _loadedAtlases:Array<String> = [];
	var _transPoint:FlxPoint;
	
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
	
	public function new(x:Float = 0, y:Float = 0, isSmooth:Bool = true) {
		super(x, y);
		_transPoint = new FlxPoint();
		anim = new FunkinSpriteAnimHandler();
		spriteOffset = FlxPoint.get();
		animOffset = FlxPoint.get();
		smooth = isSmooth;
		
		anim.onFrame.add((number:Int, anim:String) -> onAnimationFrame.dispatch(number, anim));
		anim.onComplete.add((anim:String) -> onAnimationComplete.dispatch(anim));
		anim.onLoop.add((anim:String) -> onAnimationLoop.dispatch(anim));
		anim.attachedFunk = this;
	}
	public override function destroy() {
		anim = FlxDestroyUtil.destroy(anim);
		animOffset = FlxDestroyUtil.put(animOffset);
		spriteOffset = FlxDestroyUtil.put(spriteOffset);
		_transPoint = FlxDestroyUtil.put(_transPoint);
		animate = FlxDestroyUtil.destroy(animate);
		super.destroy();
	}
	public override function update(elapsed:Float) {
		if (isAnimate) {
			animate.update(elapsed);
			frameWidth = Std.int(animate.width); //idgaf
			frameHeight = Std.int(animate.height);
		} else {
			super.update(elapsed);
		}
	}
	public override function draw() {
		transformSpriteOffset(_transPoint);
		if (renderType == ANIMATEATLAS && animate != null) {
			animate.colorTransform = colorTransform; // lmao
			animate.antialiasing = antialiasing;
			animate.scrollFactor = scrollFactor;
			animate.initialZoom = initialZoom;
			animate.zoomFactor = zoomFactor;
			animate.setPosition(x, y);
			animate.cameras = cameras;
			animate.shader = shader;
			animate.offset.set(_transPoint.x + offset.x, _transPoint.y + offset.y);
			animate.origin = origin;
			animate.scale = scale;
			animate.alpha = alpha;
			animate.angle = angle;
			animate.flipX = flipX;
			animate.flipY = flipY;
			if (visible) animate.draw();
		} else {
			super.draw();
		}
	}
	function updateShader(camera:FlxCamera) {
		if (shader == null || !Std.isOfType(shader, FunkinRuntimeShader))
			return;
		
		var funk:FunkinRuntimeShader = cast shader;
		funk.postUpdateView(camera);
		funk.postUpdateFrame(frame);
	}
	public override function getScreenBounds(?newRect:FlxRect, ?camera:FlxCamera):FlxRect {
		transformSpriteOffset(_transPoint);
		if (newRect == null)
			newRect = FlxRect.get();
		
		if (camera == null)
			camera = FlxG.camera;
		
		newRect.setPosition(x, y);
		if (pixelPerfectPosition)
			newRect.floor();
		_scaledOrigin.set(origin.x * scale.x, origin.y * scale.y);
		newRect.x += -Std.int(camera.scroll.x * scrollFactor.x) - offset.x - _transPoint.x + origin.x - _scaledOrigin.x;
		newRect.y += -Std.int(camera.scroll.y * scrollFactor.y) - offset.y - _transPoint.y + origin.y - _scaledOrigin.y;
		if (isPixelPerfectRender(camera))
			newRect.floor();
		newRect.setSize(frameWidth * Math.abs(scale.x), frameHeight * Math.abs(scale.y));
		return newRect.getRotatedBounds(angle, _scaledOrigin, newRect);
	}
	public override function drawSimple(camera:FlxCamera) {
		updateShader(camera);
		
		getScreenPosition(_point, camera).subtractPoint(offset);
		if (isPixelPerfectRender(camera))
			_point.floor();

		_point.copyToFlash(_flashPoint);
		camera.copyPixels(_frame, framePixels, _flashRect, _flashPoint, colorTransform, blend, antialiasing);
	}
	public override function drawComplex(camera:FlxCamera) {
		// todo: implement this in flxsprite instead of funkinsprite? (zoomFactor wont work for flxtexts and such)
		updateShader(camera);
		
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
		
		transformMatrixZoom(_matrix, camera, zoomFactor, initialZoom);
		camera.drawPixels(_frame, framePixels, _matrix, colorTransform, blend, antialiasing, shader);
	}
	public static function transformMatrixZoom(matrix:FlxMatrix, camera:FlxCamera, zoomFactor:Float = 1, initialZoom:Float = 1):FlxMatrix {
		if (zoomFactor == 1) return matrix;
		
		final zoomMult:Float = FlxMath.lerp(initialZoom / camera.zoom, 1, zoomFactor);
		matrix.translate(-camera.width * .5, -camera.height * .5);
		matrix.scale(zoomMult, zoomMult);
		matrix.translate(camera.width * .5, camera.height * .5);
		return matrix;
	}
	public override function isSimpleRenderBlit(?camera:FlxCamera):Bool {
		return (zoomFactor == 1 && super.isSimpleRenderBlit(camera));
	}
	
	public function resetData() {
		unloadAnimate();
		offsets.clear();
		animationList.clear();
		_loadedAtlases.resize(0);
		anim.isAnimate = false;
		anim.attachedAnimate = null;
	}
	public function unloadAnimate() {
		if (isAnimate && animate != null)
			animate = FlxDestroyUtil.destroy(animate);
	}
	public function loadAuto(path:String, ?library:String) {
		final pngExists:Bool = Paths.exists('images/$path.png', library);
		if (Paths.exists('images/${haxe.io.Path.addTrailingSlash(path)}Animation.json', library)) {
			loadAnimate(path, library);
		} else if (pngExists) {
			if (Paths.exists('images/$path.xml', library)) {
				loadAtlas(path, library, SPARROW);
			} else if (Paths.exists('images/$path.txt', library)) {
				loadAtlas(path, library, PACKER);
			} else {
				loadTexture(path, library);
			}
		} else {
			Log.warning('no asset found for "$path"...');
		}
		return this;
	}
	public function loadTexture(path:String, ?library:String) {
		resetData();
		loadGraphic(Paths.image(path, library));
		renderType = SPARROW;
		return this;
	}
	public function loadAtlas(path:String, ?library:String, renderType:SpriteRenderType = SPARROW) {
		resetData();
		frames = switch (renderType) {
			case PACKER: Paths.packerAtlas(path, library);
			default: Paths.sparrowAtlas(path, library);
		}
		this.renderType = renderType;
		return this;
	}
	public function loadAnimate(path:String, ?library:String) {
		resetData();
		animate = new FunkinAnimate().loadAnimate(path, library);
		anim.attachedAnimate = animate;
		anim.isAnimate = true;
		renderType = ANIMATEATLAS;
		return this;
	}
	public function addAtlas(path:String, overwrite:Bool = false, ?library:String, renderType:SpriteRenderType = SPARROW) {
		if (frames == null || isAnimate) {
			loadAtlas(path, library, renderType);
		} else {
			if (_loadedAtlases.contains(path))
				return this;
			
			var aFrames:FlxAtlasFrames = cast(frames, FlxAtlasFrames);
			var addedAtlas:FlxAtlasFrames = switch (renderType) {
				case PACKER: Paths.packerAtlas(path, library);
				default: Paths.sparrowAtlas(path, library);
			}
			if (addedAtlas != null) {
				_loadedAtlases.push(path);
				aFrames.addAtlas(addedAtlas, overwrite);
				@:bypassAccessor frames = aFrames; // kys
			}
		}
		return this;
	}
	
	public override function loadGraphic(graphic:FlxGraphicAsset, animated:Bool = false, frameWidth:Int = 0, frameHeight:Int = 0, unique:Bool = false, ?key:String):FunkinSprite {
		super.loadGraphic(graphic, animated, frameWidth, frameHeight, unique, key);
		return this;
	}
	public override function makeGraphic(width:Int, height:Int, color:FlxColor = FlxColor.WHITE, unique:Bool = false, ?key:String):FunkinSprite {
		super.makeGraphic(width, height, color, unique, key);
		return this;
	}
	public function setOffset(x:Float = 0, y:Float = 0) {
		offset.set();
		spriteOffset.set(x / (scaleOffsets ? scale.x : 1), y / (scaleOffsets ? scale.y : 1));
	}

	public function hasAnimationPrefix(prefix:String) {
		var frames:Array<flixel.graphics.frames.FlxFrame> = [];
		try { @:privateAccess animation.findByPrefix(frames, prefix); } catch (e:Dynamic) {} //why is it private :sob:
		return (frames.length > 0);
	}
	inline public function transformSpriteOffset(point:FlxPoint):FlxPoint {
		var xP:Float = (spriteOffset.x + animOffset.x) * (scaleOffsets ? scale.x : 1);
		var yP:Float = (spriteOffset.y + animOffset.y) * (scaleOffsets ? scale.y : 1);
		if (rotateOffsets && angle % 360 != 0) {
			var rad:Float = angle / 180 * Math.PI;
			var cos:Float = FlxMath.fastCos(rad);
			var sin:Float = FlxMath.fastSin(rad);
			point.set(cos * xP - sin * yP, cos * yP + sin * xP);
		} else {
			point.set(xP, yP);
		}
		return point;
	}
	
	public function centerToScreen(axes:FlxAxes = XY, byPivot:Bool = false) {
		if (isAnimate) {
			if (byPivot) {
				switch (axes) {
					case X:
						x = FlxG.width * .5 - animate.origin.x;
					case Y:
						y = FlxG.height * .5 - animate.origin.y;
					case XY:
						setPosition(FlxG.width * .5 - animate.origin.x, FlxG.height * .5 - animate.origin.y);
					case NONE:
				}
			} else {
				animate.screenCenter(axes);
				setPosition(animate.x, animate.y);
			}
		} else {
			screenCenter(axes);
		}
		return this;
	}
	public override function updateHitbox() {
		if (isAnimate) {
			animate.alpha = .001;
			animate.draw();
			animate.alpha = 1;
			width = animate.width * scale.x;
			height = animate.height * scale.y;
		} else {
			super.updateHitbox();
		}
		// Sys.println('HITBOX UPDATED $width x $height -> $offset');
		// spriteOffset.set(offset.x / (scaleOffsets ? scale.x : 1), offset.y / (scaleOffsets ? scale.y : 1));
	}

	public function setAnimationOffset(name:String, x:Float = 0, y:Float = 0):FlxPoint {
		if (offsets.exists(name)) {
			offsets[name].set(x, y);
			return offsets[name];
		} else {
			return offsets[name] = FlxPoint.get(x, y);
		}
	}
	public function addAnimation(name:String, ?prefix:String, fps:Float = 24, loop:Bool = false, ?frameIndices:Array<Int>, ?assetPath:String, flipX:Bool = false, flipY:Bool = false, overwrite:Bool = false) {
		if (!overwrite && animationExists(name, false))
			return;
		
		if (isAnimate || assetPath == null) // if asset path provided wait for the asset to be loaded
			this.anim.add(name, prefix, fps, loop, frameIndices, flipX, flipY, overwrite);
		animationList[name] = {prefix: prefix, fps: fps, loop: loop, assetPath: assetPath, frameIndices: frameIndices, flipX: flipX, flipY: flipY};
	}
	public function playAnimation(anim:String, forced:Bool = false, reversed:Bool = false, frame:Int = 0) {
		preloadAnimAsset(anim);
		
		var played:Bool = this.anim.play(anim, forced, reversed, frame);
		
		if (played) {
			if (offsets.exists(anim)) {
				var offset:FlxPoint = offsets[anim];
				setAnimOffset(offset.x, offset.y);
			} else {
				setAnimOffset();
			}
		}
	}
	public function animationExists(anim:String, preload:Bool = true):Bool {
		if (preload)
			preloadAnimAsset(anim);
		
		return this.anim.exists(anim);
	}
	public function setAnimOffset(x:Float = 0, y:Float = 0):Void {
		animOffset.set(x, y);
	}
	public function preloadAnimAsset(anim:String) { // preloads animation with a different spritesheet path
		if (isAnimate) return;
		
		var animData:AnimationInfo = animationList[anim];
		if (animData != null && animData.assetPath != null) {
			addAtlas(animData.assetPath, false, null, renderType);
			addAnimation(anim, animData.prefix, animData.fps, animData.loop, animData.frameIndices, null, animData.flipX, animData.flipY);
		}
	}
	function get_currentAnimation():String { return anim.name; }
	public function renameAnimation(oldAnim:String, newAnim:String):Void { return anim.rename(oldAnim, newAnim); }
	public function getAnimationNameList():Array<String> { return anim.getNameList(); }
	public function isAnimationFinished():Bool { return anim.finished; }
	public function finishAnimation():Void { anim.finish(); }
	
	function set_smooth(newSmooth:Bool):Bool {
		antialiasing = (newSmooth && Options.data.antialiasing);
		return (smooth = newSmooth);
	}
	function set_zoomFactor(value:Float):Float {
		return zoomFactor = value;
	}
	function set_initialZoom(value:Float):Float {
		return initialZoom = value;
	}

	override function get_width() {
		if (isAnimate) return animate.width;
		else return width;
	}
	override function get_height() {
		if (isAnimate) return animate.height;
		else return height;
	}
	function get_isAnimate() {
		return (renderType == ANIMATEATLAS && animate != null);
	}
}

// @:access(flixel.animation.FlxAnimation)
class FunkinSpriteAnimHandler implements IFlxDestroyable {
	public var curInstance(get, never):Dynamic; // for hscript usage, mostly...
	public var curSymbol(get, never):FlxSymbol;
	public var curAnim(get, never):FlxAnimation;
	
	public var frameName(get, never):String;
	public var curFrameFloat(get, set):Float;
	public var curFrame(get, set):Int;
	public var name(get, never):String;
	public var paused(get, set):Bool;
	public var looped(get, set):Bool;
	public var length(get, never):Int;
	public var finished(get, set):Bool;
	public var reversed(get, set):Bool;
	public var timeScale(get, set):Float;
	
	public var isAnimate:Bool = false;
	public var attachedFunk(default, set):FunkinSprite;
	public var attachedAnimate(default, set):FunkinAnimate;
	
	public var onLoop:FlxTypedSignal<String -> Void> = new FlxTypedSignal();
	public var onComplete:FlxTypedSignal<String -> Void> = new FlxTypedSignal();
	public var onFrame:FlxTypedSignal<Int -> String -> Void> = new FlxTypedSignal();
	
	var spriteC(get, never):FlxAnimationController;
	var animateC(get, never):FunkinAnimateAnim;
	
	inline function set_attachedFunk(newFunk:FunkinSprite):FunkinSprite {
		var oldAnimation:FlxAnimationController = attachedFunk?.animation;
		if (oldAnimation != null) {
			#if (flixel >= "5.9.0")
			oldAnimation.onLoop.remove(_onLoop);
			oldAnimation.onFinish.remove(_funkComplete);
			oldAnimation.onFrameChange.remove(_funkFrame);
			#else
			if (oldAnimation.callback == _funkFrame) oldAnimation.callback = null;
			if (oldAnimation.finishCallback == _funkComplete) oldAnimation.finishCallback = null;
			#end
		}
		
		if (newFunk == null) return attachedFunk = newFunk;
		
		#if (flixel >= "5.9.0")
		newFunk.animation.onLoop.add(_onLoop);
		newFunk.animation.onFinish.add(_funkComplete);
		newFunk.animation.onFrameChange.add(_funkFrame);
		#else
		newFunk.animation.callback = _funkFrame;
		newFunk.animation.finishCallback = _funkComplete;
		#end
		
		return attachedFunk = newFunk;
	}
	inline function set_attachedAnimate(newAnimate:FunkinAnimate):FunkinAnimate {
		var oldAnim:FunkinAnimateAnim = attachedAnimate?.funkAnim;
		if (oldAnim != null) {
			oldAnim.onComplete.remove(_animateComplete);
			oldAnim.onFrame.remove(_animateFrame);
		}
		
		if (newAnimate == null) return attachedAnimate = newAnimate;
		
		newAnimate.anim.onComplete.add(_animateComplete);
		newAnimate.anim.onFrame.add(_animateFrame);
		
		return attachedAnimate = newAnimate;
	}
	
	function _funkComplete(anim:String):Void {
		if (isAnimate) return;
		if (looped) { _onLoop(anim); }
		else { onComplete.dispatch(anim); }
	}
	function _funkFrame(anim:String, frameNumber:Int, frameIndex:Int):Void { if (!isAnimate) onFrame.dispatch(frameNumber, anim); }
	function _animateComplete():Void {
		if (!isAnimate) return;
		if (looped) { _onLoop(name); }
		else { onComplete.dispatch(name); }
	}
	function _animateFrame(frameNumber:Int):Void { if (isAnimate) onFrame.dispatch(frameNumber, name); }
	function _onLoop(anim:String):Void { onLoop.dispatch(anim); }
	
	inline function get_spriteC():FlxAnimationController { return attachedFunk?.animation; }
	inline function get_animateC():FunkinAnimateAnim { return attachedAnimate?.funkAnim; }
	
	inline function get_curAnim():FlxAnimation { return spriteC?.curAnim; }
	inline function get_curSymbol():FlxSymbol { return animateC?.curSymbol; }
	inline function get_curInstance():Dynamic { return (isAnimate ? curAnim : curSymbol); }
	
	inline function get_curFrame():Int { return (isAnimate ? animateC.curFrame : curAnim?.curFrame) ?? 0; }
	inline function get_frameName():String { return (isAnimate ? animateC.curSymbol?.name : attachedFunk?.frame?.name) ?? ''; }
	inline function get_name():String { return (isAnimate ? animateC.name : spriteC?.name) ?? ''; }
	inline function get_paused():Bool { return (isAnimate ? !(animateC.isPlaying ?? true) : curAnim?.paused) ?? false; }
	inline function get_looped():Bool { return (isAnimate ? (animateC.loopType == Loop) : curAnim?.looped) ?? false; }
	inline function get_length():Int { return (isAnimate ? animateC.length : curAnim?.frames.length) ?? 0; }
	inline function get_finished():Bool { return (isAnimate ? animateC.finished : curAnim?.finished) ?? false; }
	inline function get_reversed():Bool { return (isAnimate ? animateC.reversed : curAnim?.reversed) ?? false; }
	inline function get_timeScale():Float { return (isAnimate ? animateC.timeScale : spriteC?.timeScale) ?? 1; }
	function get_curFrameFloat():Float {
		@:privateAccess {
			if (isAnimate) {
				if (animateC == null) return 0;
				return (animateC._tick / animateC.frameDelay + animateC.curFrame);
			} else {
				if (curAnim == null) return 0;
				var curFrameDuration = curAnim.getCurrentFrameDuration();
				return (curAnim._frameTimer / curFrameDuration + curAnim.curFrame);
			}
		}
	}
	function set_curFrameFloat(newFrame:Float):Float {
		function fract(n:Float):Float { return n - Math.floor(n); }
		
		@:privateAccess {
			if (isAnimate) {
				if (animateC == null) return newFrame;
				if (newFrame < animateC.length) {
					animateC.curFrame = Math.floor(newFrame);
					animateC._tick = animateC.frameDelay * fract(newFrame);
				} else {
					animateC.curFrame = animateC.length;
					animateC._tick = animateC.frameDelay;
				}
			} else {
				if (curAnim == null) return newFrame;
				if (newFrame < curAnim.numFrames) {
					curAnim.curFrame = Math.floor(newFrame);
					curAnim._frameTimer = curAnim.getCurrentFrameDuration() * fract(newFrame);
				} else {
					curAnim.curFrame = curAnim.numFrames;
					curAnim._frameTimer = curAnim.getCurrentFrameDuration();
				}
			}
		}
		return newFrame;
	}
	
	inline function set_curFrame(newFrame:Int):Int {
		if (isAnimate) {
			if (animateC == null) return newFrame;
			return animateC.curFrame = newFrame;
		} else {
			if (curAnim == null) return newFrame;
			return curAnim.curFrame = newFrame;
		}
	}
	inline function set_paused(isIt:Bool):Bool {
		if (isAnimate) {
			if (animateC == null) return isIt;
			(isIt ? animateC.pause : animateC.resume)();
			return isIt;
		} else {
			if (curAnim == null) return isIt;
			return curAnim.paused = isIt;
		}
	}
	inline function set_looped(isIt:Bool):Bool {
		if (isAnimate) {
			if (animateC == null) return isIt;
			animateC.loopType = (isIt ? Loop : PlayOnce);
			return isIt;
		} else {
			if (curAnim == null) return isIt;
			return curAnim.looped = isIt;
		}
	}
	inline function set_finished(isIt:Bool):Bool {
		if (isAnimate) {
			if (animateC == null) return isIt;
			if (isIt) animateC.finish();
			return animateC.finished;
		} else {
			if (curAnim == null) return isIt;
			if (isIt) curAnim.finish();
			return isIt;
		}
	}
	inline function set_reversed(isIt:Bool):Bool {
		if (isAnimate) {
			if (animateC == null) return isIt;
			return animateC.reversed = isIt;
		} else {
			if (curAnim == null) return isIt;
			if (reversed != curAnim.reversed) curAnim.reverse();
			return isIt;
		}
	}
	inline function set_timeScale(newScale:Float):Float {
		if (isAnimate) {
			if (animateC == null) return newScale;
			return animateC.timeScale = newScale;
		} else {
			if (spriteC == null) return newScale;
			return spriteC.timeScale = newScale;
		}
	}
	
	public function new() {}
	public function add(name:String, ?prefix:String, fps:Float = 24, loop:Bool = false, ?frameIndices:Array<Int>, flipX:Bool = false, flipY:Bool = false, overwrite:Bool = false):Bool {
		if (isAnimate) {
			if (animateC == null) return false;
			
			if (overwrite) {
				animateC.remove(name);
			} else if (exists(name)) {
				return false;
			}
			
			var symbolExists:Bool = (animateC.symbolDictionary != null && animateC.symbolDictionary.exists(prefix));
			if (frameIndices == null || frameIndices.length == 0) {
				if (symbolExists) {
					animateC.addBySymbol(name, '$prefix\\', fps, loop);
				} else {
					try { animateC.addByFrameLabel(name, prefix, fps, loop); }
					catch (e:Dynamic) { Log.warning('no frame label or symbol with the name of "$prefix" was found...'); }
				}
			} else {
				if (symbolExists) {
					animateC.addBySymbolIndices(name, prefix, frameIndices, fps, loop);
				} else { // frame label by indices
					var keyFrame = animateC.getFrameLabel(prefix); // todo: move to FunkinAnimateAnim
					try {
						var keyFrameIndices:Array<Int> = keyFrame.getFrameIndices();
						var finalIndices:Array<Int> = [];
						for (index in frameIndices) finalIndices.push(keyFrameIndices[index] ?? (keyFrameIndices.length - 1));
						try { animateC.addBySymbolIndices(name, animateC.stageInstance.symbol.name, finalIndices, fps, loop); }
					} catch (e:Dynamic) {
						Log.warning('no frame label or symbol with the name of "$prefix" was found...');
					}
				}
			}
			
			return animateC.exists(name);
		} else {
			if (spriteC == null) return false;
			
			if (overwrite) {
				spriteC.remove(name);
			} else if (exists(name)) {
				return false;
			}
			
			if (frameIndices == null || frameIndices.length == 0) {
				spriteC.addByPrefix(name, prefix, fps, loop, flipX, flipY);
			} else {
				if (prefix == null) {
					spriteC.add(name, frameIndices, fps, loop, flipX, flipY);
				} else {
					spriteC.addByIndices(name, prefix, frameIndices, '', fps, loop, flipX, flipY);
				}
			}
			
			return spriteC.exists(name);
		}
	}
	public function play(anim:String, forced:Bool = false, reversed:Bool = false, frame:Int = 0):Bool {
		if (exists(anim)) {
			if (isAnimate) {
				animateC?.play(anim, forced, reversed, frame);
			} else {
				spriteC?.play(anim, forced, reversed, frame);
			}
			return true;
		}
		return false;
	}
	public function reverse():Void {
		if (isAnimate) {
			if (animateC == null) return;
			animateC.reversed = !animateC.reversed;
		} else {
			spriteC?.reverse();
		}
	}
	public function exists(anim:String):Bool {
		if (isAnimate) {
			return animateC?.exists(anim) ?? false;
		} else {
			return spriteC?.exists(anim) ?? false;
		}
	}
	public function rename(oldAnim:String, newAnim:String):Void {
		if (isAnimate) {
			animateC?.rename(oldAnim, newAnim);
		} else {
			spriteC?.rename(oldAnim, newAnim);
		}
	}
	public function remove(anim:String):Void {
		if (isAnimate) {
			animateC?.remove(anim);
		} else {
			spriteC?.remove(anim);
		}
	}
	public function getNameList():Array<String> {
		if (isAnimate) {
			return animateC?.getNameList() ?? [];
		} else {
			return spriteC?.getNameList() ?? [];
		}
	}
	public function finish():Void {
		if (isAnimate) {
			animateC?.finish();
		} else {
			spriteC?.finish();
		}
	}
	
	public function destroy():Void {
		FlxDestroyUtil.destroy(onLoop);
		FlxDestroyUtil.destroy(onFrame);
		FlxDestroyUtil.destroy(onComplete);
		// idk
	}
}

interface ISpriteVars {
	public var extraData:Map<String, Dynamic>;
	
	public function setVar(k:String, v:Dynamic):Dynamic;
	public function getVar(k:String):Dynamic;
	public function hasVar(k:String):Bool;
	public function removeVar(k:String):Bool;
}
interface IZoomFactor {
	public var zoomFactor(default, set):Float;
	public var initialZoom(default, set):Float;
}
interface IFunkinSpriteAnim { // the essentials, anyway
	public var currentAnimation(get, never):Null<String>;
	
	public function preloadAnimAsset(anim:String):Void;
	public function setOffset(x:Float = 0, y:Float = 0):Void;
	public function playAnimation(anim:String, forced:Bool = false, reversed:Bool = false, frame:Int = 0):Void;
	public function animationExists(anim:String, preload:Bool = true):Bool;
	public function isAnimationFinished():Bool;
	public function finishAnimation():Void;
	
	public var onAnimationFrame:FlxTypedSignal<Int -> String -> Void>;
	public var onAnimationComplete:FlxTypedSignal<String -> Void>;
	public var onAnimationLoop:FlxTypedSignal<String -> Void>;
}

enum abstract SpriteRenderType(String) to String {
	var PACKER = 'packer';
	var SPARROW = 'sparrow';
	var ANIMATEATLAS = 'spritemap';
}

typedef AnimationInfo = {
	var prefix:String;
	var fps:Float;
	var loop:Bool;
	
	var ?flipX:Bool;
	var ?flipY:Bool;
	var ?assetPath:String;
	var ?frameIndices:Array<Int>;
}