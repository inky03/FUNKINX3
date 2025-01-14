package funkin.backend;

import flixel.addons.display.FlxRuntimeShader;
#if (flixel_addons >= "3.3.0")
import flixel.addons.system.macros.FlxRuntimeShaderMacro;
#end

using StringTools;

class FunkinRuntimeShader extends FlxRuntimeShader {
	var compiled:Bool;
	var __frag:String;
	var __vert:String;
	
	public var name:String;
	public var frag(default, set):Null<String> = null;
	public var vert(default, set):Null<String> = null;
	public var postProcessing(default, set):Bool = false;
	
	public function new(?frag:String, ?vert:String, ?name:String) {
		this.name = name ?? 'unknown';
		this.frag = frag;
		this.vert = vert;
		super(frag, vert);
		postProcessing = (hasParameter('uScreenResolution') && hasParameter('uCameraBounds'));
	}
	public #if (flixel_addons >= "3.3.0") override #end function toString() {
		return 'FunkinRuntimeShader($name)';
	}
	function getLog(infoLog:String, source:String):String {
		var logLines:Array<String> = infoLog.trim().split('\n');
		var sourceLines:Array<String> = source.split('\n');
		var finalLog:StringBuf = new StringBuf();
		var first:Bool = true;
		for (i => logLine in logLines) {
			if (!first) finalLog.add('\n');
			if (logLine.startsWith('ERROR')) {
				var info:Array<String> = logLine.split(':');

				var col:Int = Std.parseInt(info[1]);
				var line:Int = Std.parseInt(info[2]);
				var codeLine:String = sourceLines[line - 1];
				var msg:String = logLine.substr((info[0] + info[1] + info[2]).length + 3, logLine.length).trim();

				#if I_AM_BORING_ZZZ
				finalLog.add('ERROR: $msg');
				finalLog.add('@ LINE $line: $codeLine');
				#else
				finalLog.add(Log.colorTag(Std.string(line).lpad(' ', 4) + ' | $codeLine\n', brightYellow));
				finalLog.add(Log.colorTag('     | ', brightYellow) + Log.colorTag(msg, red));
				#end
				first = false;
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
			var isVertex:Bool = (type == gl.VERTEX_SHADER);
			var message:String = 'error compiling ${isVertex ? 'vertex' : 'fragment'} code from shader "$name"...'; //$source
			var log:String = getLog(shaderInfoLog, source);
			Log.error(message);
			Sys.println(log);

			Log.minor('initializing shader with default code');
			throw log;
		}

		return shader;
	}
	@:noCompletion override function __initGL() {
		__context ??= FlxG.stage.context3D;
		try {
			compiled = false;
			super.__initGL();
		} catch (e:Dynamic) {
			var vertSource:String;
			var fragSource:String;
			
			#if (flixel_addons >= "3.3.0")
			vertSource = FlxRuntimeShaderMacro.retrieveMetadata('glVertexSource', false);
			fragSource = FlxRuntimeShaderMacro.retrieveMetadata('glFragmentSource', false);
			#else
			vertSource = FlxRuntimeShader.BASE_VERTEX_SOURCE;
			fragSource = FlxRuntimeShader.BASE_FRAGMENT_SOURCE;
			#end
			
			__data = new openfl.display.ShaderData(null);
			glFragmentSource = fragSource;
			glVertexSource = vertSource;
			__glSourceDirty = true;
			program = null;
			super.__initGL();
			Log.warning('initialized shader program for "$name" with errors');
		}
	}
	@:noCompletion override function __createGLProgram(vert:String, frag:String):openfl.display3D._internal.GLProgram {
		final match:Bool = ((this.vert == null || vert.endsWith(__vert)) && (this.frag == null || frag.endsWith(__frag))); // I guess that works ,,?
		
		if (match)
			Log.minor('initializing shader program for "$name"');
		@:privateAccess var gl = __context.gl;
		
		var vertexShader = __createGLShader(vert, gl.VERTEX_SHADER);
		var fragmentShader = __createGLShader(frag, gl.FRAGMENT_SHADER);
		
		var program = gl.createProgram();
		
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
		
		if (compiled && match)
			Log.info('initialized shader program for "$name"!');
		
		return program;
	}
	
	public function hasParameter(name:String):Bool {
		return (data != null && Reflect.hasField(data, name));
	}
	public function postUpdateView(camera:FlxCamera) {
		setFloatArray('uCameraBounds', [camera.viewLeft, camera.viewTop, camera.viewRight, camera.viewBottom]);
	}
	public function postUpdateFrame(frame:flixel.graphics.frames.FlxFrame) {
		if (hasParameter('uFrameBounds'))
			setFloatArray('uFrameBounds', [frame.uv.x, frame.uv.y, frame.uv.width, frame.uv.height]);
	}
	
	function set_postProcessing(isPost:Bool) {
		if (isPost) {
			if (!hasParameter('uScreenResolution') || !hasParameter('uCameraBounds')) {
				Log.warning('shader "$name" can\'t be used for post processing!');
				return false;
			}
			setFloatArray('uScreenResolution', [FlxG.width, FlxG.height]);
			setFloatArray('uCameraBounds', [0, 0, FlxG.width, FlxG.height]);
			if (hasParameter('uFrameBounds'))
				setFloatArray('uFrameBounds', [0, 0, FlxG.width, FlxG.height]);
		}
		return isPost;
	}
	function set_vert(?newCode:String) {
		glVertexSource = newCode;
		__vert = glVertexSource;
		return vert = newCode;
	}
	function set_frag(?newCode:String) {
		glFragmentSource = newCode;
		__frag = glFragmentSource;
		return frag = newCode;
	}
}