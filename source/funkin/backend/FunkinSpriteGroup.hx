package funkin.backend;

import funkin.backend.FunkinSprite;

typedef FunkinSpriteGroup = FunkinTypedSpriteGroup<FlxSprite>;
class FunkinTypedSpriteGroup<T:FlxSprite> implements ISpriteVars implements IZoomFactor extends FlxTypedSpriteGroup<T> {
	public var zoomFactor(default, set):Float = 1;
	public var initialZoom(default, set):Float = 1;
	public var extraData:Map<String, Dynamic> = new Map();
	
	public function setVar(k:String, v:Dynamic):Dynamic {
		if (extraData == null) extraData = new Map();
		extraData.set(k, v);
		return v;
	}
	public function getVar(k:String):Dynamic {
		if (extraData == null) return null;
		return extraData.get(k);
	}
	public function hasVar(k:String):Bool {
		if (extraData == null) return false;
		return extraData.exists(k);
	}
	public function removeVar(k:String):Bool {
		if (extraData == null) return false;
		return extraData.remove(k);
	}
	
	inline function getFunk(sprite:T):IZoomFactor {
		if (Std.isOfType(sprite, IZoomFactor))
			return cast(sprite, IZoomFactor);
		return null;
	}
	public override function updateHitbox():Void {}
	public function updateMembersHitbox():Void {
		for (sprite in members) {
			if (sprite == null) continue;
			sprite.updateHitbox();
		}
	}
	
	public function sortZIndex() {
		sort(Util.sortZIndex, FlxSort.ASCENDING);
	}
	public function insertZIndex(obj:T) {
		if (members.contains(obj)) remove(obj);
		var low:Float = Math.POSITIVE_INFINITY;
		for (pos => mem in members) {
			low = Math.min(mem.zIndex, low);
			if (obj.zIndex < mem.zIndex) {
				insert(pos, obj);
				return obj;
			}
		}
		if (obj.zIndex < low) {
			insert(0, obj);
		} else {
			add(obj);
		}
		return obj;
	}
	
	override function preAdd(sprite:T):Void {
		super.preAdd(sprite);
		var funk:IZoomFactor = getFunk(sprite);
		if (funk != null) {
			funk.zoomFactor = zoomFactor;
			funk.initialZoom = initialZoom;
		}
	}
	
	function set_zoomFactor(value:Float):Float {
		for (sprite in members) {
			if (sprite == null) continue;
			var funk:IZoomFactor = getFunk(sprite);
			if (funk != null) funk.zoomFactor = value;
		}
		return zoomFactor = value;
	}
	function set_initialZoom(value:Float):Float {
		for (sprite in members) {
			if (sprite == null) continue;
			var funk:IZoomFactor = getFunk(sprite);
			if (funk != null) funk.initialZoom = value;
		}
		return initialZoom = value;
	}
}