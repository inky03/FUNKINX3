package funkin.objects;

typedef BarBounds = {
	var min:Float;
	var max:Float;
}
class Bar extends FunkinSpriteGroup {
	public var overlay:FunkinSprite;
	public var leftBar:FunkinSprite;
	public var rightBar:FunkinSprite;
	
	public var value:Float = .5;
	public var targetPercent:Float = 50;
	public var percent(default, set):Float;
	public var percentLerp:Null<Float> = .15 * 60;
	public var valueFunc:Bar -> Float = null;
	
	public var bounds:BarBounds = {min: 0, max: 1};
	public var barRect:FlxRect = new FlxRect(4, 4);
	public var barCenter(get, null):FlxPoint;
	
	public var leftToRight(default, set):Bool = true;
	public var overlayOnTop(default, set):Bool = false;
	
	var _barPoint:FlxPoint = FlxPoint.get();
	
	public function new(x:Float = 0, y:Float = 0, valueFunction:Bar -> Float = null, overlayImage:String = 'healthBar', ?newBounds:BarBounds) {
		super(x, y);
		overlay = new FunkinSprite().loadTexture(overlayImage);
		leftBar = new FunkinSprite().makeGraphic(Std.int(overlay.width), Std.int(overlay.height), -1);
		rightBar = new FunkinSprite().makeGraphic(Std.int(overlay.width), Std.int(overlay.height), -1);
		rightBar.clipRect = new FlxRect();
		leftBar.clipRect = new FlxRect();
		valueFunc = valueFunction;
		if (newBounds != null)
			bounds = newBounds;
		
		insertZIndex(leftBar, 5);
		insertZIndex(rightBar, 10);
		
		barRect.height = leftBar.height - barRect.y * 2;
		barRect.width = leftBar.width - barRect.x * 2;
		overlayOnTop = false;
		snapToPercent();
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
	public function snapToPercent():Bar {
		percent = updateTargetPercent();
		updateBars();
		return this;
	}
	
	public override function update(elapsed:Float) {
		super.update(elapsed);
		updateTargetPercent();
		if (percentLerp != null && percentLerp >= 0) {
			percent = Util.smoothLerp(percent, targetPercent, percentLerp * elapsed);
		} else {
			percent = targetPercent;
		}
	}
	
	function get_barCenter():FlxPoint {
		var result:FlxPoint = _barPoint.set(leftBar.clipRect.x + leftBar.clipRect.width, leftBar.clipRect.y + leftBar.clipRect.height * .5);
		result.subtract(leftBar.origin);
		result.scale(leftBar.scale.x, leftBar.scale.y);
		result.degrees += leftBar.angle;
		result.add(leftBar.origin);
		result.subtract(leftBar.offset);
		result.add(leftBar.x, leftBar.y);
		
		return result;
	}
	function set_percent(newPercent:Float):Float {
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
			
			value = valueFunc(this);
			return targetPercent = Util.clamp((value - bounds.min) / (bounds.max - bounds.min) * 100, 0, 100);
		} else {
			return Util.clamp(targetPercent, 0, 100);
		}
	}
	function set_leftToRight(isIt:Bool):Bool {
		if (leftToRight == isIt) return isIt;
		leftToRight = isIt;
		updateBars();
		return isIt;
	}
	function set_overlayOnTop(yea:Bool):Bool {
		insertZIndex(overlay, (yea ? 15 : 0));
		return overlayOnTop = yea;
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
	}
}