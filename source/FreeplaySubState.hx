package;

import openfl.filters.BitmapFilterQuality;
import openfl.filters.GlowFilter;
import flixel.util.FlxSpriteUtil;
import flixel.util.FlxSignal;
import flixel.util.FlxSort;

class FreeplaySubState extends MusicBeatSubState {
	public var inputEnabled:Bool = false;
	public static var selection:Int = 0;

	public var bg:FunkinSprite;
	public var ostName:FlxText;
	public var mainCam:FlxCamera;
	public var freeplayDJ:FreeplayDJ;
	public var backingCard:BackingCard;
	public var angleMask:AngleMaskShader;

	public var exitMovers:ExitMoverData = new ExitMoverData();

	public override function create() {
		super.create();

		mainCam = new FlxCamera();
		mainCam.bgColor.alpha = 0;
		FlxG.cameras.add(mainCam, false);

		backingCard = new BackingCard();
		backingCard.x -= backingCard.back.width;
		backingCard.slideIn();
		add(backingCard);

		beatHit.add(beatHitEvent);

		angleMask = new AngleMaskShader();
		bg = new FunkinSprite(FlxG.width, 0).loadTexture('freeplay/freeplayBGdad');
		bg.setGraphicSize(0, FlxG.height);
		bg.updateHitbox();
		bg.shader = angleMask;
		angleMask.extraColor = FlxColor.BLACK;
		add(bg);
		add(backingCard.glow);

		freeplayDJ = new FreeplayDJ(FlxG.width, FlxG.height);
		freeplayDJ.startIntro();
		add(freeplayDJ);

		var clearBoxSprite:FunkinSprite = new FunkinSprite(1165, 65).loadTexture('freeplay/clearBox');
		clearBoxSprite.visible = false;
		add(clearBoxSprite);
		var fnfFreeplay:FlxText = new FlxText(8, 8, 0, 'FREEPLAY', 48);
		fnfFreeplay.font = Paths.ttf('vcr');
		fnfFreeplay.visible = false;
		ostName = new FlxText(8, 8, FlxG.width - 8 - 8, 'OFFICIAL OST', 48);
		ostName.font = Paths.ttf('vcr');
		ostName.alignment = RIGHT;
		ostName.visible = false;
		var overhangStuff:FunkinSprite = new FunkinSprite().makeGraphic(FlxG.width, 164, 0xff000000);
		overhangStuff.y -= overhangStuff.height;
		add(overhangStuff);
		add(fnfFreeplay);
		add(ostName);

		var testCaspule:FreeplayCapsule = new FreeplayCapsule(400, 400, 'TESTING!');
		add(testCaspule);

		playMusic('freeplayRandom');
		FlxTween.tween(bg, {x: backingCard.back.width * 0.74}, 0.7, {ease: FlxEase.quintOut});
		FlxTween.tween(overhangStuff, {y: -100}, 0.3, {ease: FlxEase.quartOut});

		freeplayDJ.onIntroDone.add(() -> {
			inputEnabled = true;
			backingCard.introDone();
			FlxG.state.persistentDraw = false;
			FlxG.state.persistentUpdate = false;
			FlxTween.color(bg, 0.6, 0xff000000, 0xffffffff, {ease: FlxEase.expoOut, onUpdate: (tween:FlxTween) -> {
				angleMask.extraColor = bg.color;
			}});
			new FlxTimer().start(1 / 24, function(timer:FlxTimer) {
				clearBoxSprite.visible = true;
				fnfFreeplay.visible = true;
				ostName.visible = true;
			});
		});

		exitMovers.set([testCaspule], {x: -testCaspule.width, time: .3}); // TO REMOVE
		exitMovers.set([overhangStuff, fnfFreeplay, ostName], {y: -overhangStuff.height, time: .2});
		exitMovers.set([backingCard], {x: -backingCard.back.width, time: .5, delay: .1});
		exitMovers.set([freeplayDJ], {x: -freeplayDJ.width * 1.6, time: .5});
		exitMovers.set([bg], {x: FlxG.width * 1.5, time: .8, delay: .1});
		exitMovers.set([clearBoxSprite], {x: FlxG.width, time: .3});

		for (mem in members) mem.camera = mainCam;
	}

