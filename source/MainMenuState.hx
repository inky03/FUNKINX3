package;

class MainMenuState extends MusicBeatState {
	public var target:FlxObject;
	public var buttonNames:Array<String> = ['campaign', 'freeplay', 'mods', 'options', 'credits'];
	public var menuButtons:Array<FunkinSprite> = [];
	public var inputEnabled:Bool = true;
	public var selection:Int = 0;
	
	override public function create() {
		super.create();
		
		var bg:FunkinSprite = new FunkinSprite().loadTexture('menuBG');
		bg.setGraphicSize(bg.width * 1.1);
		bg.scrollFactor.set(.1, .1);
		bg.updateHitbox();
		bg.screenCenter();
		add(bg);
		
		var buttonSpacing:Float = 152;
		for (i => buttonName in buttonNames) {
			var button:FunkinSprite = new FunkinSprite(FlxG.width * .5, FlxG.height * .5 + (i - buttonNames.length * .5 + .5) * buttonSpacing).loadAtlas('mainmenu/button-${buttonName}');
			button.animation.addByPrefix('unselected', '${buttonName} unselected', 24, true);
			button.animation.addByPrefix('selected', '${buttonName} selected', 24, true);
			button.playAnimation('unselected', true);
			button.scrollFactor.set(.4, .4);
			menuButtons.push(button);
			add(button);
			button.updateHitbox();
			button.setOffset(button.width * .5, button.height * .5);
		}
		
		FlxG.camera.target = target = new FlxObject();
		FlxG.camera.followLerp = 9 / 60;
		target.x = FlxG.width * .5;
		select();
		
		DiscordRPC.presence.details = 'In the main menu!';
		DiscordRPC.dirty = true;

		Paths.clean();
	}
	
	override public function update(elapsed:Float) {
		super.update(elapsed);
		DiscordRPC.update();
		if (!inputEnabled) return;
		
		if (FlxG.keys.justPressed.UP) select(-1);
		if (FlxG.keys.justPressed.DOWN) select(1);
		if (FlxG.keys.justPressed.ENTER) {
			inputEnabled = false;
			FlxG.sound.play(Paths.sound('confirmMenu'));
			
			new FlxTimer().start(1, (timer:FlxTimer) -> menuRedirect(selection));
		}
	}
	
	public function menuRedirect(selection:Int) {
		switch (buttonNames[selection]) {
			case 'freeplay':
				FlxG.switchState(() -> new FreeplayState());
			default:
				inputEnabled = true;
		}
	}
	
	public function select(mod:Int = 0) {
		if (mod != 0) FlxG.sound.play(Paths.sound('scrollMenu'), .8);
		
		var button:FunkinSprite = menuButtons[selection];
		button.playAnimation('unselected', true);
		button.updateHitbox();
		button.setOffset(button.width * .5, button.height * .5);
		
		selection = FlxMath.wrap(selection + mod, 0, menuButtons.length - 1);
		button = menuButtons[selection];
		button.playAnimation('selected', true);
		button.updateHitbox();
		button.setOffset(button.width * .5, button.height * .5);
		
		target.x = button.x;
		target.y = button.y;
	}
}