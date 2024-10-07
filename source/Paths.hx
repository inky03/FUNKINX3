package;

import openfl.utils.Assets as OFLAssets;
import lime.utils.Assets as LimeAssets;
import flixel.graphics.FlxGraphic;
import openfl.display.BitmapData;
import flixel.graphics.frames.*;
import openfl.utils.AssetType;
import openfl.media.Sound;
import openfl.Assets;
import haxe.io.Path;

using StringTools;

class Paths {
	public static var workingDir:String = FileSystem.absolutePath('');
	public static var graphicCache:Map<String, FlxGraphic> = [];
	public static var soundCache:Map<String, Sound> = [];
	public static var trackedAssets:Array<String> = [];
	public static var excludeClear:Array<String> = [];

	static public function clearUnused() { // adapted from psych
		var cleared:Int = 0;
		@:privateAccess
		for (key => graphic in graphicCache) {
			if (!trackedAssets.contains(key) && !excludeClear.contains(key)) {
				if (graphic != null) {
					FlxG.bitmap._cache.remove(key);
					Assets.cache.removeBitmapData(key);
					graphic.destroyOnNoUse = true;
					graphic.persist = false;
					graphic.destroy();
				}
				graphicCache.remove(key);
				cleared ++;
			}
		}
		Sys.println('clearUnused: cleared $cleared assets');
		runGC();
	}
	static public function clearStored() {
		var cleared:Int = 0;
		@:privateAccess
		for (key => bmd in FlxG.bitmap._cache) {
			if (bmd != null && !graphicCache.exists(key) && !excludeClear.contains(key)) {
				Assets.cache.removeBitmapData(key);
				FlxG.bitmap._cache.remove(key);
				bmd.destroy();
				cleared ++;
			}
		}
		for (key => snd in soundCache) {
			if (snd != null) {
				LimeAssets.cache.clear(key);
				cleared ++;
			}
			soundCache.remove(key);
		}
		trackedAssets.resize(0);
		Sys.println('clearStored: cleared $cleared assets');
		runGC();
	}
	static public function runGC() {
		openfl.system.System.gc();
		#if hl
		hl.Gc.major();
		#end
	}
	static public function getPath(key:String, allowMods:Bool = true) {
		if (allowMods) {
			var currentMod:String = Mods.currentMod;
			if (currentMod != '') {
				var path:String = modPath(key, currentMod);
				if (FileSystem.exists(path)) return path;
			}
			for (mod in Mods.get()) {
				if (!mod.global) continue;
				var path:String = modPath(key, mod.directory);
				if (FileSystem.exists(path)) return path;
			}
			if (FileSystem.exists(globalModPath(key))) return globalModPath(key);
		}
		if (FileSystem.exists(sharedPath(key))) return sharedPath(key);
		if (FileSystem.exists(key)) return key;

		return null;
	}
	inline static public function modPath(key:String, mod:String = '')
		return mod.trim() == '' ? globalModPath(key) : 'mods/$mod/$key';
	inline static public function globalModPath(key:String)
		return 'mods/$key';
	inline static public function sharedPath(key:String)
		return 'assets/$key';
	inline static public function exists(key:String, allowMods:Bool = true)
		return (getPath(key, allowMods) != null);

	static public function text(key:String) {
		var assetKey:String = getPath(key);
		if (assetKey == sharedPath(key) && OFLAssets.exists(assetKey, TEXT)) {
			return OFLAssets.getText(sharedPath(key));
		} else if (assetKey == null) {
			return null;
		}
		
		return File.getContent(assetKey);
	}

	inline static public function sound(key:String)
		return ogg('sounds/$key');

	static public function image(key:String) {
		var bmdKey:String = 'images/$key.png';
		var assetKey:String = getPath(bmdKey);
		if (graphicCache[assetKey] != null) {
			if (!trackedAssets.contains(assetKey)) trackedAssets.push(assetKey);
			return graphicCache[assetKey];
		}

		var bmd:BitmapData = bmd(key);
		if (bmd == null) return null;
		
		var graphic:FlxGraphic = graphicCache[assetKey] = FlxGraphic.fromBitmapData(bmd, false, assetKey);
		trackedAssets.push(assetKey);
		graphic.destroyOnNoUse = false;
		graphic.persist = true;
		// graphic.dump();
		return graphic;
	}
	
	static public function bmd(key:String) {
		var bmdKey:String = 'images/$key.png';
		var assetKey:String = getPath(bmdKey);

		var bmd:BitmapData = null;
		if (assetKey == sharedPath(bmdKey) && OFLAssets.exists(assetKey, IMAGE)) {
			return OFLAssets.getBitmapData(assetKey);
		} else {
			if (assetKey == null) return null;
			return BitmapData.fromFile(assetKey);
		}
	}

	static public function ogg(key:String, isMusic:Bool = false) {
		var sndKey:String = '$key.ogg';
		var assetKey:String = getPath(sndKey);
		if (soundCache[assetKey] != null)  {
			if (!trackedAssets.contains(assetKey)) trackedAssets.push(assetKey);
			return soundCache[assetKey];
		}

		if (assetKey == sharedPath(sndKey) && OFLAssets.exists(assetKey, SOUND)) {
			return (isMusic ? OFLAssets.getMusic : OFLAssets.getSound)(assetKey);
		} else if (assetKey == null) {
			return new Sound();
		}
		
		trackedAssets.push(assetKey);
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