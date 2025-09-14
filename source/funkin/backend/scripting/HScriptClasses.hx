package funkin.backend.scripting;

#if ALLOW_SCRIPTS
import flixel.util.FlxAxes;

class HScriptRuntimeShader extends FunkinRuntimeShader {
	public function new(name:String) {
		this.name = name;
		var frag:String = Paths.shaderFrag(name);
		var vert:String = Paths.shaderVert(name);
		if (frag == null && vert == null) {
			Log.warning('shader code for "$name" not found...');
			Log.minor('verify paths:');
			Log.minor('- vertex: shaders/$name.vert');
			Log.minor('- fragment: shaders/$name.frag');
		} else {
			var str:String;
			if (frag != null) {
				str = (vert == null ? 'fragment' : 'fragment and vertex');
			} else {
				str = 'vertex';
			}
			Log.minor('loaded $str shader code for "$name"');
		}
		super(frag, vert, name);
	}
}

class HScriptFlxColor { // i hate it in here
	public static var BLACK(default, never):Int = cast FlxColor.BLACK;
	public static var GRAY(default, never):Int = cast FlxColor.GRAY;
	public static var WHITE(default, never):Int = cast FlxColor.WHITE;
	public static var BROWN(default, never):Int = cast FlxColor.BROWN;
	public static var RED(default, never):Int = cast FlxColor.RED;
	public static var ORANGE(default, never):Int = cast FlxColor.ORANGE;
	public static var YELLOW(default, never):Int = cast FlxColor.YELLOW;
	public static var LIME(default, never):Int = cast FlxColor.LIME;
	public static var GREEN(default, never):Int = cast FlxColor.GREEN;
	public static var CYAN(default, never):Int = cast FlxColor.CYAN;
	public static var BLUE(default, never):Int = cast FlxColor.BLUE;
	public static var PURPLE(default, never):Int = cast FlxColor.PURPLE;
	public static var PINK(default, never):Int = cast FlxColor.PINK;
	public static var MAGENTA(default, never):Int = cast FlxColor.MAGENTA;
	public static var TRANSPARENT(default, never):Int = cast FlxColor.TRANSPARENT;

	public var color:FlxColor;
	@:isVar public var red(get, set):Int;
	@:isVar public var green(get, set):Int;
	@:isVar public var blue(get, set):Int;
	@:isVar public var alpha(get, set):Int;
	@:isVar public var redFloat(get, set):Float;
	@:isVar public var greenFloat(get, set):Float;
	@:isVar public var blueFloat(get, set):Float;
	@:isVar public var alphaFloat(get, set):Float;
	@:isVar public var hue(get, set):Float;
	@:isVar public var cyan(get, set):Float;
	@:isVar public var magenta(get, set):Float;
	@:isVar public var yellow(get, set):Float;
	@:isVar public var black(get, set):Float;
	@:isVar public var saturation(get, set):Float;
	@:isVar public var brightness(get, set):Float;
	@:isVar public var lightness(get, set):Float;
	
	public function new(color:Int = 0xffffffff) {
		this.color = cast (color, FlxColor);
	} // this is so horrible i could kill myself
	function set_alpha(newAlpha:Int) return alpha = color.alpha = newAlpha;
	function get_alpha() return color.alpha;
	function set_alphaFloat(newAlpha:Float) return alphaFloat = color.alphaFloat = newAlpha;
	function get_alphaFloat() return color.alphaFloat;
	function get_red() return color.red;
	function set_red(newRed:Int) return red = color.red = newRed;
	function get_green() return color.green;
	function set_green(newGreen:Int) return green = color.green = newGreen;
	function get_blue() return color.blue;
	function set_blue(newBlue:Int) return blue = color.blue = newBlue;
	function get_redFloat() return color.redFloat;
	function set_redFloat(newRed:Float) return redFloat = color.redFloat = newRed;
	function get_greenFloat() return color.greenFloat;
	function set_greenFloat(newGreen:Float) return greenFloat = color.greenFloat = newGreen;
	function get_blueFloat() return color.blueFloat;
	function set_blueFloat(newBlue:Float) return blueFloat = color.blueFloat = newBlue;
	function get_hue() return color.hue;
	function set_hue(newHue:Float) return hue = color.hue = newHue;
	function get_saturation() return color.saturation;
	function set_saturation(newSat:Float) return saturation = color.saturation = newSat;
	function get_brightness() return color.brightness;
	function set_brightness(newBrt:Float) return brightness = color.brightness = newBrt;
	function get_lightness() return color.lightness;
	function set_lightness(newLt:Float) return lightness = color.lightness = newLt;
	function get_cyan() return color.cyan;
	function set_cyan(newCyan:Float) return cyan = color.cyan = newCyan;
	function get_magenta() return color.magenta;
	function set_magenta(newMagenta:Float) return magenta = color.magenta = newMagenta;
	function get_yellow() return color.cyan;
	function set_yellow(newYellow:Float) return yellow = color.yellow = newYellow;
	function get_black() return color.black;
	function set_black(newBlack:Float) return black = color.black = newBlack;

