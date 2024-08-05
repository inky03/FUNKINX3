package;

class Bar extends FlxSpriteGroup {
	public var overlay:FunkinSprite;
	public var leftBar:FunkinSprite;
	public var rightBar:FunkinSprite;
	
	public var valueFunc:()->Float = null;
	public var targetPercent:Float;
	public var percent(default, set):Float;
	public var percentLerp:Float = .15 * 60;
	
	public var bounds:Dynamic = {min: 0, max: 1};
	public var barRect:FlxRect = new FlxRect(4, 4);
	public var barCenter:FlxPoint = new FlxPoint();
	
	public var leftToRight:Bool = true;
	
	public function new(x:Float = 0, y:Float = 0, overlayImage:String = 'healthBar', value:()->Float = null) {
		super(x, y);
		overlay = new FunkinSprite().loadTexture(overlayImage);
		leftBar = new FunkinSprite().makeGraphic(Std.int(overlay.width), Std.int(overlay.height), -1);
		rightBar = new FunkinSprite().makeGraphic(Std.int(overlay.width), Std.int(overlay.height), -1);
		add(overlay);
		add(leftBar);
		add(rightBar);
		updateHitbox();
		valueFunc = value;
		
		barRect.width = leftBar.width - barRect.x * 2;
		barRect.height = leftBar.height - barRect.y * 2;
		leftBar.clipRect = new FlxRect().copyFrom(barRect);
		rightBar.clipRect = new FlxRect().copyFrom(barRect);
		targetPercent = 50;
		percent = targetPercent;
		setColors();
	}
	public function loadTexture(overlayImage:String = 'healthBar') {
		overlay.loadTexture(overlayImage);
		leftBar.setGraphicSize(overlay.width, overlay.height);
		rightBar.setGraphicSize(overlay.width, overlay.height);
		leftBar.updateHitbox();
		rightBar.updateHitbox();
		updateBars();
	}
	public function setColors(leftColor:FlxColor = 0xff0000, rightColor:FlxColor = 0x66ff33) {
		leftBar.color = leftColor;
		rightBar.color = rightColor;
	}
	
	public override function update(elapsed:Float) {
		super.update(elapsed);
		if (valueFunc != null) targetPercent = FlxMath.remapToRange(valueFunc(), bounds.min, bounds.max, 0, 100);
		percent = FlxMath.lerp(percent, targetPercent, percentLerp * elapsed);
		barCenter.set(leftBar.x + leftBar.clipRect.x + leftBar.clipRect.width, y + height * .5);
	}
	
	public function set_percent(newPercent:Float) {
		if (percent != newPercent) {
			percent = newPercent;
			updateBars();
		}
		return newPercent;
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