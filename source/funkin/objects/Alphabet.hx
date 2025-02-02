package funkin.objects;

import funkin.shaders.MonoSwap;

class Alphabet extends FlxSpriteGroup {
	public var type(default, set):String;
	public var text(default, set):String;
	public var padding(default, set):Float = -3;
	public var letterCase(default, set):LetterCase = NONE;
	public var characters:Array<AlphabetCharacter> = [];
	
	public var white(default, set):FlxColor = FlxColor.WHITE;
	public var black(default, set):FlxColor = FlxColor.BLACK;
	
	public function new(x:Float = 0, y:Float = 0, text:String = '', type:String = 'bold') {
		super(x, y);
		this.type = type;
		this.text = text;
	}
	
	public function scaleTo(x:Float = 1, y:Float = 1):Alphabet {
		scale.set(x, y);
		recalculateLetters();
		return this;
	}
	public function recalculateLetters() {
		var xx:Float = 0;
		var blankWidth:Float;
		for (character in characters) {
			character.baseX = xx;
			character.updateHitbox();
			blankWidth = 50 * scale.x;
			xx += (character.blank ? blankWidth : character.width) + padding * scale.x;
		}
	}
	
	public function setColors(white:FlxColor = FlxColor.WHITE, black:FlxColor = FlxColor.BLACK):Alphabet {
		for (character in characters)
			character.setColors(white, black);
		return this;
	}
	function set_white(col:FlxColor):FlxColor {
		if (col == white)
			return col;
		for (character in characters)
			character.white = col;
		return white = col;
	}
	function set_black(col:FlxColor):FlxColor {
		if (col == black)
			return col;
		for (character in characters)
			character.black = col;
		return black = col;
	}
	
	function set_padding(newPadding:Float):Float {
		var i:Int = 0;
		var diff:Float = newPadding - padding;
		for (character in characters) {
			character.baseX += (i * diff);
			i ++;
		}
		return padding = newPadding;
	}
	function set_letterCase(newCase:LetterCase):LetterCase {
		for (character in characters) character.letterCase = newCase;
		recalculateLetters();
		return letterCase = newCase;
	}
	function set_type(newType:String) {
		switch (newType) {
			case 'techno':
				padding = -4;
				letterCase = UPPERCASE;
			case 'bold':
				padding = -3;
				letterCase = UPPERCASE;
			case 'black':
				padding = 3;
				letterCase = NONE;
			default:
		}
		for (character in characters) {
			character.letterCase = letterCase;
			character.type = newType;
		}
		recalculateLetters();
		return type = newType;
	}
	function set_text(newText:String = ''):String {
		if (newText == text) return newText;
		
		while (characters.length > newText.length) {
			var character:AlphabetCharacter = characters.shift();
			remove(character, true);
			character.destroy(); //todo: pool letters?
		}
		
		var stringLetters:Array<String> = newText.split('');
		var i:Int = 0;
		for (letter in stringLetters) {
			var character:AlphabetCharacter;
			if (i >= characters.length) {
				character = new AlphabetCharacter(0, 0, letter, type);
				character.setColors(white, black);
				character.scale.copyFrom(scale);
				character.updateHitbox();
				characters.push(character);
				add(character);
			} else {
				character = characters[i];
				character.character = letter;
			}
			character.letterCase = letterCase;
			i ++;
		}
		
		recalculateLetters();
		return text = newText;
	}
}

class AlphabetCharacter extends FunkinSprite {
	public var monoShader:MonoSwap;
	public var colored(default, set):Bool = false;
	public var white(default, set):FlxColor = FlxColor.WHITE;
	public var black(default, set):FlxColor = FlxColor.BLACK;
	
	public var tallHeight:Float;
	public var smallHeight:Float;
	public var baseX(default, set):Float;
	public var baseY(default, set):Float;
	public var type(default, set):String;
	public var blank(default, null):Bool;
	public var character(default, set):String = '';
	public var letterCase(default, set):LetterCase = NONE;
	public static var meta:Map<String, Map<String, Letter>> = [
		"default" => [
			"b" => {alignment: BOTTOM},
			"d" => {alignment: BOTTOM},
			"f" => {alignment: BOTTOM},
			"g" => {alignment: TOP},
			"h" => {alignment: BOTTOM},
			"i" => {alignment: BOTTOM},
			"k" => {alignment: BOTTOM},
			"l" => {alignment: BOTTOM},
			"p" => {alignment: TOP},
			"q" => {alignment: TOP},
			"t" => {alignment: BOTTOM},
			"y" => {alignment: TOP},
			"'" => {name: '-apostrophe-', alignment: TOP},
			'.' => {name: '-period-', alignment: BOTTOM},
			'!' => {name: '-exclamation point-'},
			'&' => {name: '-and-'},
			'@' => {name: '-at-'}
		],
		"techno" => [
			"f" => {alignment: TOP},
			"j" => {alignment: TOP},
			"(" => {alignment: BOTTOM},
			")" => {alignment: BOTTOM}
		]
	];
	
