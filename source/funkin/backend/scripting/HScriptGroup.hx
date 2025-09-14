package funkin.backend.scripting;

using StringTools;
using Lambda;

typedef HScriptAsset = flixel.util.typeLimit.OneOfTwo<String, HScript>;

class HScriptGroup extends FlxTypedGroup<HScript> {
	public var interceptArray:Array<Dynamic>;
	public var defaultVars:Map<String, Dynamic>;
	
	public function new(?interceptArray:Array<Dynamic>, ?defaultVars:Map<String, Dynamic>) {
		super();
		this.interceptArray = interceptArray;
		this.defaultVars = defaultVars;
	}
	public function find(test:HScriptAsset):HScript {
		if (Std.isOfType(test, HScript)) {
			return (members.contains(test) ? test : null);
		} else {
			return members.find((hscript:HScript) -> hscript.scriptName == test);
		}
	}
	public function scriptExists(test:HScriptAsset):Bool {
		return (find(test) != null);
	}
	public function findFromSuffix(test:String):HScript {
		return members.find((hscript:HScript) -> (hscript.exists && hscript.scriptName.endsWith(test)));
	}
	public function destroyScript(?hscript:HScript):Void {
		if (hscript == null) return;
		hscript.destroy();
		remove(hscript);
		cleanup();
	}
	public function destroyScripts():Void {
		while (members.length > 0)
			destroyScript(members.shift());
	}
	public function set(field:String, value:Any):Void {
		for (hscript in members) {
			if (!hscript.exists) continue;
			
			hscript.set(field, value);
		}
	}
	public function run(?name:String, ?args:Array<Any>):Any {
		var returnLocked:Bool = false;
		var returnValue:Dynamic = null;
		for (hscript in members) {
			if (!hscript.exists) continue;
			
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
	public function concat(group:Dynamic) {
		if (Std.isOfType(group, HScriptGroup)) {
			for (script in cast(group, HScriptGroup).members)
				add(script);
		} else if (Std.isOfType(group, Array)) {
			var array:Array<HScript> = cast group;
			for (script in array)
				add(script);
		} else {
			throw 'Invalid type';
		}
	}
	public override function destroy():Void {
		destroyScripts();
		super.destroy();
	}
	
	function getScriptName(name:String, unique:Bool = false, warn:Bool = false):String {
		var found:HScript = find(name);
		if (found != null && unique) {
			var n:Int = 1;
			while (scriptExists('${name}_$n')) n ++;
			name = '${name}_$n';
		}
		return name;
	}
	function cleanup():Void {
		while (true) {
			var deadScript:HScript = members.find((hscript:HScript) -> !hscript.exists);
			if (deadScript == null) return;
			else remove(deadScript, true);
		}
	}
	
	public function loadFromString(code:String, ?name:String):HScript {
		name ??= 'hscript';
		if (scriptExists(name)) {
			Log.warning('hscript @ "$name" is already active!');
			name = getScriptName(name, true);
			Log.minor('using name "$name"...');
		}
		
		cleanup();
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
	public function loadFromFile(file:String, unique:Bool = false, ?newName:String, ?defaultVars:Map<String, Dynamic>):HScript {
		if (scriptExists(newName ?? file) && !unique) {
			Log.warning('hscript @ "$file" is already active!');
			return find(file);
		}
		
		var name:String = getScriptName(newName ?? file, unique, true);
		var code:String;
		if (FileSystem.exists(file)) {
			code = File.getContent(file);
		} else {
			Log.error('hscript @ "$file" wasn\'t found...');
			code = '';
		}
		
		var defaultestVars:Map<String, Dynamic> = this.defaultVars;
		if (defaultVars != null) {
			defaultestVars = defaultVars.copy();
			for (k => v in this.defaultVars)
				defaultestVars.set(k, v);
		}
		
		cleanup();
		var hs:HScript = new HScript(name, code, interceptArray, defaultestVars);
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
	public function loadFromFolder(path:String, allMods:Bool = false, ?defaultVars:Map<String, Dynamic>):Array<HScript> {
		var dirList:Array<String> = [Paths.sharedPath(path), Paths.globalModPath(path)];
		var loaded:Array<HScript> = [];
		
		for (mod in Mods.getLocal(allMods)) {
			dirList.push(Paths.modPath(path, mod.directory));
		}
		
		for (dir in dirList) {
			if (FileSystem.exists(dir)) {
				Log.minor('loading hscripts @ "$dir"');
				for (file in FileSystem.readDirectory(dir)) {
					if (!file.endsWith('.hx')) continue;
					
					var script:HScript = loadFromFile('$dir/$file', defaultVars);
					if (script != null) loaded.push(script);
				}
			}
		}
		
		return loaded;
	}
	public function loadFromPaths(basePath:String, allMods:Bool = false, unique:Bool = false, ?defaultVars:Map<String, Dynamic>):Array<HScript> {
		var loaded:Array<HScript> = [];
		
		for (path in Paths.getPaths(basePath, true, allMods)) {
			var scriptFile:String = path.path;
			if (!scriptFile.endsWith('.hx')) continue;
			if (!unique && scriptExists(scriptFile)) continue;
			
			var script:HScript = loadFromFile(scriptFile, unique, defaultVars);
			if (script != null) loaded.push(script);
		}
		
		return loaded;
	}
	
	@:deprecated('activeScripts is deprecated, use members instead!') public var activeScripts(get, null):Array<HScript>;
	function get_activeScripts():Array<HScript> { return members; }
}