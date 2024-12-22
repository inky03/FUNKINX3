package funkin.backend.states;

interface IFunkinState {
	public var curBar:Int;
	public var curBeat:Int;
	public var curStep:Int;
	
	public var conductorInUse:funkin.backend.rhythm.Conductor;
}