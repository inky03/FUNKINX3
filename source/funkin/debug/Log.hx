package funkin.debug;

class Log {
	public static var reset:String = '\033[0m';
	#if I_AM_BORING_ZZZ
	public static function colorTag(text:String, _, __) return text;
	public static function warning(text:String) return Sys.println('[ WARNING ] $text');
	public static function error(text:String) return Sys.println('[ ERROR ] $text');
	public static function fatal(text:String) return Sys.println('[ FATAL ] $text');
	public static function info(text:String) return Sys.println(text);
	public static function minor(text:String) return Sys.println(text);
	#else
	public static function fromCodes(codes:Array<Int>) {
		var finalStr = '\033[';
		for (i => code in codes) {
			if (code < 0) continue;
			finalStr += code + (i == codes.length - 1 ? 'm' : ';');
		}
		if (codes.length > 0)
			return finalStr.substr(0, finalStr.length - 1) + 'm';
		return '';
	}
	public static function colorTag(text:String, textColor:TextColor = none, backgroundColor:BackgroundColor = none) {
		var tags:String = fromCodes([cast textColor, cast backgroundColor]);
		return '$tags$text$reset';
	}
	public static function warning(text:String) return Sys.println(colorTag(' WARNING ', black, yellow) + ' $text');
	public static function error(text:String) return Sys.println(colorTag(' ERROR ', black, red) + ' $text');
	public static function fatal(text:String) return Sys.println(colorTag(' FATAL ', black, brightRed) + ' $text');
	public static function info(text:String) return Sys.println(colorTag(' INFO ', black, cyan) + ' $text');
	public static function minor(text:String) return Sys.println(colorTag(text, white, none));
	#end
}

enum abstract TextColor(Int) {
	public var none = -1;
	public var black = 30;
	public var red = 31;
	public var green = 32;
	public var yellow = 33;
	public var blue = 34;
	public var magenta = 35;
	public var cyan = 36;
	public var white = 37;
	public var brightBlack = 90;
	public var brightRed = 91;
	public var brightGreen = 92;
	public var brightYellow = 93;
	public var brightBlue = 94;
	public var brightMagenta = 95;
	public var brightCyan = 96;
	public var brightWhite = 97;
	public var reset = 0;
}

enum abstract BackgroundColor(Int) {
	public var none = -1;
	public var black = 40;
	public var red = 41;
	public var green = 42;
	public var yellow = 43;
	public var blue = 44;
	public var magenta = 45;
	public var cyan = 46;
	public var white = 47;
	public var brightBlack = 100;
	public var brightRed = 101;
	public var brightGreen = 102;
	public var brightYellow = 103;
	public var brightBlue = 104;
	public var brightMagenta = 105;
	public var brightCyan = 106;
	public var brightWhite = 107;
	public var reset = 0;
}