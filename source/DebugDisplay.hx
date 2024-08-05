package;

import flixel.FlxG;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.system.System;

class DebugDisplay extends TextField {
	public var currentFPS(default, null):Int;
	public var mem:Float;
	public var maxMem:Float;
	public static var byteUnits:Array<String> = ['bytes', 'kb', 'mb', 'gb'];
	
	@:noCompletion private var currentTime:Float;
	@:noCompletion private var times:Array<Float>;

	public function new(x:Float = 10, y:Float = 10, color:Int = 0x000000) {
		super();
		
		this.x = x;
		this.y = y;
		
		currentFPS = 0;
		autoSize = LEFT;
		multiline = true;
		selectable = false;
		mouseEnabled = false;
		defaultTextFormat = new TextFormat('_sans', 12, color);
		
		currentTime = 0;
		times = [];
	}

	// Event Handlers
	private #if !flash override #end function __enterFrame(deltaTime:Float):Void {
		var oldFPS:Int = currentFPS;
		var oldMem:Float = mem;
		
		currentTime += deltaTime;
		times.push(currentTime);
		while (times[0] < currentTime - 1000) times.shift();
		
		currentFPS = Math.round((oldFPS + times.length) / 2);
		mem = cast(System.totalMemory, UInt);
		
		if (oldFPS != currentFPS || oldMem != mem) {
			maxMem = Math.max(mem, maxMem);
			text = 'FPS: ${currentFPS}'+
			'\nGC MEM: ${DebugDisplay.formatBytes(mem)} / ${DebugDisplay.formatBytes(maxMem)}';
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