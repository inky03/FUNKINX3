package funkin.backend;

import funkin.backend.FunkinSprite;

import haxe.iterators.ArrayKeyValueIterator;

typedef FunkinSpriteGroup = FunkinTypedSpriteGroup<FlxSprite>;
class FunkinTypedSpriteGroup<T:FlxSprite> implements ISpriteGroup implements ISpriteVars implements IZoomFactor extends FlxTypedSpriteGroup<T> {
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
	public inline function killMembers():Void { group.killMembers(); }
	public inline function reviveMembers():Void { group.reviveMembers(); }
	
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
	public inline function moveToTop(sprite:T):T {
		if (!members.contains(sprite)) return add(sprite);
		members.remove(sprite);
		members.push(sprite);
		return sprite;
	}
	public inline function moveToBottom(sprite:T):T {
		if (!members.contains(sprite)) return insert(0, sprite);
		members.remove(sprite);
		members.unshift(sprite);
		return sprite;
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
	
	public inline function keyValueIterator():ArrayKeyValueIterator<T> { return new ArrayKeyValueIterator(members); }
	
	override function findMinXHelper():Float {
		var value = Math.POSITIVE_INFINITY;
		for (member in group.members) {
			if (member == null) continue;
			
			var minX:Float;
			if (Std.isOfType(member, ISpriteGroup)) {
				minX = cast(member, ISpriteGroup).findMinX();
			} else if (member.flixelType == SPRITEGROUP) {
				minX = (cast member:FlxSpriteGroup).findMinX();
			} else {
				minX = member.x;
			}
			
			if (minX < value) value = minX;
		}
		return value;
	}
	override function findMaxXHelper():Float {
		var value = Math.NEGATIVE_INFINITY;
		for (member in group.members) {
			if (member == null) continue;
			
			var maxX:Float;
			if (Std.isOfType(member, ISpriteGroup)) {
				maxX = cast(member, ISpriteGroup).findMaxX();
			} else if (member.flixelType == SPRITEGROUP) {
				maxX = (cast member:FlxSpriteGroup).findMaxX();
			} else {
				maxX = member.x + member.width;
			}
			
			if (maxX > value) value = maxX;
		}
		return value;
	}
	override function findMinYHelper():Float {
		var value = Math.POSITIVE_INFINITY;
		for (member in group.members) {
			if (member == null) continue;
			
			var minY:Float;
			if (Std.isOfType(member, ISpriteGroup)) {
				minY = cast(member, ISpriteGroup).findMinY();
			} else if (member.flixelType == SPRITEGROUP) {
				minY = (cast member:FlxSpriteGroup).findMinY();
			} else {
				minY = member.y;
			}
			
			if (minY < value) value = minY;
		}
		return value;
	}
	override function findMaxYHelper():Float {
		var value = Math.NEGATIVE_INFINITY;
		for (member in group.members) {
			if (member == null) continue;
			
			var maxY:Float;
			if (Std.isOfType(member, ISpriteGroup)) {
				maxY = cast(member, ISpriteGroup).findMaxY();
			} else if (member.flixelType == SPRITEGROUP) {
				maxY = (cast member:FlxSpriteGroup).findMaxY();
			} else {
				maxY = member.y + member.height;
			}
			
			if (maxY > value) value = maxY;
		}
		return value;
	}
}

interface ISpriteGroup {
	function findMinX():Float;
	function findMaxX():Float;
	function findMinY():Float;
	function findMaxY():Float;
}