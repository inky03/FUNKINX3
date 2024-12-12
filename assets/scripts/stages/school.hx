function setupStage(id:String, stage:Stage) {
	if (stage.characters['dad']?.character == 'senpai-angry')
		stage.props['freaks'].idleSuffix = '-scared';
}