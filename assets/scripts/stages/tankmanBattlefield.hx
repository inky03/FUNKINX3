import flixel.group.FlxTypedSpriteGroup;
import flixel.effects.FlxFlicker;
import flixel.math.FlxAngle;
import funkin.backend.play.Chart;

var picoStrumline:Strumline;

var tankRolling:StageProp;
var tankAngle:Float = FlxG.random.int(-90, 45);
var tankSpeed:Float = FlxG.random.float(5, 7);
var tankMoving:Bool = false;
var tankX:Float = 400;

var tankmanSpriteGroup:FlxTypedSpriteGroup;

function createPost() {
	if (player3.character == 'pico-speaker') {
		var picoSong:Chart = Chart.loadChart(PlayState.chart.path, 'picospeaker');
		picoStrumline = new Strumline(4);
		picoStrumline.cpu = true;
		picoStrumline.noteEvent.add(picoNoteEvent);
		for (lane in picoStrumline.lanes.members) lane.spawnRadius = 3000;
		
		for (i => note in picoSong.notes) {
			note.setVar('isTank', FlxG.random.bool(100 / 8)); //100 / 16); too low
			picoStrumline.queueNote(note);
		}
	}
}

function setupStage(id:String, stage:Stage) {
	var clouds:StageProp = stage.props['clouds'];
	clouds.velocity.x = FlxG.random.float(5, 15);
	clouds.x = FlxG.random.int(-700, -100);
	clouds.y = FlxG.random.int(-20, 20);
	clouds.active = true;

	tankRolling = stage.props['tankRolling'];
	tankAngle = FlxG.random.int(-90, 45);
	tankSpeed = FlxG.random.float(5, 7);
	
	Paths.sparrowAtlas('tankmanKilled1', 'week7');
	tankmanSpriteGroup = new FlxTypedSpriteGroup();
	tankmanSpriteGroup.zIndex = 30;
	stage.add(tankmanSpriteGroup);
}

function update(elapsed:Float, paused:Bool, dead:Bool) {
	if (paused || dead) return;
	if (picoStrumline != null)
		picoStrumline.update(elapsed);
	moveTank(elapsed);
}

function updatePost(elapsed:Float, paused:Bool) {
	if (paused) return;
	for (tankman in tankmanSpriteGroup.members) {
		if (!tankman.alive) continue;
		if (tankman.currentAnimation == 'run') {
			var edgeX:Float = (tankman.flipX ? FlxG.width * 0.02 : FlxG.width * 0.74);
			var endingOffset:Float = tankman.extraData['endingOffset'];
			var strumTime:Float = tankman.extraData['strumTime'];
			var runSpeed:Float = tankman.extraData['runSpeed'];
			var dir:Int = (tankman.flipX ? 1 : -1);
			tankman.x = (edgeX - tankman.width * .5 - endingOffset * dir) + (conductor.songPosition - strumTime) * runSpeed * dir;
			
			if (conductor.songPosition >= strumTime)
				tankman.playAnimation('shot');
		} else if (tankman.currentAnimation == 'shot' && tankman.animation.curAnim.curFrame >= 10 && tankman.extraData['deathFlicker'] == null) {
			deathFlicker(tankman);
		}
	}
}

function moveTank(elapsed:Float) {
	var daAngleOffset:Float = 1;
	tankAngle += elapsed * tankSpeed;
	
	tankRolling.angle = tankAngle - 90 + 15;
	tankRolling.x = tankX + Math.cos(FlxAngle.asRadians((tankAngle * daAngleOffset) + 180)) * 1500;
	tankRolling.y = 1300 + Math.sin(FlxAngle.asRadians((tankAngle * daAngleOffset) + 180)) * 1100;
}

function deathFlicker(tankman:FunkinSprite) {
	tankman.extraData['deathFlicker'] = FlxFlicker.flicker(tankman, 0.3, 1 / 20, false, true, (_) -> {
		tankmanSpriteGroup.members.remove(tankman);
		tankman.destroy();
	});
}

function createTankman(y:Float, nextTime:Float, goingRight:Bool) {
	// trace('craete a tankman here');
	var tankman:FunkinSprite = new FunkinSprite();
	tankman.loadAtlas('tankmanKilled1', 'week7');
	tankman.addAnimation('run', 'tankman running', 24, true);
	tankman.addAnimation('shot', 'John Shot ${FlxG.random.int(1, 2)}', 24, false);
	tankman.setAnimationOffset('shot', 150, 200);
	tankman.flipX = !goingRight;
	
	tankman.playAnimation('run');
	tankman.animation.curAnim.curFrame = FlxG.random.int(0, tankman.animation.curAnim.numFrames - 1);
	
	tankman.scale.set(.8, .8);
	tankman.updateHitbox();
	tankman.y = y;
	
	tankman.extraData['strumTime'] = nextTime;
	tankman.extraData['runSpeed'] = FlxG.random.float(0.6, 1);
	tankman.extraData['endingOffset'] = FlxG.random.float(50, 200);
	
	return tankman;
}

function opponentNoteEventPre(e:NoteEvent) {
	if (e.type == NoteEventType.HIT && e.note.noteKind == 'hehPrettyGood') {
		e.targetCharacter.playAnimationSteps('hehPrettyGood', true);
		e.targetCharacter.specialAnim = true;
	}
}
function picoNoteEvent(e:NoteEvent) {
	switch (e.type) {
		case NoteEventType.SPAWNED:
			if (e.note.extraData['isTank']) {
				var nextTime:Float = e.note.msTime;
				var goingRight:Bool = (e.note.noteData == 3 ? false : true);
				var yPos:Float = 250 + FlxG.random.int(50, 100);
				tankmanSpriteGroup.add(createTankman(yPos, nextTime, goingRight)); // todo: recycling
			}
		case NoteEventType.HIT:
			var dir:Int = e.note.noteData + 1;
			if (dir == 4) dir -= FlxG.random.int(0, 1);
			else dir += FlxG.random.int(0, 1);
			
			player3.playAnimationSteps('shoot$dir', true);
	}
	e.dispatch();
}