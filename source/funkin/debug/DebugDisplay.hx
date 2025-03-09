package funkin.debug;

import openfl.geom.Point;
import openfl.display.Sprite;
import openfl.display.Bitmap;
import openfl.text.TextField;
import openfl.text.TextFormat;

class DebugDisplay extends Sprite {
	public var perfCounter:PerfCounter;
	public var watermark:X3Watermark;
	public var offset:Point;
	
	public var showWatermark:Bool = false;
	
	public function new(x:Float = 10, y:Float = 3) {
		super();
		
		offset = new Point(x, y);
		watermark = new X3Watermark(x);
		perfCounter = new PerfCounter(x, y);
		
		addChild(watermark);
		addChild(perfCounter);
	}
	
	override function __enterFrame(deltaTime:Float):Void {
		perfCounter.update(deltaTime);
		
		final deltaSec:Float = deltaTime * .001;
		if (showWatermark) {
			watermark.p = Math.min(watermark.p + deltaSec / watermark.time, 1);
		} else {
			watermark.p = Math.max(watermark.p - deltaSec / watermark.time, 0);
		}
		
		final winHeight:Int = FlxG.stage.window.height;
		watermark.y = winHeight - Std.int((watermark.height + offset.y) * watermark.p);
		watermark.visible = (watermark.y < winHeight);
	}
}

class X3Watermark extends Sprite {
	public var time:Float = 1.25;
	public var p:Float = 0;
	
	public function new(x:Float = 0, y:Float = 0) {
		super();
		
		this.x = x;
		this.y = y;
		
		var icon:Bitmap = new Bitmap(Paths.bmd('x3'));
		
		var text:TextField = new TextField();
		text.x = icon.width + 8;
		text.autoSize = LEFT;
		text.selectable = false;
		text.mouseEnabled = false;
		text.text = '${Main.engineVersion} by emi3';
		text.defaultTextFormat = new TextFormat('_sans', 12, FlxColor.WHITE);
		
		addChild(icon);
		addChild(text);
	}
}

class PerfCounter extends TextField {
	public var showFPS:Bool = true;
	public var showMem:Bool = true;
	
	var mem:Float;
	var maxMem:Float;
	var currentFPS:Int;
	
	var currentTime:Float;
	var times:Array<Float>;
	static var byteUnits:Array<String> = ['bytes', 'kb', 'mb', 'gb'];

	public function new(x:Float = 0, y:Float = 0) {
		super();
		
		this.x = x;
		this.y = y;
		
		currentFPS = 0;
		autoSize = LEFT;
		multiline = true;
		selectable = false;
		mouseEnabled = false;
		// filters = [new openfl.filters.GlowFilter(0, 4, 2, 2)];

		var tf:TextFormat = new TextFormat('_sans', 12, FlxColor.WHITE);
		tf.leading = -4;
		defaultTextFormat = tf;
		
		currentTime = 0;
		times = [];
	}

	public function update(deltaTime:Float):Void {
		var oldFPS:Int = currentFPS;
		var oldMem:Float = mem;
		
		currentTime += deltaTime;
		times.push(currentTime);
		while (times[0] < currentTime - 1000) times.shift();
		
		currentFPS = Math.round((oldFPS + times.length) / 2);
		mem = cast(openfl.system.System.totalMemory, UInt);
		
		if (oldFPS != currentFPS || oldMem != mem) {
			maxMem = Math.max(mem, maxMem);
			text = (showFPS ? 'FPS: ${Math.min(currentFPS, FlxG.drawFramerate)}' : '') + (showMem ? '\nGC MEM: ${formatBytes(mem)} / ${formatBytes(maxMem)}' : '');
		}
	}
	
	public static function formatBytes(bytes:Float, precision:Int = 2):String {
		var curUnit:Int = 0;
		while (bytes >= 1024 && curUnit < byteUnits.length - 1) {
			bytes /= 1024;
			curUnit++;
		}
		return FlxMath.roundDecimal(bytes, precision) + byteUnits[curUnit];
	}
}