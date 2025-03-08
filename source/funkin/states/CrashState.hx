package funkin.states;

import haxe.CallStack;
import openfl.events.MouseEvent;
import openfl.events.UncaughtErrorEvent;
import flixel.addons.display.FlxBackdrop;

using StringTools;

class CrashState extends FlxState {
	public static var error:UncaughtErrorEvent;
	public static var stack:Array<StackItem>;
	public static var errorMessage:String;
	static var caughtError:Bool = false;
	static var inState:Bool = false;
	
	public var reportPath:String;
	public var windowText:FlxText;
	
	public function new(reportPath:String) {
		this.reportPath = reportPath;
		super();
	}
	
	public override function create() {
		inState = true;

		Paths.trackedAssets.resize(0);
		Paths.clean(); // CLEAR CACHE
		
		super.create();
		
		FlxG.sound.music.stop();
		Main.instance.removeChild(Main.debugDisplay);
		
		function loadCrashAsset(sprite:FunkinSprite, ?stack:Array<StackItem>) {
			var culprit:String = 'haxe';
			
			if (stack != null && stack[0] != null) {
				switch (stack[0]) {
					case FilePos(s, file, _, _):
						switch (s) {
							case Module(m):
								m = m.substring(0, m.indexOf('.'));
							case Method(cls, method):
								culprit = cls.substring(0, cls.indexOf('.'));
							default:
								culprit = file.substring(0, file.indexOf('/'));
						}
					default:
				}
				
				if (Paths.image('crash/dead/$culprit') == null) {
					culprit = switch (culprit) {
						case 'lime':
							'openfl';
						default:
							culprit;
					}
				}
			}
			if (Paths.image('crash/dead/$culprit') == null)
				culprit = 'haxe'; // blame it on haxe
			
			sprite.loadTexture('crash/dead/$culprit');
		}
		
		var background:FlxBackdrop = new FlxBackdrop(Paths.image('charter/bg'));
		background.velocity.set(15, 15);
		background.scale.set(.45, .45);
		background.antialiasing = true;
		add(background);
		for (rect in [new FlxRect(-2, 0, 447, 209), new FlxRect(462, 0, 743, 420), new FlxRect(656, 436, 548, 211)]) { // im lazyyy
			var box:FunkinSprite = new FunkinSprite(rect.x + 36, rect.y + 36).makeGraphic(1, 1, 0xffccccff);
			box.scale.set(rect.width, rect.height);
			box.updateHitbox();
			box.alpha = .35;
			add(box);
		}
		
		var blue:FlxTextFormat = new FlxTextFormat(FlxColor.BLUE);
		var windowBg:FunkinSprite = new FunkinSprite(511 + 14, 50 + 53).makeGraphic(1, 1, -1);
		windowBg.scale.set(690, 330);
		windowBg.updateHitbox();
		add(windowBg);
		windowText = new FlxText(511 + 28, 50 + 66);
		windowText.setFormat('_sans', 18, FlxColor.BLACK, LEFT);
		windowText.addFormat(new FlxTextFormat(FlxColor.RED), 0, errorMessage.indexOf('\n'));
		windowText.addFormat(blue, errorMessage.indexOf('Stack Traceback'), errorMessage.indexOf('\n', errorMessage.indexOf('Stack Traceback')));
		windowText.clipRect = new FlxRect(0, 0, 660, 296);
		windowText.text = errorMessage;
		windowText.antialiasing = true;
		add(windowText);
		var window:FunkinSprite = new FunkinSprite(511, 50).loadTexture('crash/window');
		add(window);
		
		var uhOh:FunkinSprite = new FunkinSprite(74, 52).loadTexture('crash/uhOh');
		add(uhOh);
		var dead:FunkinSprite = new FunkinSprite(670, 740);
		loadCrashAsset(dead, stack);
		dead.y -= dead.height;
		dead.x -= dead.width;
		add(dead);
		
		add(quickText(56, 180, 440, 'funkinx3 has encountered an unexpected error.', 22));
		add(quickText(705, 482, 530, 'The full Crash Dump has been saved in $reportPath', 21));
		add(quickText(705, 546, 530, 'If you believe this error was caused by the game, please open an issue in GitHub.', 21));
		var bigText:FlxText = quickText(705, 615, 520, '', 26);
		bigText.applyMarkup('Press &ENTER& to open GitHub issues\nPress &ESCAPE& to return to game', [new FlxTextFormatMarkerPair(blue, '&')]);
		bigText.alignment = CENTER;
		add(bigText);
		
		FunkinSound.playOnce(Paths.sound('gameplay/hitsounds/miss${FlxG.random.int(1, 3)}'));
	}
	function quickText(x:Float, y:Float, w:Float, str:String, size:Int = 24, color:FlxColor = FlxColor.BLACK):FlxText {
		var text:FlxText = new FlxText(x, y, w, str);
		text.setFormat('_sans', size, color, LEFT);
		text.antialiasing = true;
		return text;
	}
	
