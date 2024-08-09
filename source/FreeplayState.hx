class FreeplayState extends MusicBeatState {
	override public function create() {
		super.create();
		
		var bg:FunkinSprite = new FunkinSprite().loadTexture('menuBGBlue');
		bg.setGraphicSize(bg.width * 1.1);
		bg.scrollFactor.set();
		bg.updateHitbox();
		bg.screenCenter();
		add(bg);
	}
}

class SongItem extends FlxSpriteGroup {
	public var text:Alphabet;
	public function new(x:Float = 0, y:Float = 0, name:String = 'unknown', icon:String = 'face') {
		super(x, y);
		text = new Alphabet(x, y, name);
	}
}