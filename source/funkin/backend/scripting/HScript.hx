package funkin.backend.scripting;

#if ALLOW_SCRIPTS // TODO: make the game actually compile without this define
import funkin.backend.FunkinRuntimeShader;
import funkin.backend.scripting.HScriptClasses;

import haxe.PosInfos;
import crowplexus.iris.Iris;
import crowplexus.iris.IrisConfig;
import crowplexus.iris.ErrorSeverity;
import crowplexus.hscript.*;
import crowplexus.hscript.Printer;
import crowplexus.hscript.Expr.Error as IrisError;

using StringTools;

enum HScriptFunctionEnum {
	STOP;
	STOPALL;
}
class HScript extends FlxBasic {
	public static var staticVariables:Map<String, Dynamic> = [];
	public static var STOP(default, never):HScriptFunctionEnum = HScriptFunctionEnum.STOP;
	public static var STOPALL(default, never):HScriptFunctionEnum = HScriptFunctionEnum.STOPALL;
	@:noReflection public static var defaultVariables:Map<String, Dynamic> = [
		'Std' => Std,
		'Math' => #if hl HScriptMath #else Math #end,
		'StringTools' => StringTools,
		
		'Main' => Main,
		'Type' => Type,
		'Reflect' => Reflect,
		'HScript' => HScript,
		'FlxG' => flixel.FlxG,
		'FlxSprite' => flixel.FlxSprite,
		'FlxCamera' => flixel.FlxCamera,
		'FlxMath' => flixel.math.FlxMath,
		'FlxText' => flixel.text.FlxText,
		'FlxEase' => flixel.tweens.FlxEase,
		'FlxTimer' => flixel.util.FlxTimer,
		'FlxSound' => flixel.sound.FlxSound,
		'FlxTween' => flixel.tweens.FlxTween,
		'FlxSpriteGroup' => FlxSpriteGroup,
		'ShaderFilter' => openfl.filters.ShaderFilter,
		
		'FunkinText' => funkin.backend.FunkinText,
		'FunkinSound' => funkin.backend.FunkinSound,
		'FunkinSprite' => funkin.backend.FunkinSprite,
		'FunkinCamera' => funkin.backend.FunkinCamera,
		'FunkinAnimate' => funkin.backend.FunkinAnimate,
		'FunkinSpriteGroup' => funkin.backend.FunkinSpriteGroup,
		
		'Util' => funkin.util.Util,
		'Lane' => funkin.objects.play.Lane,
		'Note' => funkin.objects.play.Note,
		'Paths' => funkin.backend.Paths,
		'Options' => funkin.backend.Options,
		'Controls' => funkin.backend.Controls,
		'PlayState' => funkin.states.PlayState,
		'Character' => funkin.objects.Character,
		'HealthIcon' => funkin.objects.HealthIcon,
		'NoteEvent' => funkin.backend.play.NoteEvent,
		'NoteStyle' => funkin.backend.play.NoteStyle,
		'Strumline' => funkin.objects.play.Strumline,
		'StageProp' => funkin.objects.Stage.StageProp,
		'Conductor' => funkin.backend.rhythm.Conductor,
		'Metronome' => funkin.backend.rhythm.Metronome,
		'CharacterGroup' => funkin.objects.CharacterGroup,
		
		'NoteEventType' => {SPAWNED: 'spawned', DESPAWNED: 'despawned', HIT: 'hit', HELD: 'held', RELEASED: 'released', LOST: 'lost', GHOST: 'ghost'},
		// THIS WILL BE DEPRECATED
		
		'STOP' => STOP,
		'STOPALL' => STOPALL,
		'FlxAxes' => HScriptFlxAxes,
		'FlxColor' => HScriptFlxColor,
		'BlendMode' => HScriptBlendMode,
		'RuntimeShader' => HScriptRuntimeShader,
		
		'experimentalVars' => true
	];
	
	var expr:Expr;
	var parser:ModParser;
	var interp:ModInterp;
	var executed:Bool = false;
	public var failed:Bool = false;
	public var compiled:Bool = false;
	
	public var interceptArray:Array<Dynamic> = null;
	public var defaultVars:Map<String, Dynamic> = null;
	
	public var scriptString(default, set):String = '';
	public var scriptPath:Null<String> = null;
	public var packageName:String = '';
	public var scriptName:String = '';
	
	public static function init() {
		Iris.logLevel = customLog;
	}
	public static function stopped(result:Dynamic) {
		return (result == STOP || result == STOPALL);
	}
	public function new(name:String, code:String, ?interceptArray:Array<Dynamic>, ?defaultVars:Map<String, Dynamic>) {
		super();
		
		parser = new ModParser();
		interp = new ModInterp();
		interp.hscript = this;
		
		parser.allowTypes = parser.allowJSON = parser.allowMetadata = true;
		preset();
		
		this.interceptArray = interceptArray;
		this.defaultVars = defaultVars;
		
		this.scriptName = name;
		this.scriptString = code;
	}
	
