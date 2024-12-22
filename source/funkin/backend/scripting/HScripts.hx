package funkin.backend.scripting;

import flixel.util.typeLimit.OneOfTwo;

using StringTools;

class HScripts {
	public var activeScripts:Array<HScript>;
	
	public function new() {
		activeScripts = [];
	}
	public function find(test:OneOfTwo<String, HScript>) {
		if (Std.isOfType(test, HScript)) {
			return activeScripts.contains(test) ? test : null;
		} else {
			for (hscript in activeScripts) {
				if (hscript.scriptName == test) return hscript;
			}
			return null;
		}
	}
	public function exists(name:String) return (find(name) != null);
	public function findFromSuffix(test:String) {
		for (hscript in activeScripts) {
			if (hscript.scriptName.endsWith(test)) return hscript;
		}
		return null;
	}
	public function add(hscript:HScript):Void {
		if (!activeScripts.contains(hscript)) activeScripts.push(hscript);
	}
	public function destroy(hscript:HScript):Void {
		if (activeScripts.contains(hscript))
			activeScripts.remove(hscript);
		hscript.destroy();
	}
	public function destroyAll():Void {
		while (activeScripts.length > 0)
			destroy(activeScripts[0]);
	}
	public function set(field:String, value:Any):Void {
		for (hscript in activeScripts) {
			hscript.set(field, value);
		}
	}
	public function run(?name:String, ?args:Array<Any>):Any {
		var returnLocked:Bool = false;
		var returnValue:Dynamic = null;
		for (hscript in activeScripts) {
			var result:Dynamic = hscript.run(name, args, true);
			switch (result) {
				case null:
				case HScript.STOPALL: return result;
				case HScript.STOP: returnLocked = true; returnValue = result;
				default: if (!returnLocked) returnValue = result;
			}
		}
		return returnValue;
	}
	public function loadFromFolder(path:String):Void {
		var dirList:Array<String> = [Paths.sharedPath(path)];
		dirList.push(Paths.modPath(path));
		for (mod in Mods.get()) {
			dirList.push(Paths.modPath(path, mod.directory));
		}
		for (dir in dirList) {
			if (FileSystem.exists(dir)) {
				Log.minor('loading hscripts @ "$dir"');
				for (file in FileSystem.readDirectory(dir)) {
					if (!file.endsWith('.hx') && !file.endsWith('.hxs')) continue;
					loadFromFile('$dir/$file');
				}
			}
		}
	}
	function getScriptName(name:String, unique:Bool = false, warn:Bool = false) {
		var found:HScript = find(name);
		if (found != null && unique) {
			var n:Int = 1;
			while (exists('${name}_$n')) n ++;
			name = '${name}_$n';
		}
		return name;
	}
	public function loadFromString(code:String, ?name:String):Null<HScript> {
		name ??= 'hscript';
		if (exists(name)) {
			Log.warning('hscript @ "$name" is already active!');
			name = getScriptName(name, true);
			Log.minor('using name "$name"...');
		}

		var hs:HScript = new HScript(name, code);
		if (hs.compiled) {
			Log.info('hscript "$name" loaded successfully!');
			hs.run();
			add(hs);
			return hs;
		} else {
			hs.destroy();
			return null;
		}
	}
	public function loadFromFile(file:String, unique:Bool = false):Null<HScript> {
		if (exists(file) && !unique) {
			Log.warning('hscript @ "$file" is already active!');
			return find(file);
		}

		var name:String = getScriptName(file, unique, true);
		var code:String;
		if (FileSystem.exists(file)) {
			code = File.getContent(file);
		} else {
			Log.error('hscript @ "$file" wasn\'t found...');
			code = '';
		}

		var hs:HScript = new HScript(name, code);
		if (hs.compiled) {
			Log.info('hscript @ "$file" loaded successfully!');
			hs.run();
			add(hs);
			return hs;
		} else {
			hs.destroy();
			return null;
		}
	}
	public function loadFromPaths(basepath:String, unique:Bool = false) {
		var found:Bool = false;
		for (path in Paths.getPaths(basepath)) {
			var scriptFile:String = path.path;
			if (exists(scriptFile) && !unique) continue;
			loadFromFile(scriptFile, unique);
			found = true;
		}
		return found;
	}
}