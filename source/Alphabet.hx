package;

class Alphabet extends FlxSpriteGroup {
	public var bold(default, set):Bool;
	public var text(default, set):String = '';
	public var padding(default, set):Float = -3;
	public var characters:Array<AlphabetCharacter> = [];
	
	public function new(x:Float = 0, y:Float = 0, text:String = '', bold:Bool = true) {
		super(x, y);
		this.bold = bold;
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
	public function set_bold(newBold:Bool) {
		for (letter in characters) letter.bold = newBold;
		return bold = newBold;
	}
	public function set_text(newText:String = '') {
		if (newText == text) return newText;
		while (characters.length > newText.length) {
			var character:AlphabetCharacter = characters.shift();
			remove(character, true);
			character.destroy();
		}
		
		var stringLetters:Array<String> = newText.split('');
		var xx:Float = 0;
		var i:Int = 0;
		for (letter in stringLetters) {
			var character:Null<AlphabetCharacter> = null;
			if (i >= characters.length) {
				character = new AlphabetCharacter(xx, 0, letter, bold);
				characters.push(character);
				add(character);
			} else {
				character = characters[i];
				//trace('mod character ${character.character} -> ${letter}');
				character.character = letter;
				character.baseX = xx;
			}
			if (character != null)
				xx += (character.blank ? 50 : character.width) + padding;
			i ++;
		}
		
		var penis:String = '';
		for (char in characters) penis += char.character;
		//trace('${characters.length} / ${stringLetters.length} /// ${penis} / ${newText}');
			//trace('${newChar} (${letter.name}) -> ${letterAnim}');
		return text = newText;
	}
}

class AlphabetCharacter extends FunkinSprite {
	public var baseX(default, set):Float;
	public var baseY(default, set):Float;
	public var bold(default, set):Bool;
	public var blank(default, null):Bool;
	public var character(default, set):String = '';
	public static var meta:Map<String, Letter> = [
		'.' => {name: '-period-', boldOffset: [0, 0], blackOffset: [0, 0]},
		'&' => {name: '-and-', boldOffset: [0, 0], blackOffset: [0, 0]},
	];
	
	inline static function isLowerCase(character:String) return (character.toLowerCase() == character && character.toUpperCase() != character);
	public static function getLetter(character:String, bold:Bool = true) {
		if (AlphabetCharacter.meta.exists(character)) return AlphabetCharacter.meta[character];
		return {name: character, boldOffset: [0, 0], blackOffset: [0, 0]};
	}
	
	public function new(x:Float = 0, y:Float = 0, character:String = ' ', bold:Bool = true) {
		super();
		this.baseX = x;
		this.baseY = y;
		this.bold = bold;
		this.character = character;
	}
	public function set_character(newChar:String) {
		if (frames == null) return character = newChar;
		if (!animation.exists(newChar)) {
			var letter:Letter = AlphabetCharacter.getLetter(bold ? newChar.toUpperCase() : newChar, bold);
			
			var letterOffset:Array<Float> = (bold ? letter.boldOffset : letter.blackOffset);
			var letterAnim:String = letter.name;
			if (bold) letterAnim = '${letterAnim} bold';
			else if (isLowerCase(letterAnim)) letterAnim = '${letterAnim} lowercase';
			
			if (hasAnimationPrefix(letterAnim)) {
				visible = true;
				blank = false;
				offsets[newChar] = FlxPoint.get(letterOffset[0], letterOffset[1]);
				animation.addByPrefix(newChar, letterAnim, 24, true);
				playAnimation(newChar);
				updateHitbox();
				if (letterOffset[1] == 0) offsets[newChar].y = height - 68;
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
	public function set_bold(newBold:Bool) {
		if (bold != newBold) {
			offsets.clear();
			loadAtlas('alphabet-${newBold ? 'bold' : 'black'}');
			set_character(character);
		}
		return bold = newBold;
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
	public var boldOffset:Array<Float>;
	public var blackOffset:Array<Float>;
}