	public static function fromCMYK(c:Float, m:Float, y:Float, k:Float, a:Float = 1) {
		return FlxColor.fromCMYK(c, m, y, k, a);
	}
	public static function fromHSB(h:Float, s:Float, b:Float, a:Float = 1) {
		return FlxColor.fromHSB(h, s, b, a);
	}
	public static function fromHSL(h:Float, s:Float, l:Float, a:Float = 1) {
		return FlxColor.fromHSL(h, s, l, a);
	}
	public static function fromRGBFloat(r:Float, g:Float, b:Float, a:Float = 1) {
		return FlxColor.fromRGBFloat(r, g, b, a);
	}
	public static function fromRGB(r:Int, g:Int, b:Int, a:Int = 255) {
		return FlxColor.fromRGB(r, g, b, a);
	}
	public static function fromString(str:String) {
		return FlxColor.fromString(str);
	}
	public static function getHSBColorWheel(a:Int = 255) {
		return FlxColor.getHSBColorWheel(a);
	}
	public static function getDarkened(col:Int, factor:Float = .2) {
		return cast(col, FlxColor).getDarkened(factor);
	}
	public static function getInverted(col:Int) {
		return cast(col, FlxColor).getInverted();
	}
	public static function getLightened(col:Int, factor:Float = .2) {
		return cast(col, FlxColor).getLightened(factor);
	}
	public static function gradient(col:Int, col2:Int, steps:Int, ?ease:Float -> Float) {
		return FlxColor.gradient(col, col2, steps, ease);
	}
	public static function interpolate(col:Int, col2:Int, factor:Float) {
		return FlxColor.interpolate(col, col2, factor);
	}
	public static function multiply(col:Int, col2:Int) {
		return FlxColor.multiply(col, col2);
	}
	public static function from(num:Int) {
		return new HScriptFlxColor(num);
	}
}

class HScriptFlxAxes {
	public static var X:Int = cast FlxAxes.X;
	public static var Y:Int = cast FlxAxes.Y;
	public static var XY:Int = cast FlxAxes.XY;
	public static var NONE:Int = cast FlxAxes.NONE;
	
	public static function fromBools(x:Bool, y:Bool):Int {
		return x && y ? XY : (x ? X : (y ? Y : NONE));
	}
	public static function fromString(axes:String):Int {
		return switch (axes.toLowerCase()) {
			case 'x': X;
			case 'y': Y;
			case 'xy', 'yx', 'both': XY;
			default: NONE;
		}
	}
	public static function toString(axes:Int):String {
		return cast(axes, FlxAxes).toString();
	}
}

class HScriptBlendMode {
	public static var ADD(default, never):Int = cast BlendMode.ADD;
	public static var ALPHA(default, never):Int = cast BlendMode.ALPHA;
	public static var ERASE(default, never):Int = cast BlendMode.ERASE;
	public static var LAYER(default, never):Int = cast BlendMode.LAYER;
	public static var INVERT(default, never):Int = cast BlendMode.INVERT;
	public static var DARKEN(default, never):Int = cast BlendMode.DARKEN;
	public static var SCREEN(default, never):Int = cast BlendMode.SCREEN;
	public static var SHADER(default, never):Int = cast BlendMode.SHADER;
	public static var NORMAL(default, never):Int = cast BlendMode.NORMAL;
	public static var LIGHTEN(default, never):Int = cast BlendMode.LIGHTEN;
	public static var OVERLAY(default, never):Int = cast BlendMode.OVERLAY;
	public static var MULTIPLY(default, never):Int = cast BlendMode.MULTIPLY;
	public static var SUBTRACT(default, never):Int = cast BlendMode.SUBTRACT;
	public static var HARDLIGHT(default, never):Int = cast BlendMode.HARDLIGHT;
	public static var DIFFERENCE(default, never):Int = cast BlendMode.DIFFERENCE;
	
