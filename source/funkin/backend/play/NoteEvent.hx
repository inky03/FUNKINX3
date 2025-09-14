package funkin.backend.play;

import funkin.states.PlayState;
import funkin.objects.Character;
import funkin.objects.play.Note;
import funkin.objects.play.Lane;
import funkin.objects.play.Strumline;
import funkin.backend.play.ScoreSystem;
import funkin.backend.play.ScoreHandler;

using StringTools;

@:structInit class NoteEvent implements IPlayEvent { // TODO: EVENT RECYCLER
	public var type(default, null):NoteEventType;
	public var cancelled:Bool = false;
	
	public var note:Note;
	public var lane:Lane;
	public var receptor:Receptor;
	public var strumline:Strumline;
	public var animSuffix:String = '';
	public var songPosition:Float = 0;
	public var holdDelta:Float = 0;

	public var spark:NoteSpark = null;
	public var splash:NoteSplash = null;
	public var score:Score = null;
	public var scoring(get, set):Score;
	public var scoreHandler:ScoreHandler = null;

	public var perfect:Bool = false; // release event
	public var doSpark:Bool = false; // many vars...
	public var doSplash:Bool = false;
	public var playSound:Bool = false;
	public var popCover:Bool = true;
	public var popRating:Bool = true;
	public var applyHealth:Bool = false;
	public var applyRating:Bool = false;
	public var playAnimation:Bool = true;
	public var animateReceptor:Bool = true;
	public var singAnimation:Null<String> = null;
	public var targetCharacter:ICharacter = null;
	
	var game:PlayState = null;
	var inGame:Bool = false;
	
	public function cancel() cancelled = true;
	public inline function setup() {
		inGame = Std.isOfType(FlxG.state, PlayState);
		if (inGame) {
			game = cast FlxG.state;
			scoreHandler ??= game.scoring;
		}
		
		targetCharacter ??= lane.character;
		singAnimation ??= lane.getSingAnimation();
	}
	public function dispatch() { // hahaaa
		if (cancelled) return;
		
		switch (type) {
			case HIT:
				if (game.genericVocals != null)
					game.genericVocals.volume = 1;
				if (targetCharacter != null) {
					targetCharacter.volume = 1;
					targetCharacter.held = true;
				}

				note.hitTime = note.holdTime = songPosition;

				if (playSound)
					game.hitsound.play(true);
				
				if (applyRating) {
					applyExtraWindow(6);
					score ??= scoreHandler?.judgeNoteHit(note, note.msTime - songPosition);
					
					if (inGame) {
						if (popRating) {
							var rating:FunkinSprite = game.popRating('gameplay/funkin/${score.rating}');
							rating.velocity.y = -FlxG.random.int(140, 175);
							rating.velocity.x = FlxG.random.int(0, 10);
							rating.acceleration.y = 550;
						}
						
						if (applyHealth)
							game.health += note.healthGain * score.healthMod;
					}
					
					applyScore(scoreHandler, score, game);
					note.score = score;
				}
				
				if (doSplash && (score?.hitWindow == null || score.hitWindow.splash))
					splash = lane.splash(note);
				
				if (playAnimation && targetCharacter != null) {
					var suffixAnim:String = '$singAnimation$animSuffix';
					if (targetCharacter.animationExists(suffixAnim + targetCharacter.animSuffix))
						targetCharacter.playAnimationSteps(suffixAnim, true);
				}

				if (animateReceptor)
					lane.receptor.playAnimation('confirm', true);
				
				if (note.isHoldNote) {
					lane.held = true;
					lane.heldNote = note;
					if (popCover) spark = lane.popCover(note);
				} else if (animateReceptor && !lane.cpu) {
					lane.receptor.grayBeat = note.beatTime + .5;
				}
			case PRESSED:
				lane.pressed = true;
				
				if (note != null) {
					lane.hitNote(note, true, songPosition);
				} else {
					lane.ghostTapped(songPosition);
				}
			case HELD | RELEASED:
				final released:Bool = (type == RELEASED);
				
				if (released && note == null) {
					lane.held = false;
					lane.pressed = false;
					
					if (animateReceptor && !lane.cpu)
						receptor.playAnimation('static');
					
					if (targetCharacter != null) {
						var canUnhold:Bool = true;
						
						if (strumline != null) {
							for (lane in strumline.lanes)
								canUnhold = canUnhold && !lane.pressed;
						}
						
						if (canUnhold)
							targetCharacter.held = false;
					}
					
					return;
				}
				
				var perfectRelease:Bool = true;
				final songPos:Float = songPosition;
				
				perfect = (released && songPos >= note.endMs - scoreHandler.system.holdLeniencyMS);
				
				if (applyRating && scoreHandler.system.holdScoring) {
					perfectRelease = perfect;
					
					var prevHitTime:Float;
					if (!note.held && note.holdTime <= note.msTime + scoreHandler.system.holdLeniencyMS) {
						prevHitTime = note.msTime;
					} else {
						prevHitTime = Math.max(note.holdTime, note.msTime);
					}
					
					var nextHitTime:Float;
					if (perfectRelease) {
						nextHitTime = note.endMs;
					} else {
						nextHitTime = Math.max(Math.min(songPos, note.endMs), prevHitTime);
					}
					
					holdDelta = Math.max(0, nextHitTime - prevHitTime);
					
					final secondDiff:Float = holdDelta * .001;
					score ??= {score: 0, healthMod: secondDiff};
					
					if (scoreHandler != null)
						score.score = scoreHandler.system.holdScorePerSecond * secondDiff;
					
					if (inGame && applyRating && applyHealth)
						game.health += (score.healthMod ?? 1) * note.healthGainPerSecond;
					
					applyScore(scoreHandler, score, game);
					
					if (!released)
						note.held = true;
					note.holdTime = nextHitTime;
				}
				
				if (playAnimation && targetCharacter != null) {
					var suffixAnim:String = '$singAnimation$animSuffix${targetCharacter.animSuffix}';
					if (targetCharacter.currentAnimation == suffixAnim || targetCharacter.animationIsLooping(suffixAnim))
						targetCharacter.timeAnimSteps();
				}
				
				if (released && note.isHoldNote) {
					note.consumed = true;
					
					if (lane.heldNote == note) {
						lane.held = false;
						lane.heldNote = null;
						if (animateReceptor)
							lane.receptor.playAnimation(lane.cpu ? 'static' : 'press');
					}
					
					if (perfectRelease) {
						if (popCover) spark = lane.spark(note, doSpark);
						if (playSound)
							FunkinSound.playOnce(Paths.sound('gameplay/hitsounds/hitsoundTail'), .7);
					} else {
						if (popCover) spark = lane.spark(note, false);
						if (playSound)
							FunkinSound.playOnce(Paths.sound('gameplay/hitsounds/hitsoundFail'), .7);
					}
					
					if (lane.cpu && targetCharacter != null)
						targetCharacter.held = false;
					
					note.held = false;
					lane.killNote(note);
				}
			case GHOST:
				if (animateReceptor)
					lane.receptor.playAnimation('press', true);
				if (playSound) {
					FunkinSound.playOnce(Paths.sound('gameplay/hitsounds/miss${FlxG.random.int(1, 3)}'), FlxG.random.float(0.25, 0.3));
					FunkinSound.playOnce(Paths.sound('gameplay/hitsounds/hitsoundFail'), .7);
				}
				if (playAnimation && targetCharacter != null) {
					targetCharacter.specialAnim = false;
					targetCharacter.playAnimationSteps('${singAnimation}miss', true);
				}
				
				applyExtraWindow(15);
				if (applyRating) {
					score ??= scoreHandler?.judgeNoteGhost();
					
					if (inGame && applyHealth)
						game.health += (score.healthMod ?? -.01);
				}
				
				applyScore(scoreHandler, score, game);
			case LOST:
				note.multAlpha *= .3;
				
				if (inGame && game.genericVocals != null)
					game.genericVocals.volume = 0;
				
				if (targetCharacter != null) {
					targetCharacter.volume = 0;
					if (playAnimation)
						targetCharacter.playAnimationSteps('${singAnimation}miss', true);
				}
				
				if (playSound)
					FunkinSound.playOnce(Paths.sound('gameplay/hitsounds/miss${FlxG.random.int(1, 3)}'), FlxG.random.float(0.5, 0.6));

				if (applyRating) {
					score ??= scoreHandler?.judgeNoteMiss(note);
					
					if (inGame) {
						if (popRating) {
							var rating:FunkinSprite = game.popRating('gameplay/funkin/sadmiss');
							rating.velocity.y = -FlxG.random.int(80, 95);
							rating.velocity.x = FlxG.random.int(-6, 6);
							rating.acceleration.y = 240;
						}
						
						if (applyHealth)
							game.health -= note.healthLoss * (score.healthMod ?? 1);
					}
					
					applyScore(scoreHandler, score, game);
				}
			default:
		}
	}
	inline function applyScore(handler:ScoreHandler, score:Score, playState:PlayState) {
		if (handler == null || score == null || !applyRating) return;
		
		if (playState != null) {
			playState.totalNotes += score.hits + score.misses;
			playState.totalHits += score.hits;
		}
		
		handler.applyScore(score);
		playState?.updateScoreText();
	}
	inline function applyExtraWindow(window:Float) {
		var extraWin:Float = Math.min(lane.extraWindow + window, 200);
		if (strumline != null) {
			for (lane in strumline.lanes)
				lane.extraWindow = extraWin;
		} else {
			lane.extraWindow = extraWin;
		}
	}
	
	function get_scoring():Score {
		return score;
	}
	function set_scoring(now:Score):Score {
		return score = now;
	}
}

enum abstract NoteEventType(String) to String {
	var SPAWNED = 'spawned';
	var DESPAWNED = 'despawned';

	var HIT = 'hit';
	var HELD = 'held';
	var PRESSED = 'pressed';
	var RELEASED = 'released';

	var LOST = 'lost';
	var GHOST = 'ghost';
}