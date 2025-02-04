package funkin.backend.scripting;

#if ALLOW_SCRIPTS // TODO: make the game actually compile without the define
import funkin.backend.FunkinRuntimeShader;
import funkin.backend.scripting.HScriptClasses;

import crowplexus.iris.Iris;
import crowplexus.iris.IrisConfig;
import crowplexus.iris.ErrorSeverity;
import crowplexus.hscript.Printer;
import crowplexus.hscript.Expr.Error as IrisError;

using StringTools;

enum HScriptFunctionEnum {
	STOP;
	STOPALL;
}
class HScript extends Iris {
	public static var staticVariables:Map<String, Dynamic> = [];
	public static var STOP(default, never):HScriptFunctionEnum = HScriptFunctionEnum.STOP;
	public static var STOPALL(default, never):HScriptFunctionEnum = HScriptFunctionEnum.STOPALL;
	@:noReflection public static var defaultVariables:Map<String, Dynamic> = [
		#if hl
		'Math' => HScriptMath,
		#end
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
		
		'FunkinSound' => funkin.backend.FunkinSound,
		'FunkinSprite' => funkin.backend.FunkinSprite,
		'FunkinAnimate' => funkin.backend.FunkinAnimate,
		
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
		'Strumline' => funkin.objects.play.Strumline,
		'StageProp' => funkin.objects.Stage.StageProp,
		'Conductor' => funkin.backend.rhythm.Conductor,
		'Metronome' => funkin.backend.rhythm.Metronome,
		'CharacterGroup' => funkin.objects.CharacterGroup,
		'RuntimeShader' => HScriptRuntimeShader,
		
		'NoteEventType' => {SPAWNED: 'spawned', DESPAWNED: 'despawned', HIT: 'hit', HELD: 'held', RELEASED: 'released', LOST: 'lost', GHOST: 'ghost'},
		// THIS WILL BE DEPRECATED
		
		'STOP' => STOP,
		'STOPALL' => STOPALL,
		'FlxAxes' => HScriptFlxAxes,
		'FlxColor' => HScriptFlxColor,
		'BlendMode' => HScriptBlendMode
	];
	
	public var scriptString(default, set):String = '';
	public var scriptPath:Null<String> = null;
	public var scriptName:String = '';
	public var compiled:Bool = false;
	public var active:Bool = true;
	var modInterp:ModInterp;
	
	public static function init() {
		Iris.logLevel = customLog;
	}
	public static function stopped(result:Dynamic) {
		return (result == STOP || result == STOPALL);
	}
	public function new(name:String, code:String) {
		super('', new IrisConfig(name, false, false, []));
		scriptString = code;
		scriptName = name;
		
		interp = modInterp = new ModInterp();
		modInterp.hscript = this;
		preset();
	}
	
	public function errorCaught(e:IrisError, ?extra:String) {
		Log.fatal(Printer.errorToString(e));
	}
	public static function customLog(level:ErrorSeverity, x, ?pos:haxe.PosInfos) {
		if (pos == null) pos = Iris.getDefaultPos();

		var out:String = Std.string(x);
		if (pos != null && pos.customParams != null)
			for (i in pos.customParams)
				out += "," + Std.string(i);

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

		for (field => val in defaultVariables)
			set(field, val);
		
		set('game', FlxG.state);
		set('state', FlxG.state);
		set('add', FlxG.state.add);
		set('remove', FlxG.state.remove);
		set('insert', FlxG.state.insert);
		ModInterp.intercept = [FlxG.state/*, getClass(FlxG.state)*/];
		if (Std.isOfType(FlxG.state, FunkinState)) {
			var state:FunkinState = cast FlxG.state;
			set('conductor', state.conductorInUse);
		}

		#if hscriptPos
		set("trace", Reflect.makeVarArgs(function(x:Array<Dynamic>) { // fix static trace
			var pos = this.interp != null ? this.interp.posInfos() : Iris.getDefaultPos(this.name);
			var v = x.shift();
			if (x.length > 0)
				pos.customParams = x;
			var str:String = Std.string(v);
			Iris.print(str, pos);
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
#else
class HScript {}
#end