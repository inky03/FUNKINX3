package;

import funkin.debug.DebugDisplay;
import funkin.backend.FunkinSoundTray;

import openfl.events.UncaughtErrorEvent;

class Main extends openfl.display.Sprite {
	public static var instance:Main;
	
	public static var soundTray(get, never):FunkinSoundTray;
	public static var windowTitle(default, null):String;
	public static var debugDisplay:DebugDisplay;
	public static var engineVersion = '0.0.5';
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
		
		watermark = new FlxText(10, FlxG.height + 5, FlxG.width, 'funkinmess $engineVersion\nengine by emi3');
		watermark.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		watermark.alpha = .7;
		watermark.updateHitbox();
		watermark.borderSize = 1.25;
		watermark.scrollFactor.set();
		
		FlxG.plugins.drawOnTop = true;
		FlxG.plugins.addPlugin(watermark);
		showWatermark = true;
		
		DiscordRPC.presence.largeImageText = 'funkinmess $engineVersion';
	}
	
	public static function get_soundTray() {
		return cast(FlxG.game.soundTray, FunkinSoundTray);
	}
	public static function set_showWatermark(show:Bool) {
		if (showWatermark == show) return showWatermark;
		FlxTween.tween(watermark, {y: FlxG.height + (show ? -40 : 5)}, 1, {ease: FlxEase.quartOut});
		return showWatermark = show;
	}
}

class FunkinGame extends flixel.FlxGame {
	var _time:Float = -1;
	
	override function switchState() {
		_time = -1;
		super.switchState();
	}
	
	override function update():Void {
		if (!_state.active || !_state.exists)
			return;

		if (_nextState != null)
			switchState();

		#if FLX_DEBUG
		if (FlxG.debugger.visible)
			ticks = getTicks();
		#end
		
		var curTime:Float = haxe.Timer.stamp();
		var realTime:Float = 0;
		if (_time >= 0)
			realTime = Math.min(curTime - _time, FlxG.maxElapsed);
		_elapsedMS = realTime * 1000;
		_time = curTime;
		_total = ticks;
		
		updateElapsed();

		FlxG.signals.preUpdate.dispatch();

		updateInput();

		#if FLX_POST_PROCESS
		if (postProcesses[0] != null)
			postProcesses[0].update(realTime);
		#end

		#if FLX_SOUND_SYSTEM
		FlxG.sound.update(realTime);
		#end
		FlxG.plugins.update(realTime);

		_state.tryUpdate(realTime);

		FlxG.cameras.update(realTime);
		FlxG.signals.postUpdate.dispatch();

		#if FLX_DEBUG
		debugger.stats.flixelUpdate(getTicks() - ticks);
		#end

		#if FLX_POINTER_INPUT
		var len = FlxG.swipes.length;
		while (len-- > 0) {
			final swipe = FlxG.swipes.pop();
			if (swipe != null)
				swipe.destroy();
		}
		#end

		filters = filtersEnabled ? _filters : null;
	}
}