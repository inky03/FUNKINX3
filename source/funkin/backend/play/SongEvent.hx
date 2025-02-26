package funkin.backend.play;

import funkin.states.PlayState;
import funkin.states.GameOverSubState;
import funkin.objects.Character;
import funkin.objects.CharacterGroup;
import funkin.backend.scripting.HScript;

@:structInit class SongEvent implements IPlayEvent {
	public var type(default, null):SongEventType;
	public var cancelled:Bool = false;
	
	public var time:Null<Int> = null;
	public var sprite:FlxSprite = null;
	public var character:Character = null;
	public var chartEvent:Chart.ChartEvent = null;
	
	public var countdown:Null<String> = null;
	public var countdownSprite:FunkinSprite = null;
	
	public var subState:FunkinState = null;
	
	public function cancel() cancelled = true;
	public function dispatch() { // hahaaa
		if (!Std.isOfType(FlxG.state, PlayState)) {
			throw(new haxe.Exception('song event can\'t be dispatched outside of PlayState!!'));
			return;
		}
		var game:PlayState = cast FlxG.state;
		
		if (cancelled) {
			switch (type) {
				case START_COUNTDOWN:
					game.conductorInUse.paused = true;
					
				case SONG_START:
					game.conductorInUse.songPosition = 0;
					game.conductorInUse.paused = true;
					
				default:
			}
			return;
		}
		
		switch (type) {
			case START_COUNTDOWN:
				for (strumline in game.strumlineGroup)
					strumline.fadeIn();
			case TICK_COUNTDOWN:
				var folder:String = 'funkin';
				FunkinSound.playOnce(Paths.sound('gameplay/countdown/$folder/intro$countdown'));
				
				countdownSprite = game.popCountdown(countdown);
			
			case SONG_START:
				game.music.play(true);
				game.syncMusic(true, true);
				game.songStarted = true;
			case SONG_FINISH:
				if (HScript.stopped(game.hscripts.run('finishSong'))) {
					game.conductorInUse.paused = true;
				} else {
					FlxG.switchState(() -> new funkin.states.FreeplayState());
				}
				
			case STEP_HIT:
				game.stepHitEvent(time);
			case BEAT_HIT:
				game.beatHitEvent(time);
			case BAR_HIT:
				game.barHitEvent(time);
				
			case DEATH_FIRST:
				if (Std.isOfType(subState, GameOverSubState))
					cast(subState, GameOverSubState).firstDeathEvent();
			case DEATH_START:
				if (Std.isOfType(subState, GameOverSubState))
					cast(subState, GameOverSubState).startDeathEvent();
			case DEATH_CONFIRM:
				if (Std.isOfType(subState, GameOverSubState))
					cast(subState, GameOverSubState).confirmDeathEvent();
				
			case PUSH_EVENT:
				PlayStateEventHandler.pushEvent(chartEvent, game);
			case TRIGGER_EVENT:
				PlayStateEventHandler.triggerEvent(chartEvent, game);
				
			default:
		}
	}
}

enum abstract SongEventType(String) to String {
	var SONG_START = 'songStart';
	var SONG_FINISH = 'songFinish';
	
	var PUSH_EVENT = 'pushEvent';
	var TRIGGER_EVENT = 'triggerEvent';
	var CHANGE_SPOTLIGHT = 'changeSpotlight';
	
	var START_COUNTDOWN = 'startCountdown';
	var TICK_COUNTDOWN = 'tickCountdown';
	
	var DEATH_INIT = 'deathInit';
	var DEATH_FIRST = 'deathFirst';
	var DEATH_START = 'deathStart';
	var DEATH_CONFIRM = 'deathConfirm';
	
	var STEP_HIT = 'stepHit';
	var BEAT_HIT = 'beatHit';
	var BAR_HIT = 'barHit';
}

class PlayStateEventHandler {
	public static function pushEvent(chartEvent:Chart.ChartEvent, game:PlayState) {
		var params:Map<String, Dynamic> = chartEvent.params;
		var simple:Bool = game.simple;
		
		switch (chartEvent.name) {
			case 'PlayAnimation':
				if (simple) return;
				
				var focusChara:Null<CharacterGroup> = null;
				switch (params['target']) {
					case 'girlfriend', 'gf': focusChara = game.player3;
					case 'boyfriend', 'bf': focusChara = game.player1;
					case 'dad': focusChara = game.player2;
				}
				
				if (focusChara != null)
					focusChara.preloadAnimAsset(params['anim']);
		}
		
		game.events.push(chartEvent);
		game.hscripts.run('eventPushed', [chartEvent]);
	}
	
