package funkin.states;

import funkin.objects.ui.*;
import funkin.objects.ui.SettingItem;

class OptionsState extends FunkinState {
	public var bg:FunkinSprite;
	public var target:FlxObject;
	public var items:TextItemGroup;
	public var inputEnabled:Bool = true;
	
	public static var selection:Int = 0;
	
	override public function create() {
		super.create();
		
		playMusic(MainMenuState.menuMusic);
		
		bg = new FunkinSprite().loadTexture('mainmenu/bgMagenta');
		bg.setGraphicSize(bg.width * 1.1);
		bg.scrollFactor.set();
		bg.updateHitbox();
		bg.screenCenter();
		add(bg);
		
		items = new TextItemGroup();
		items.itemDrift = 12.5;
		add(items);
		
		items.addItem(new CheckboxItem('Downscroll', 'downscroll'));
		items.addItem(new CheckboxItem('Middlescroll', 'middlescroll'));
		items.addItem(new CheckboxItem('Ghost Tapping', 'ghostTapping'));
		items.addItem(new CheckboxItem('Extended Score Display', 'xtendScore'));
		items.select(selection, false);
		
		FlxG.camera.target = target = new FlxObject();
		FlxG.camera.followLerp = 9 / 60;
		select();
		FlxG.camera.snapToTarget();
		
		Main.showWatermark = true;
		
		DiscordRpc.presence.details = 'Navigating options';
		DiscordRpc.dirty = true;
	}
	
	override public function update(elapsed:Float) {
		super.update(elapsed);
		if (!inputEnabled) return;
		
		if (FlxG.keys.justPressed.UP) select(-1);
		if (FlxG.keys.justPressed.DOWN) select(1);
		if (FlxG.keys.justPressed.ENTER) items.confirm();
		if (FlxG.keys.justPressed.ESCAPE) FlxG.switchState(MainMenuState.new);
	}
	
	public function select(mod:Int = 0) {
		items.select(mod);
		
		if (items.selectedItem != null)
			target.setPosition(items.selectedItem.x + 400, items.selectedItem.getMidpoint().y);
		
		selection = items.selection;
	}
}