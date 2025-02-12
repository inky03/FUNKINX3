package funkin.states;

class MainMenuState extends FunkinState {
	public var target:FlxObject;
	public var buttonNames:Array<String> = ['campaign', 'freeplay', 'mods', 'options', 'credits'];
	public var menuButtons:Array<FunkinSprite> = [];
	public var inputEnabled:Bool = true;
	public var bg:FunkinSprite;
	public var flashBG:FunkinSprite;
	public static var selection:Int = 0;
	public static var menuMusic:String = 'freakyMenu';
	
	override public function create() {
		super.create();
		
		playMusic(menuMusic);
		flashBG = new FunkinSprite().loadTexture('mainmenu/bgMagenta');
		bg = new FunkinSprite().loadTexture('mainmenu/bg');
		for (bg in [flashBG, bg]) {
			bg.setGraphicSize(bg.width * 1.1);
			bg.scrollFactor.set(.1, .1);
			bg.updateHitbox();
			bg.screenCenter();
			add(bg);
		}
		
		var buttonSpacing:Float = 152;
		for (i => buttonName in buttonNames) {
			var button:FunkinSprite = new FunkinSprite(FlxG.width * .5, FlxG.height * .5 + (i - buttonNames.length * .5 + .5) * buttonSpacing).loadAtlas('mainmenu/button-${buttonName}');
			button.addAnimation('unselected', '$buttonName unselected', 24, true);
			button.addAnimation('selected', '$buttonName selected', 24, true);
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
		FlxG.camera.snapToTarget();
		
		DiscordRPC.presence.details = 'In the main menu';
		DiscordRPC.dirty = true;

		Paths.clean();
	}

	public function returned(sub:FlxSubState) {
		playMusic(menuMusic);
		bg.visible = true;
		inputEnabled = true;
		for (button in menuButtons) {
			button.visible = true;
			button.alpha = 1;
		}
	}
	
	override public function update(elapsed:Float) {
		super.update(elapsed);
		if (!inputEnabled) return;
		
		if (FlxG.keys.justPressed.ESCAPE) {
			FlxG.switchState(() -> new TitleState(true));
			return;
		}
		
		if (FlxG.keys.justPressed.UP) select(-1);
		if (FlxG.keys.justPressed.DOWN) select(1);
		if (FlxG.keys.justPressed.ENTER) {
			inputEnabled = false;
			FunkinSound.playOnce(Paths.sound('confirmMenu'));
			FlxFlicker.flicker(bg, 1.1, 0.15, false);
			for (i => button in menuButtons) {
				if (i == selection) {
					FlxFlicker.flicker(button, 1, 0.06, true, false, (flicker:FlxFlicker) -> menuRedirect(selection));
				} else {
					FlxTween.tween(button, {alpha: 0}, 0.4, {ease: FlxEase.quadOut});
				}
			}
		}
	}
	
	public function menuRedirect(selection:Int) {
		switch (buttonNames[selection]) {
			case 'options':
				FlxG.switchState(OptionsState.new);
			case 'mods':
				FlxG.switchState(ModMenuState.new);
			case 'freeplay':
				if (FlxG.keys.pressed.SHIFT) {
					openSubState(new FreeplaySubState());
				} else {
					FlxG.switchState(FreeplayState.new);
				}
			default:
				FlxG.resetState();
		}
	}
	
	public function select(mod:Int = 0) {
		if (mod != 0) FunkinSound.playOnce(Paths.sound('scrollMenu'), .8);
		
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