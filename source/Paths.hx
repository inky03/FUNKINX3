package;

import flixel.graphics.FlxGraphic;
import openfl.display.BitmapData;
import flixel.graphics.frames.*;
import openfl.utils.AssetType;
import openfl.utils.Assets;
import openfl.media.Sound;
import haxe.Exception;

class Paths {
	public static var workingDir:String = FileSystem.absolutePath('');
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
		var bmdKey:String = 'images/$key.png';
		var assetKey:String = getPath(bmdKey);
		if (graphicCache[assetKey] != null) return graphicCache[assetKey];

		var bmd:BitmapData;

		if (Assets.exists(sharedPath(bmdKey), IMAGE))
			bmd = Assets.getBitmapData(sharedPath(bmdKey));
		else {
			if (assetKey == null) return null;
			bmd = BitmapData.fromFile(assetKey);
		}

		var graphic:FlxGraphic = graphicCache[assetKey] = FlxGraphic.fromBitmapData(bmd);
		graphic.destroyOnNoUse = false;
		graphic.persist = true;
		return graphic;
	}

	inline static public function ogg(key:String, isMusic:Bool = false) {
		var sndKey:String = '$key.ogg';
		var assetKey:String = getPath(sndKey);
		if (soundCache[assetKey] != null) return soundCache[assetKey];

		if (Assets.exists(sharedPath(sndKey), SOUND))
			return (isMusic ? Assets.getMusic : Assets.getSound)(sharedPath(sndKey));
		
		if (assetKey == null) return null;
		var snd:Sound = soundCache[assetKey] = Sound.fromFile(assetKey);
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