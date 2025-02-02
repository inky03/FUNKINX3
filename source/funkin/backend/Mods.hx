package funkin.backend;

using Lambda;

class Mods {
	public static var currentMod:String = '';
	private static var list:Array<Mod> = [];

	inline public static function get() {
		return list;
	}
	public static function modByDirectory(dir:String):Null<Mod> {
		return list.find((mod:Mod) -> mod.directory == dir);
	}
	public static function containsModDirectory(dir:String):Bool {
		return (modByDirectory(dir) != null);
	}
	public static function getLocal(allMods:Bool = false, keepPriority:Bool = false):Array<Mod> {
		var localList:Array<Mod> = [];
		
		var priorize:Bool = (!allMods || keepPriority);
		
		if (currentMod != '' && priorize) { // current mod is always high priority
			var curMod:Mod = modByDirectory(currentMod);
			if (curMod.doLoad)
				localList.push(curMod);
		}
		
		for (mod in list) {
			if (!mod.doLoad || !mod.enabled || (!allMods && !mod.global) || (priorize && mod.directory == currentMod))
				continue;
			localList.push(mod);
		}
		return localList;
	}
	public static function refresh() {
		#if MODS_ALLOWED
		if (!FileSystem.exists('mods'))
			return list;
		
		for (dir in FileSystem.readDirectory('mods')) {
			if (modByDirectory(dir) == null && FileSystem.exists('mods/$dir/pack.json'))
				list.push(new Mod(dir));
		}
		var i:Int = list.length;
		while (i > 0) {
			i --;
			var mod:Mod = list[i];
			if (!FileSystem.exists('mods/${mod.directory}/pack.json')) {
				list.remove(mod);
			} else {
				mod.directory = mod.directory;
			}
		}
		Log.info('refreshed mod info!');
		#end
		return list;
	}
}

@:structInit
class Mod {
	public var author:String = 'Unknown';
	public var name:String = 'Unnamed';
	public var global:Bool = false;
	
	public var directory(default, set):Null<String> = null;
	public var enabled:Bool = true;
	public var doLoad:Bool = false;
	
	public var info:ModInfo = null;
	
	public function new(?directory:String) {
		this.directory = directory;
	}
	
	function set_directory(newDir:Null<String>):Null<String> {
		info = null;
		doLoad = false;
		var jsonPath:String = 'mods/$newDir/pack.json';
		if (newDir != null && FileSystem.exists(jsonPath)) {
			try {
				var content:String = File.getContent(jsonPath);
				info = TJSON.parse(content);
				name = info.title;
				global = info.global ?? false;
				author = info.author ?? 'Unknown';
				
				doLoad = true;
			} catch (e:haxe.Exception) {
				Log.error('failed to load mod information from directory "$newDir"...');
				doLoad = false;
			}
		}
		return directory = newDir;
	}
	
	public function toString():String {
		return 'Mod($name by $author)';
	}
}

typedef ModInfo = {
	var title:String;
	var api_version:String;
	
	var ?description:String;
	var ?color:Array<Int>;
	var ?author:String;
	var ?global:Bool;
}