package funkin.backend.play;

interface IPlayEvent {
	public var cancelled:Bool;
	
	public function cancel():Void;
	public function dispatch():Void;
}