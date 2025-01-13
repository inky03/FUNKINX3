package funkin.objects;

class Bar extends FlxSpriteGroup {
	public var overlay:FunkinSprite;
	public var leftBar:FunkinSprite;
	public var rightBar:FunkinSprite;
	
	public var targetPercent:Float;
	public var percent(default, set):Float;
	public var percentLerp:Float = .15 * 60;
	public var valueFunc:Bar -> Float = null;
	
	public var bounds:Dynamic = {min: 0, max: 1};
	public var barRect:FlxRect = new FlxRect(4, 4);
	public var barCenter:FlxPoint = new FlxPoint();
	
	public var leftToRight:Bool = true;
	
	public function new(x:Float = 0, y:Float = 0, valueFunction:Bar -> Float = null, overlayImage:String = 'healthBar') {
		super(x, y);
		overlay = new FunkinSprite().loadTexture(overlayImage);
		leftBar = new FunkinSprite().makeGraphic(Std.int(overlay.width), Std.int(overlay.height), -1);
		rightBar = new FunkinSprite().makeGraphic(Std.int(overlay.width), Std.int(overlay.height), -1);
		add(overlay);
		add(leftBar);
		add(rightBar);
		updateHitbox();
		valueFunc = valueFunction;
		
		barRect.width = leftBar.width - barRect.x * 2;
		barRect.height = leftBar.height - barRect.y * 2;
		leftBar.clipRect = new FlxRect().copyFrom(barRect);
		rightBar.clipRect = new FlxRect().copyFrom(barRect);
		targetPercent = 50;
		percent = targetPercent;
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
		if (valueFunc != null) targetPercent = FlxMath.remapToRange(valueFunc(this), bounds.min, bounds.max, 0, 100);
		percent = Util.smoothLerp(percent, targetPercent, percentLerp * elapsed);
		barCenter.set(leftBar.x + leftBar.clipRect.x + leftBar.clipRect.width, y + height * .5);
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
		updateBars();
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
		
		leftBar.clipRect = leftBar.clipRect;
		rightBar.clipRect = rightBar.clipRect;
	}
}