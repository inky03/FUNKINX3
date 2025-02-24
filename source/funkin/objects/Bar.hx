package funkin.objects;

typedef BarBounds = {
	var min:Float;
	var max:Float;
}
class Bar extends FunkinSpriteGroup {
	public var overlay:FunkinSprite;
	public var leftBar:FunkinSprite;
	public var rightBar:FunkinSprite;
	
	public var targetPercent:Float = 100;
	public var percent(default, set):Float;
	public var percentLerp:Float = .15 * 60;
	public var valueFunc:Bar -> Float = null;
	
	public var bounds:BarBounds = {min: 0, max: 1};
	public var barRect:FlxRect = new FlxRect(4, 4);
	public var barCenter:FlxPoint = new FlxPoint();
	
	public var leftToRight(default, set):Bool = true;
	
	public function new(x:Float = 0, y:Float = 0, valueFunction:Bar -> Float = null, overlayImage:String = 'healthBar') {
		super(x, y);
		overlay = new FunkinSprite().loadTexture(overlayImage);
		leftBar = new FunkinSprite().makeGraphic(Std.int(overlay.width), Std.int(overlay.height), -1);
		rightBar = new FunkinSprite().makeGraphic(Std.int(overlay.width), Std.int(overlay.height), -1);
		rightBar.clipRect = new FlxRect();
		leftBar.clipRect = new FlxRect();
		add(overlay);
		add(leftBar);
		add(rightBar);
		valueFunc = valueFunction;
		
		barRect.width = leftBar.width - barRect.x * 2;
		barRect.height = leftBar.height - barRect.y * 2;
		percent = updateTargetPercent();
		updateBars();
		setColors();
	}
	public function loadTexture(overlayImage:String = 'healthBar'):Bar {
		overlay.loadTexture(overlayImage);
		reloadBars();
		return this;
	}
	public function loadFillTexture(?leftFill:String, ?rightFill:String):Bar {
		if (leftFill != null) {
			leftBar.loadTexture(leftFill);
		} else {
			leftBar.makeGraphic(Std.int(overlay.width), Std.int(overlay.height), -1);
		}
		if (rightFill == null)
			rightBar.graphic = leftBar.graphic;
		reloadBars();
		return this;
	}
	public function setColors(leftColor:FlxColor = 0xff0000, rightColor:FlxColor = 0x66ff33):Bar {
		leftBar.color = leftColor;
		rightBar.color = rightColor;
		return this;
	}
	
	public override function update(elapsed:Float) {
		super.update(elapsed);
		updateTargetPercent();
		if (percentLerp >= 0) {
			percent = Util.smoothLerp(percent, targetPercent, percentLerp * elapsed);
		} else {
			percent = targetPercent;
		}
		updateBarCenter();
	}
	
	function set_percent(newPercent:Float) {
		if (percent != newPercent) {
			percent = newPercent;
			updateBars();
		}
		return newPercent;
	}
	function reloadBars() {
		leftBar.setGraphicSize(overlay.width, overlay.height);
		rightBar.setGraphicSize(overlay.width, overlay.height);
		leftBar.updateHitbox();
		rightBar.updateHitbox();
		
		barRect.width = leftBar.width - barRect.x * 2;
		barRect.height = leftBar.height - barRect.y * 2;
		updateBars();
	}
	function updateTargetPercent():Float {
		if (valueFunc != null) {
			if (bounds.max <= bounds.min)
				return 0;
			
			var val:Float = valueFunc(this);
			return targetPercent = Util.clamp((val - bounds.min) / bounds.max * 100, 0, 100);
		} else {
			return Util.clamp(targetPercent, 0, 100);
		}
	}
	function set_leftToRight(isIt:Bool) {
		if (leftToRight == isIt) return isIt;
		leftToRight = isIt;
		updateBars();
		return isIt;
	}
	public function updateBars() {
		var fPercent:Float = (leftToRight ? 100 - percent : percent) * .01;
		var leftWidth:Float = FlxMath.lerp(0, barRect.width, fPercent);
		
		leftBar.clipRect.x = barRect.x;
		leftBar.clipRect.y = barRect.y;
		leftBar.clipRect.width = leftWidth;
		
		rightBar.clipRect.y = barRect.y;
		rightBar.clipRect.x = barRect.x + leftWidth;
		rightBar.clipRect.width = barRect.width - leftWidth;
		
		rightBar.clipRect.height = leftBar.clipRect.height = barRect.height;
		rightBar.clipRect = rightBar.clipRect;
		leftBar.clipRect = leftBar.clipRect;
		
		updateBarCenter();
	}
	inline function updateBarCenter() {
		barCenter.set(leftBar.x + leftBar.clipRect.x + leftBar.clipRect.width, leftBar.y + leftBar.height * .5);
	}
}