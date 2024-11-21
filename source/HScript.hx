package;

using StringTools;
import Lane.NoteEventType;
import flixel.util.FlxAxes;
import FunkinSprite.SpriteRenderType;
import flixel.addons.display.FlxRuntimeShader;

import crowplexus.iris.Iris;
import crowplexus.iris.IrisConfig;
import crowplexus.iris.ErrorSeverity;
import crowplexus.hscript.Printer;
import crowplexus.hscript.Expr.Error as IrisError;

class HScript extends Iris {
	public static var STOP(default, never):HScriptFunctionEnum = STOP;
	public static var STOPALL(default, never):HScriptFunctionEnum = STOPALL;

	public var scriptString(default, set):String = '';
	public var scriptPath:Null<String> = null;
	public var scriptName:String = '';
	public var compiled:Bool = false;
	public var active:Bool = true;
	
	public function new(name:String, code:String) {
		super('', new IrisConfig(name, false, true, []));
		Iris.logLevel = customLog;
		scriptString = code;
		scriptName = name;
	}
	
	public function errorCaught(e:IrisError, ?extra:String) {
		Log.fatal(Printer.errorToString(e));
	}
	public function customLog(level:ErrorSeverity, x, ?pos:haxe.PosInfos) {
		if (pos == null) pos = Iris.getDefaultPos();

		var out:String = Std.string(x);
		if (pos != null && pos.customParams != null)
			for (i in pos.customParams)
				out += "," + Std.string(i);

		var posPrefix:String = pos.fileName;
		if (pos.lineNumber != -1)
			posPrefix += ':${pos.lineNumber}';

		switch (level) {
			case FATAL: posPrefix = Log.colorTag(' FATAL:$posPrefix ', black, brightRed);
			case ERROR: posPrefix = Log.colorTag(' ERROR:$posPrefix ', black, red);
			case WARN: posPrefix = Log.colorTag(' WARNING:$posPrefix ', black, yellow);
			default: posPrefix = Log.colorTag(' $posPrefix ', black, blue);
		}
		Sys.println('$posPrefix $out');
	}
	
	public function run(?func:String, ?args:Array<Any>, safe:Bool = true):Any {
		if (!compiled || !active) return null;
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
	public override function destroy() {
		run('destroy');
		super.destroy();
	}
	public override function preset() {
		super.preset();
		set('this', this);
		set('Type', Type);
		set('Reflect', Reflect);
		set('HScript', HScript);
		
		set('FlxG', flixel.FlxG);
		set('FlxSprite', flixel.FlxSprite);
		set('FlxCamera', flixel.FlxCamera);
		set('FlxMath', flixel.math.FlxMath);
		set('FlxText', flixel.text.FlxText);
		set('FlxEase', flixel.tweens.FlxEase);
		set('FlxTimer', flixel.util.FlxTimer);
		set('FlxSound', flixel.sound.FlxSound);
		set('FlxTween', flixel.tweens.FlxTween);
		set('FlxRuntimeShader', FlxRuntimeShader);

		set('Lane', Lane);
		set('Note', Note);
		set('Paths', Paths);
		set('HScript', HScript);
		set('Options', Options);
		set('Controls', Controls);
		set('PlayState', PlayState);
		set('Conductor', Conductor);
		set('Character', Character);
		set('Strumline', Strumline);
		set('HealthIcon', HealthIcon);
		set('SongEvent', Song.SongEvent);
		set('NoteEvent', Lane.NoteEvent);
		set('StageProp', Stage.StageProp);
		set('FunkinSprite', FunkinSprite);
		set('Metronome', Conductor.Metronome);
		set('RuntimeShader', QuickRuntimeShader);
		set('ShaderFilter', openfl.filters.ShaderFilter);

		set('NoteEventType', NoteEventType);
		set('SpriteRenderType', SpriteRenderType);
		
		set('game', FlxG.state);
		set('state', FlxG.state);
		set('add', FlxG.state.add);
		set('remove', FlxG.state.remove);
		set('insert', FlxG.state.insert);
		if (Std.isOfType(FlxG.state, MusicBeatState)) {
			var state:MusicBeatState = cast FlxG.state;
			set('conductor', state.conductorInUse);
			set('sortZIndex', state.sortZIndex);
			set('insertZIndex', state.insertZIndex);
		}
		if (Std.isOfType(FlxG.state, PlayState)) {
			var playState:PlayState = cast FlxG.state;
			set('stage', playState.stage);
		}
		
		// abstract classes and special
		set('STOP', STOP);
		set('STOPALL', STOPALL);
		set('FlxAxes', HScriptFlxAxes);
		set('FlxColor', HScriptFlxColor);
		set('BlendMode', HScriptBlendMode);

		#if hscriptPos
		set("trace", Reflect.makeVarArgs(function(x:Array<Dynamic>) { // fix static trace
			var pos = this.interp != null ? this.interp.posInfos() : Iris.getDefaultPos(this.name);
			var v = x.shift();
			if (x.length > 0)
				pos.customParams = x;
			Iris.print(Std.isOfType(v, Array) ? v : Std.string(v), pos);
		}));
		#end
	}
	public function set_scriptString(newCode:String) {
		if (newCode == scriptString) return scriptString;
		scriptCode = newCode;
		try {
			parse(true);
			compiled = true;
		} catch (e:IrisError) {
			compiled = false;
			errorCaught(e);
		}
		return scriptString = newCode;
	}
}
enum HScriptFunctionEnum {
	STOP;
	STOPALL;
}

class QuickRuntimeShader extends FlxRuntimeShader {
	public var frag:Null<String> = null;
	public var vert:Null<String> = null;
	public var name:String;
	var compiled:Bool;
	var perfect:Bool;