	public static function triggerEvent(chartEvent:Chart.ChartEvent, game:PlayState) {
		var params:Map<String, Dynamic> = chartEvent.params;
		var simple:Bool = game.simple;
		
		switch (chartEvent.name) {
			case 'FocusCamera':
				if (simple) return;
				
				var focusCharaInt:Int;
				var focusChara:Null<CharacterGroup> = null;
				if (params.exists('char')) {
					focusCharaInt = Util.parseInt(params['char']);
				} else {
					focusCharaInt = Util.parseInt(params['value']);
				}
				
				switch (focusCharaInt) {
					case 0: // player focus
						focusChara = game.player1;
					case 1: // opponent focus
						focusChara = game.player2;
					case 2: // gf focus
						focusChara = game.player3;
				}

				if (focusChara != null) {
					game.focusOnCharacter(focusChara.current);
				} else {
					game.camFocusTarget.x = 0;
					game.camFocusTarget.y = 0;
					game.spotlight = null;
				}
				if (params.exists('x')) game.camFocusTarget.x += Util.parseFloat(params['x']);
				if (params.exists('y')) game.camFocusTarget.y += Util.parseFloat(params['y']);
				
				FlxTween.cancelTweensOf(game.camGame.scroll);
				switch (params['ease']) {
					case 'CLASSIC' | null:
						game.camGame.pauseFollowLerp = false;
					case 'INSTANT':
						game.camGame.snapToTarget();
						game.camGame.pauseFollowLerp = false;
					default:
						var duration:Float = Util.parseFloat(params['duration'], 4) * game.conductorInUse.stepCrochet * .001;
						if (duration <= 0) {
							game.camGame.snapToTarget();
							game.camGame.pauseFollowLerp = false;
						} else {
							var easeFunction:Null<Float -> Float> = Reflect.field(FlxEase, params['ease'] ?? 'linear');
							if (easeFunction == null) {
								Log.warning('FocusCamera event: ease function invalid');
								easeFunction = FlxEase.linear;
							}
							game.camGame.pauseFollowLerp = true;
							FlxTween.tween(game.camGame.scroll, {x: game.camFocusTarget.x - FlxG.width * .5, y: game.camFocusTarget.y - FlxG.height * .5}, duration, {ease: easeFunction, onComplete: (_) -> {
								game.camGame.pauseFollowLerp = false;
							}});
						}
				}
			
			case 'ZoomCamera':
				if (simple) return;
				
				var targetZoom:Float = Util.parseFloat(params['zoom'], 1);
				var direct:Bool = (params['mode'] ?? 'direct' == 'direct');
				targetZoom *= (direct ? FlxCamera.defaultZoom : (game.stage?.zoom ?? 1));
				game.camGame.zoomTarget = targetZoom;
				FlxTween.cancelTweensOf(game.camGame, ['zoom']);
				switch (params['ease']) {
					case 'INSTANT':
						game.camGame.zoom = targetZoom;
						game.camGame.pauseZoomLerp = false;
					default:
						var duration:Float = Util.parseFloat(params['duration'], 4) * game.conductorInUse.stepCrochet * .001;
						if (duration <= 0) {
							game.camGame.zoom = targetZoom;
							game.camGame.pauseZoomLerp = false;
						} else {
							var easeFunction:Null<Float -> Float> = Reflect.field(FlxEase, params['ease'] ?? 'linear');
							if (easeFunction == null) {
								Log.warning('FocusCamera event: ease function invalid');
								easeFunction = FlxEase.linear;
							}
							game.camGame.pauseZoomLerp = true;
							FlxTween.tween(game.camGame, {zoom: targetZoom}, duration, {ease: easeFunction, onComplete: (_) -> {
								game.camGame.pauseZoomLerp = false;
							}});
						}
				}
			
			case 'SetCameraBop':
				var targetRate:Int = Util.parseInt(params['rate'], -1);
				var targetIntensity:Float = Util.parseFloat(params['intensity'], 1);
				
				game.hudZoomIntensity = targetIntensity * 2;
				game.camZoomIntensity = targetIntensity;
				game.camZoomRate = targetRate;
			
			case 'PlayAnimation':
				if (simple) return;
				
				var anim:String = params['anim'];
				var target:String = params['target'];
				var focus:FlxSprite = null;
				
				switch (target) {
					case 'dad' | 'opponent': focus = game.player2;
					case 'girlfriend' | 'gf': focus = game.player3;
					case 'boyfriend' | 'bf' | 'player': focus = game.player1;
					default: focus = game.stage?.getProp(target);
				}
				
				if (focus != null) {
					var forced:Bool = params['force'];
					
					if (Std.isOfType(focus, CharacterGroup)) {
						var chara:CharacterGroup = cast focus;
						if (chara.animationExists(anim)) {
							chara.playAnimation(anim, forced);
							chara.specialAnim = forced;
							chara.timeAnimSteps();
						}
					} else if (Std.isOfType(focus, FunkinSprite)) {
						var funk:FunkinSprite = cast focus;
						if (funk.animationExists(anim)) {
							funk.playAnimation(anim, forced);
						}
					}
				}
		}
		game.hscripts.run('eventTriggered', [chartEvent]);
	}
}