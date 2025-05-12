package funkin.backend.rhythm;

interface ITimeSortable {
	public var msTime:Float;
}
interface ITimedEvent<T> extends ITimeSortable {
	public var func:#if hl Dynamic #else T #end -> Void;
}

class Event implements ITimedEvent<Event> {
	public var msTime:Float;
	public var func:#if hl Dynamic #else Event #end -> Void;
	
	public function new(msTime:Float, ?func:#if hl Dynamic #else Event #end -> Void) {
		this.msTime = msTime;
		this.func = func;
	}
}
// thats crazy