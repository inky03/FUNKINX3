package funkin.util;

using StringTools;

class Util { // maybe these utils can be on their own specific purpose classes
	public static var keyMod(get, never):lime.ui.KeyModifier;
	public static var gameScaleX(get, never):Float;
	public static var gameScaleY(get, never):Float;

	// string
	public static function padDecimals(number:Float, places:Int):String {
		var len:Int = Std.string(Std.int(number)).length + (places > 0 ? places + 1 : 0);
		var num:String = Std.string(number).substring(0, len);
		if (num.indexOf('.') < 0) num += '.';
		return num.rpad('0', len);
	}
	public static function pathSuffix(str:String, suffix:String = '', sep:String = '-'):String {
		return (suffix.trim().length == 0 ? str : '$str$sep$suffix');
	}
	public static function thousandSep(num:Float):String {
		return flixel.util.FlxStringUtil.formatMoney(num, false);
	}
	public static function parseFloat(v:Dynamic, fallback:Float = 0):Float {
		if (Std.isOfType(v, Float) || Std.isOfType(v, Int)) return cast v;
		if (Std.isOfType(v, String)) return Std.parseFloat(v);
		return fallback;
	}
	public static function parseInt(v:Dynamic, fallback:Int = 0):Int {
		if (Std.isOfType(v, Float) || Std.isOfType(v, Int)) return cast v;
		if (Std.isOfType(v, String)) return Std.parseInt(v);
		return fallback;
	}

	// keyboard
	static function get_keyMod():lime.ui.KeyModifier {
		return @:privateAccess FlxG.stage.application.__backend.keyEventInfo.modifier;
	}
	public static function capsLockEnabled():Bool { // p sure these are abstracted so, to be nice
		return keyMod.capsLock;
	}
	public static function capsEnabled():Bool {
		return keyMod.capsLock != keyMod.shiftKey;
	}
	public static function numLockEnabled():Bool {
		return keyMod.numLock;
	}
	public static function keyboardMeta():Bool {
		return keyMod.metaKey;
	}

	// math
	public static function clamp(n:Float, ?min:Float, ?max:Float):Float {
		if (min != null && n < min) return min;
		return (max != null && n > max ? max : n);
	}
	public static function smoothLerp(a:Float, b:Float, t:Float):Float {
		return FlxMath.lerp(a, b, 1 - Math.exp(-t));
	}

	// idfk
	public static function sortZIndex(order:Int, a:FlxBasic, b:FlxBasic):Int {
		if (a == null || b == null) return 0;
		return FlxSort.byValues(order, a.zIndex, b.zIndex);
	}
	public static function getHighestZIndex(?iter:Iterable<FlxBasic>, ?fallback:Int = 0):Int {
		if (iter == null)
			return fallback;
		var hi:Null<Int> = null;
		for (member in iter) {
			if (hi == null || hi < member.zIndex)
				hi = member.zIndex;
		}
		return hi ?? fallback;
	}
	public static function getLowestZIndex(?iter:Iterable<FlxBasic>, ?fallback:Int = 0):Int {
		if (iter == null)
			return fallback;
		var lo:Null<Int> = null;
		for (member in iter) {
			if (lo == null || lo > member.zIndex)
				lo = member.zIndex;
		}
		return lo ?? fallback;
	}
	public static function get_gameScaleX() {
		var scaleX:Float = FlxG.stage.window.width / FlxG.width;
		return switch (FlxG.stage.scaleMode) {
			case EXACT_FIT:
				scaleX;
			case NO_BORDER:
				var scaleY:Float = FlxG.stage.window.height / FlxG.height;
				Math.max(scaleX, scaleY);
			default:
				var scaleY:Float = FlxG.stage.window.height / FlxG.height;
				Math.min(scaleX, scaleY);
		}
	}
	public static function get_gameScaleY() {
		var scaleY:Float = FlxG.stage.window.height / FlxG.height;
		return switch (FlxG.stage.scaleMode) {
			case EXACT_FIT:
				scaleY;
			case NO_BORDER:
				var scaleX:Float = FlxG.stage.window.width / FlxG.width;
				Math.max(scaleX, scaleY);
			default:
				var scaleX:Float = FlxG.stage.window.width / FlxG.width;
				Math.min(scaleX, scaleY);
		}
	}
	public static function copyColorTransform(transform:openfl.geom.ColorTransform, copyTransform:openfl.geom.ColorTransform) {
		transform.redOffset = copyTransform.redOffset; // wow
		transform.blueOffset = copyTransform.blueOffset;
		transform.greenOffset = copyTransform.greenOffset;
		transform.alphaOffset = copyTransform.alphaOffset;
		transform.redMultiplier = copyTransform.redMultiplier;
		transform.blueMultiplier = copyTransform.blueMultiplier;
		transform.greenMultiplier = copyTransform.greenMultiplier;
		transform.alphaMultiplier = copyTransform.alphaMultiplier;
		return transform;
	}
}