package funkin.backend;

import flixel.math.FlxMatrix;
import flixel.util.FlxAxes;
import flixel.util.FlxSignal;
import flixel.util.FlxDestroyUtil;
import flixel.graphics.frames.FlxFrame;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.frames.FlxFramesCollection;
import funkin.backend.FunkinAnimate;

class FunkinSprite extends FlxSprite implements IFunkinSpriteAnim {
	public var onAnimationComplete:FlxTypedSignal<String -> Void> = new FlxTypedSignal();
	public var onAnimationFrame:FlxTypedSignal<Int -> Void> = new FlxTypedSignal();
	public var currentAnimation(get, never):Null<String>;

	public var animationList:Map<String, AnimationInfo> = new Map();
	public var extraData:Map<String, Dynamic> = new Map();
	public var offsets:Map<String, FlxPoint> = new Map();
	public var smooth(default, set):Bool = true;
	public var spriteOffset:FlxPoint;
	public var animOffset:FlxPoint;
	public var rotateOffsets:Bool = false;
	public var scaleOffsets:Bool = true;
	
	public var zoomFactor:Float = 1;
	public var initialZoom:Float = 1;

	var renderType:SpriteRenderType = SPARROW;
	public var isAnimate(get, never):Bool;
	public var anim(get, never):Dynamic; // for scripting purposes
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
	
