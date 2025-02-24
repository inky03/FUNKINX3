import funkin.backend.DiscordRPC;
import flixel.tweens.FlxEase;

var isErect:Bool = (PlayState.chart.audioSuffix == 'erect');
var cutscenePlayed:Bool = false;

if (isErect) {
	Paths.sound('santa_emotion', 'week5');
	Paths.sound('santa_shot_n_falls', 'week5');
	FunkinAnimate.cacheAnimate('christmas/santa_speaks_assets', 'week5');
	FunkinAnimate.cacheAnimate('christmas/parents_shoot_assets', 'week5');
}

function finishSong() {
	if (isErect && !cutscenePlayed) {
		playCutscene();
		return STOP;
	}
}
function playCutscene() {
	DiscordRPC.state = 'Watching cutscene';
	autoUpdateRPC = false;
	cutscenePlayed = true;
	inputDisabled = false;
	pauseDisabled = true;
	
	if (player2 != null) {
		var parentsShoot:FunkinSprite = new FunkinSprite().loadAnimate('christmas/parents_shoot_assets', 'week5');
		parentsShoot.setPosition(player2.x - 555, player2.y - 379);
		parentsShoot.x -= 3; // sorry but i liked the number
		parentsShoot.addAnimation('anim', 'parents whole scene');
		parentsShoot.playAnimation('anim');
		parentsShoot.zIndex = player2.zIndex;
		
		player2.visible = false;
		stage.insertZIndex(parentsShoot);
	}
	
	var santa:StageProp = stage.props.get('santa');
	var santaDies:FunkinSprite = new FunkinSprite().loadAnimate('christmas/santa_speaks_assets', 'week5');
	santaDies.setPosition(santa.x + 381, santa.y + 347);
	santaDies.addAnimation('anim', 'santa whole scene');
	santaDies.playAnimation('anim', true);
	santaDies.zIndex = santa.zIndex;
	santaDies.shader = santa.shader;
	
	santa.visible = false;
	stage.insertZIndex(santaDies);
	
	FunkinSound.playOnce(Paths.sound('santa_emotion', 'week5'), 1);
	
	// camjob
	FlxTween.cancelTweensOf(camGame);
	FlxTween.cancelTweensOf(camGame.scroll);
	
	var xO:Float = camGame.width * .5;
	var yO:Float = camGame.height * .5;
	camGame.pauseFollowLerp = camGame.pauseZoomLerp = true;
	FlxTween.tween(camGame, {zoom: .73}, 2, {ease: FlxEase.quadInOut});
	FlxTween.tween(camGame.scroll, {x: santaDies.x + 300 - xO, y: santaDies.y - yO}, 2.8, {ease: FlxEase.expoOut});
	
	new FlxTimer().start(2.8, (_) -> {
		FlxTween.tween(strumlineGroup, {alpha: 0}, 6, {ease: FlxEase.sineInOut});
		FlxTween.tween(camGame, {zoom: .79}, 9, {ease: FlxEase.quadInOut});
		FlxTween.tween(camGame.scroll, {x: santaDies.x + 150 - xO, y: santaDies.y - yO}, 9, {ease: FlxEase.quartInOut});
	});
	new FlxTimer().start(11.375, (_) -> FunkinSound.playOnce(Paths.sound('santa_shot_n_falls', 'week5'), 1));
	new FlxTimer().start(12.83, (_) -> {
		camGame.shake(0.005, 0.2);
		FlxTween.tween(camGame.scroll, {x: santaDies.x + 160 - xO, y: santaDies.y + 80 - yO}, 5, {ease: FlxEase.expoOut});
	});
	new FlxTimer().start(15, (_) -> camHUD.fade(0xFF000000, 1, false, null, true));
	new FlxTimer().start(16, (_) -> game.finishSong());
}