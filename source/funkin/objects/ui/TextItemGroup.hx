package funkin.objects.ui;

class TextItemGroup extends FunkinTypedSpriteGroup<TextItem> {
	public var itemPadding:Float = 25;
	public var selection:Int = 0;
	
	public function new() {
		super();
	}
	
	public function addItem(item:TextItem):TextItem {
		add(item);
		repositionItems();
		
		return item;
	}
	
	public function repositionItems():Void {
		var yy:Float = y;
		
		for (item in members) {
			if (item == null || !item.exists) continue;
			
			item.y = yy;
			yy += item.height + itemPadding;
		}
	}
	
	public function confirm():Void {
		var curOption:TextItem = members[selection];
		if (curOption != null) {
			curOption.confirm();
		}
	}
	
	public function select(mod:Int = 0):Void {
		if (length == 0) return;
		
		if (mod != 0) FunkinSound.playOnce(Paths.sound('scrollMenu'), .8);
		
		var prevOption:TextItem = members[selection];
		if (prevOption != null) {
			prevOption.highlight(false);
		}
		
		selection = FlxMath.wrap(selection + mod, 0, length - 1);
		
		var curOption:TextItem = members[selection];
		if (curOption != null) {
			curOption.highlight(true);
		}
	}
}