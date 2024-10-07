package;

import flixel.FlxGame;
import openfl.display.Sprite;

class Main extends Sprite {
	public static var debugDisplay:DebugDisplay;
	public static var engineVersion = '0.0.2';
	public static var watermark:FlxText;
	public static var showWatermark(default, set):Bool;
	
	public function new() {
		super();
		Sys.println('WE REALLY OUT HERE - GAME STARTED ON ${Date.now().toString()}');

		Mods.refresh();
		DiscordRPC.prepare();
		var game:FlxGame = new FlxGame(0, 0, MainMenuState);
		@:privateAccess game._customSoundTray = FunkinSoundTray;
		addChild(game);
		addChild(debugDisplay = new DebugDisplay(10, 3, 0xFFFFFF));

		FlxG.maxElapsed = 1;
		FlxG.drawFramerate = 144;
		FlxG.updateFramerate = 144;
		// FlxG.fixedTimestep = false;
		
		watermark = new FlxText(10, FlxG.height + 5, FlxG.width, 'funkin\' mess $engineVersion\nengine by emi3');
		watermark.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		watermark.updateHitbox();
		watermark.borderSize = 1.25;
		watermark.scrollFactor.set();
		watermark.alpha = .7;
		
		FlxG.plugins.drawOnTop = true;
		FlxG.plugins.addPlugin(watermark);
		showWatermark = true;
		
		DiscordRPC.presence.largeImageText = 'funkin\' mess $engineVersion';
	}
	
	public static function set_showWatermark(show:Bool) {
		if (showWatermark == show) return showWatermark;
		FlxTween.tween(watermark, {y: FlxG.height + (show ? -40 : 5)}, 1, {ease: FlxEase.quartOut});
		return showWatermark = show;
	}
}
