package funkin.objects;

class Alphabet extends FlxSpriteGroup {
	public var type(default, set):String;
	public var text(default, set):String;
	public var padding(default, set):Float = -3;
	public var letterCase(default, set):AlphabetCase = NONE;
	public var characters:Array<AlphabetCharacter> = [];
	
	public function new(x:Float = 0, y:Float = 0, text:String = '', type:String = 'bold') {
		super(x, y);
		this.type = type;
		this.text = text;
	}
	
	public function set_padding(newPadding:Float) {
		var i:Int = 0;
		var diff:Float = newPadding - padding;
		for (character in characters) {
			character.baseX += (i * diff);
			i ++;
		}
		return padding = newPadding;
	}
	public function scaleTo(x:Float = 1, y:Float = 1) {
		scale.set(x, y);
		recalculateLetters();
	}
	public inline function recalculateLetters() {
		var xx:Float = 0;
		for (character in characters) {
			character.baseX = xx;
			xx += ((character.blank ? 50 : character.width) + padding) * scale.x;
		}
	}
	public function set_letterCase(newCase:AlphabetCase) {
		for (character in characters) character.letterCase = newCase;
		recalculateLetters();
		return letterCase = newCase;
	}
	public function set_type(newType:String) {
		switch (newType) {
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
	public function set_text(newText:String = '') {
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
				character.scale.copyFrom(scale);
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
		updateHitbox();
		return text = newText;
	}
}

class AlphabetCharacter extends FunkinSprite {
	public var baseX(default, set):Float;
	public var baseY(default, set):Float;
	public var type(default, set):String;
	public var blank(default, null):Bool;
	public var character(default, set):String = '';
	public var letterCase(default, set):AlphabetCase = NONE;
	public static var meta:Map<String, Letter> = [
		"'" => {name: '-apostrophe-', alignment: TOP},
		'.' => {name: '-period-', alignment: BOTTOM},
		'!' => {name: '-exclamation point-'},
		'&' => {name: '-and-'},
		'@' => {name: '-at-'}
	];
	
	inline static function isLowerCase(char:String):Bool {
		return (char.toLowerCase() == char && char.toUpperCase() != char);
	}
	public static function getLetter(char:String):Letter {
		return AlphabetCharacter.meta[char] ?? {name: char};
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
		
		if (!animation.exists(newChar)) {
			var letter:Letter = AlphabetCharacter.getLetter(newChar);
			
			var letterAnim:String = letter.name;
			if (isLowerCase(newChar)) {
				var lowercaseAnim:String = '$letterAnim lowercase';
				if (hasAnimationPrefix(lowercaseAnim + 0)) letterAnim = lowercaseAnim;
			}
			
			if (hasAnimationPrefix(letterAnim + 0)) {
				var letterOffset:Null<Array<Null<Float>>> = (letter.offsets == null ? null : letter.offsets[type]); // Wtf
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
							offsetY = frameHeight - 68;
						default: // center
							offsetY = (frameHeight - 68) * .5;
					}
				}
				setAnimationOffset(newChar, offsetX, offsetY);
				
				playAnimation(newChar);
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
	public function set_letterCase(newCase:AlphabetCase) {
		letterCase = newCase;
		set_character(character);
		return letterCase = newCase;
	}
	public function set_type(newType:String) {
		if (type != newType) {
			offsets.clear();
			loadAtlas('fonts/$newType');
			set_character(character);
		}
		return type = newType;
	}
	public function set_baseX(newX:Float) {
		x += newX - baseX;
		return baseX = newX;
	}
	public function set_baseY(newY:Float) {
		y += newY - baseY;
		return baseY = newY;
	}
}

typedef Letter = {
	var name:String;
	var ?alignment:LetterAlignment;
	var ?offsets:Map<String, Array<Null<Float>>>;
}

enum LetterAlignment {
	TOP;
	CENTER;
	BOTTOM;
}

enum AlphabetCase {
	UPPERCASE;
	LOWERCASE;
	NONE;
}