package;

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
	public inline function recalculateLetters() {
		var xx:Float = 0;
		for (character in characters) {
			character.baseX = xx;
			xx += (character.blank ? 50 : character.width) + padding;
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
		'!' => {name: '-exclamation point-', boldOffset: [0, 0], blackOffset: [0, 0]},
		'.' => {name: '-period-', boldOffset: [0, 0], blackOffset: [0, 0]},
		'&' => {name: '-and-', boldOffset: [0, 0], blackOffset: [0, 0]},
	];
	
	inline static function isLowerCase(char:String) return (char.toLowerCase() == char && char.toUpperCase() != char);
	public static function getLetter(char:String) {
		if (AlphabetCharacter.meta.exists(char)) return AlphabetCharacter.meta[char];
		return {name: char, boldOffset: [0, 0], blackOffset: [0, 0]};
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
			if (type == 'bold') letterAnim = '${letterAnim} bold';
			else if (isLowerCase(newChar)) letterAnim = '${letterAnim} lowercase';
			
			if (hasAnimationPrefix(letterAnim)) {
				var letterOffset:Array<Float> = (type == 'bold' ? letter.boldOffset : letter.blackOffset);
				visible = true;
				blank = false;
				offsets[newChar] = FlxPoint.get(letterOffset[0], letterOffset[1]);
				animation.addByPrefix(newChar, '${letterAnim}0', 24, true);
				playAnimation(newChar);
				updateHitbox();
				if (letterOffset[1] == 0)
					spriteOffset.y = offsets[newChar].y = height - 68;
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
			loadAtlas('alphabet${newType == '' ? '' : '-${newType}'}');
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
	public var name:String;
	public var boldOffset:Array<Float>; //well uh.
	public var blackOffset:Array<Float>;
}

enum AlphabetCase {
	UPPERCASE;
	LOWERCASE;
	NONE;
}