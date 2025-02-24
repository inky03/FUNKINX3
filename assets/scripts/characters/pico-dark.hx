var lightChara:Character = new Character(x, y, 'pico-playable', side, fallbackCharacter);

function update(elapsed:Float) {
	lightChara.update(elapsed);
}
function playAnimation(anim:String, forced:Bool = false, reversed:Bool = false, frame:Int = 0) {
	lightChara.playAnimation(flipAnim(anim), forced, reversed, frame);
}
function drawPost() {
	lightChara.setPosition(x, y);
	lightChara.scale.set(scale.x, scale.y);
	lightChara.origin.set(origin.x, origin.y);
	lightChara.offset.set(offset.x, offset.y);
	lightChara.alpha = getVar('light');
	lightChara.draw();
}