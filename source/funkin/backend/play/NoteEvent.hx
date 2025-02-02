package funkin.backend.play;

import funkin.states.PlayState;
import funkin.objects.Character;
import funkin.objects.play.Note;
import funkin.objects.play.Lane;
import funkin.backend.play.Scoring;
import funkin.objects.play.Strumline;

@:structInit class NoteEvent {
	public var note:Note;
	public var lane:Lane;
	public var receptor:Receptor;
	public var type:NoteEventType;
	public var strumline:Strumline;
	public var cancelled:Bool = false;
	public var animSuffix:String = '';

	public var spark:NoteSpark = null;
	public var splash:NoteSplash = null;
	public var scoring:Scoring.Score = null;
	public var scoreHandler:ScoreHandler = null;
	public var targetCharacter:ICharacter = null;

	public var perfect:Bool = false; // release event
	public var doSpark:Bool = false; // many vars...
	public var doSplash:Bool = false;
	public var playSound:Bool = false;
	public var applyRating:Bool = false;
	public var playAnimation:Bool = true;
	public var animateReceptor:Bool = true;

	public function cancel() cancelled = true;
	public function dispatch() { // hahaaa
		if (cancelled) return;
		var game:PlayState;
		if (Std.isOfType(FlxG.state, PlayState)) {
			game = cast FlxG.state;
			scoreHandler ??= game.scoring;
		} else {
			throw(new haxe.Exception('note event can\'t be dispatched outside of PlayState!!'));
			return;
		}
		switch (type) {
			case HIT:
				if (game.genericVocals != null)
					game.genericVocals.volume = 1;
				if (targetCharacter != null)
					targetCharacter.volume = 1;

				note.hitTime = lane.conductorInUse.songPosition;
				if (!note.isHoldPiece) {
					// if (lane.heldNote != null)
					// 	lane.hitSustainsOf(lane.heldNote);
					lane.heldNote = note;

					if (playSound)
						game.hitsound.play(true);
					
					if (applyRating) {
						scoring ??= scoreHandler?.judgeNoteHit(note, (lane.cpu ? 0 : note.msTime - lane.conductorInUse.songPosition));
						var rating:FunkinSprite = game.popRating(scoring.rating);
						rating.velocity.y = -FlxG.random.int(140, 175);
						rating.velocity.x = FlxG.random.int(0, 10);
						rating.acceleration.y = 550;
						applyExtraWindow(6);
						
						game.totalHits ++;
						game.totalNotes ++;
						game.health += note.healthGain * scoring.healthMod;
						if (scoreHandler != null) {
							scoreHandler.countRating(scoring.rating);
							note.score = scoring;
							
							scoreHandler.score += scoring.score;
							scoreHandler.addMod(scoring.accuracyMod);
							if (scoring.hitWindow != null && scoring.hitWindow.breaksCombo) {
								scoreHandler.combo = 0; // maybe add the ghost note here?
							} else {
								scoreHandler.combo ++;
							}
						}
						
						game.updateScoreText();
					}
					
					if (doSplash && (scoring.hitWindow == null || scoring.hitWindow.splash))
						splash = lane.splash();
				}
				
				if (playAnimation && targetCharacter != null) {
					var anim:String = 'sing${game.singAnimations[note.noteData]}';
					var suffixAnim:String = anim + targetCharacter.animSuffix;
					if (targetCharacter.animationExists(suffixAnim)) {
						if (!note.isHoldPiece)
							targetCharacter.playAnimationSoft(suffixAnim, true);
						targetCharacter.timeAnimSteps();
					}
				}

				if (animateReceptor) lane.receptor.playAnimation('confirm', true);
				if (!note.isHoldPiece) {
					if (note.msLength > 0) {
						lane.held = true;
						for (child in note.children) {
							child.canHit = true;
							lane.updateNote(child);
						}
					} else if (!lane.cpu && animateReceptor) {
						lane.receptor.grayBeat = note.beatTime + 1;
					}
				}
			case HELD | RELEASED:
				var perfectRelease:Bool = true;
				final released:Bool = (type == RELEASED);
				final songPos:Float = lane.conductorInUse.songPosition;
				perfect = (released && songPos >= note.endMs - Scoring.holdLeniencyMS);
				if (applyRating) {
					perfectRelease = perfect;
				}
				/*   ... ill do this later
				if (applyRating) {
					if (note.isHoldPiece && note.endMs > note.msTime) {
						var prevHitTime:Float;
						if (!note.held && note.hitTime <= note.msTime + Scoring.holdLeniencyMS)
							prevHitTime = note.msTime;
						else
							prevHitTime = Math.max(note.hitTime, note.msTime);

						perfectRelease = (released && songPos >= note.endMs - Scoring.holdLeniencyMS);
						var nextHitTime:Float;
						if (perfectRelease)
							nextHitTime = note.endMs;
						else
							nextHitTime = Math.min(songPos, note.endMs);
						if (!note.held) trace('started hitting ${Math.round(note.msTime)} -> ${Math.round(prevHitTime)} / ${Math.round(note.endMs)}');
						if (released) trace('released ${Math.round(nextHitTime)} / ${Math.round(note.endMs)} (last : ${Math.round(prevHitTime)})');

						final secondDiff:Float = Math.max(0, (nextHitTime - prevHitTime) * .001);
						final scoreGain:Float = game.scoring.holdScorePerSecond * secondDiff;
						scoring ??= {score: scoreGain, healthMod: secondDiff};
						note.hitTime = nextHitTime;
					}
					if (scoring != null) {
						game.health += scoring.healthMod * note.healthGainPerSecond;
						game.score += scoring.score;
						game.updateRating();
					}
				} else {
					note.hitTime = songPos;
				} */
				if (released && note.isHoldTail) {
					if (lane.held && (lane.heldNote == null || lane.heldNote == note.parent)) {
						lane.heldNote = null;
						lane.held = false;
						if (!lane.cpu && animateReceptor)
							lane.receptor.playAnimation('press', true);
					}
					if (perfectRelease) {
						if (doSpark)
							spark = lane.spark();
						if (playSound)
							FunkinSound.playOnce(Paths.sound('gameplay/hitsounds/hitsoundTail'), .7);
					} else {
						if (playSound)
							FunkinSound.playOnce(Paths.sound('gameplay/hitsounds/hitsoundFail'), .7);
					}
				}
				note.held = true;
			case GHOST:
				if (animateReceptor)
					lane.receptor.playAnimation('press', true);
				if (playSound) {
					FunkinSound.playOnce(Paths.sound('gameplay/hitsounds/miss${FlxG.random.int(1, 3)}'), FlxG.random.float(0.25, 0.3));
					FunkinSound.playOnce(Paths.sound('gameplay/hitsounds/hitsoundFail'), .7);
				}
				if (playAnimation && targetCharacter != null) {
					targetCharacter.specialAnim = false;
					targetCharacter.playAnimationSteps('sing${game.singAnimations[lane.noteData]}miss', true);
				}

				applyExtraWindow(15);
				if (applyRating) {
					game.score -= 10;
					game.health -= .01;
					game.updateScoreText();
				}
			case LOST:
				if (game.genericVocals != null)
					game.genericVocals.volume = 0;
				if (targetCharacter != null) {
					targetCharacter.volume = 0;
					if (playAnimation) {
						targetCharacter.specialAnim = false;
						targetCharacter.playAnimationSteps('sing${game.singAnimations[note.noteData]}miss', true);
					}
				}
				
				if (playSound)
					FunkinSound.playOnce(Paths.sound('gameplay/hitsounds/miss${FlxG.random.int(1, 3)}'), FlxG.random.float(0.5, 0.6));

				if (applyRating) {
					scoring ??= scoreHandler?.judgeNoteMiss(note);
					var rating:FunkinSprite = game.popRating('sadmiss');
					rating.velocity.y = -FlxG.random.int(80, 95);
					rating.velocity.x = FlxG.random.int(-6, 6);
					rating.acceleration.y = 240;
					
					if (scoreHandler != null) {
						game.totalNotes ++;
						scoreHandler.combo = 0;
						scoreHandler.misses ++;
						scoreHandler.score += scoring.score;
						scoreHandler.addMod(scoring.accuracyMod);
					}
					
					game.health -= note.healthLoss * scoring.healthMod;
					
					game.updateScoreText();
				}
			default:
		}
	}
	function applyExtraWindow(window:Float) {
		@:privateAccess {
			var extraWin:Float = Math.min(lane.extraWindow + window, 200);
			if (strumline != null) {
				for (lane in strumline.lanes)
					lane.extraWindow = extraWin;
			} else {
				lane.extraWindow = extraWin;
			}
		}
	}
}

enum NoteEventType {
	SPAWNED;
	DESPAWNED;

	HIT;
	HELD;
	RELEASED;

	LOST;
	GHOST;
}