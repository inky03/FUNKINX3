package funkin.backend;

typedef FunkinSpriteGroup = FunkinTypedSpriteGroup<FlxSprite>;
class FunkinTypedSpriteGroup<T:FlxSprite> extends FlxTypedSpriteGroup<T> {
	public var zoomFactor(default, set):Float = 1;
	public var initialZoom(default, set):Float = 1;
	
	inline function getFunk(sprite:FlxSprite):FunkinSprite {
		if (Std.isOfType(sprite, FunkinSprite))
			return cast sprite;
		return null;
	}
	public override function updateHitbox():Void {}
	public function updateMembersHitbox():Void {
		for (sprite in members) {
			if (sprite == null) continue;
			sprite.updateHitbox();
		}
	}
	override function preAdd(sprite:T):Void {
		super.preAdd(sprite);
		var funk:FunkinSprite = getFunk(sprite);
		if (funk != null) {
			funk.zoomFactor = zoomFactor;
			funk.initialZoom = initialZoom;
		}
	}
	
	function set_zoomFactor(value:Float):Float {
		for (sprite in members) {
			if (sprite == null) continue;
			var funk:FunkinSprite = getFunk(sprite);
			if (funk != null) funk.zoomFactor = value;
		}
		return zoomFactor = value;
	}
	function set_initialZoom(value:Float):Float {
		for (sprite in members) {
			if (sprite == null) continue;
			var funk:FunkinSprite = getFunk(sprite);
			if (funk != null) funk.initialZoom = value;
		}
		return initialZoom = value;
	}
}