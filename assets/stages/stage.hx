function createPost() {
	var stageBack = new FunkinSprite().loadTexture('stageback');
	stageBack.setPosition(-1200, -200);
	stageBack.scrollFactor.set(.9, .9);
	addBG(stageBack);

	var stageFront = new FunkinSprite().loadTexture('stagefront');
	stageFront.setPosition(-1250, 550);
	stageFront.scrollFactor.set(.9, .9);
	addBG(stageFront);

	var stageCurtains = new FunkinSprite().loadTexture('stagecurtains');
	stageCurtains.setPosition(-1250, -300);
	stageCurtains.scale.set(.9, .9);
	stageCurtains.scrollFactor.set(1.3, 1.3);
	stageCurtains.updateHitbox();
	add(stageCurtains);
}