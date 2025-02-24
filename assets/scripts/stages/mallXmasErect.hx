function setupStage(id:String, stage:Stage) {
	var colorShader:RuntimeShader = new RuntimeShader('adjustColor');
	colorShader.setFloat('saturation', 20);
	colorShader.setFloat('hue', 5);
	stage.getProp('santa').shader = colorShader;
}