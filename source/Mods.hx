package;

class Mods {
	public static var currentMod:String = '';
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
		Log.info('refreshed mod list!');
		return list;
	}
}

@:structInit
class Mod {
	public var global:Bool = false;
	public var directory:String = '';
	public var name:String = 'Unknown';
}