	public function run(?func:String, ?args:Array<Any>, safe:Bool = true, forceRun:Bool = false):Any {
		if (!compiled || failed || (!active && !forceRun)) return null;
		try {
			if (func != null) {
				if (!executed) execute();
				executed = true;
				
				if (safe && !hasVar(func)) return null;
				var result:IrisCall = call(func, args);
				return result?.returnValue ?? null;
			} else {
				return execute();
			}
		} catch (e:Dynamic) {
			if (!executed)
				failed = true;
			
			errorCaught(e);
			
			return null;
		}
	}
	public override function kill():Void {
		if (alive)
			run('kill', true, true);
		
		super.kill();
	}
	public override function revive():Void {
		if (!alive)
			run('revive', true, true);
		
		super.revive();
	}
	public override function destroy():Void {
		if (exists)
			run('destroy', true, true);
		
		interp = null;
		parser = null;
		super.destroy();
	}
	public function preset():Void {
		for (field => val in defaultVariables)
			set(field, val);
		
		set('script', this);
		set('game', FlxG.state);
		if (Std.isOfType(FlxG.state, FunkinState)) {
			var state:FunkinState = cast FlxG.state;
			set('conductor', state.conductorInUse);
		}

		#if hscriptPos
		set('trace', Reflect.makeVarArgs(function(x:Array<Dynamic>) { // fix static trace
			@:privateAccess var pos = (interp != null ? this.interp.posInfos() : Iris.getDefaultPos(scriptName));
			
			var v = x.shift();
			if (x.length > 0) pos.customParams = x;
			
			Iris.print(Std.string(v), pos);
		}));
		#end
	}
	
	public function parse(string:String, force:Bool = false) {
		if (force || expr == null)
			expr = parser.parseString(string, scriptName);
		return expr;
	}
	public function execute():Dynamic {
		packageName = parser.packageName;
		return interp.execute(expr);
	}
	public function set(name:String, value:Dynamic, allowOverride:Bool = true):Void {
		if (allowOverride || !hasVar(name))
			setVar(name, value);
	}
	public function call(fun:String, ?args:Array<Dynamic>):IrisCall {
		var ny:Dynamic = getVar(fun); // function signature
		var isFunction:Bool = false;
		
		try {
			isFunction = (ny != null && Reflect.isFunction(ny));
			if (!isFunction) throw 'Tried to call a non-function, for "$fun"';

			final ret = Reflect.callMethod(null, ny, args ?? []);
			return {funName: fun, signature: ny, returnValue: ret};
		}
		
		#if hscriptPos
		catch (e:Expr.Error) {
			Iris.error(Printer.errorToString(e, false), this.interp.posInfos());
		}
		#end
		catch (e:haxe.Exception) {
			@:privateAccess var pos = (isFunction ? this.interp.posInfos() : Iris.getDefaultPos(scriptName));
			Iris.error(
				Std.string(e)
					#if IRIS_DEBUG + "\n" + CallStack.toString(CallStack.exceptionStack(true)) #end,
				pos
			);
		}
		
		return null;
	}
	
	public override function setVar(name:String, value:Dynamic):Dynamic {
		interp.variables.set(name, value);
		return value;
	}
	public override function getVar(name:String):Dynamic {
		return interp.variables.get(name);
	}
	public override function removeVar(name:String):Void {
		interp.variables.remove(name);
	}
	public override function hasVar(name:String):Bool {
		return interp.variables.exists(name);
	}
	
	function set_scriptString(newCode:String):String {
		if (newCode == scriptString) return scriptString;
		
		failed = false;
		try {
			parse(newCode, true);
			executed = false;
			compiled = true;
		} catch (e:IrisError) {
			compiled = false;
			errorCaught(e);
		}
		
		return scriptString = newCode;
	}
	
	function errorCaught(e:Dynamic):Void {
		if (Std.isOfType(e, IrisError)) {
			var pos:PosInfos = cast {fileName: e.origin, lineNumber: e.line};
			Iris.fatal(Printer.errorToString(e, false), pos);
		} else {
			var pos:PosInfos = @:privateAccess { cast interp.posInfos(); }
			Iris.fatal(Std.string(e), pos);
		}
	}
	public static function customLog(level:ErrorSeverity, x, ?pos:haxe.PosInfos) {
		@:privateAccess if (pos == null) pos = Iris.getDefaultPos();

		var out:String = Std.string(x);
		if (pos != null && pos.customParams != null)
			for (i in pos.customParams)
				out += ',$i';

		var posPrefix:String = pos.fileName;
		if (pos.lineNumber != -1)
			posPrefix += ':${pos.lineNumber}';

		switch (level) {
			#if I_AM_BORING_ZZZ
			case FATAL: posPrefix = '[ FATAL:$posPrefix ]';
			case ERROR: posPrefix = '[ ERROR:$posPrefix ]';
			case WARN: posPrefix = '[ WARNING:$posPrefix ]';
			default:
			#else
			case FATAL: posPrefix = Log.colorTag(' FATAL:$posPrefix ', black, brightRed);
			case ERROR: posPrefix = Log.colorTag(' ERROR:$posPrefix ', black, red);
			case WARN: posPrefix = Log.colorTag(' WARNING:$posPrefix ', black, yellow);
			default: posPrefix = Log.colorTag(' $posPrefix ', black, blue);
			#end
		}
		Sys.println('$posPrefix $out');
	}
}
#else
class HScript {}
#end