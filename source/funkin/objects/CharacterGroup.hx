package funkin.objects;

import flixel.util.FlxSignal;
import funkin.objects.Character;

using Lambda;

typedef CharacterOrString = flixel.util.typeLimit.OneOfTwo<Character, String>;
typedef CharacterOrGroup = flixel.util.typeLimit.OneOfTwo<Character, CharacterGroup>;

class CharacterGroup extends FunkinTypedSpriteGroup<Character> implements ICharacter { // TODO: implement interface so currently CharacterGroup type fields can be both group and character instead?
	public var onAnimationComplete:FlxTypedSignal<String -> Void> = new FlxTypedSignal();
	public var onAnimationFrame:FlxTypedSignal<Int -> Void> = new FlxTypedSignal();
	
	public var bop(default, set):Bool = true;
	public var side(default, set):CharacterSide;
	public var animReset(default, set):Float = 0;
	public var idleSuffix(default, set):String = '';
	public var animSuffix(default, set):String = '';
	public var specialAnim(default, set):Bool = false;
	public var conductorInUse(default, set):Conductor;
	public var stageCameraOffset(default, null):FlxCallbackPoint;
	public var onCharacterChanged:FlxTypedSignal<String -> Character -> Void> = new FlxTypedSignal();
	@:isVar public var cameraOffset(get, never):FlxPoint;
	
	public var volume(default, set):Float = 1;
	public var character(default, set):String;
	public var current(default, set):Character = null;
	
	@:isVar public var healthIcon(get, never):String;
	@:isVar public var currentAnimation(get, never):String;
	
	public var fallbackCharacter:Null<String>;
	var fallbackChara:Null<String>;
	var invisible:Float = .0001;
	var initialChara:Character;
	
	public function new(x:Float = 0, y:Float = 0, initialCharacter:String, side:CharacterSide = IDGAF, ?fallback:String) {
		super(x, y);
		this.side = side;
		fallbackChara = fallback;
		character = initialCharacter;
		conductorInUse = FunkinState.getCurrentConductor();
		stageCameraOffset = new FlxCallbackPoint(stageCamCallback);
	}
	override function initVars():Void {
		flixelType = SPRITEGROUP;
		
		offset = new FlxCallbackPoint(offsetCallback);
		origin = new FlxCallbackPoint(originCallback);
		scale = new FlxCallbackPoint(charScaleCallback);
		scrollFactor = new FlxCallbackPoint(scrollFactorCallback);
		
		scale.set(1, 1);
		scrollFactor.set(1, 1);
		
		initMotionVars();
	}
	public override function draw():Void {
		if (current != null && current.shader != shader)
			current.shader = shader;
		super.draw();
	}
	public override function destroy():Void {
		stageCameraOffset = flixel.util.FlxDestroyUtil.destroy(stageCameraOffset);
		super.destroy();
	}
	
	override function set_alpha(value:Float):Float {
		if (exists && current != null)
			current.alpha = Util.clamp(value, 0, 1);
		return alpha = value;
	}
	function set_side(newSide:CharacterSide) {
		for (chara in members) {
			if (chara == null) continue;
			chara.side = newSide;
		}
		return side = newSide;
	}
	function get_healthIcon():String {
		return current?.healthIcon;
	}
	function get_character():String {
		return current?.character;
	}
	function set_character(newChara:String):String {
		changeCharacter(newChara);
		return character = current?.character;
	}
	function set_current(newChara:Character):Character {
		if (current != null) {
			current.shader = null;
			current.alpha = invisible;
		}
		newChara ??= initialChara;
		if (newChara != null)
			newChara.alpha = alpha;
		onCharacterChanged.dispatch(newChara.character, newChara);
		return current = newChara;
	}
	function set_bop(value:Bool):Bool {
		for (chara in members) {
			if (chara == null) continue;
			chara.bop = value;
		}
		return specialAnim = value;
	}
	function set_animReset(value:Float):Float {
		if (current != null)
			current.animReset = value;
		return animReset = value;
	}
	function set_conductorInUse(value:Conductor):Conductor {
		for (chara in members) {
			if (chara == null) continue;
			chara.conductorInUse = value;
		}
		return conductorInUse = value;
	}
	function set_specialAnim(value:Bool):Bool {
		if (current != null)
			current.specialAnim = value;
		return specialAnim = value;
	}
	function get_volume():Float {
		return (current?.volume ?? 0);
	}
	function set_volume(value:Float):Float {
		if (current != null)
			current.volume = value;
		return value;
	}
	function set_idleSuffix(suffix:String):String {
		for (chara in members) {
			if (chara == null) continue;
			chara.idleSuffix = suffix;
		}
		return idleSuffix = suffix;
	}
	function set_animSuffix(suffix:String):String {
		for (chara in members) {
			if (chara == null) continue;
			chara.animSuffix = suffix;
		}
		return animSuffix = suffix;
	}
	function get_cameraOffset():FlxPoint {
		return (current?.cameraOffset ?? FlxPoint.get());
	}
	function get_currentAnimation():String {
		return (current?.currentAnimation);
	}
	override function set_zIndex(newZ:Int):Int {
		for (chara in members) {
			if (chara == null) continue;
			chara.zIndex = newZ;
		}
		return zIndex = newZ;
	}
	inline function stageCamCallback(offset:FlxPoint) {
		for (chara in members) {
			if (chara == null) continue;
			chara.stageCameraOffset.copyFrom(offset);
		}
	}
	inline function charScaleCallback(scale:FlxPoint) {
		for (chara in members) {
			if (chara == null) continue;
			chara.scale.set(scale.x * chara.scaleMultiplier, scale.y * chara.scaleMultiplier);
		}
	}
	public override function getMidpoint(?point:FlxPoint):FlxPoint {
		if (current != null)
			return current.getMidpoint(point);
		return super.getMidpoint(point);
	}
	public override function getGraphicMidpoint(?point:FlxPoint):FlxPoint {
		if (current != null)
			return current.getGraphicMidpoint(point);
		return super.getGraphicMidpoint(point);
	}
	
