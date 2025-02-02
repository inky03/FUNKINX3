package funkin.backend.scripting;

import crowplexus.iris.Iris;
import crowplexus.hscript.Expr;
import crowplexus.hscript.Tools;

class ModInterp extends crowplexus.hscript.Interp {
	public static var intercept:Array<Dynamic>;
	public var hscript:HScript;
	
	override function setVar(name:String, v:Dynamic) {
		if (variables.exists(name)) {
			variables.set(name, v);
			return;
		}
		
		if (intercept != null) {
			for (obj in intercept) {
				var prop:Dynamic = Reflect.getProperty(obj, name);
				if (Reflect.hasField(obj, name) || prop != null) {
					Reflect.setProperty(obj, name, v);
					return;
				}
			}
		}
		
		error(EUnknownVariable(name));
	}
	override function resolve(id:String):Dynamic {
		if (locals.exists(id)) {
			var l = locals.get(id);
			return l.r;
		} else if (variables.exists(id)) {
			var v = variables.get(id);
			return v;
		} else if (imports.exists(id)) {
			var v = imports.get(id);
			return v;
		}
		
		if (intercept != null) {
			for (obj in intercept) {
				var prop:Dynamic = Reflect.getProperty(obj, id);
				if (Reflect.hasField(obj, id) || prop != null)
					return prop;
			}
		}

		error(EUnknownVariable(id));
		return null;
	}
	override function get(o:Dynamic, f:String):Dynamic {
		if (o == null)
			error(EInvalidAccess(f));
		
		#if hl
		if (Type.typeof(o) == Type.ValueType.TObject && Reflect.hasField(o, '__evalues__')) { // hashlink enums
			try {
				var vals:hl.NativeArray<Dynamic> = Reflect.getProperty(o, '__evalues__');
				for (i in 0...vals.length) {
					@:privateAccess var val:Dynamic = vals.get(i);
					if (Std.string(val) == f)
						return val;
				}
			} catch (e:Dynamic) {}
			error(EInvalidAccess(f));
		}
		#end
		return Reflect.getProperty(o, f);
	}
	override function makeIterator(v:Dynamic):Iterator<Dynamic> {
		try {
			#if hl
			var iter = Reflect.getProperty(v, 'iterator');
			if (iter != null)
				v = Reflect.callMethod(v, iter, []);
			else
				v = v.iterator();
			#else
			v = v.iterator();
			#end
		} catch (e:Dynamic) {}
		
		if (v.hasNext == null || v.next == null) {
			error(EInvalidIterator(Std.string(v)));
			return null;
		} else {
			return v;
		}
	}
	override function makeKVIterator(v:Dynamic):Null<KeyValueIterator<Dynamic, Dynamic>> {
		try {
			#if hl
			var iter = Reflect.getProperty(v, 'keyValueIterator');
			if (iter != null)
				v = Reflect.callMethod(v, iter, []);
			else {
				if (v.keyValueIterator != null)
					v = v.keyValueIterator();
				else
					v = makeIterator(v);
			}
			#else
			v = v.keyValueIterator();
			#end
		} catch (e:Dynamic) {
			#if !hl
			try {
				v = v.iterator();
			} catch (e:Dynamic) {}
			#end
		}
		
		if (v.hasNext == null || v.next == null) {
			error(EInvalidKVIterator(Std.string(v)));
			return null;
		} else {
			return v;
		}
	}
	
	public function doImport(cls:String, ?alias:String) { // TODO: fun things
		final aliasStr = (alias != null ? ' named $alias' : ''); // for errors
		if (Iris.blocklistImports.contains(cls)) {
			error(ECustom('Import of class $cls is blacklisted'));
			return null;
		}
		
		var n = Tools.last(cls.split('.'));
		if (imports.exists(n))
			return imports.get(n);
		
		var c:Dynamic = getOrImportClass(cls);
		if (c == null)
			return warn(ECustom('Import$aliasStr of class $cls could not be added'));
		else {
			imports.set(n, c);
			if (alias != null)
				imports.set(alias, c);
		}
		return null;
	}
	public override function expr(e: Expr): Dynamic {
		#if hscriptPos
		curExpr = e;
		var eDef = e.e;
		#end
		switch (eDef) {
			case EImport(v, as):
				return doImport(v, as);
			default:
		}
		return super.expr(e);
	}
}