package;

class MainMenuState extends MusicBeatState {
	public var target:FlxObject;
	public var menuButtons:Array<FunkinSprite> = [];
	public var curSelected:Int = 0;
	
	override public function create() {
		super.create();
		
		var bg:FunkinSprite = new FunkinSprite().loadTexture('menuBG');
		bg.setGraphicSize(bg.width * 1.1);
		bg.scrollFactor.set(.1, .1);
		bg.updateHitbox();
		bg.screenCenter();
		add(bg);
		
		var watermark:FlxText = new FlxText(10, FlxG.height + 8, FlxG.width, 'funkin\' mess ${Main.engineVersion}\nengine by emi3', 20);
		watermark.setFormat(Paths.font('vcr.ttf'), 18, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		watermark.updateHitbox();
		watermark.y -= watermark.height;
		watermark.borderSize = 1.25;
		watermark.scrollFactor.set();
		
		var i:Int = 0;
		var buttonSpacing:Float = 152;
		var buttons:Array<String> = ['campaign', 'freeplay', 'mods', 'options', 'credits'];
		for (buttonName in buttons) {
			var button:FunkinSprite = new FunkinSprite(FlxG.width * .5, FlxG.height * .5 + (i - buttons.length * .5 + .5) * buttonSpacing).loadAtlas('mainmenu/button-${buttonName}');
			button.animation.addByPrefix('unselected', '${buttonName} unselected', 24, true);
			button.animation.addByPrefix('selected', '${buttonName} selected', 24, true);
			button.playAnimation('unselected', true);
			button.scrollFactor.set(.4, .4);
			menuButtons.push(button);
			add(button);
			button.updateHitbox();
			button.setOffset(button.width * .5, button.height * .5);
			i ++;
		}
		
		add(watermark);
		FlxG.camera.target = target = new FlxObject();
		FlxG.camera.followLerp = 9 / 60;
		target.x = FlxG.width * .5;
		select();
	}
	
	override public function update(elapsed:Float) {
		super.update(elapsed);
		if (FlxG.keys.justPressed.UP) select(-1);
		if (FlxG.keys.justPressed.DOWN) select(1);
	}
	
	public function select(mod:Int = 0) {
		FlxG.sound.play(Paths.sound('scrollMenu'), .8);
		
		var button:FunkinSprite = menuButtons[curSelected];
		button.playAnimation('unselected', true);
		button.updateHitbox();
		button.setOffset(button.width * .5, button.height * .5);
		
		curSelected = FlxMath.wrap(curSelected + mod, 0, menuButtons.length - 1);
		button = menuButtons[curSelected];
		button.playAnimation('selected', true);
		button.updateHitbox();
		button.setOffset(button.width * .5, button.height * .5);
		
		target.x = button.x;
		target.y = button.y;
	}
}