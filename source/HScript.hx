package;

import Lane.NoteEventType;
import flixel.util.FlxAxes;
import openfl.display.BlendMode;

import crowplexus.iris.Iris;
import crowplexus.iris.IrisConfig;
import crowplexus.hscript.Printer;
import crowplexus.hscript.Expr.Error as IrisError;

class HScript extends Iris {
	public var scriptString(default, set):String = '';
	public var scriptName:String = '';
	
	public function new(name:String, code:String) {
		super('', new IrisConfig(name, false, true, []));
		scriptString = code;
		scriptName = name;
	}
	
	public function errorCaught(e:IrisError, ?extra:String) {
		trace('HSCRIPT ERROR: ${Printer.errorToString(e)}');
	}
	
	public function run(?func:String, ?args:Array<Any>, safe:Bool = false):Any {
		try {
			if (func != null) {
				if (safe && !exists(func)) return null;
				var result:IrisCall = call(func, args);
				return result?.returnValue ?? null;
			} else {
				return execute();
			}
		} catch (e:IrisError) {
			errorCaught(e);
			return null;
		}
	}
	public override function preset() {
		super.preset();
		set('Type', Type);
		set('Reflect', Reflect);
		
		set('FlxG', flixel.FlxG);
		set('FlxSprite', flixel.FlxSprite);
		set('FlxCamera', flixel.FlxCamera);
		set('FlxMath', flixel.math.FlxMath);
		set('FlxText', flixel.text.FlxText);
		set('FlxEase', flixel.tweens.FlxEase);
		set('FlxTimer', flixel.util.FlxTimer);
		set('FlxTween', flixel.tweens.FlxTween);
		set('FlxRuntimeShader', flixel.addons.display.FlxRuntimeShader);
		
		set('Lane', Lane);
		set('Note', Note);
		set('Paths', Paths);
		set('Controls', Controls);
		set('Settings', Settings);
		set('PlayState', PlayState);
		set('Conductor', Conductor);
		set('Character', Character);
		set('Strumline', Strumline);
		set('HealthIcon', HealthIcon);
		set('SongEvent', Song.SongEvent);
		set('NoteEvent', Lane.NoteEvent);
		set('FunkinSprite', FunkinSprite);
		set('Metronome', Conductor.Metronome);
		#if static
		set('NoteEventType', {HIT: NoteEventType.HIT, LOST: NoteEventType.LOST, SPAWNED: NoteEventType.SPAWNED, DESPAWNED: NoteEventType.DESPAWNED});
		#else
		set('NoteEventType', NoteEventType);
		#end
		
		set('state', FlxG.state);
		set('add', FlxG.state.add);
		set('remove', FlxG.state.remove);
		set('insert', FlxG.state.insert);
		
		// abstract classes
		set('FlxAxes', HScriptFlxAxes);
		set('FlxColor', HScriptFlxColor);
		set('BlendMode', HScriptBlendMode);
	}
	public function set_scriptString(newCode:String) {
		if (newCode == scriptString) return scriptString;
		scriptCode = newCode;
		try {
			parse(true);
		} catch (e:IrisError) {
			errorCaught(e);
		}
		return scriptString = newCode;
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
	
	public static function retrieve(num:Int) {
		var col:FlxColor = num;
		return {
			red: col.red, green: col.green, blue: col.blue, alpha: col.alpha,
			redFloat: col.redFloat, greenFloat: col.greenFloat, blueFloat: col.blueFloat,
			hue: col.hue, saturation: col.saturation, brightness: col.brightness, lightness: col.lightness
		};
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