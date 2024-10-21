class Log {
	public static function fromCodes(codes:Array<Int>) {
		var finalStr = '\033[';
		for (i => code in codes) {
			if (code < 0) continue;
			finalStr += code + (i == codes.length - 1 ? 'm' : ';');
		}
		return (codes.length > 0 ? finalStr : '');
	}
	public static function colorTag(text:String, textColor:TextColor = none, backgroundColor:BackgroundColor = none) {
		return '${fromCodes([cast textColor, cast backgroundColor])}$text\033[0m';
	}
	public static function warning(text:String) {
		return Sys.println(colorTag(' WARNING ', TextColor.black, BackgroundColor.yellow) + ' $text');
	}
	public static function error(text:String) {
		return Sys.println(colorTag(' ERROR ', TextColor.black, BackgroundColor.red) + ' $text');
	}
	public static function fatal(text:String) {
		return Sys.println(colorTag(' FATAL ', TextColor.black, BackgroundColor.brightRed) + ' $text');
	}
	public static function info(text:String) {
		return Sys.println(colorTag(' INFO ', TextColor.black, BackgroundColor.cyan) + ' $text');
	}
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