package;

import openfl.utils.Assets as OFLAssets;
import lime.utils.Assets as LimeAssets;
import flxanimate.data.AnimationData;
import flixel.graphics.FlxGraphic;
import openfl.display.BitmapData;
import flixel.graphics.frames.*;
import openfl.utils.AssetType;
import openfl.media.Sound;
import openfl.Assets;
import haxe.io.Path;

using StringTools;

class Paths {
	public static var workingDirectory:String = FileSystem.absolutePath('');
	public static var graphicCache:Map<String, FlxGraphic> = [];
	public static var dynamicCache:Map<String, Dynamic> = [];
	public static var soundCache:Map<String, Sound> = [];

	public static var trackedAssets:Array<String> = [];
	static var excludeSprites:Array<FlxSprite> = [];
	static var excludeKeys:Array<String> = [];

	static public function clean() { // adapted from psych
		var exclusions:Array<String> = excludedGraphicKeys();
		@:privateAccess
		for (key => graphic in graphicCache) {
			if (!trackedAssets.contains(key) && !exclusions.contains(key)) {
				if (graphic != null) {
					graphic.destroyOnNoUse = true;
					graphic.persist = false;
					FlxG.bitmap.remove(graphic);
					// trace('graphic $key removed');
				}
				graphicCache.remove(key);
			}
		}
		for (key => snd in soundCache) {
			if (!trackedAssets.contains(key) && !excludeKeys.contains(key)) {
				if (snd != null) {
					LimeAssets.cache.clear(key);
					// trace('sound $key removed');
				}
				soundCache.remove(key);
			}
		}
		FlxG.bitmap.clearUnused();
		runGC();
	}
	inline static public function excludedGraphicKeys():Array<String> {
		var exclusions:Array<String> = excludeKeys.copy();
		while (excludeSprites.contains(null)) excludeSprites.remove(null);
		for (spr in excludeSprites) exclusions.push(spr.graphic.key);
		return exclusions;
	}
	static public function runGC() {
		openfl.system.System.gc();
		#if hl
		hl.Gc.major();
		#end
	}

	static public function getPath(key:String, allowMods:Bool = true, ?library:String) {
		if (allowMods) {
			var currentMod:String = Mods.currentMod;
			if (currentMod != '') {
				var path:String = modPath(key, currentMod, library);
				if (FileSystem.exists(path)) return path;
			}
			for (mod in Mods.get()) {
				if (!mod.global) continue;
				var path:String = modPath(key, mod.directory, library);
				if (FileSystem.exists(path)) return path;
				if (library != null) {
					var path:String = modPath(key, mod.directory);
					if (FileSystem.exists(path)) return path;
				}
			}
			if (FileSystem.exists(globalModPath(key))) return globalModPath(key);
		}
		if (FileSystem.exists(sharedPath(key, library))) return sharedPath(key, library);
		if (FileSystem.exists(key)) return key;

		return (library == null ? null : getPath(key, allowMods));
	}
	static public function getPaths(key:String, allowMods:Bool = true, allMods:Bool = false, ?library:String):Array<PathsFile> {
		var files:Array<PathsFile> = [];

		if (FileSystem.exists(key))
			files.push({path: key, type: ABSOLUTE});
		if (FileSystem.exists(sharedPath(key, library)))
			files.push({path: sharedPath(key, library), type: SHARED});
		if (allowMods) {
			if (FileSystem.exists(globalModPath(key)))
				files.push({path: globalModPath(key), type: GLOBAL});
			if (!allMods) {
				var currentMod:String = Mods.currentMod;
				if (currentMod != '') {
					var path:String = modPath(key, currentMod, library);
					if (FileSystem.exists(path)) files.push({mod: currentMod, path: path});
				}
			}
			for (mod in Mods.get()) {
				if (!allMods && (!mod.global || mod.directory == Mods.currentMod))
					continue;
				var path:String = modPath(key, mod.directory, library);
				if (FileSystem.exists(path)) files.push({mod: '', path: path});
			}
		}

		return files;
	}
	inline static public function typePath(key:String, type:PathsType, ?mod:String, ?library:String) {
		return switch (type) {
			case ABSOLUTE: key;
			case SHARED: sharedPath(key, library);
			case GLOBAL: globalModPath(key, library);
			case MOD: modPath(key, mod, library);
		}
	}
	inline static public function modPath(key:String, mod:String = '', library:String = '')
		return mod.trim() == '' ? globalModPath(key) : 'mods/$mod/${library == '' ? key : '$library/$key'}';
	inline static public function globalModPath(key:String, library:String = '')
		return 'mods/${library == '' ? key : '$library/$key'}';
	inline static public function sharedPath(key:String, library:String = '')
		return 'assets/${library == '' ? key : '$library/$key'}';
	inline static public function exists(key:String, allowMods:Bool = true, ?library:String)
		return (getPath(key, allowMods, library) != null);

