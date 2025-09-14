package funkin.util;

#if hl import hl.Gc;
#elseif cpp import cpp.vm.Gc;
#elseif neko import neko.vm.Gc; #end

class MemoryUtil {
	public static function getMemoryUsed():#if cpp Float #else Int #end {
		#if cpp
		return Gc.memInfo64(Gc.MEM_INFO_CURRENT);
		#else
		return openfl.system.System.totalMemory;
		#else
		Log.warning('GC not implemented on this platform');
		#end
	}
	
	public static function enable(yea:Bool = true):Void {
		#if (cpp || hl)
		Gc.enable(yea);
		#else
		Log.warning('GC not implemented on this platform');
		#end
	}
	
	public static function collect(major:Bool = true):Void {
		openfl.system.System.gc();
		#if (cpp || neko)
		Gc.run(major);
		#elseif hl
		if (major) Gc.major();
		#end
	}
	
	public static function compact():Void {
		#if cpp
		Gc.compact();
		#end
	}
}