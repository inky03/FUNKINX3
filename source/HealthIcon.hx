package;

class HealthIcon extends FunkinSprite {
	public var icon(default, set):String;
	public var defaultScale:Float = 1;
	public var bopIntensity:Float = .2;
	public var bopSpeed:Float = 1;
	
	public function new(x:Float = 0, y:Float = 0, icon:String = 'face') {
		super(x, y);
		this.icon = icon;
		origin.set(width * .5, height * .5);
	}

	public function bop() {
		var target:Float = defaultScale + bopIntensity;
		scale.set(target, target);
	}
	public function updateBop(elapsed:Float) {
		var target:Float = Util.smoothLerp(scale.x, defaultScale, bopSpeed * elapsed * 15);
		scale.set(target, target);
	}
	
	public function set_icon(newIcon:String) {
		if (icon == newIcon) return icon;
		loadTexture('icons/$newIcon');
		if (graphic == null) loadTexture('icons/icon-$newIcon');
		var wFrameRatio:Int = Math.round(width / height);
		loadGraphic(graphic ?? Paths.image('icons/face'), true, Std.int(width / wFrameRatio), Std.int(height));
		animation.add('neutral', [0]);
		animation.add('winning', [animation.numFrames >= 2 ? 2 : 0]);
		animation.add('losing', [1]);
		playAnimation('neutral');
		updateHitbox();
		return icon = newIcon;
	}
}