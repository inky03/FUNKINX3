package;

import funkin.states.CrashState;
import funkin.debug.DebugDisplay;
import funkin.backend.FunkinGame;
import funkin.backend.scripting.HScript;

class Main extends openfl.display.Sprite {
	public static var instance:Main;
	
	public static var engineVersion(default, never):String = '0.0.7';
	public static var apiVersion(default, never):String = '0.0.1';
	
	public static var compiledTo(get, never):String;
	public static var compiledWith(get, never):String;
	
	public static var soundTray(get, never):funkin.backend.FunkinSoundTray;
	public static var windowTitle(default, null):String;
	public static var showWatermark(default, set):Bool;
	public static var debugDisplay:DebugDisplay;
	public static var watermark:FlxText;
	
	public function new() {
		super();
		instance = this;
		windowTitle = FlxG.stage.window.title;
		
		final timeText:String = 'GAME STARTED ON ${Date.now().toString()}';
		Sys.println('');
		#if I_AM_BORING_ZZZ
		Sys.println('TRANS RIGHTS');
		Sys.println('WE REALLY OUT HERE');
		Sys.println(timeText);
		#else
		if (Pride.flags.length > 0) {
			var flagArray:Array<String> = Pride.getFlagSlices(FlxG.random.getObject(Pride.flags));
			var texts:Array<String> = ['TRANS RIGHTS', 'WE REALLY OUT HERE', timeText];
			
			var textI:Int = Std.int((texts.length - flagArray.length) * .5);
			while (flagArray.length > 0) {
				var flagSlice:String = flagArray.shift();
				if (textI >= 0 && textI < texts.length) {
					Sys.println('$flagSlice ${texts[textI]}');
				} else {
					Sys.println(flagSlice);
				}
				textI ++;
			}
		}
		#end
		Sys.println('');
		
		Mods.refresh();
		HScript.init();
		DiscordRPC.prepare();
		var game:FunkinGame = new FunkinGame(0, 0, funkin.states.TitleState);
		addChild(game);
		addChild(debugDisplay = new DebugDisplay(10, 3));

		FlxG.maxElapsed = 1;
		FlxG.drawFramerate = 144;
		FlxG.updateFramerate = 144;
		FlxG.fixedTimestep = false;
		
		watermark = new FlxText(10, FlxG.height + 5, FlxG.width, 'FUNKINX3 $engineVersion\nengine by emi3');
		watermark.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		watermark.alpha = .7;
		watermark.updateHitbox();
		watermark.borderSize = 1.25;
		watermark.scrollFactor.set();
		
		FlxG.signals.postUpdate.add(() -> DiscordRPC.update());
		
		FlxG.plugins.drawOnTop = true;
		FlxG.plugins.addPlugin(watermark);
		showWatermark = true;
		
		DiscordRPC.presence.largeImageText = 'FUNKINX3 $engineVersion';
		openfl.Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(openfl.events.UncaughtErrorEvent.UNCAUGHT_ERROR, CrashState.handleUncaughtError);
	}
	
	public static function get_soundTray() {
		return cast(FlxG.game.soundTray, funkin.backend.FunkinSoundTray);
	}
	public static function set_showWatermark(show:Bool) {
		if (showWatermark == show) return showWatermark;
		FlxTween.tween(watermark, {y: FlxG.height + (show ? -40 : 5)}, 1, {ease: FlxEase.quartOut});
		return showWatermark = show;
	}
	
	static function get_compiledTo():String {
		return 
		#if windows
		'Windows'
		#elseif linux
		'Linux'
		#elseif mac
		'Mac'
		#elseif html5
		'HTML5'
		#else
		'Unknown'
		#end;
	}
	static function get_compiledWith():String {
		return 
		#if cpp
		'HXCPP'
		#elseif hl
		'Hashlink'
		#else
		'Unknown'
		#end;
	}
}

class Pride {
	public static var flagsMap:Map<String, Array<BackgroundColor>> = [
		'transgender' => [brightCyan, brightMagenta, brightWhite, brightMagenta, brightCyan],
		'lesbian' => [brightRed, brightYellow, brightWhite, brightMagenta, magenta],
		'pride' => [brightRed, brightYellow, green, brightBlue, magenta],
		'bisexual' => [brightRed, brightRed, magenta, blue, blue],
		'pansexual' => [brightRed, brightRed, brightYellow, brightCyan, brightCyan]
	];
	public static var flags(get, never):Array<Array<BackgroundColor>>;
	
	static function get_flags():Array<Array<BackgroundColor>> {
		var array:Array<Array<BackgroundColor>> = [];
		for (item in flagsMap)
			array.push(item);
		return array;
	}
	public static function getFlagSlices(array:Array<BackgroundColor>, width:Int = 15):Array<String> {
		var rectangle:String = StringTools.rpad('', ' ', width);
		var slices:Array<String> = [];
		for (color in array)
			slices.push(Log.colorTag(rectangle, none, color));
		return slices;
	}
}