	inline static public function sound(key:String, ?library:String)
		return ogg('sounds/$key', false, library);
	inline static public function music(key:String, ?library:String)
		return ogg('music/$key', false, library);
	inline static public function shaderFrag(key:String, ?library:String)
		return text('shaders/$key.frag', library);
	inline static public function shaderVert(key:String, ?library:String)
		return text('shaders/$key.vert', library);

	static public function image(key:String, ?library:String) {
		var bmdKey:String = 'images/$key.png';
		var assetKey:String = getPath(bmdKey, library);
		if (graphicCache[assetKey] != null) {
			if (!trackedAssets.contains(assetKey)) trackedAssets.push(assetKey);
			return graphicCache[assetKey];
		}

		var bmd:BitmapData = bmd(key, library);
		if (bmd == null) return null;
		
		var graphic:FlxGraphic = graphicCache[assetKey] = FlxGraphic.fromBitmapData(bmd, false, assetKey);
		trackedAssets.push(assetKey);
		graphic.destroyOnNoUse = false;
		graphic.persist = true;
		// graphic.dump();
		return graphic;
	}
	
	static public function bmd(key:String, ?library:String) {
		var bmdKey:String = 'images/$key.png';
		var assetKey:String = getPath(bmdKey, library);

		var bmd:BitmapData = null;
		if (assetKey == sharedPath(bmdKey, library) && OFLAssets.exists(assetKey, IMAGE)) {
			return OFLAssets.getBitmapData(assetKey);
		} else {
			if (assetKey == null) return null;
			return BitmapData.fromFile(assetKey);
		}
	}

	static public function ogg(key:String, isMusic:Bool = false, ?library:String) {
		var sndKey:String = '$key.ogg';
		var assetKey:String = getPath(sndKey, library);
		if (soundCache[assetKey] != null)  {
			if (!trackedAssets.contains(assetKey)) trackedAssets.push(assetKey);
			return soundCache[assetKey];
		}

		if (assetKey == sharedPath(sndKey, library) && OFLAssets.exists(assetKey, SOUND)) {
			return (isMusic ? OFLAssets.getMusic : OFLAssets.getSound)(assetKey);
		} else if (assetKey == null) {
			return new Sound();
		}
		
		trackedAssets.push(assetKey);
		var snd:Sound = soundCache[assetKey] = Sound.fromFile(assetKey);
		return snd;
	}

	static public function text(key:String, ?library:String) {
		var assetKey:String = getPath(key, library);
		if (assetKey == sharedPath(key, library) && OFLAssets.exists(assetKey, TEXT)) {
			return OFLAssets.getText(sharedPath(key, library));
		} else if (assetKey == null) {
			return null;
		}
		
		return File.getContent(assetKey);
	}
	static public function cachedDynamic(key:String, dataFunc:Void->Dynamic) {
		if (dynamicCache[key] != null) {
			return dynamicCache[key];
		}

		return dynamicCache[key] = dataFunc();
	}

	inline static public function font(key:String, ?library:String)
		return (getPath('fonts/$key', library) ?? 'Nokia Cellphone FC');
	inline static public function ttf(key:String, ?library:String)
		return font('$key.ttf', library);
	inline static public function otf(key:String, ?library:String)
		return font('$key.otf', library);

	static public function sparrowAtlas(key:String, ?library:String) {
		var xmlContent:String = text('images/$key.xml', library);
		if (xmlContent == null) return null;
		return FlxAtlasFrames.fromSparrow(image(key, library), xmlContent);
	}
}

@:structInit class PathsFile {
	public var path:String;
	public var mod:String = '';
	public var type:PathsType = MOD;
}

enum PathsType {
	ABSOLUTE;
	SHARED;
	GLOBAL;
	MOD;
}