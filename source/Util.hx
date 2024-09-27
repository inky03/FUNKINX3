package;

using StringTools;

class Util { // maybe these utils can be on their own specific purpose classes
	// string
	public static function padDecimals(number:Float, places:Int) {
		var len:Int = Std.string(Std.int(number)).length + (places > 0 ? places + 1 : 0);
		var num:String = Std.string(number).substring(0, len);
		if (num.indexOf('.') < 0) num += '.';
		return num.rpad('0', len);
	}
	public static function pathSuffix(str:String, suffix:String = '') {
		return (suffix.trim().length == 0 ? str : '$str-$suffix');
	}
	public static function thousandSep(num:Float) {
		return flixel.util.FlxStringUtil.formatMoney(num, false);
	}
	public static function parseFloat(v:Dynamic):Float {
		if (Std.isOfType(v, Float) || Std.isOfType(v, Int)) return cast v;
		if (Std.isOfType(v, String)) return Std.parseFloat(v);
		return 0;
	}
	public static function parseInt(v:Dynamic):Int {
		if (Std.isOfType(v, Float) || Std.isOfType(v, Int)) return cast v;
		if (Std.isOfType(v, String)) return Std.parseInt(v);
		return 0;
	}

	// math
	public static function smoothLerp(a:Float, b:Float, t:Float) {
		return FlxMath.lerp(a, b, 1 - Math.exp(-t));
	}
}