package;

using StringTools;

class Util { // maybe these utils can be on their own specific purpose classes
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
}