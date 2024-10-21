package;

import flixel.util.typeLimit.OneOfTwo;

using StringTools;

class HScriptBackend {
	public static var activeScripts:Array<HScript> = [];
	
	public static function find(test:OneOfTwo<String, HScript>) {
		if (Std.isOfType(test, HScript)) {
			return activeScripts.contains(test) ? test : null;
		} else {
			for (hscript in activeScripts) {
				if (hscript.scriptName == test) return hscript;
			}
			return null;
		}
	}
	public static function findFromSuffix(test:String) {
		for (hscript in activeScripts) {
			if (hscript.scriptName.endsWith(test)) return hscript;
		}
		return null;
	}
	public static function add(hscript:HScript):Void {
		if (!activeScripts.contains(hscript)) activeScripts.push(hscript);
	}
	public static function stop(hscript:HScript):Void {
		if (activeScripts.contains(hscript)) activeScripts.remove(hscript);
		hscript.destroy();
	}
	public static function stopAllScripts():Void {
		while (activeScripts.length > 0) stop(activeScripts[0]);
	}
	public static function set(field:String, value:Any):Void {
		for (hscript in activeScripts) {
			hscript.set(field, value);
		}
	}
	public static function run(?name:String, ?args:Array<Any>):Any {
		var returnValue:Any = null;
		var returnLocked:Bool = false;
		for (hscript in activeScripts) {
			var result:Any = hscript.run(name, args, true);
			switch (result) {
				case null:
				case HScript.STOPALL: return result;
				case HScript.STOP: returnLocked = true;
				default: if (!returnLocked) returnValue = result;
			}
		}
		return returnValue;
	}
	public static function loadFromFolder(path:String):Void {
		var dirList:Array<String> = [Paths.sharedPath(path)];
		dirList.push(Paths.modPath(path));
		for (mod in Mods.get()) {
			dirList.push(Paths.modPath(path, mod.directory));
		}
		for (dir in dirList) {
			if (FileSystem.exists(dir)) {
				Log.info('loading scripts from $dir');
				for (file in FileSystem.readDirectory(dir)) {
					if (!file.endsWith('.hx') && !file.endsWith('.hxs')) continue;
					loadFromFile('$dir/$file');
				}
			}
		}
	}
	public static function loadFromString(code:String):HScript {
		var hs:HScript = new HScript(code, code);
		hs.run();
		add(hs);
		return hs;
	}
	public static function loadFromFile(file:String, unique:Bool = false):HScript {
		if (!unique) {
			var found:HScript = find(file);
			if (found != null) {
				// Sys.println('HScript: found active script $file');
				return found;
			}
		}
		
		var code:String;
		if (FileSystem.exists(file)) {
			Sys.println('HScript: loading script from $file');
			code = File.getContent(file);
		} else {
			Log.error('HScript: couldn\'t load script from $file!!');
			code = '';
		}
		var hs:HScript = new HScript(file, code);
		hs.run();
		add(hs);
		return hs;
	}
	public static function loadFromPaths(basepath:String) {
		var found:Bool = false;
		for (path in Paths.getPaths(basepath)) {
			HScriptBackend.loadFromFile(path);
			found = true;
		}
		return found;
	}
}