	public function back() {
		if (Std.isOfType(FlxG.state, MainMenuState)) {
			var menuState:MainMenuState = cast FlxG.state;
			menuState.returned(this);
		}

		var maxTime:Float = 0;
		inputEnabled = false;
		backingCard.exit();
		FlxG.state.persistentDraw = true;
		FlxG.state.persistentUpdate = true;
		for (grpSpr => moveData in exitMovers) {
			if (moveData == null) continue;

			for (spr in grpSpr) {
				if (spr == null) continue;

				var mover:MoveData = moveData;
				var moverTime:Float = mover.time ?? .2;
				var moverDelay:Float = mover.delay ?? 0;
				maxTime = Math.max(maxTime, moverTime + moverDelay);

				FlxTween.tween(spr, {x: mover.x ?? spr.x, y: mover.y ?? spr.y}, moverTime, {ease: FlxEase.expoIn});
			}
		}
		new FlxTimer().start(maxTime, (timer:FlxTimer) -> {
			close();
		});
	}

	public function beatHitEvent(beat:Int) {
		if (freeplayDJ != null && beat % 2 == 0) {
			freeplayDJ.dance(beat);
		}
	}

	public override function update(elapsed:Float) {
		if (FlxG.keys.justPressed.ESCAPE && inputEnabled) back();

		super.update(elapsed);
	}
}

class BackingCard extends FlxSpriteGroup {
	public var back:FunkinSprite;
	public var glow:FunkinSprite;
	public var orangeBack:FunkinSprite;
	public var alsoOrange:FunkinSprite;
	public var scrollingTexts:Array<BGScrollingText> = [];

	public function new() {
		super();
		back = new FunkinSprite().loadTexture('freeplay/back');
		back.color = 0xffd4e9;
		add(back);
		orangeBack = new FunkinSprite(84, 440).makeGraphic(Std.int(back.width), 75, 0xfffeda00);
		FlxSpriteUtil.alphaMaskFlxSprite(orangeBack, back, orangeBack);
		orangeBack.visible = false;
		add(orangeBack);
		alsoOrange = new FunkinSprite(0, orangeBack.y).makeGraphic(100, Std.int(orangeBack.height), 0xffffd400);
		alsoOrange.visible = false;
		add(alsoOrange);
		glow = new FunkinSprite(-30, -30).loadTexture('freeplay/cardGlow');
		glow.blend = BlendMode.ADD;
		glow.visible = false;
		updateHitbox();

		var screaming:String = 'BOYFRIEND';
		scrollingTexts.push(new BGScrollingText(0, 220, screaming, FlxG.width * .5, false, 60)); // this is so dumbass
		scrollingTexts.push(new BGScrollingText(0, 335, screaming, FlxG.width * .5, false, 60));
		scrollingTexts.push(new BGScrollingText(0, orangeBack.y + 10, screaming, FlxG.width * .5, false, 60));
		scrollingTexts.push(new BGScrollingText(0, 160, 'HOT BLOODED IN MORE WAYS THAN ONE', FlxG.width, true, 43));
		scrollingTexts.push(new BGScrollingText(0, 397, 'HOT BLOODED IN MORE WAYS THAN ONE', FlxG.width, true, 43));
		scrollingTexts.push(new BGScrollingText(0, 285, 'PROTECT YO NUTS', FlxG.width * .5, true, 43));
		scrollingTexts[0].color = 0xff9983;
		scrollingTexts[0].speed = -3.8;
		scrollingTexts[1].color = 0xff9983;
		scrollingTexts[1].speed = -3.8;
		scrollingTexts[2].color = 0xfea400;
		scrollingTexts[2].speed = -3.8;
		scrollingTexts[3].color = 0xfff383;
		scrollingTexts[3].speed = 6.8;
		scrollingTexts[4].color = 0xfff383;
		scrollingTexts[4].speed = 6.8;
		scrollingTexts[5].speed = 3.5;

		for (text in scrollingTexts) {
			text.visible = false;
			add(text);
		}
	}