	public function findCharacter(toFind:CharacterOrString):Character {
		if (Std.isOfType(toFind, Character)) {
			var chara:Character = cast toFind;
			return (members.contains(chara) ? chara : null);
		} else {
			var name:String = cast toFind;
			return members.find((chara:Character) -> (chara != null && chara.character == name));
		}
	}
	public function hasCharacter(toFind:CharacterOrString):Bool {
		return (findCharacter(toFind) != null);
	}
	public function preloadCharacter(name:String, destroyFallback:Bool = true):Character {
		var char:Character = findCharacter(name);
		if (char != null)
			return char;
		
		var newChara:Character = new Character(0, 0, name, side, fallbackChara);
		if (hasCharacter(newChara.character)) {
			newChara.destroy();
			return null;
		}
		var off:FlxPoint = FlxPoint.get(stageCameraOffset?.x ?? 0, stageCameraOffset?.y ?? 0);
		newChara.scale.set(scale.x * newChara.scaleMultiplier, scale.y * newChara.scaleMultiplier);
		newChara.updateHitbox();
		newChara.zIndex = zIndex;
		newChara.x += newChara.width * -.5 + newChara.originOffset.x;
		newChara.y += newChara.height * -1 + newChara.originOffset.y;
		newChara.stageCameraOffset.copyFrom(off);
		newChara.conductorInUse = conductorInUse;
		newChara.bop = bop;
		off.put();
		
		newChara.alpha = invisible;
		return add(newChara);
	}
	public function unloadCharacter(?chara:CharacterOrString) {
		var toDestroy:Character;
		if (chara != null) {
			toDestroy = findCharacter(chara);
		} else {
			toDestroy = current;
		}
		if (toDestroy != null) {
			if (current == toDestroy) {
				current = initialChara;
				if (initialChara == toDestroy) // kys
					initialChara = current = members[0];
				if (current != null)
					current.alpha = alpha;
			}
			remove(toDestroy, true);
			toDestroy.destroy();
		}
	}
	public function changeCharacter(?name:String):Character {
		if (name == null)
			return current = initialChara;
		return current = preloadCharacter(name);
	}
	public override function remove(chara:Character, splice = false):Character {
		chara.x -= x;
		chara.y -= y;
		chara.cameras = null;
		@:privateAccess chara.characterGroup = null;
		return group.remove(chara, splice);
	}
	
	public function timeAnimSteps(?steps:Float):Void {
		for (chara in members) {
			if (chara == null) continue;
			chara.timeAnimSteps(steps);
		}
	}
	public function setOffset(x:Float = 0, y:Float = 0):Void {
		if (current != null)
			current.setOffset(x, y);
	}
	public function finishAnimation():Void {
		if (current != null)
			current.finishAnimation();
	}
	public function isAnimationFinished():Bool {
		if (current != null)
			return current.isAnimationFinished();
		return false;
	}
	public function animationExists(anim:String, includeUnloaded:Bool = true):Bool {
		if (current != null)
			return current.animationExists(anim, includeUnloaded);
		return false;
	}
	public function animationIsLooping(anim:String):Bool {
		if (current != null)
			return current.animationIsLooping(anim);
		return false;
	}
	public function playAnimationSoft(anim:String, forced:Bool = false, reversed:Bool = false, frame:Int = 0):Void {
		for (chara in members) {
			if (chara == null) continue;
			chara.playAnimationSoft(anim, forced, reversed, frame);
		}
	}
	public function playAnimation(anim:String, forced:Bool = false, reversed:Bool = false, frame:Int = 0):Void {
		for (chara in members) {
			if (chara == null) continue;
			chara.playAnimation(anim, forced, reversed, frame);
		}
	}
	public function playAnimationSteps(anim:String, forced:Bool = false, ?steps:Float, reversed:Bool = false, frame:Int = 0):Void {
		for (chara in members) {
			if (chara == null) continue;
			chara.playAnimationSteps(anim, forced, steps, reversed, frame);
		}
	}
	public function preloadAnimAsset(anim:String) { // preloads animation with a different spritesheet path
		for (chara in members) {
			if (chara == null) continue;
			chara.preloadAnimAsset(anim);
		}
	}
	public function dance(beat:Int = 0, forced:Bool = false):Bool {
		for (chara in members) {
			if (chara == null) continue;
			chara.dance(beat, forced);
		}
		return true;
	}
	public function flip():CharacterGroup {
		if (side != IDGAF)
			side = (side == RIGHT ? LEFT : RIGHT);
		return this;
	}
}