package funkin.objects;

class HealthIcon extends FunkinSprite {
	public static var defaultIconSize = 150;
	
	public var autoUpdateBop:Bool = true;
	public var autoUpdateState:Bool = true;
	public var autoUpdatePosition:Bool = true;
	
	public var iconData(default, set):ModernCharacterHealthIconData;
	public var isPixel(default, set):Bool = false;
	public var flipped(default, set):Bool = false;
	public var state(default, set):IconState;
	public var bopIntensity:Float = .2;
	public var targetSize:Float = 150;
	public var bopSpeed:Float = 1;
	public var canBop:Bool = true;
	public var name:String;
	
	public function new(x:Float = 0, y:Float = 0, ?data:ModernCharacterHealthIconData, flipped:Bool = false) {
		super(x, y);
		this.iconData = data;
		this.flipped = flipped;
	}
	
	public function getHealthBarColor():Null<FlxColor> {
		if (iconData.healthBarRGB != null) {
			var rgb:Array<Int> = iconData.healthBarRGB;
			return FlxColor.fromRGB(rgb[0], rgb[1], rgb[2]);
		} else {
			return null;
		}
	}
	public function snapToTargetScale() {
		setGraphicSize(targetSize);
		updateHitbox();
	}
	public function bop() {
		if (!canBop)
			return;
		var bopSize:Float = targetSize * bopIntensity;
		setGraphicSize(targetSize + bopSize);
	}
	public override function update(elapsed:Float) {
		super.update(elapsed);
		if (autoUpdateBop) {
			var target:Float = Util.smoothLerp(scale.x, targetSize / frameWidth, bopSpeed * elapsed * 15);
			scale.set(target, target);
		}
	}
	
	function updateIconState(state:IconState, forced:Bool = false) {
		var nextAnim:String = (switch (state) {
			case NEUTRAL: 'neutral';
			case WINNING: 'winning';
			case LOSING: 'losing';
		});
		if (forced || currentAnimation != nextAnim)
			playAnimation(nextAnim, true);
	}
	function set_state(newState:IconState):IconState {
		if (state == newState) return newState;
		updateIconState(newState);
		return state = newState;
	}
	function set_iconData(newIcon:ModernCharacterHealthIconData) {
		if (iconData == newIcon) return newIcon;
		
		newIcon ??= {id: 'face', flipX: false};
		
		name = newIcon.id;
		loadGraphic(Paths.image('icons/$name') ?? Paths.image('icons/icon-$name') ?? Paths.image('icons/face'));
		var wFrameRatio:Int = Math.round(width / height);
		loadGraphic(graphic, true, Std.int(width / wFrameRatio), Std.int(height));
		updateHitbox();
		
		targetSize = defaultIconSize * (newIcon?.scale ?? 1);
		addAnimation('winning', [animation.numFrames > 2 ? 2 : 0]);
		addAnimation('neutral', [0]);
		addAnimation('losing', [1]);
		playAnimation('neutral');
		snapToTargetScale();
		origin.set(frameWidth * .5, frameHeight * .5);
		flipped = flipped;
		
		if (newIcon.isPixel == null) {
			isPixel = (frameWidth <= 32);
		} else {
			isPixel = newIcon.isPixel;
		}
		
		if (newIcon.offsets != null) {
			spriteOffset.set(newIcon.offsets[0], newIcon.offsets[1]);
		} else {
			spriteOffset.set();
		}
		
		updateIconState(state);
		
		return iconData = newIcon;
	}
	function set_flipped(doFlip:Bool) {
		flipX = (doFlip != (iconData?.flipX ?? false));
		return flipped = doFlip;
	}
	function set_isPixel(butIsIt:Bool) {
		smooth = !butIsIt;
		snapToTargetScale();
		return isPixel = butIsIt;
	}
}

typedef ModernCharacterHealthIconData = {
	var id:String;
	var ?flipX:Bool;
	var ?healthBarRGB:Array<Int>; // for the psych engine fans
	
	var ?scale:Float;
	var ?isPixel:Bool;
	var ?offsets:Array<Int>;
}

enum abstract IconState(String) to String {
	var NEUTRAL = 'neutral';
	var WINNING = 'winning';
	var LOSING = 'losing';
}