	public function slideIn() {
		FlxTween.tween(this, {x: 0}, .6, {ease: FlxEase.quartOut});
	}
	public function exit() {
		scrollingTexts.sort((a, b) -> Std.int(b.y - a.y));
		for (i => text in scrollingTexts) {
			new FlxTimer().start(i / 24, (timer:FlxTimer) -> {
				if (scrollingTexts == null || text == null) return; // lmao
				scrollingTexts.remove(text);
				text.destroy();
			});
		}
	}
	public function introDone() {
		back.color = 0xffd863;
		glow.visible = true;
		orangeBack.visible = true;
		alsoOrange.visible = true;
		for (text in scrollingTexts)
			text.visible = true;
		FlxTween.tween(glow, {alpha: 0, 'scale.x': 1.2, 'scale.y': 1.2}, 0.45, {ease: FlxEase.sineOut});
	}
}

class FreeplaySongText extends FlxSpriteGroup {
	public var blurText:FlxText;
	public var whiteText:FlxText;
	public var textGlowFilter:GlowFilter;
	public var text(default, set):String;
	public var font(default, set):Null<String>;
	public var glowColor(default, set):FlxColor;

	public function new(x:Float = 0, y:Float = 0, ?text:String, glowColor:FlxColor = 0xff00ccff) {
		super(x, y);
		blurText = new FlxText(0, 0, 'Random', 40);
		whiteText = new FlxText(0, 0, 'Random', 40);
		textGlowFilter = new GlowFilter(glowColor, 1, 5, 5, 210, BitmapFilterQuality.MEDIUM);
		blurText.textField.filters = [new openfl.filters.BlurFilter(2, 2, BitmapFilterQuality.MEDIUM)];
		whiteText.textField.filters = [textGlowFilter];
		blurText.blend = BlendMode.ADD;

		add(blurText);
		add(whiteText);

		this.text = text;
		this.glowColor = glowColor;
		this.font = Paths.ttf('5by7');
	}
	function set_glowColor(newColor:FlxColor) {
		return textGlowFilter.color = newColor;
	}
	function set_text(newText:String) {
		blurText.text = newText;
		return whiteText.text = newText;
	}
	function set_font(newFont:Null<String>) {
		blurText.font = newFont;
		return whiteText.font = newFont;
	}
}

class FreeplayCapsule extends FlxSpriteGroup {
	public var capsule:FunkinSprite;
	public var bpmText:FunkinSprite;
	public var weekType:FunkinSprite;
	public var songText:FreeplaySongText;
	public var difficultyText:FunkinSprite;

	public function new(x:Float = 0, y:Float = 0, ?text:String, bpm:Float = 100, difficulty:Int = 1) {
		super(x, y);
		capsule = new FunkinSprite().loadAtlas('freeplay/capsule/capsule');
		capsule.addAnimation('unselected', 'mp3 capsule w backing NOT SELECTED', 24, true);
		capsule.addAnimation('selected', 'mp3 capsule w backing0', 24, true);
		capsule.playAnimation('unselected');
		add(capsule);

		songText = new FreeplaySongText(capsule.width * 0.26, 45, text);
		add(songText);

		bpmText = new FunkinSprite(144, 87).loadTexture('freeplay/capsule/bpmtext');
		bpmText.setGraphicSize(Std.int(bpmText.width * 0.9));
		add(bpmText);

		difficultyText = new FunkinSprite(414, 87).loadTexture('freeplay/capsule/difficultytext');
		difficultyText.setGraphicSize(Std.int(difficultyText.width * 0.9));
		add(difficultyText);

		weekType = new FunkinSprite(291, 87).loadAtlas('freeplay/capsule/weektypes');
		weekType.addAnimation('weekend', 'WEEKEND text instance 1', 24, false);
		weekType.addAnimation('week', 'WEEK text instance 1', 24, false);
		weekType.setGraphicSize(weekType.width * 0.9);
		add(weekType);
	}
}

