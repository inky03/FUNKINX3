package funkin.backend.rhythm;

interface ITimeSortable {
	public var msTime:Float;
}
interface ITimedEvent<T> extends ITimeSortable {
	public var func:T -> Void;
}

class Event implements ITimedEvent<Event> {
	public var msTime:Float;
	public var func:Event -> Void;
	
	public function new(msTime:Float, ?func:Event -> Void) {
		this.msTime = msTime;
		this.func = func;
	}
}
// thats crazy