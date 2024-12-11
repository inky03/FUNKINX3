package;

class HealthIcon extends FunkinSprite {
	public var isPixel(default, set):Bool = false;
	public var icon(default, set):String;
	public var defaultSize:Float = 150;
	public var bopIntensity:Float = .2;
	public var bopSpeed:Float = 1;
	
	public function new(x:Float = 0, y:Float = 0, icon:String = 'face', ?isPixel:Bool) {
		super(x, y);
		this.icon = icon;
		if (isPixel == null)
			this.isPixel = (frameWidth <= 32);
		else
			this.isPixel = isPixel;
	}
	
	public function snapToTargetScale() {
		setGraphicSize(defaultSize);
	}
	public function bop() {
		var bopSize:Float = defaultSize * bopIntensity;
		setGraphicSize(defaultSize + bopSize);
	}
	public function updateBop(elapsed:Float) {
		var target:Float = Util.smoothLerp(scale.x, defaultSize / frameWidth, bopSpeed * elapsed * 15);
		scale.set(target, target);
	}
	
	public function set_icon(newIcon:String) {
		if (icon == newIcon) return icon;
		loadTexture('icons/$newIcon');
		if (graphic == null) loadTexture('icons/icon-$newIcon');
		var wFrameRatio:Int = Math.round(width / height);
		loadGraphic(graphic ?? Paths.image('icons/face'), true, Std.int(width / wFrameRatio), Std.int(height));
		animation.add('neutral', [0]);
		animation.add('winning', [animation.numFrames > 2 ? 2 : 0]);
		animation.add('losing', [1]);
		playAnimation('neutral');
		origin.set(frameWidth * .5, frameHeight * .5);
		return icon = newIcon;
	}
	public function set_isPixel(butIsIt:Bool) {
		smooth = !butIsIt;
		snapToTargetScale();
		width = height = defaultSize;
		return isPixel = butIsIt;
	}
}