class FreeplayDJ extends FunkinSprite { // i do not fucking care right now. implement player data later
	public var bop:Bool = false;
	public var onIntroDone:FlxSignal = new FlxSignal();

	public function new(x:Float = 0, y:Float = 0) {
		super(x, y);
		loadAnimate('freeplay/boyfriend');
		addAnimation('intro', 'boyfriend dj intro', 24, false);
		addAnimation('idle', 'Boyfriend DJ', 24, false);
		setAnimationOffset('intro', 631.7, 362.6);
		setAnimationOffset('idle', 625, 360);
		visible = false;
	}

	public function startIntro() {
		visible = true;
		playAnimation('intro', true);
		onAnimationComplete.add((name:String) -> {
			if (name == 'intro') {
				onIntroDone.dispatch();
				playAnimation('idle');
				bop = true;
			}
		});
	}
	public function dance(beat:Int = 0) {
		if (beat % 2 == 0 && bop) {
			playAnimation('idle');
		}
	}
}

class BGScrollingText extends FlxSpriteGroup {
	var grpTexts:FlxTypedSpriteGroup<FlxText>;

	public var speed:Float = 1;
	public var placementOffset:Float = 20;
	public var marqueeWidth:Float = FlxG.width;
	public var size(default, set):Int = 48;

	public function new(x:Float, y:Float, text:String, marqueeWidth:Float = 100, bold:Bool = false, size:Int = 48) {
		super(x, y);

		this.marqueeWidth = marqueeWidth;

		grpTexts = new FlxTypedSpriteGroup<FlxText>();
		add(grpTexts);

		this.size = size;

		var testText:FlxText = new FlxText(0, 0, 0, text, this.size);
		testText.font = Paths.ttf('5by7');
		testText.bold = bold;
		testText.updateHitbox();
		grpTexts.add(testText);

		var needed:Int = Math.ceil(marqueeWidth / testText.frameWidth) + 1;

		for (i in 0...needed) {
			var xP:Float = (i + 1) * (testText.frameWidth + placementOffset);
			var coolText:FlxText = new FlxText(xP, 0, 0, text, this.size);

			coolText.font = Paths.ttf('5by7');
			coolText.bold = bold;
			coolText.updateHitbox();
			grpTexts.add(coolText);
		}
	}

	function set_size(newSize:Int) {
		for (txt in grpTexts) txt.size = newSize;
		return size = newSize;
	}

	override public function update(elapsed:Float) {
		var sort:Bool = false;
		for (txt in grpTexts) {
			txt.x -= speed * elapsed * 60;

			if (txt.x < -txt.frameWidth - placementOffset) {
				var backMem:FlxText = grpTexts.members[grpTexts.length - 1];
				txt.x = backMem.x + backMem.frameWidth + placementOffset;
				sort = true;
			} else if (txt.x > (txt.frameWidth + placementOffset) * 2) {
				var backMem:FlxText = grpTexts.members[0];
				txt.x = backMem.x - backMem.frameWidth - placementOffset;
				sort = true;
			}
		}
		if (sort) sortTexts();

		super.update(elapsed);
	}

	function sortTexts() {
		grpTexts.sort((order:Int, a:FlxObject, b:FlxObject) -> FlxSort.byValues(order, a.x, b.x));
	}
}

typedef ExitMoverData = Map<Array<FlxSprite>, MoveData>;
typedef MoveData = {
	var ?x:Float;
	var ?y:Float;
	var ?time:Float;
	var ?delay:Float;
}