	public static function fromString(bm:String) {
		return switch (bm.toLowerCase()) {
			case 'add': HScriptBlendMode.ADD;
			case 'alpha': HScriptBlendMode.ALPHA;
			case 'erase': HScriptBlendMode.ERASE;
			case 'layer': HScriptBlendMode.LAYER;
			case 'invert': HScriptBlendMode.INVERT;
			case 'darken': HScriptBlendMode.DARKEN;
			case 'screen': HScriptBlendMode.SCREEN;
			case 'shader': HScriptBlendMode.SHADER;
			case 'lighten': HScriptBlendMode.LIGHTEN;
			case 'overlay': HScriptBlendMode.OVERLAY;
			case 'multiply': HScriptBlendMode.MULTIPLY;
			case 'subtract': HScriptBlendMode.SUBTRACT;
			case 'hardlight': HScriptBlendMode.HARDLIGHT;
			case 'difference': HScriptBlendMode.DIFFERENCE;
			default: HScriptBlendMode.NORMAL;
		}
	}
	public static function toString(bm:Int) {
		return switch (bm) {
			case HScriptBlendMode.ADD: 'add';
			case HScriptBlendMode.ALPHA: 'alpha';
			case HScriptBlendMode.ERASE: 'erase';
			case HScriptBlendMode.LAYER: 'layer';
			case HScriptBlendMode.INVERT: 'invert';
			case HScriptBlendMode.DARKEN: 'darken';
			case HScriptBlendMode.SCREEN: 'screen';
			case HScriptBlendMode.SHADER: 'shader';
			case HScriptBlendMode.LIGHTEN: 'lighten';
			case HScriptBlendMode.OVERLAY: 'overlay';
			case HScriptBlendMode.MULTIPLY: 'multiply';
			case HScriptBlendMode.SUBTRACT: 'subtract';
			case HScriptBlendMode.HARDLIGHT: 'hardlight';
			case HScriptBlendMode.DIFFERENCE: 'difference';
			default: 'normal';
		}
	}
}

#if hl // curse you, hashlink externs
// TODO: make this a macro...
// (and probably everything else, by extension)
class HScriptMath {
	public static var PI:Float = Math.PI;
	public static var NaN:Float = Math.NaN;
	public static var NEGATIVE_INFINITY:Float = Math.NEGATIVE_INFINITY;
	public static var POSITIVE_INFINITY:Float = Math.POSITIVE_INFINITY;

	public static function abs(n:Float):Float return Math.abs(n);
	public static function acos(n:Float):Float return Math.acos(n);
	public static function asin(n:Float):Float return Math.asin(n);
	public static function atan(n:Float):Float return Math.atan(n);
	public static function atan2(y:Float, x:Float):Float return Math.atan2(y, x);
	public static function ceil(n:Float):Int return Math.ceil(n);
	public static function cos(n:Float):Float return Math.cos(n);
	public static function exp(n:Float):Float return Math.exp(n);
	public static function fceil(n:Float):Float return Math.fceil(n);
	public static function ffloor(n:Float):Float return Math.ffloor(n);
	public static function floor(n:Float):Int return Math.floor(n);
	public static function fround(n:Float):Float return Math.fround(n);
	public static function isFinite(n:Float):Bool return Math.isFinite(n);
	public static function isNaN(n:Float):Bool return Math.isNaN(n);
	public static function log(n:Float):Float return Math.log(n);
	public static function max(a:Float, b:Float):Float return Math.max(a, b);
	public static function min(a:Float, b:Float):Float return Math.min(a, b);
	public static function pow(n:Float, exp:Float):Float return Math.pow(n, exp);
	public static function random():Float return Math.random();
	public static function round(n:Float):Int return Math.round(n);
	public static function sin(n:Float):Float return Math.sin(n);
	public static function sqrt(n:Float):Float return Math.sqrt(n);
	public static function tan(n:Float):Float return Math.tan(n);
}
#end

#end