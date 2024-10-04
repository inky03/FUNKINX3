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

	static public function getPath(key:String, allowMods:Bool = true) {
		if (allowMods) {
			var currentMod:String = Mods.currentMod;
			if (currentMod != '') {
				var path:String = 'mods/$currentMod/$key';
				if (FileSystem.exists(path)) return path;
			}
			for (mod in Mods.get()) {
				if (!mod.global) continue;
				var path:String = 'mods/${mod.directory}/$key';
				if (FileSystem.exists(path)) return path;
			}
			if (FileSystem.exists(globalModPath(key))) return globalModPath(key);
		}
		if (FileSystem.exists(sharedPath(key))) return sharedPath(key);

		return null;
	}
	inline static public function globalModPath(key:String)
		return 'mods/$key';
	inline static public function sharedPath(key:String)
		return 'assets/$key';
	inline static public function exists(key:String, ignoreMods:Bool = false)
		return (getPath(key, ignoreMods) != null);

	static public function text(key:String) {
		var assetKey:String = getPath(key);
		if (assetKey == sharedPath(key) && Assets.exists(assetKey, TEXT)) {
			return Assets.getText(sharedPath(key));
		} else if (assetKey == null) {
			return null;
		}
		
		trace(assetKey);
		return File.getContent(assetKey);
	}

	inline static public function sound(key:String)
		return ogg('sounds/$key');

	static public function image(key:String) {
		if (graphicCache[key] != null) return graphicCache[key];

		var bmd:BitmapData = bmd(key);
		if (bmd == null) return null;
		
		var graphic:FlxGraphic = graphicCache[key] = FlxGraphic.fromBitmapData(bmd);
		graphic.destroyOnNoUse = false;
		graphic.persist = true;
		return graphic;
	}
	
	static public function bmd(key:String) {
		var bmdKey:String = 'images/$key.png';
		var assetKey:String = getPath(bmdKey);

		var bmd:BitmapData = null;
		if (assetKey == sharedPath(bmdKey) && Assets.exists(assetKey, IMAGE)) {
			return Assets.getBitmapData(assetKey);
		} else {
			if (assetKey == null) return null;
			return BitmapData.fromFile(assetKey);
		}
	}

	static public function ogg(key:String, isMusic:Bool = false) {
		var sndKey:String = '$key.ogg';
		var assetKey:String = getPath(sndKey);
		if (soundCache[key] != null) return soundCache[key];

		if (assetKey == sharedPath(sndKey) && Assets.exists(assetKey, SOUND)) {
			return (isMusic ? Assets.getMusic : Assets.getSound)(assetKey);
		} else if (assetKey == null) {
			return new Sound();
		}
		
		var snd:Sound = soundCache[key] = Sound.fromFile(key);
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