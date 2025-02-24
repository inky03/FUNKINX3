import funkin.backend.DiscordRPC;

Paths.sound('Lights_Turn_On', 'week5');

function createPost() {
	conductorInUse.paused = true;
	horrorCutscene();
}
function horrorCutscene() {
	DiscordRPC.state = 'Watching cutscene';
	autoUpdateRPC = false;
	pauseDisabled = true;
	inputDisabled = true;
	
	camHUD.visible = camGame.visible = false;
	
	camFocusTarget.setPosition(400, -2050);
	camGame.snapToTarget();
	
	new FlxTimer().start(1, (_) -> {
		camGame.visible = true;
		
		FunkinSound.playOnce(Paths.sound('Lights_Turn_On', 'week5'));
		/*new FlxTimer().start(1, (_) -> {
			camGame.pauseFollowLerp = true;
			focusOnCharacter(player1.current);
			FlxTween.tween(camGame.scroll, {x: camFocusTarget.x - FlxG.width * .5, y: camFocusTarget.y - FlxG.height * .5}, 8, {ease: FlxEase.quadIn, onComplete: (_) -> camGame.pauseFollowLerp = false});
		});*/
		new FlxTimer().start(2, (_) -> {
			camHUD.alpha = 0;
			camHUD.visible = true;
			FlxTween.tween(camHUD, {alpha: 1}, 2, {ease: FlxEase.quadInOut});
			
			conductorInUse.paused = false;
			inputDisabled = false;
			pauseDisabled = false;
			autoUpdateRPC = true;
			refreshRPCDetails();
		});
	});
}