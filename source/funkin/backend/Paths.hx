package funkin.backend;

import flixel.util.FlxDestroyUtil.IFlxDestroyable;
import openfl.utils.Assets as OFLAssets;
import lime.utils.Assets as LimeAssets;
import flxanimate.data.AnimationData;
import flixel.graphics.FlxGraphic;
import openfl.display.BitmapData;
import flixel.graphics.frames.*;
import flixel.system.FlxAssets;
import openfl.utils.AssetType;
import openfl.media.Sound;
import openfl.Assets;
import haxe.io.Path;

using StringTools;

class Paths {
	public static var library:String = '';
	
	public static var workingDirectory:String = FileSystem.absolutePath('');
	public static var graphicCache:Map<String, FlxGraphic> = [];
	public static var dynamicCache:Map<String, Dynamic> = [];
	public static var soundCache:Map<String, Sound> = [];

	public static var trackedAssets:Array<String> = [];
	static var excludeSprites:Array<FlxSprite> = [];
	static var excludeKeys:Array<String> = [];

	public static function clean() { // adapted from psych
		var exclusions:Array<String> = excludedGraphicKeys();
		@:privateAccess
		for (key => graphic in graphicCache) {
			if (!trackedAssets.contains(key) && !exclusions.contains(key)) {
				if (graphic != null) {
					graphic.persist = false;
					graphic.destroyOnNoUse = true;
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
		for (key => dyn in dynamicCache) {
			if (!trackedAssets.contains(key) && !excludeKeys.contains(key)) {
				if (dyn != null) {
					if (Std.isOfType(dyn, IFlxDestroyable))
						try dyn.destroy();
					dyn = null;
				}
				dynamicCache.remove(key);
			}
		}
		FlxG.bitmap.clearUnused();
		runGC();
	}
	inline public static function excludedGraphicKeys():Array<String> {
		var exclusions:Array<String> = excludeKeys.copy();
		while (excludeSprites.contains(null)) excludeSprites.remove(null);
		for (spr in excludeSprites) exclusions.push(spr.graphic.key);
		return exclusions;
	}
	public static function runGC() {
		openfl.system.System.gc();
		#if hl
		hl.Gc.major();
		#end
	}

	public static function getPath(key:String, allowMods:Bool = true, ?library:String) {
		if (allowMods) {
			if (FileSystem.exists(globalModPath(key)))
				return globalModPath(key);
			
			var path:String;
			var allMods:Bool = (Mods.currentMod == null);
			var priorize:Bool = (!allMods);
			
			if (!allMods && Mods.currentMod != '') { // current mod is high priority
				var curMod:Mod = Mods.modByDirectory(Mods.currentMod);
				
				priorize = true;
				if (curMod.doLoad) {
					path = modPath(key, Mods.currentMod, library);
					if (FileSystem.exists(path)) {
						return path;
					} else {
						path = modPath(key, Mods.currentMod);
						if (FileSystem.exists(path))
							return path;
					}
				}	
			}
			
			for (mod in Mods.get()) {
				if (!mod.doLoad || !mod.enabled || (!allMods && !mod.global) || (priorize && mod.directory == Mods.currentMod))
					continue;
				
				path = modPath(key, mod.directory, library);
				if (FileSystem.exists(path))
					return path;
				
				if (library != null) {
					path = modPath(key, mod.directory);
					if (FileSystem.exists(path))
						return path;
				}
			}
		}
		if (FileSystem.exists(sharedPath(key, library))) return sharedPath(key, library);
		if (FileSystem.exists(key)) return key;
		
		if (library == null && Paths.library != '') {
			return getPath(key, allowMods, Paths.library ?? '');
		} else {
			return null;
		}

		return (library == null ? null : getPath(key, allowMods));
	}
	public static function getPaths(key:String, allowMods:Bool = true, allMods:Bool = false, ?library:String):Array<PathsFile> {
		var files:Array<PathsFile> = [];
		
		if (FileSystem.exists(key))
			files.push({path: key, type: ABSOLUTE});
		if (FileSystem.exists(sharedPath(key, library)))
			files.push({path: sharedPath(key, library), type: SHARED});
		if (allowMods) {
			if (FileSystem.exists(globalModPath(key)))
				files.push({path: globalModPath(key), type: GLOBAL});
			
			var path:String;
			var priorize:Bool = (!allMods);
			
			if (Mods.currentMod == null) {
				allMods = true;
				priorize = false;
			} else if (Mods.currentMod != '') { // current mod is high priority
				var curMod:Mod = Mods.modByDirectory(Mods.currentMod);
				
				priorize = true;
				path = modPath(key, Mods.currentMod, library);
				if (curMod.doLoad && FileSystem.exists(path))
					files.push({mod: Mods.currentMod, path: path, type: MOD});
			}
			
			for (mod in Mods.get()) {
				if (!mod.doLoad || !mod.enabled || (!allMods && !mod.global) || (priorize && mod.directory == Mods.currentMod))
					continue;
				
				path = modPath(key, mod.directory, library);
				if (FileSystem.exists(path))
					files.push({mod: mod.directory, path: path, type: MOD});
			}
		}
		
		return files;
	}
	inline public static function typePath(key:String, type:PathsType, ?mod:String, ?library:String) {
		return switch (type) {
			case ABSOLUTE: key;
			case SHARED: sharedPath(key, library);
			case GLOBAL: globalModPath(key, library);
			case MOD: modPath(key, mod, library);
		}
	}
	inline static function offLibrary(library):Bool
		return (library == null || library == '');
	inline public static function modPath(key:String, mod:String = '', library:String = ''):String
		return mod.trim() == '' ? globalModPath(key) : 'mods/$mod/${offLibrary(library) ? key : '$library/$key'}';
	inline public static function globalModPath(key:String, library:String = ''):String
		return 'mods/${offLibrary(library) ? key : '$library/$key'}';
	inline public static function sharedPath(key:String, library:String = ''):String
		return 'assets/${offLibrary(library) ? key : '$library/$key'}';
	inline public static function modPathExists(key:String, mod:String = '', library:String = ''):Bool
		return (FileSystem.exists(modPath(key, mod, library)));
	inline public static function exists(key:String, allowMods:Bool = true, ?library:String):Bool
		return (getPath(key, allowMods, library) != null);

	inline public static function sound(key:String, ?library:String)
		return ogg('sounds/$key', false, library);
	inline public static function music(key:String, ?library:String)
		return ogg('music/$key', false, library);
	inline public static function shaderFrag(key:String, ?library:String)
		return text('shaders/$key.frag', library);
	inline public static function shaderVert(key:String, ?library:String)
		return text('shaders/$key.vert', library);
		
	public static function image(key:String, ?library:String) {
		var bmdKey:String = 'images/$key.png';
		var assetKey:Null<String> = getPath(bmdKey, library);
		if (assetKey == null) assetKey = getPath(key);
		
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
	
	public static function bmd(key:String, ?library:String) {
		var bmdKey:String = 'images/$key.png';
		var assetKey:Null<String> = getPath(bmdKey, library);
		if (assetKey == null) assetKey = getPath(key);

		var bmd:BitmapData = null;
		#if !SOFT_ASSETS
		if (assetKey == sharedPath(bmdKey, library) && OFLAssets.exists(assetKey, IMAGE)) {
			try {
				return OFLAssets.getBitmapData(assetKey);
			} catch (e:haxe.Exception) {
				return null;
			}
		} else
		#end
		{
			if (assetKey == null) return null;
			return BitmapData.fromFile(assetKey);
		}
	}

	public static function ogg(key:String, isMusic:Bool = false, ?library:String) {
		var sndKey:String = '$key.ogg';
		var assetKey:Null<String> = getPath(sndKey, library);
		if (assetKey == null) assetKey = getPath(key);
		
		if (soundCache[assetKey] != null)  {
			if (!trackedAssets.contains(assetKey)) trackedAssets.push(assetKey);
			return soundCache[assetKey];
		}

		#if !SOFT_ASSETS
		if (assetKey == sharedPath(sndKey, library) && OFLAssets.exists(assetKey, SOUND)) {
			try {
				return (isMusic ? OFLAssets.getMusic : OFLAssets.getSound)(assetKey);
			} catch (e:haxe.Exception) {
				assetKey = null;
			}
		} else
		#end
		if (assetKey == null) {
			return new Sound();
		}
		
		trackedAssets.push(assetKey);
		var snd:Sound = soundCache[assetKey] = Sound.fromFile(assetKey);
		return snd;
	}

	public static function text(key:String, ?library:String) {
		var assetKey:String = getPath(key, library);
		if (assetKey == null) assetKey = getPath(key);
		
		#if !SOFT_ASSETS
		if (assetKey == sharedPath(key, library) && OFLAssets.exists(assetKey, TEXT)) {
			return OFLAssets.getText(sharedPath(key, library));
		} else
		#end
		if (assetKey == null) {
			return null;
		}
		
		return File.getContent(assetKey);
	}
	
	public static function cachedDynamic(key:String, dataFunc:Void->Dynamic) {
		if (dynamicCache[key] != null) {
			return dynamicCache[key];
		}

		trackedAssets.push(key);
		return dynamicCache[key] = dataFunc();
	}

	inline public static function font(?key:String, ?library:String) {
		if (font == null) {
			return FlxAssets.FONT_DEFAULT;
		} else {
			return (getPath('fonts/$key', library) ?? FlxAssets.FONT_DEFAULT);
		}
	}
	inline public static function ttf(key:String, ?library:String)
		return font('$key.ttf', library);
	inline public static function otf(key:String, ?library:String)
		return font('$key.otf', library);
	
	public static function sparrowAtlas(key:String, ?library:String):FlxAtlasFrames {
		var xmlContent:String = text('images/$key.xml', library);
		if (xmlContent == null) return null;
		return FlxAtlasFrames.fromSparrow(image(key, library), xmlContent);
	}
	public static function packerAtlas(key:String, ?library:String):FlxAtlasFrames {
		var sheetContent:String = text('images/$key.txt', library);
		if (sheetContent == null) return null;
		return FlxAtlasFrames.fromSpriteSheetPacker(image(key, library), sheetContent);
	}
	public static function packerJSONAtlas(key:String, ?library:String):FlxAtlasFrames {
		var sheetContent:String = text('images/$key.json', library);
		if (sheetContent == null) return null;
		return FlxAtlasFrames.fromTexturePackerJson(image(key, library), sheetContent);
	}
}

typedef PathsFile = {
	var ?mod:String;
	var path:String;
	var type:PathsType;
}

enum abstract PathsType(String) to String {
	var ABSOLUTE = 'absolute';
	var SHARED = 'shared';
	var GLOBAL = 'global';
	var MOD = 'mod';
}