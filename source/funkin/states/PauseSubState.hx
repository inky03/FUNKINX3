package funkin.states;

import funkin.objects.ui.*;

class PauseSubState extends FunkinState {
	public var items:TextItemGroup;
	
	public var playState:PlayState = null;
	
	public override function new(?playState:PlayState) {
		super();
		this.bgColor = 0x80000000;
		this.playState = playState;
	}
	
	public override function create() {
		super.create();
		
		items = new TextItemGroup();
		items.addItem(new TextItem('Resume', function() close()));
		items.addItem(new TextItem('Restart', function() playState?.restartSong()));
		items.addItem(new TextItem('Exit to Menu', function() FlxG.switchState(FreeplayState.new)));
		items.screenCenter(Y);
		items.select();
		add(items);
		
		items.x = -items.width;
		FlxTween.tween(items, {x: 75}, .35, {ease: FlxEase.expoOut});
		
		camera = FunkinCamera.topCamera;
	}
	
	public override function update(elapsed:Float):Void {
		super.update(elapsed);
		
		if (FlxG.keys.justPressed.UP) items.select(-1);
		if (FlxG.keys.justPressed.DOWN) items.select(1);
		if (FlxG.keys.justPressed.ENTER) items.confirm();
	}
}