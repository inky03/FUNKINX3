package;

import funkin.states.CrashState;
import funkin.debug.DebugDisplay;
import funkin.backend.FunkinGame;
import funkin.backend.FunkinSoundTray;

class Main extends openfl.display.Sprite {
	public static var instance:Main;
	
	public static var compiledTo(get, never):String;
	public static var compiledWith(get, never):String;
	
	public static var soundTray(get, never):FunkinSoundTray;
	public static var windowTitle(default, null):String;
	public static var debugDisplay:DebugDisplay;
	public static var engineVersion = '0.0.6';
	public static var watermark:FlxText;
	public static var showWatermark(default, set):Bool;
	
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
		final flag:String = '               ';
		Sys.println(Log.colorTag(flag, cyan, brightCyan));
		Sys.println(Log.colorTag(flag, magenta, brightMagenta) + ' TRANS RIGHTS');
		Sys.println(Log.colorTag(flag, white, brightWhite) + ' WE REALLY OUT HERE');
		Sys.println(Log.colorTag(flag, magenta, brightMagenta) + ' $timeText');
		Sys.println(Log.colorTag(flag, cyan, brightCyan));
		#end
		Sys.println('');
		
		Mods.refresh();
		DiscordRPC.prepare();
		var game:FunkinGame = new FunkinGame(0, 0, funkin.states.MainMenuState);
		@:privateAccess game._customSoundTray = FunkinSoundTray;
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
		
		FlxG.plugins.drawOnTop = true;
		FlxG.plugins.addPlugin(watermark);
		showWatermark = true;
		
		DiscordRPC.presence.largeImageText = 'funkinmess $engineVersion';
		openfl.Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(openfl.events.UncaughtErrorEvent.UNCAUGHT_ERROR, CrashState.handleUncaughtError);
	}
	
	public static function get_soundTray() {
		return cast(FlxG.game.soundTray, FunkinSoundTray);
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