	inline static function isLowerCase(char:String):Bool {
		return (char.toLowerCase() == char && char.toUpperCase() != char);
	}
	public static function getLetter(char:String, ?type:String):Letter {
		var meta:Map<String, Letter>;
		var lowChar:String = char.toLowerCase();
		
		if (type != null) {
			meta = AlphabetCharacter.meta[type];
			if (meta != null) {
				if (meta[char] != null)
					return meta[char];
				if (meta[lowChar] != null)
					return meta[lowChar];
			}
		}
		meta = AlphabetCharacter.meta['default'];
		return meta[char] ?? meta[lowChar] ?? {name: char};
	}
	
	public function new(x:Float = 0, y:Float = 0, character:String = ' ', type:String = 'bold') {
		super();
		this.baseX = x;
		this.baseY = y;
		this.type = type;
		this.character = character;
	}
	public function set_character(newChar:String) {
		switch (letterCase) {
			case UPPERCASE:
				newChar = newChar.toUpperCase();
			case LOWERCASE:
				newChar = newChar.toLowerCase();
			default:
		}
		
		if (frames == null) return character = newChar;
		
		if (!animationExists(newChar)) {
			var letter:Letter = AlphabetCharacter.getLetter(newChar, type);
			
			var letterAnim:String = letter.name ?? newChar;
			if (isLowerCase(newChar)) {
				var lowercaseAnim:String = '$letterAnim lowercase';
				if (hasAnimationPrefix(lowercaseAnim + 0)) letterAnim = lowercaseAnim;
			}
			if (!hasAnimationPrefix(letterAnim + 0) && hasAnimationPrefix(letterAnim.toUpperCase() + 0))
				letterAnim = letterAnim.toUpperCase();
			
			if (hasAnimationPrefix(letterAnim + 0)) {
				var letterOffset:Null<Array<Null<Float>>> = (letter.offsets == null ? null : letter.offsets[type]); // Wtf
				var baseHeight:Float = (letter.base == TALL ? tallHeight : smallHeight);
				visible = true;
				blank = false;

				addAnimation(newChar, letterAnim + 0, 24, true);
				playAnimation(newChar);

				var offsetX:Float = 0;
				var offsetY:Null<Float> = null;
				if (letterOffset != null) {
					offsetX = letterOffset[0] ?? 0;
					offsetY = letterOffset[1];
				}
				if (offsetY == null) {
					switch (letter.alignment) {
						case TOP:
							offsetY = 0;
						case BOTTOM:
							offsetY = frameHeight - baseHeight;
						default: // center
							offsetY = (baseHeight - frameHeight) * .5;
					}
				}
				setAnimationOffset(newChar, offsetX, offsetY);
				
				playAnimation(newChar, true);
				updateHitbox();
			} else {
				blank = true;
				visible = false;
			}
		} else {
			blank = false;
			visible = true;
			playAnimation(newChar);
			updateHitbox();
		}
		return character = newChar;
	}
	public function setupFont() {
		if (hasAnimationPrefix('base small')) {
			addAnimation('small', 'base small');
			playAnimation('small', true);
			smallHeight = frameHeight;
		} else {
			smallHeight = 68;
		}
		if (hasAnimationPrefix('base tall')) {
			addAnimation('tall', 'base tall');
			playAnimation('tall', true);
			tallHeight = frameHeight;
		} else {
			tallHeight = 68;
		}
	}
	
	public function setColors(white:FlxColor = FlxColor.WHITE, black:FlxColor = FlxColor.BLACK) {
		this.white = white;
		this.black = black;
	}
	inline function isColored():Bool {
		return (white != FlxColor.WHITE || black != FlxColor.BLACK);
	}
	function set_white(col:FlxColor):FlxColor {
		if (col == white) return col;
		white = col;
		colored = isColored();
		if (monoShader != null) monoShader.white = col;
		return col;
	}
	function set_black(col:FlxColor):FlxColor {
		if (col == black) return col;
		black = col;
		colored = isColored();
		if (monoShader != null) monoShader.black = col;
		return col;
	}
	function set_colored(isIt:Bool):Bool {
		if (colored == isIt) return isIt;
		
		if (isIt) {
			if (monoShader == null)
				monoShader = new MonoSwap();
			shader = monoShader.shader;
		} else {
			shader = null;
		}
		
		return colored = isIt;
	}
	
	function set_letterCase(newCase:LetterCase):LetterCase {
		letterCase = newCase;
		set_character(character);
		return letterCase = newCase;
	}
	function set_type(newType:String):String {
		if (type != newType) {
			offsets.clear();
			loadAtlas('fonts/$newType');
			setupFont();
			set_character(character);
		}
		return type = newType;
	}
	function set_baseX(newX:Float):Float {
		x += newX - baseX;
		return baseX = newX;
	}
	function set_baseY(newY:Float):Float {
		y += newY - baseY;
		return baseY = newY;
	}
}

typedef Letter = {
	var ?name:String;
	var ?base:LetterBase;
	var ?alignment:LetterAlignment;
	var ?offsets:Map<String, Array<Null<Float>>>;
}

enum abstract LetterBase(String) to String {
	var SMALL = 'small';
	var TALL = 'tall';
}
enum abstract LetterAlignment(String) to String {
	var TOP = 'top';
	var CENTER = 'center';
	var BOTTOM = 'bottom';
}
enum abstract LetterCase(String) to String {
	var UPPERCASE = 'uppercase';
	var LOWERCASE = 'lowercase';
	var NONE = 'none';
}