	override public function update(elapsed:Float) {
		mouseScrollEvent(FlxG.mouse.wheel);

		if (FlxG.keys.justPressed.ENTER) {
			/*#if hl
			@:privateAccess final exePath:String = Sys.makePath(Sys.sys_exe_path());
			#else
			final exePath:String = Sys.programPath();
			#end
			Sys.command('start "" "$exePath"');
			Sys.exit(0);*/
			FlxG.openURL('https://github.com/inky03/funkinmess/issues');
		}
		if (FlxG.keys.justPressed.ESCAPE) {
			Paths.trackedAssets.resize(0);
			Log.minor('returning to initial game state');
			@:privateAccess FlxG.switchState(FlxG.game._initialState);
			return;
		}
		super.update(elapsed);
	}
	
	public function mouseScrollEvent(delta:Int = 0) {
		if (delta == 0 || !FlxG.mouse.overlaps(windowText)) return;
		
		var max:Float;
		var movement:Float = delta * -15;
		if (Util.keyMod.shiftKey) {
			max = windowText.graphic.width - windowText.clipRect.width;
			windowText.offset.x = Util.clamp(windowText.offset.x + movement, 0, Math.max(max, 0));
		} else {
			max = windowText.graphic.height + 25 - windowText.clipRect.height;
			windowText.offset.y = Util.clamp(windowText.offset.y + movement, 0, Math.max(max, 0));
		}
		windowText.clipRect.x = windowText.offset.x;
		windowText.clipRect.y = windowText.offset.y;
		windowText.clipRect = windowText.clipRect;
	}
	
	public static function errorToString(?stack:Array<StackItem>, ?error:UncaughtErrorEvent):String {
		if (stack == null)
			return 'Unknown error';
		
		var b:StringBuf = new StringBuf();
		
		if (error != null) {
			b.add('Uncaught Exception: ');
			b.add(error.error);
		} else {
			b.add('Uncaught Exception');
		}
		b.add('\nStack Traceback:');
		if (stack.length > 0) {
			for (item in stack) {
				b.add('\n');
				b.add(itemToString(item));
			}
		} else {
			b.add('\n- (empty)');
		}
		
		return b.toString();
	}
	
	public static function itemToString(item:StackItem):String {
		return switch (item) {
			case FilePos(s, file, line, col):
				var f:String = file;
				if (f.endsWith('.hx'))
					f = f.substring(0, f.lastIndexOf('.hx'));
				if (s != null)
					f = '${itemToString(s)} in $f';
				'- $f (line $line${col == null ? '' : ', column $col'})';
			case CFunction:
				'Function from C';
			case Module(m):
				'Module $m';
			case Method(cls, method):
				'Method ${cls ?? '<unknown>'}.$method';
			case LocalFunction(n):
				'Local function #$n';
		}
	}
	
	public static function generateReportString(message:String, date:Date) {
		return
'FUNKINX3 CRASH DUMP

Date/Time:      ${date.toString()}
Build Target:   ${Main.compiledTo} (compiled with ${Main.compiledWith})
Engine Version: ${Main.engineVersion}
		
$message';
	}
	
	public static function handleUncaughtError(e:UncaughtErrorEvent) {
		error = e;
		stack = CallStack.exceptionStack(true);
		errorMessage = errorToString(stack, error);
		
		if (inState) {
			Log.error('YOUR CRASH HANDLER CRASHED IDIOT\n$errorMessage');
			Sys.exit(0);
		}
		
		e.preventDefault();
		e.stopImmediatePropagation();
		
		if (caughtError) return;
		
		var date:Date = Date.now();
		var crashLog:String = generateReportString(errorMessage, date);
		
		if (!FileSystem.exists('logs'))
			FileSystem.createDirectory('logs');
		
		final reportPath:String = 'logs/FUNKINX3_crashdump_${date.toString().replace(' ', '_').replace(':', "'")}.txt';
		File.saveContent(reportPath, '$crashLog\n');
		Log.info('saved crash report to $reportPath');
		
		caughtError = true;
		FlxG.switchState(() -> new CrashState(reportPath));
		Log.error('GAME CRASHED!!!\n$errorMessage');
	}
	
	override public function destroy() {
		Main.instance.addChild(Main.debugDisplay);
		super.destroy();
		
		error = null;
		stack = null;
		inState = false;
		errorMessage = '';
		caughtError = false;
	}
}