var fastCarCanDrive:Bool = false;

function setupStage(id:String, stage:Stage) {
	Paths.sound('carPass0', 'week4');
	Paths.sound('carPass1', 'week4');
	
	stage.characters.get('gf').current.idleSuffix = '-hairblowCar';
	
	// todo: whatever shader shit is in the base stage
	resetFastCar();
}

function stepHit()
	camGame.targetOffset.set(FlxG.random.float(-3, 3), FlxG.random.float(-3, 3));

function beatHit(beat:Int) {
	if (FlxG.random.bool(10) && fastCarCanDrive)
		fastCarDrive();
}

function resetFastCar() {
	var fastCar:StageProp = stage.props['fastCar'];
	if (fastCar == null)
		return;
	
	fastCar.active = true;

	fastCar.x = -12600;
	fastCar.y = FlxG.random.int(140, 250);
	fastCar.velocity.x = 0;
	fastCarCanDrive = true;
}

function fastCarDrive() {
	FlxG.sound.play(Paths.sound('carPass${FlxG.random.int(0, 1)}', 'week4'), .7);

	var fastCar:StageProp = stage.props['fastCar'];
	fastCar.velocity.x = (FlxG.random.int(170, 220) / FlxG.elapsed) * 3;
	fastCarCanDrive = false;
	new FlxTimer().start(2, () -> { resetFastCar(); });
}