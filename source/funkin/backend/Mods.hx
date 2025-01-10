package funkin.backend;

class Mods {
	public static var currentMod:String = '';
	private static var list:Array<Mod> = [];

	inline public static function get() return list;
	public static function refresh() {
		list.resize(0);
		#if MODS_ALLOWED
		if (!FileSystem.exists('mods'))
			return list;
		
		for (dir in FileSystem.readDirectory('mods')) {
			if (FileSystem.exists('mods/$dir/pack.json')) {
				var mod:Mod = {
					directory: dir,
					global: true // todo
				};
				list.push(mod);
			}
		}
		Log.info('refreshed mod list!');
		#end
		return list;
	}
}

@:structInit
class Mod {
	public var global:Bool = false;
	public var directory:String = '';
	public var name:String = 'Unknown';
	
	public function toString():String {
		return 'Mod($directory)';
	}
}