	public function new(name:String) {
		this.name = name;
		frag = Paths.shaderFrag(name);
		vert = Paths.shaderVert(name);
		if (frag == null && vert == null) {
			Log.warning('shader code for "$name" not found...');
			Log.minor('verify paths:');
			Log.minor('- vertex: shaders/$name.vert');
			Log.minor('- fragment: shaders/$name.frag');
		} else {
			Log.minor('loaded shader code for "$name"');
		}
		super(frag, vert);
	}

	function getLog(infoLog:String, source:String):String {
		var logLines:Array<String> = infoLog.trim().split('\n');
		var sourceLines:Array<String> = source.split('\n');
		var finalLog:StringBuf = new StringBuf();
		for (i => logLine in logLines) {
			if (logLine.startsWith('ERROR')) {
				var info:Array<String> = logLine.split(':');

				var col:Int = Std.parseInt(info[1]);
				var line:Int = Std.parseInt(info[2]);
				var codeLine:String = sourceLines[line - 1];
				var msg:String = logLine.substr((info[0] + info[1] + info[2]).length + 3, logLine.length).trim();

				finalLog.add(Log.colorTag(Std.string(line).lpad(' ', 4) + ' | $codeLine\n', brightYellow));
				finalLog.add(Log.colorTag('     | ', brightYellow) + Log.colorTag(msg, red));
				if (i < logLines.length - 1) finalLog.add('\n');
			}
		}
		return finalLog.toString();
	}
	@:noCompletion override function __createGLShader(source:String, type:Int):openfl.display3D._internal.GLShader {
		@:privateAccess var gl = __context.gl;

		var shader = gl.createShader(type);
		gl.shaderSource(shader, source);
		gl.compileShader(shader);
		var shaderInfoLog = gl.getShaderInfoLog(shader).trim();
		var compileStatus = gl.getShaderParameter(shader, gl.COMPILE_STATUS);

		if (compileStatus == 0) {
			var isVertex:Bool = type == gl.VERTEX_SHADER;
			var message:String = 'error compiling ${isVertex ? 'vertex' : 'fragment'} code from shader "$name"...'; //$source
			Log.error(message);
			Sys.println(getLog(shaderInfoLog, source));

			Log.minor('compiling with default code...');
			var source:String;
			if (type == gl.VERTEX_SHADER) {
				source = FlxRuntimeShader.BASE_VERTEX_SOURCE.replace('#pragma header', FlxRuntimeShader.BASE_VERTEX_HEADER);
				source = source.replace('#pragma body', FlxRuntimeShader.BASE_VERTEX_BODY);
			} else {
				source = FlxRuntimeShader.BASE_FRAGMENT_SOURCE.replace('#pragma header', FlxRuntimeShader.BASE_FRAGMENT_HEADER);
				source = source.replace('#pragma body', FlxRuntimeShader.BASE_FRAGMENT_BODY);
			}
			gl.shaderSource(shader, source);
			gl.compileShader(shader);
			perfect = false;
			// dev FlxRuntimeShaderMacro.retrieveMetadata('gl${type == gl.VERTEX_SHADER ? 'Vertex' : 'Fragment'}Source', false)
		}

		return shader;
	}
	@:noCompletion override function __createGLProgram(vert:String, frag:String):openfl.display3D._internal.GLProgram {
		Log.minor('initializing shader "$name"');
		perfect = true;

		@:privateAccess var gl = __context.gl;

		var vertexShader = __createGLShader(vert, gl.VERTEX_SHADER);
		var fragmentShader = __createGLShader(frag, gl.FRAGMENT_SHADER);

		var program = gl.createProgram();

		// Fix support for drivers that don't draw if attribute 0 is disabled
		for (param in __paramFloat) {
			if (param.name.indexOf("Position") > -1 && StringTools.startsWith(param.name, "openfl_")) {
				gl.bindAttribLocation(program, 0, param.name);
				break;
			}
		}

		try {
			gl.attachShader(program, vertexShader);
			gl.attachShader(program, fragmentShader);
			gl.linkProgram(program);
			compiled = (gl.getProgramParameter(program, gl.LINK_STATUS) != 0);
			if (!compiled)
				Log.error('could not initialize shader program for "$name"...\n${gl.getProgramInfoLog(program)}');
		} catch(e:Dynamic) {
			compiled = false;
			Log.error('could not initialize shader program for "$name"...\n(LINK ERROR)');
		}

		if (compiled) {
			if (perfect)
				Log.info('initialized shader program for "$name"!');
			else
				Log.warning('initialized shader program for "$name" with errors');
		}

		return program;
	}
	function resetShader() {

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
	public var alpha(default, set):Int;
	public var alphaFloat(default, set):Float;
	@:isVar public var red(get, set):Int;
	@:isVar public var green(get, set):Int;
	@:isVar public var blue(get, set):Int;
	@:isVar public var redFloat(get, set):Float;
	@:isVar public var greenFloat(get, set):Float;
	@:isVar public var blueFloat(get, set):Float;
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
	function set_alphaFloat(newAlpha:Float) return alphaFloat = color.alphaFloat = newAlpha;
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