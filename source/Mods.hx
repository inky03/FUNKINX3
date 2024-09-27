package;

class Mods {
	public static var currentMod(default, null):String = '';
	private static var list:Array<Mod> = [];

	inline public static function get() return list;
	public static function refresh() {
		list.resize(0);
		if (!FileSystem.exists('mods')) return list;
		for (dir in FileSystem.readDirectory('mods')) {
			if (FileSystem.exists('$dir/pack.json')) {
				var mod:Mod = {
					directory: dir,
					global: true, // todo
					name: ''
				};
				list.push(mod);
			}
		}
		return list;
	}
}

typedef Mod = {
	var directory:String;
	var global:Bool;
	var name:String;
}