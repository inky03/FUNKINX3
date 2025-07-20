package funkin.backend;

import openfl.display.Shader;
import openfl.filters.ShaderFilter;
import openfl.filters.BitmapFilter;

typedef ShaderOrFilter = flixel.util.typeLimit.OneOfTwo<Shader, BitmapFilter>;
class FunkinCamera extends FlxCamera {
	public var pauseZoomLerp:Bool = false; // OK, this is hacky but i cant be arsed
	public var pauseFollowLerp:Bool = false;
	
	public var zoomTarget:Null<Float> = null;
	public var zoomFollowLerp:Float = -1;
	public var zoomOffset:Float = 0;
	
	public static var topCamera(get, never):FlxCamera;
	
	public override function update(elapsed:Float):Void {
		if (target != null) updateFollow();
		updateLerp(elapsed);

		updateScroll();
		updateFlash(elapsed);
		updateFade(elapsed);
		
		updateShake(elapsed);
	}
	public override function follow(target:FlxObject, ?style:FlxCameraFollowStyle, ?lerp:Float):Void {
		super.follow(target, style, lerp);
		followLerp = lerp ?? -1;
	}
	public override function snapToTarget() {
		super.snapToTarget();
		if (zoomTarget != null)
			zoom = zoomTarget;
	}
	override function render() {
		flashSprite.filters = filtersEnabled ? filters : null;
		updateFlashSpritePosition();
		
		if (filters != null) {
			for (filter in filters) {
				if (!Std.isOfType(filter, openfl.filters.ShaderFilter))
					continue;
				
				var filt:openfl.filters.ShaderFilter = cast filter;
				
				if (Std.isOfType(filt.shader, FunkinRuntimeShader)) {
					var funk:FunkinRuntimeShader = cast filt.shader;
					funk.postUpdateView(this);
				}
			}
		}
		
		super.render();
	}
	
	public function findShaderFilter(shd:Shader):ShaderFilter {
		if (filters == null) return null;
		
		for (filter in filters) {
			if (Std.isOfType(filter, ShaderFilter)) {
				var filt:ShaderFilter = cast filter;
				if (filt.shader == shd)
					return filt;
			}
		}
		return null;
	}
	public function addFilter(filter:ShaderOrFilter, pos:Int = -1):ShaderFilter {
		if (filter == null) return null;
		
		var filterToPush:ShaderFilter;
		if (Std.isOfType(filter, Shader)) {
			var shd:Shader = cast filter;
			
			var foundFilter:ShaderFilter = findShaderFilter(shd);
			if (foundFilter == null) {
				filterToPush = new ShaderFilter(shd);
			} else {
				return foundFilter;
			}
		} else {
			filterToPush = cast filter;
			
			if (filters.contains(filterToPush))
				return filterToPush;
		}
		
		filters ??= [];
		filters.insert(pos, filterToPush);
		return filterToPush;
	}
	public function removeFilter(filter:ShaderOrFilter):Void {
		if (filter == null || filters == null) return;
		
		if (Std.isOfType(filter, Shader)) {
			var foundFilter:ShaderFilter = findShaderFilter(cast filter);
			if (foundFilter != null)
				filters.remove(foundFilter);
		} else {
			filters.remove(cast filter);
		}
	}
	
	public override function updateLerp(elapsed:Float):Void {
		if (target != null && !pauseFollowLerp) {
			if (followLerp < 0) {
				scroll.copyFrom(_scrollTarget); // no easing
			} else if (followLerp > 0) {
				scroll.x = Util.smoothLerp(scroll.x, _scrollTarget.x, followLerp * elapsed);
				scroll.y = Util.smoothLerp(scroll.y, _scrollTarget.y, followLerp * elapsed);
			}
		}
		
		if (zoomTarget != null && !pauseZoomLerp) {
			if (zoomFollowLerp < 0) {
				zoom = zoomTarget + zoomOffset;
			} else if (zoomFollowLerp > 0) {
				zoom = Util.smoothLerp(zoom, zoomTarget + zoomOffset, zoomFollowLerp * elapsed);
			}
		}
	}

	override function set_followLerp(value:Float) {
		return followLerp = value;
	}
	static function get_topCamera():FlxCamera {
		return FlxG.cameras.list[FlxG.cameras.list.length - 1];
	}
}