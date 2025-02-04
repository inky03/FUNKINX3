package funkin.states;

import funkin.objects.Alphabet;
import funkin.backend.rhythm.Event;

using StringTools;

class TitleState extends FunkinState {
	public var introGroup:FlxSpriteGroup = new FlxSpriteGroup();
	public var titleGroup:FlxSpriteGroup = new FlxSpriteGroup();
	
	public var ngSpr:FunkinSprite;
	public var enter:FunkinSprite;
	public var logo:FunkinSprite;
	
	public var introTexts:Array<Array<String>> = [];
	public var currentIntroText:Array<String>;
	public var titleStarted:Bool = false;
	public var inputEnabled:Bool = true;
	public var confirmed:Bool = false;
	var skipIntro:Bool = false;
	
	public function new(skipIntro:Bool = false) {
		this.skipIntro = skipIntro;
		super();
	}
	public function loadIntroTexts() {
		introTexts.resize(0);
		var introTextPaths:Array<PathsFile> = Paths.getPaths('data/introText.txt', true, true);
		for (file in introTextPaths) {
			try {
				var content:String = File.getContent(file.path);
				var contentLines:Array<String> = content.replace('\r', '').split('\n');
				for (line in contentLines) {
					var items:Array<String> = line.split('--');
					if (items.length >= 2)
						introTexts.push(items);
				}
			} catch (e:haxe.Exception) {
				Log.error('Failed to get intro text content for mod "${file.mod}" (skipped)...');
			}
		}
	}
	public override function create() {
		preload();
		currentIntroText = FlxG.random.getObject(introTexts) ?? ['funkin', 'FOREVER'];
		
		beatHit.add(beatHitEvent);
		
		logo = new FunkinSprite().loadAtlas('titlescreen/logo');
		logo.addAnimation('bump', 'logo bumpin');
		logo.playAnimation('bump');
		logo.updateHitbox();
		logo.screenCenter();
		logo.y = 50;
		titleGroup.add(logo);
		
		enter = new FunkinSprite(0, FlxG.height - 50).loadAtlas('titlescreen/titleEnter');
		enter.addAnimation('flash', 'enter to begin', 24, true);
		enter.addAnimation('idle', 'enter to begin', 24);
		enter.playAnimation('idle', true);
		enter.updateHitbox();
		enter.y -= enter.height;
		enter.screenCenter(X);
		titleGroup.add(enter);
		
		ngSpr = new FunkinSprite();
	    if (FlxG.random.bool(1)) {
			ngSpr.loadGraphic(Paths.image('titlescreen/ngClassic'));
	    } else if (FlxG.random.bool(30)) {
			ngSpr.loadGraphic(Paths.image('titlescreen/ngAnimated'), true, 600);
			ngSpr.setGraphicSize(Std.int(ngSpr.width * 0.55));
			ngSpr.addAnimation('idle', null, 4, true, [0, 1]);
			ngSpr.playAnimation('idle');
			ngSpr.y += 25;
		} else {
			ngSpr.loadTexture('titlescreen/ng');
			ngSpr.setGraphicSize(Std.int(ngSpr.width * 0.8));
		}
		ngSpr.alpha = .0001;
		ngSpr.updateHitbox();
    	ngSpr.screenCenter(X);
    	ngSpr.y = FlxG.height - ngSpr.height - 160;
		
		playMusic(MainMenuState.menuMusic, !skipIntro);
		conductorInUse.syncTracker = FlxG.sound.music;
		add(introGroup);
		
		if (!skipIntro) {
    		add(ngSpr);
			final ySpacing:Float = 60;
			
			queueEvent(beatToMS(1), (_) -> {
				makeText('The', -ySpacing);
				makeText('Funkin\' Crew Inc.');
			});
			queueEvent(beatToMS(3), (_) -> makeText('Presents', ySpacing));
			
			queueEvent(beatToMS(4), (_) -> clearIntroGroup());
			queueEvent(beatToMS(5), (_) -> {
				(makeText('In association with')).y = 160;
			});
			queueEvent(beatToMS(7), (_) -> ngSpr.alpha = 1);
			
			queueEvent(beatToMS(8), (_) -> {
				clearIntroGroup();
				remove(ngSpr);
			});
			queueEvent(beatToMS(9), (_) -> makeText(currentIntroText[0], ySpacing * -.5));
			queueEvent(beatToMS(11), (_) -> makeText(currentIntroText[1], ySpacing * .5));
			
			queueEvent(beatToMS(12), (_) -> {
				clearIntroGroup();
				makeText('FRIDAY', ySpacing * -1.5);
			});
			queueEvent(beatToMS(13), (_) -> makeText('NIGHT', ySpacing * -.5));
			queueEvent(beatToMS(14), (_) -> makeText('FUNKIN', ySpacing * .5));
			queueEvent(beatToMS(15), (_) -> makeText('X3', ySpacing * 1.5));
			
			queueEvent(beatToMS(16), (_) -> showTitleScreen());
		} else {
			showTitleScreen(true);
		}
		
		DiscordRPC.presence.details = 'In the title screen';
		DiscordRPC.dirty = true;
	}
	
	public function beatHitEvent(beat:Int) {
		logo.playAnimation('bump', true);
		if (beat % 2 == 0) {
			if (!confirmed) {
				var to:FlxColor = 0xff3333cc;
				var from:FlxColor = 0xff33ffff;
				FlxTween.cancelTweensOf(enter);
				FlxTween.color(enter, conductorInUse.crochet * .001 * 2, from, to, {type: (beat % 4 < 2 ? ONESHOT : BACKWARD)});
			}
		}
	}
	
	public override function update(elapsed:Float) {
		super.update(elapsed);
		if (!inputEnabled) return;
		
		if (FlxG.keys.justPressed.ENTER) {
			if (!titleStarted) {
				showTitleScreen();
			} else {
				FunkinSound.playOnce(Paths.sound('confirmMenu'), .8);
				inputEnabled = false;
				confirmed = true;
				
				FlxTween.cancelTweensOf(enter);
				enter.playAnimation('flash', true);
				enter.color = FlxColor.WHITE;
				
				new FlxTimer().start(2, (_) -> {
					FlxG.switchState(MainMenuState.new);
				});
			}
		}
	}
	
	function preload() {
		loadIntroTexts();
		makeText('ABCD');
		introGroup.draw();
		clearIntroGroup();
	}
	public function showTitleScreen(skipFlash:Bool = false) {
		events.resize(0);
		clearIntroGroup();
		titleStarted = true;
		remove(introGroup);
		add(titleGroup);
		remove(ngSpr);
		
		if (!skipFlash)
			FlxG.camera.flash(-1, 1);
	}
	public function clearIntroGroup() {
		for (obj in introGroup)
			obj.destroy();
		introGroup.clear();
	}
	public function makeText(string:String, yOffset:Float = 0):Alphabet {
		var text:Alphabet = new Alphabet(string);
		text.screenCenter();
		text.y += yOffset;
		introGroup.add(text);
		return text;
	}
	inline function beatToMS(beat:Float) {
		return conductorInUse.convertMeasure(beat, BEAT, MS);
	}
}