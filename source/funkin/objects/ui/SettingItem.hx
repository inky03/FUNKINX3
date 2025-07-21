package funkin.objects.ui;

class CheckboxItem extends SettingItem {
	public var checkbox:Checkbox;
	
	public function new(name:String, ?save:String) {
		super(name, save);
		
		add(checkbox = new Checkbox(0, -30));
		checkbox.scale.set(.5, .5);
		checkbox.updateHitbox();
		
		text.x += 100;
		value ??= false;
		check(value, true);
	}
	
	public override function confirm():Void {
		setValue(value == false);
		check(value);
		
		super.confirm();
	}
	
	public function check(on:Bool, instant:Bool = false) {
		checkbox.check(on, instant);
	}
}

class Checkbox extends FunkinSprite {
	public function new(x:Float = 0, y:Float = 0) {
		super(x, y);
		
		loadAtlas('options/checkbox');
		addAnimation('select', 'checkbox select');
		addAnimation('unselect', 'checkbox unselect');
		setAnimationOffset('select', 12, 40);
		
		check(false, true);
		updateHitbox();
	}
	
	public function check(on:Bool, instant:Bool = false) {
		playAnimation(on ? 'select' : 'unselect', true);
		if (instant) finishAnimation();
	}
}

class SettingItem extends TextItem {
	public var value:Dynamic = null;
	
	public var save(default, set):String;
	
	public function new(name:String, ?save:String) {
		super(name);
		
		this.save = save;
	}
	
	public function getValue():Dynamic {
		return (save == null ? value : Reflect.getProperty(Options.data, save));
	}
	
	public function setValue(value:Dynamic):Void {
		if (save != null) Reflect.setProperty(Options.data, save, value);
		this.value = value;
	}
	
	function set_save(now:String):String {
		save = now;
		value = getValue();
		
		return now;
	}
}