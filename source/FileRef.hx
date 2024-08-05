package; //so much for adobe flash support that nobody will(or should lmao!!) use

import openfl.utils.Assets;
import openfl.utils.AssetType;

class FileRef {
	public var path:String;
	public var assetType:AssetType;
	public var exists(get, null):Bool = false;
	public var content(get, null):Dynamic;
	private var fromAssets(default, null):Bool = false;
	
	public function get_exists() {
		@:privateAccess fromAssets = false;
		#if !flash
			if (FileSystem.exists(path)) return true;
		#end
		if (Assets.exists(path, assetType)) {
			@:privateAccess fromAssets = true;
			return true;
		}
		return false;
	}
	
	public function get_content() {
		if (!exists) return null;
		if (assetType == TEXT) {
			if (fromAssets) return Assets.getText(path);
			#if !flash return File.getContent(path); #end
		}
		//well uh.
		return null;
	}
	
	public function new(path:String, assetType:AssetType = TEXT) {
		this.path = path;
		this.assetType = assetType;
	}
}