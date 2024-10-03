package;

class HealthIcon extends FunkinSprite {
	public var icon(default, set):String;
	public var defaultScale:Float = 1;
	public var bopIntensity:Float = .2;
	public var bopSpeed:Float = 1;
	
	public function new(icon:String) {
		super();
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
		var iconPath:String = 'icons/$newIcon';
		loadTexture(iconPath);
		loadGraphic(Paths.image(iconPath), true, Std.int(width * .5), Std.int(height));
		animation.add('neutral', [0]);
		animation.add('winning', [0]);
		animation.add('losing', [1]);
		playAnimation('neutral');
		updateHitbox();
		return icon = newIcon;
	}
}