package funkin.objects.ui;

class TextItemGroup extends FunkinTypedSpriteGroup<TextItem> {
	public var itemPadding:Float = 25;
	public var itemDrift:Float = 0;
	public var selection:Int = 0;
	
	public var selectedItem(get, never):TextItem;
	
	public function new() {
		super();
	}
	
	public function addItem(item:TextItem):TextItem {
		add(item);
		repositionItems();
		
		return item;
	}
	
	public function repositionItems():Void {
		var xx:Float = 0;
		var yy:Float = 0;
		
		for (item in members) {
			if (item == null || !item.exists) continue;
			
			item.startY = yy;
			item.startX = xx;
			item.setPosition(x + xx, y + yy);
			
			xx += itemDrift;
			yy += item.text.height + itemPadding;
		}
	}
	
	public function confirm():Void {
		selectedItem?.confirm();
	}
	
	public function select(mod:Int = 0, sound:Bool = true):Void {
		if (length == 0) return;
		
		if (mod != 0 && sound) FunkinSound.playOnce(Paths.sound('scrollMenu'), .8);
		
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
	
	function get_selectedItem():TextItem {
		return members[selection];
	}
}