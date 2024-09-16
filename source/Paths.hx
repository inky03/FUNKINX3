package;

import flixel.graphics.FlxGraphic;
import openfl.display.BitmapData;
import flixel.graphics.frames.*;
import openfl.utils.AssetType;
import openfl.media.Sound;
import openfl.utils.Assets;
// TODO: maybe i should bring back the usage of Assets for html5 and stuff. lol.

class Paths {
	public static var graphicCache:Map<String, FlxGraphic> = [];
	public static var soundCache:Map<String, Sound> = [];

	inline static public function getPath(key:String, ignoreMods:Bool = false) {
		var path:String = sharedPath(key);
		if (FileSystem.exists(path)) return path;
		return null;
	}
	inline static public function sharedPath(key:String)
		return 'assets/$key';
	inline static public function exists(key:String, ignoreMods:Bool = false)
		return (getPath(key, ignoreMods) != null);

	static public function text(key:String) {
		if (Assets.exists(sharedPath(key), TEXT))
			return Assets.getText(sharedPath(key));

		var assetKey:String = getPath(key);
		if (assetKey == null) return null;
		return File.getContent(assetKey);
	}

	inline static public function sound(key:String)
		return ogg('sounds/$key');

	static public function image(key:String) {
		if (graphicCache[key] != null) return graphicCache[key];

		var bmd:BitmapData;
		var bmdKey:String = 'images/$key.png';

		if (Assets.exists(sharedPath(bmdKey), IMAGE))
			bmd = Assets.getBitmapData(sharedPath(bmdKey));
		else {
			var assetKey:String = getPath(bmdKey);
			if (assetKey == null) return null;
			bmd = BitmapData.fromFile(assetKey);
		}

		var graphic:FlxGraphic = graphicCache[key] = FlxGraphic.fromBitmapData(bmd);
		graphic.destroyOnNoUse = false;
		graphic.persist = true;
		return graphic;
	}

	inline static public function ogg(key:String):Sound {
		if (soundCache[key] != null) return soundCache[key];

		var sndKey:String = '$key.ogg';

		if (Assets.exists(sharedPath(sndKey), SOUND))
			return Assets.getSound(sharedPath(sndKey));
		
		var assetKey:String = getPath(sndKey);
		if (assetKey == null) return new Sound();
		var snd:Sound = soundCache[key] = Sound.fromFile(assetKey);
		return snd;
	}

	inline static public function font(key:String)
		return (getPath('fonts/$key') ?? 'Nokia Cellphone FC');

	static public function sparrowAtlas(key:String) {
		var xmlContent:String = text('images/$key.xml');
		if (xmlContent == null) return null;
		return FlxAtlasFrames.fromSparrow(image(key), xmlContent);
	}
}