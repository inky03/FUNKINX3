package;

import flixel.graphics.frames.FlxFramesCollection;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.math.FlxPoint.FlxCallbackPoint;

class FunkinSprite extends FlxSprite {
	public var extraData:Map<String, Dynamic> = new Map<String, Dynamic>();
	public var offsets:Map<String, FlxPoint> = new Map<String, FlxPoint>();
	public var smooth(default, set):Bool = true;
	public var spriteOffset:FlxCallbackPoint;
	public var animOffset:FlxCallbackPoint;
	public var rotateOffsets:Bool = false;
	
	public function new(x:Float = 0, y:Float = 0, smooth:Bool = true) {
		super(x, y);
		spriteOffset = new FlxCallbackPoint((point:FlxPoint) -> refreshOffset());
		animOffset = new FlxCallbackPoint((point:FlxPoint) -> refreshOffset());
		this.smooth = smooth;
	}
	public override function destroy() {
		spriteOffset.destroy();
		animOffset.destroy();
		super.destroy();
	}
	public override function update(elapsed:Float) {
		refreshOffset();
		super.update(elapsed);
	}
	
	public function loadTexture(path:String) {
		loadGraphic(Paths.image(path));
		return this;
	}
	public function loadAtlas(path:String) {
		frames = Paths.sparrowAtlas(path);
		return this;
	}
	public function addAtlas(path:String, overwrite:Bool = false) {
		if (frames == null) loadAtlas(path);
		else {
			var aFrames:FlxAtlasFrames = cast(frames, FlxAtlasFrames);
			aFrames.addAtlas(Paths.sparrowAtlas(path), overwrite);
			@:bypassAccessor frames = aFrames; // kys
		}
		return this;
	}
	
	public override function makeGraphic(width:Int, height:Int, color:FlxColor = FlxColor.WHITE, unique:Bool = false, ?key:String) {
		super.makeGraphic(width, height, color, unique, key);
		return this;
	}
	public override function updateHitbox() {
		super.updateHitbox();
		spriteOffset.set(offset.x / scale.x, offset.y / scale.y);
	}
	public override function centerOffsets(adjustPosition:Bool = false) {
		super.centerOffsets(adjustPosition);
		spriteOffset.set(offset.x / scale.x, offset.y / scale.y);
	}

	public function setOffset(x:Float, y:Float) spriteOffset.set(x / scale.x, y / scale.y);
	public function hasAnimationPrefix(prefix:String) {
		if (animation == null) return false;
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
			var cos:Float = Math.cos(rad);
			var sin:Float = Math.sin(rad);
			offset.set(cos * xP + sin * yP, cos * yP + sin * xP);
		} else
			offset.set(xP, yP);
	}
	
	public function playAnimation(anim:String, forced:Bool = false) {
		if (animation.exists(anim)) {
			animation.play(anim, forced);
			if (offsets.exists(anim)) {
				var offset:FlxPoint = offsets[anim];
				animOffset.x = offset.x;
				animOffset.y = offset.y;
			} else
				animOffset.set(0, 0);
		}
	}

	public function set_smooth(newSmooth:Bool) {
		antialiasing = (newSmooth && Settings.data.antialiasing);
		return (smooth = newSmooth);
	}
}