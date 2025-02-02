package funkin.objects;

class HealthIcon extends FunkinSprite {
	public var isPixel(default, set):Bool = false;
	public var state(default, set):IconState;
	public var icon(default, set):String;
	public var defaultSize:Float = 150;
	public var bopIntensity:Float = .2;
	public var bopSpeed:Float = 1;
	public var canBop:Bool = true;
	
	public function new(x:Float = 0, y:Float = 0, icon:String = 'face', ?isPixel:Bool) {
		super(x, y);
		this.icon = icon;
		if (isPixel == null) {
			this.isPixel = (frameWidth <= 32);
		} else {
			this.isPixel = isPixel;
		}
	}
	
	public function snapToTargetScale() {
		setGraphicSize(defaultSize);
		updateHitbox();
	}
	public function bop() {
		if (!canBop)
			return;
		var bopSize:Float = defaultSize * bopIntensity;
		setGraphicSize(defaultSize + bopSize);
	}
	public override function update(elapsed:Float) {
		super.update(elapsed);
		if (!canBop)
			return;
		var target:Float = Util.smoothLerp(scale.x, defaultSize / frameWidth, bopSpeed * elapsed * 15);
		scale.set(target, target);
	}
	
	function set_state(newState:IconState):IconState {
		if (state == newState) return newState;
		
		var nextAnim:String = (switch (newState) {
			case NEUTRAL: 'neutral';
			case WINNING: 'winning';
			case LOSING: 'losing';
		});
		if (currentAnimation != nextAnim)
			playAnimation(currentAnimation);
		return state = newState;
	}
	function set_icon(newIcon:String) {
		if (icon == newIcon) return newIcon;
		
		loadTexture('icons/$newIcon');
		if (graphic == null) loadTexture('icons/icon-$newIcon');
		var wFrameRatio:Int = Math.round(width / height);
		loadGraphic(graphic ?? Paths.image('icons/face'), true, Std.int(width / wFrameRatio), Std.int(height));
		animation.add('neutral', [0]);
		animation.add('winning', [animation.numFrames > 2 ? 2 : 0]);
		animation.add('losing', [1]);
		playAnimation('neutral');
		snapToTargetScale();
		origin.set(frameWidth * .5, frameHeight * .5);
		return icon = newIcon;
	}
	function set_isPixel(butIsIt:Bool) {
		smooth = !butIsIt;
		snapToTargetScale();
		return isPixel = butIsIt;
	}
}

enum abstract IconState(String) to String {
	var NEUTRAL = 'neutral';
	var WINNING = 'winning';
	var LOSING = 'losing';
}