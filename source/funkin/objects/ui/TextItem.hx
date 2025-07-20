package funkin.objects.ui;

class TextItem extends FunkinSpriteGroup {
	public var onSelected:Void -> Void;
	
	public var text:Alphabet;
	
	public function new(name:String, ?func:Void -> Void) {
		super();
		
		text = new Alphabet(name);
		text.scaleTo(.75, .75);
		add(text);
		
		onSelected = func;
		
		highlight(false);
	}
	
	public function confirm():Void {
		if (onSelected != null)
			onSelected();
	}
	
	public function highlight(on:Bool):Void {
		if (on) {
			text.color = 0xffffcc66;
			text.alpha = 1;
		} else {
			text.color = FlxColor.WHITE;
			text.alpha = .65;
		}
	}
}