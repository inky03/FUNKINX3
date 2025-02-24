var lightChara:Character = new Character(x, y, 'pico-playable', side, fallbackCharacter);

function update(elapsed:Float) {
	super.update(elapsed);
	lightChara.update(elapsed);
}
function playAnimation(anim:String, forced:Bool = false, reversed:Bool = false, frame:Int = 0) {
	super.playAnimation(anim, forced, reversed, frame);
	lightChara.playAnimation(flipAnim(anim), forced, reversed, frame);
}
function draw() {
	super.draw();
	lightChara.setPosition(x, y);
	lightChara.scale.set(scale.x, scale.y);
	lightChara.origin.set(origin.x, origin.y);
	lightChara.offset.set(offset.x, offset.y);
	lightChara.alpha = getVar('light');
	lightChara.draw();
}