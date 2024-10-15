function create() {
	var stageBack = new FunkinSprite().loadTexture('stageback');
	stageBack.setPosition(-1200, -200);
	stageBack.scrollFactor.set(.9, .9);
	add(stageBack);

	var stageFront = new FunkinSprite().loadTexture('stagefront');
	stageFront.setPosition(-1250, 550);
	stageFront.scrollFactor.set(.9, .9);
	add(stageFront);

	var stageCurtains = new FunkinSprite().loadTexture('stagecurtains');
	stageCurtains.setPosition(-1250, -300);
	stageCurtains.scale.set(.9, .9);
	stageCurtains.scrollFactor.set(1.3, 1.3);
	stageCurtains.updateHitbox();
	add(stageCurtains);
}

function createPost() {
	var bf = state.player1;
	var dad = state.player2;
	var gf = state.player3;

	/*bf.setPosition(50,350);
	dad.setPosition(-600,0);
	gf.setPosition(-323,0);
	state.defaultCamZoom = state.camGame.zoom = 0.9;*/
}