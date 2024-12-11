var wiggle:RuntimeShader;

function setupStage(id:String, stage:Stage) {
	wiggle = new RuntimeShader('wiggle');
	wiggle.setFloat('uSpeed', 2);
	wiggle.setFloat('uFrequency', 4);
	wiggle.setFloat('uWaveAmplitude', .017);
	
	stage.props['evilSchoolBG'].shader = wiggle;
	stage.props['evilSchoolFG'].shader = wiggle;
}

function update(elapsed:Float, paused:Bool, dead:Bool) {
	if (paused || dead) return;
	wiggle.setFloat('uTime', conductor.songPosition * .001);
}