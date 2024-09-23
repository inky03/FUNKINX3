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

	// math
	public static function smoothLerp(a:Float, b:Float, t:Float) {
		return FlxMath.lerp(a, b, 1 - Math.exp(-t));
	}
}