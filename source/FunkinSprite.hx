package;

import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.frames.FlxFramesCollection;
import flixel.math.FlxPoint.FlxCallbackPoint;
import flxanimate.animate.FlxAnim;

class FunkinSprite extends FlxSprite {
	public var extraData:Map<String, Dynamic> = new Map<String, Dynamic>();
	public var offsets:Map<String, FlxPoint> = new Map<String, FlxPoint>();
	public var smooth(default, set):Bool = true;
	public var spriteOffset:FlxCallbackPoint;
	public var animOffset:FlxCallbackPoint;
	public var rotateOffsets:Bool = false;
	public var prevScale:FlxPoint;

	var renderType:SpriteRenderType = SPARROW;
	public var anim(get, never):Dynamic;
	public var animate:FlxAnimate;
	
	public function new(x:Float = 0, y:Float = 0, smooth:Bool = true) {
		super(x, y);
		spriteOffset = new FlxCallbackPoint((point:FlxPoint) -> refreshOffset());
		animOffset = new FlxCallbackPoint((point:FlxPoint) -> refreshOffset());
		prevScale = FlxPoint.get(scale.x, scale.y);
		this.smooth = smooth;
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
		if (renderType == ANIMATEATLAS && animate != null) {
			animate.update(elapsed);
			frameWidth = Std.int(animate.width); //idgaf
			frameHeight = Std.int(animate.height);
		}
	}
	
	public function loadTexture(path:String, ?library:String) {
		loadGraphic(Paths.image(path, library));
		return this;
	}
	public function loadAtlas(path:String, ?library:String) {
		switch (renderType) {
			// implement packer
			default:
				frames = Paths.sparrowAtlas(path, library);
				renderType = SPARROW;
		}
		return this;
	}
	public function loadAnimate(path:String, ?library:String) {
		if (animate != null) animate.destroy();
		var atlasPath:String = 'images/$path';
		if (Paths.exists(atlasPath)) {
			animate = new FlxAnimate(0, 0, Paths.getPath(atlasPath));
			renderType = ANIMATEATLAS;
		} else {
			Sys.println('WARNING: animate atlas path not found... (verify: $atlasPath)');
		}
		return this;
	}
	public function addAtlas(path:String, overwrite:Bool = false, ?library:String) {
		if (frames == null || renderType == ANIMATEATLAS) loadAtlas(path, library);
		else {
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
		spriteOffset.set(offset.x / scale.x, offset.y / scale.y);
	}

	public function setOffset(x:Float, y:Float) spriteOffset.set(x / scale.x, y / scale.y);
	public function hasAnimationPrefix(prefix:String) {
		var frames:Array<flixel.graphics.frames.FlxFrame> = [];
		@:privateAccess //why is it private :sob:
		animation.findByPrefix(frames, prefix);
		return (frames.length > 0);
	}
	inline public function refreshOffset() {
		var xP:Float = (spriteOffset.x + animOffset.x) * scale.x;
		var yP:Float = (spriteOffset.y + animOffset.y) * scale.y;
		if (rotateOffsets) {
			var rad:Float = angle / 180 * Math.PI;
			var cos:Float = FlxMath.fastCos(rad);
			var sin:Float = FlxMath.fastSin(rad);
			offset.set(cos * xP - sin * yP, cos * yP + sin * xP);
		} else
			offset.set(xP, yP);
	}
	
	public override function updateHitbox() {
		if (renderType == ANIMATEATLAS && animate != null) {
			animate.alpha = .001;
			animate.draw();
			animate.alpha = 1;
			width = animate.width * scale.x;
			height = animate.height * scale.y;
		} else {
			super.updateHitbox();
		}
		spriteOffset.set(offset.x * (prevScale.x / scale.x), offset.y * (prevScale.y / scale.y));
		prevScale.copyFrom(scale);
	}
	public function animationExists(anim:String):Bool {
		if (renderType == ANIMATEATLAS) {
			if (animate == null) return false;
			@:privateAccess return (animate.anim.animsMap.exists(anim) ? true : animate.anim.symbolDictionary.exists(anim));
		} else {
			return animation?.exists(anim) ?? false;
		}
	}
	public function playAnimation(anim:String, forced:Bool = false, reversed:Bool = false, frame:Int = 0) {
		var animExists:Bool = false;
		if (renderType == ANIMATEATLAS) {
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
	public function getAnimationName() {
		if (renderType == ANIMATEATLAS)
			return animate?.anim?.name ?? '';
		else
			return animation.name ?? '';
	}
	public function isAnimationFinished():Bool {
		if (renderType == ANIMATEATLAS)
			return animate?.anim?.finished ?? false;
		else
			return animation?.finished ?? false;
	}
	public function finishAnimation() {
		if (renderType == ANIMATEATLAS)
			if (anim != null) anim.finish();
		else
			animation.finish();
	}
	public function unloadAnimate() {
		if (renderType == ANIMATEATLAS && animate != null) {
			animate.destroy();
			animate = null;
		}
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
		if (renderType == ANIMATEATLAS && animate != null) return animate.width;
		else return width;
	}
	public override function get_height() {
		if (renderType == ANIMATEATLAS && animate != null) return animate.height;
		else return height;
	}
	public function get_anim() {
		return (renderType == ANIMATEATLAS && animate != null ? animate.anim : animation);
	}
}

enum SpriteRenderType {
	PACKER;
	SPARROW;
	ANIMATEATLAS;
}