package;

using StringTools;

class Simfile {
	public var metadata:Map<String, Dynamic> = [];
	
	public function new(content:String) {
		var lines:Array<String> = content.replace('\n', '').replace('\r', '').split(';');
		/*for (line in lines) {
			var split:Array<Dynamic> = line.split(':');
			
			var key:String = split[0];
			var values:Array<Dynamic> = split[1].split(':');
			
			for (i in 0...values.length)
				if (Std.parseFloat(values[i]) != Math.NaN)
					values[i] = Std.parseFloat(values[i]);
			metadata[key.sub(1, key)] = values;
		}*/
	}
	
	public function findNotes(type:String) {
	}
}