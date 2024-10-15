function create() {
	basicBG = new FunkinSprite().loadTexture('bg');
	basicBG.setPosition(-basicBG.width * .5, (FlxG.height - basicBG.height) * .5 + 75);
	basicBG.scrollFactor.set(.95, .95);
	basicBG.scale.set(2.25, 2.25);
	add(basicBG);
}