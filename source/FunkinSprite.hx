package;

import flixel.util.FlxAxes;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.frames.FlxFramesCollection;
import flixel.math.FlxPoint.FlxCallbackPoint;
import flixel.util.FlxSignal.FlxTypedSignal;
import flxanimate.animate.FlxAnim;
import haxe.io.Path;

class FunkinSprite extends FlxSprite {
	public var onAnimationComplete:FlxTypedSignal<String -> Void> = new FlxTypedSignal();
	public var currentAnimation(get, never):Null<String>;

	public var extraData:Map<String, Dynamic> = new Map<String, Dynamic>();
	public var offsets:Map<String, FlxPoint> = new Map<String, FlxPoint>();
	public var animationList:Map<String, AnimationInfo> = [];
	public var smooth(default, set):Bool = true;
	public var spriteOffset:FlxCallbackPoint;
	public var animOffset:FlxCallbackPoint;
	public var rotateOffsets:Bool = false;
	public var scaleOffsets:Bool = true;

	var renderType:SpriteRenderType = SPARROW;
	public var isAnimate(get, never):Bool;
	public var anim(get, never):Dynamic; // for scripting purposes
	public var animate:FunkinAnimate;
	
	public function new(x:Float = 0, y:Float = 0, isSmooth:Bool = true) {
		super(x, y);
		spriteOffset = new FlxCallbackPoint((point:FlxPoint) -> refreshOffset());
		animOffset = new FlxCallbackPoint((point:FlxPoint) -> refreshOffset());
		smooth = isSmooth;
		animation.finishCallback = (anim:String) -> {
			if (renderType != ANIMATEATLAS)
				_onAnimationComplete();
		};
	}
	public override function destroy() {
		if (animate != null) animate.destroy();
		spriteOffset.destroy();
		animOffset.destroy();
		super.destroy();
	}
	public override function update(elapsed:Float) {
		refreshOffset();
		super.update(elapsed);
		if (isAnimate) {
			animate.update(elapsed);
			frameWidth = Std.int(animate.width); //idgaf
			frameHeight = Std.int(animate.height);
		}
	}
	
	public function loadAuto(path:String, ?library:String) {
		final pngExists:Bool = Paths.exists('images/$path.png', library);
		if (Paths.exists('images/${Path.addTrailingSlash(path)}Animation.json', library)) {
			loadAnimate(path, library);
		} else if (pngExists) {
			if (Paths.exists('images/$path.xml', library)) {
				loadAtlas(path, library);
			} else {
				loadTexture(path, library);
			}
		} else {
			Log.warning('no asset found for "$path"...');
		}
		return this;
	}
	public function loadTexture(path:String, ?library:String) {
		animationList.clear();
		loadGraphic(Paths.image(path, library));
		renderType = SPARROW;
		return this;
	}
	public function loadAtlas(path:String, ?library:String) {
		unloadAnimate();
		animationList.clear();
		switch (renderType) {
			// implement packer
			default:
				frames = Paths.sparrowAtlas(path, library);
				renderType = SPARROW;
		}
		return this;
	}
	public function loadAnimate(path:String, ?library:String) {
		unloadAnimate();
		animationList.clear();
		animate = new FunkinAnimate().loadAnimate(path, library);
		animate.anim.onComplete.add(() -> {
			if (renderType == ANIMATEATLAS)
				_onAnimationComplete();
		});
		renderType = ANIMATEATLAS;
		return this;
	}
	public function addAtlas(path:String, overwrite:Bool = false, ?library:String) {
		if (frames == null || isAnimate) {
			loadAtlas(path, library);
		} else {
			var aFrames:FlxAtlasFrames = cast(frames, FlxAtlasFrames);
			aFrames.addAtlas(Paths.sparrowAtlas(path, library), overwrite);
			@:bypassAccessor frames = aFrames; // kys
		}
		return this;
	}
	
	public override function makeGraphic(width:Int, height:Int, color:FlxColor = FlxColor.WHITE, unique:Bool = false, ?key:String) {
		super.makeGraphic(width, height, color, unique, key);
		return this;
	}
	public override function centerOffsets(adjustPosition:Bool = false) {
		super.centerOffsets(adjustPosition);
		spriteOffset.set(offset.x / (scaleOffsets ? scale.x : 1), offset.y / (scaleOffsets ? scale.y : 1));
	}

