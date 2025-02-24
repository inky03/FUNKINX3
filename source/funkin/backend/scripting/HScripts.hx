package funkin.backend.scripting;

using StringTools;

typedef HScriptAsset = flixel.util.typeLimit.OneOfTwo<String, HScript>;
class HScripts { // todo: make this a flxtypedgroup?
	public var interceptArray:Array<Dynamic>;
	public var defaultVars:Map<String, Dynamic>;
	
	public var activeScripts:Array<HScript> = [];
	
	public function new(?interceptArray:Array<Dynamic>, ?defaultVars:Map<String, Dynamic>) {
		this.interceptArray = interceptArray;
		this.defaultVars = defaultVars;
	}
	public function find(test:HScriptAsset) {
		if (Std.isOfType(test, HScript)) {
			return activeScripts.contains(test) ? test : null;
		} else {
			for (hscript in activeScripts) {
				if (hscript.scriptName == test)
					return hscript;
			}
			return null;
		}
	}
	public function exists(test:HScriptAsset) return (find(test) != null);
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
				case null: // dont change return value to null
				case HScript.STOPALL:
					return result;
				case HScript.STOP:
					returnLocked = true;
					returnValue = result;
				default:
					if (!returnLocked)
						returnValue = result;
			}
		}
		return returnValue;
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

		var hs:HScript = new HScript(name, code, interceptArray, defaultVars);
		if (hs.compiled) {
			Log.info('hscript "$name" loaded successfully!');
			hs.run('create');
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

		var hs:HScript = new HScript(name, code, interceptArray, defaultVars);
		if (hs.compiled) {
			Log.info('hscript @ "$file" loaded successfully!');
			hs.run('create');
			add(hs);
			return hs;
		} else {
			hs.destroy();
			return null;
		}
	}
	public function loadFromFolder(path:String, allMods:Bool = false):Void {
		var dirList:Array<String> = [Paths.sharedPath(path), Paths.globalModPath(path)];
		
		for (mod in Mods.getLocal(allMods)) {
			dirList.push(Paths.modPath(path, mod.directory));
		}
		for (dir in dirList) {
			if (FileSystem.exists(dir)) {
				Log.minor('loading hscripts @ "$dir"');
				for (file in FileSystem.readDirectory(dir)) {
					if (!file.endsWith('.hx')) continue;
					loadFromFile('$dir/$file');
				}
			}
		}
	}
	public function loadFromPaths(basePath:String, allMods:Bool = false, unique:Bool = false):Bool {
		var found:Bool = false;
		for (path in Paths.getPaths(basePath, true, allMods)) {
			var scriptFile:String = path.path;
			if (exists(scriptFile) && !unique) continue;
			loadFromFile(scriptFile, unique);
			found = true;
		}
		return found;
	}
}