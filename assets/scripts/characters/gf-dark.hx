var lightChara:Character = new Character(x, y, 'gf', side, fallbackCharacter);

function update(elapsed:Float) {
	lightChara.update(elapsed);
}
function playAnimation(anim:String, forced:Bool = false, reversed:Bool = false, frame:Int = 0) {
	lightChara.playAnimation(flipAnim(anim), forced, reversed, frame);
}
function draw() {
	if (getVar('light') > 0) {
		lightChara.setPosition(x - 4.6, y - 15.4);
		lightChara.scale.set(scale.x, scale.y);
		lightChara.origin.set(origin.x, origin.y);
		lightChara.offset.set(offset.x, offset.y);
		lightChara.animate.anim.curSymbol.curFrame = animation.curAnim.curFrame;
		lightChara.update(0);
		lightChara.draw();
	}
	alpha = 1 - getVar('light');
}