	public function setOffset(x:Float = 0, y:Float = 0) spriteOffset.set(x / scale.x, y / scale.y);
	public function hasAnimationPrefix(prefix:String) {
		var frames:Array<flixel.graphics.frames.FlxFrame> = [];
		@:privateAccess //why is it private :sob:
		animation.findByPrefix(frames, prefix);
		return (frames.length > 0);
	}
	inline public function refreshOffset() {
		var xP:Float = (spriteOffset.x + animOffset.x) * (scaleOffsets ? scale.x : 1);
		var yP:Float = (spriteOffset.y + animOffset.y) * (scaleOffsets ? scale.y : 1);
		if (rotateOffsets && angle % 360 != 0) {
			var rad:Float = angle / 180 * Math.PI;
			var cos:Float = FlxMath.fastCos(rad);
			var sin:Float = FlxMath.fastSin(rad);
			offset.set(cos * xP - sin * yP, cos * yP + sin * xP);
		} else
			offset.set(xP, yP);
	}
	
	public function centerToScreen(axes:FlxAxes = XY, byPivot:Bool = false) {
		if (isAnimate) {
			if (byPivot) {
				setPosition(FlxG.width * .5 - animate.origin.x, FlxG.height * .5 - animate.origin.y);
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
		spriteOffset.set(offset.x / (scaleOffsets ? scale.x : 1), offset.y / (scaleOffsets ? scale.y : 1));
	}

	public function setAnimationOffset(name:String, x:Float = 0, y:Float = 0):FlxPoint {
		if (offsets.exists(name)) {
			offsets[name].set(x, y);
			return offsets[name];
		} else {
			return offsets[name] = FlxPoint.get(x, y);
		}
	}
	public function addAnimation(name:String, prefix:String, fps:Float = 24, loop:Bool = false, ?frameIndices:Array<Int>, ?assetPath:String) {
		if (isAnimate) {
			if (animate == null || animate.anim == null) return;
			var anim:flxanimate.animate.FlxAnim = animate.anim;
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
				} else {
					var keyFrame = anim.getFrameLabel(prefix);
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
					animation.addByPrefix(name, prefix, fps, loop);
				} else {
					animation.addByIndices(name, prefix, frameIndices, '', fps, loop);
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
				animate.anim.play(anim, forced, reversed, frame);
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
				animOffset.x = offset.x;
				animOffset.y = offset.y;
			} else
				animOffset.set(0, 0);
		}
	}
	public function preloadAnimAsset(anim:String) { // preloads animation with a different spritesheet path
		if (isAnimate) return;
		var animData:AnimationInfo = animationList[anim];
		if (animData != null && animData.assetPath != null) {
			addAtlas(animData.assetPath, true);
			addAnimation(anim, animData.prefix, animData.fps, animData.loop, animData.frameIndices);
		}
	}
	public function animationExists(anim:String):Bool {
		if (isAnimate) {
			return animate.anim.exists(anim);
		} else {
			return animation.exists(anim) ?? false;
		}
	}
	public function isAnimationFinished():Bool {
		if (isAnimate) {
			return animate.anim.finished ?? false;
		} else {
			return animation.finished ?? false;
		}
	}
	public function finishAnimation() {
		if (isAnimate) {
			animate.anim.finish();
		} else {
			animation.finish();
		}
	}
	public function unloadAnimate() {
		if (isAnimate) {
			animate.destroy();
			animate = null;
		}
	}
	function _onAnimationComplete() {
		onAnimationComplete.dispatch(currentAnimation ?? '');
	}

	public function set_smooth(newSmooth:Bool) {
		antialiasing = (newSmooth && Settings.data.antialiasing);
		return (smooth = newSmooth);
	}

	public override function draw() {
		if (renderType == ANIMATEATLAS && animate != null) {
			animate.colorTransform = colorTransform; // lmao
			animate.scrollFactor = scrollFactor;
			animate.antialiasing = antialiasing;
			animate.setPosition(x, y);
			animate.cameras = cameras;
			animate.shader = shader;
			animate.offset = offset;
			animate.origin = origin;
			animate.scale = scale;
			animate.alpha = alpha;
			animate.angle = angle;
			animate.flipX = flipX;
			animate.flipY = flipY;
			if (visible) animate.draw();
		} else
			super.draw();
	}
	public override function get_width() {
		if (isAnimate) return animate.width;
		else return width;
	}
	public override function get_height() {
		if (isAnimate) return animate.height;
		else return height;
	}
	public function get_anim() {
		return (isAnimate ? animate.anim : animation);
	}
	public function get_isAnimate() {
		return (renderType == ANIMATEATLAS && animate != null);
	}
	public function get_currentAnimation() {
		if (isAnimate) return animate.anim.name;
		else return animation.name;
	}
}

enum SpriteRenderType {
	PACKER;
	SPARROW;
	ANIMATEATLAS;
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