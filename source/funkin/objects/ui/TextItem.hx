package funkin.objects.ui;

class TextItem extends FunkinSpriteGroup {
	public var highlighted:Bool = false;
	public var onSelected:Void -> Void;
	public var selected:Bool = false;
	
	public var startX:Float = 0;
	public var startY:Float = 0;
	
	public var text:Alphabet;
	
	public function new(name:String, ?func:Void -> Void, scale:Float = .75) {
		super();
		
		add(text = new Alphabet(name));
		scaleTo(scale, scale);
		
		this.onSelected = func;
		
		highlight(false);
	}
	
	public function confirm():Void {
		if (onSelected != null)
			onSelected();
	}
	
	public function highlight(on:Bool):Void {
		highlighted = on;
		
		if (on) {
			text.color = 0xffffcc66;
			alpha = 1;
		} else {
			text.color = FlxColor.WHITE;
			alpha = .65;
		}
	}
	
	function scaleTo(x:Float = 1, y:Float = 1):Void {
		text.scaleTo(x, y);
	}
}