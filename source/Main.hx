package;

import flixel.FlxGame;
import openfl.display.Sprite;
#if hxdiscord_rpc import lib.DiscordRPC; #end

class Main extends Sprite {
	public static var engineVersion = '0.0.2';
	
	public function new() {
		super();
		#if hxdiscord_rpc
		DiscordRPC.prepare();
		#end
		addChild(new FlxGame(0, 0, PlayState));
		addChild(new DebugDisplay(10, 3, 0xFFFFFF));
	}
}