	public function new(x:Float = 0, y:Float = 0, isSmooth:Bool = true) {
		super(x, y);
		_transPoint = new FlxPoint();
		spriteOffset = FlxPoint.get();
		animOffset = FlxPoint.get();
		smooth = isSmooth;
	}
	public override function destroy() {
		_transPoint = FlxDestroyUtil.put(_transPoint);
		animOffset = FlxDestroyUtil.put(animOffset);
		spriteOffset = FlxDestroyUtil.put(spriteOffset);
		if (animate != null) animate.destroy();
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
			animate.offset.set(_transPoint.x, _transPoint.y);
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
	
	function resetData() {
		unloadAnimate();
		offsets.clear();
		animationList.clear();
		_loadedAtlases.resize(0);
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
		#if (flixel >= "5.9.0")
		animation.onFinish.add((anim:String) -> {
			if (this.renderType != ANIMATEATLAS)
				_onAnimationComplete(anim);
		});
		animation.onFrameChange.add((anim:String, frameNumber:Int, frameIndex:Int) -> {
			if (this.renderType != ANIMATEATLAS)
				_onAnimationFrame(frameNumber);
		});
		#else
		animation.finishCallback = (anim:String) -> {
			if (this.renderType != ANIMATEATLAS)
				_onAnimationComplete(anim);
		};
		animation.callback = (anim:String, frameNumber:Int, frameIndex:Int) -> {
			if (this.renderType != ANIMATEATLAS)
				_onAnimationFrame(frameNumber);
		}
		#end
		return this;
	}
	public function loadAnimate(path:String, ?library:String) {
		resetData();
		animate = new FunkinAnimate().loadAnimate(path, library);
		animate.funkAnim.onComplete.add(() -> {
			if (renderType == ANIMATEATLAS)
				_onAnimationComplete();
		});
		animate.funkAnim.onFrame.add((frameNumber:Int) -> {
			if (renderType == ANIMATEATLAS)
				_onAnimationFrame(frameNumber);
		});
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
	
	public override function makeGraphic(width:Int, height:Int, color:FlxColor = FlxColor.WHITE, unique:Bool = false, ?key:String) {
		super.makeGraphic(width, height, color, unique, key);
		return this;
	}
	public function setOffset(x:Float = 0, y:Float = 0) {
		offset.set();
		spriteOffset.set(x / (scaleOffsets ? scale.x : 1), y / (scaleOffsets ? scale.y : 1));
	}

	public function hasAnimationPrefix(prefix:String) {
		var frames:Array<flixel.graphics.frames.FlxFrame> = [];
		@:privateAccess //why is it private :sob:
		animation.findByPrefix(frames, prefix);
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
		if (!overwrite && animationExists(name))
			return;
		
		if (isAnimate) {
			if (animate == null || animate.funkAnim == null) return;
			var anim:FunkinAnimateAnim = animate.funkAnim;
			var symbolExists:Bool = (anim.symbolDictionary != null && anim.symbolDictionary.exists(prefix));
			if (frameIndices == null || frameIndices.length == 0) {
				if (symbolExists) {
					anim.addBySymbol(name, '$prefix\\', fps, loop);
				} else {
					try { anim.addByFrameLabel(name, prefix, fps, loop); }
					catch (e:Dynamic) { Log.warning('no frame label or symbol with the name of "$prefix" was found...'); }
				}
			} else {
				if (symbolExists) {
					anim.addBySymbolIndices(name, prefix, frameIndices, fps, loop);
				} else { // frame label by indices
					var keyFrame = anim.getFrameLabel(prefix); // todo: move to FunkinAnimateAnim
					try {
						var keyFrameIndices:Array<Int> = keyFrame.getFrameIndices();
						var finalIndices:Array<Int> = [];
						for (index in frameIndices) finalIndices.push(keyFrameIndices[index] ?? (keyFrameIndices.length - 1));
						try { anim.addBySymbolIndices(name, anim.stageInstance.symbol.name, finalIndices, fps, loop); }
						catch (e:Dynamic) {}
					} catch (e:Dynamic) {
						Log.warning('no frame label or symbol with the name of "$prefix" was found...');
					}
				}
			}
		} else {
			if (assetPath == null) { // wait for the asset to be loaded
				if (frameIndices == null || frameIndices.length == 0) {
					animation.addByPrefix(name, prefix, fps, loop, flipX, flipY);
				} else {
					if (prefix == null)
						animation.add(name, frameIndices, fps, loop, flipX, flipY);
					else
						animation.addByIndices(name, prefix, frameIndices, '', fps, loop, flipX, flipY);
				}
			}
		}
		animationList[name] = {prefix: prefix, fps: fps, loop: loop, assetPath: assetPath, frameIndices: frameIndices};
	}
	public function playAnimation(anim:String, forced:Bool = false, reversed:Bool = false, frame:Int = 0) {
		preloadAnimAsset(anim);
		var animExists:Bool = false;
		if (isAnimate) {
			if (animate == null) return;
			if (animationExists(anim)) {
				animate.funkAnim.play(anim, forced, reversed, frame);
				animExists = true;
			}
		} else {
			if (animationExists(anim)) {
				animation.play(anim, forced, reversed, frame);
				animExists = true;
			}
		}
		if (animExists) {
			if (offsets.exists(anim)) {
				var offset:FlxPoint = offsets[anim];
				setAnimOffset(offset.x, offset.y);
			} else {
				setAnimOffset();
			}
		}
	}
	public function setAnimOffset(x:Float = 0, y:Float = 0):Void {
		animOffset.set(x, y);
	}
	public function preloadAnimAsset(anim:String) { // preloads animation with a different spritesheet path
		if (isAnimate) return;
		
		var animData:AnimationInfo = animationList[anim];
		if (animData != null && animData.assetPath != null) {
			addAtlas(animData.assetPath, false, null, renderType);
			if (!animation.exists(anim))
				addAnimation(anim, animData.prefix, animData.fps, animData.loop, animData.frameIndices);
		}
	}
	public function animationExists(anim:String, preload:Bool = false):Bool {
		if (preload)
			preloadAnimAsset(anim);
		if (isAnimate) {
			return animate.funkAnim.exists(anim);
		} else {
			return animation.exists(anim);
		}
	}
	public function renameAnimation(oldAnim:String, newAnim:String) {
		if (isAnimate) {
			animate.funkAnim.rename(oldAnim, newAnim);
		} else {
			animation.rename(oldAnim, newAnim);
		}
	}
	public function getAnimationNameList():Array<String> {
		if (isAnimate) {
			return animate.funkAnim.getNameList();
		} else {
			return animation.getNameList();
		}
	}
	public function isAnimationFinished():Bool {
		if (isAnimate) {
			return animate.funkAnim.finished ?? false;
		} else {
			return animation.finished ?? false;
		}
	}
	public function finishAnimation() {
		if (isAnimate) {
			animate.funkAnim.finish();
		} else {
			animation.finish();
		}
	}
	public function unloadAnimate() {
		if (isAnimate && animate != null) {
			animate.destroy();
			animate = null;
		}
	}
	function _onAnimationComplete(?anim:String) {
		onAnimationComplete.dispatch(anim ?? currentAnimation ?? '');
	}
	function _onAnimationFrame(frameNumber:Int) {
		onAnimationFrame.dispatch(frameNumber);
	}

	public function set_smooth(newSmooth:Bool) {
		antialiasing = (newSmooth && Options.data.antialiasing);
		return (smooth = newSmooth);
	}

	override function get_width() {
		if (isAnimate) return animate.width;
		else return width;
	}
	override function get_height() {
		if (isAnimate) return animate.height;
		else return height;
	}
	function get_anim() {
		return (isAnimate ? animate.funkAnim : animation);
	}
	function get_isAnimate() {
		return (renderType == ANIMATEATLAS && animate != null);
	}
	function get_currentAnimation() {
		if (isAnimate) return animate.funkAnim.name;
		else return animation.name;
	}
}
interface IFunkinSpriteAnim { // the essentials, anyway
	public var currentAnimation(get, never):Null<String>;
	
	public function preloadAnimAsset(anim:String):Void;
	public function setOffset(x:Float = 0, y:Float = 0):Void;
	public function playAnimation(anim:String, forced:Bool = false, reversed:Bool = false, frame:Int = 0):Void;
	public function animationExists(anim:String, preload:Bool = false):Bool;
	public function isAnimationFinished():Bool;
	public function finishAnimation():Void;
	
	public var onAnimationComplete:FlxTypedSignal<String -> Void>;
	public var onAnimationFrame:FlxTypedSignal<Int -> Void>;
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
	@:optional var flipX:Bool;
	@:optional var flipY:Bool;
	@:optional var assetPath:String;
	@:optional var frameIndices:Array<Int>;
}