package funkin.backend.scripting;

import crowplexus.hscript.Tools;
import crowplexus.hscript.Expr;

class ModInterp extends crowplexus.hscript.Interp {
	public static var intercept:Array<Dynamic>;
	
	public function interceptSetVar(name:String, v:Dynamic) {
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
		if (Reflect.hasField(o, '__evalues__')) { // hashlink enums
			try {
				var vals:hl.NativeArray<Dynamic> = Reflect.getProperty(o, '__evalues__');
				for (i in 0...vals.length) {
					@:privateAccess var val:Dynamic = vals.get(i);
					if (Std.string(val) == f)
						return val;
				}
			} catch (e:Dynamic) {}
			return null;
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
	
	// allat just to replace one inlined function
	override function assign(e1:Expr, e2:Expr):Dynamic {
		var v = expr(e2);
		switch (Tools.expr(e1)) {
			case EIdent(id):
				var l = locals.get(id);
				if (l == null)
					interceptSetVar(id, v)
				else {
					if (l.const != true)
						l.r = v;
					else
						warn(ECustom("Cannot reassign final, for constant expression -> " + id));
				}
			case EField(e, f, s):
				var e = expr(e);
				if (e == null)
					if (!s)
						error(EInvalidAccess(f));
					else
						return null;
				v = set(e, f, v);
			case EArray(e, index):
				var arr: Dynamic = expr(e);
				var index: Dynamic = expr(index);
				if (isMap(arr)) {
					setMapValue(arr, index, v);
				} else {
					arr[index] = v;
				}

			default:
				error(EInvalidOp("="));
		}
		return v;
	}
	override function evalAssignOp(op, fop, e1, e2): Dynamic {
		var v;
		switch (Tools.expr(e1)) {
			case EIdent(id):
				var l = locals.get(id);
				v = fop(expr(e1), expr(e2));
				if (l == null)
					interceptSetVar(id, v)
				else {
					if (l.const != true)
						l.r = v;
					else
						warn(ECustom("Cannot reassign final, for constant expression -> " + id));
				}
			case EField(e, f, s):
				var obj = expr(e);
				if (obj == null)
					if (!s)
						error(EInvalidAccess(f));
					else
						return null;
				v = fop(get(obj, f), expr(e2));
				v = set(obj, f, v);
			case EArray(e, index):
				var arr: Dynamic = expr(e);
				var index: Dynamic = expr(index);
				if (isMap(arr)) {
					v = fop(getMapValue(arr, index), expr(e2));
					setMapValue(arr, index, v);
				} else {
					v = fop(arr[index], expr(e2));
					arr[index] = v;
				}
			default:
				return error(EInvalidOp(op));
		}
		return v;
	}
	override function increment(e: Expr, prefix: Bool, delta: Int): Dynamic {
		#if hscriptPos
		curExpr = e;
		var e = e.e;
		#end
		switch (e) {
			case EIdent(id):
				var l = locals.get(id);
				var v: Dynamic = (l == null) ? resolve(id) : l.r;
				function setTo(a) {
					if (l == null)
						interceptSetVar(id, a)
					else {
						if (l.const != true)
							l.r = a;
						else
							error(ECustom("Cannot reassign final, for constant expression -> " + id));
					}
				}
				if (prefix) {
					v += delta;
					setTo(v);
				} else {
					setTo(v + delta);
				}
				return v;
			case EField(e, f, s):
				var obj = expr(e);
				if (obj == null)
					if (!s)
						error(EInvalidAccess(f));
					else
						return null;
				var v: Dynamic = get(obj, f);
				if (prefix) {
					v += delta;
					set(obj, f, v);
				} else
					set(obj, f, v + delta);
				return v;
			case EArray(e, index):
				var arr: Dynamic = expr(e);
				var index: Dynamic = expr(index);
				if (isMap(arr)) {
					var v = getMapValue(arr, index);
					if (prefix) {
						v += delta;
						setMapValue(arr, index, v);
					} else {
						setMapValue(arr, index, v + delta);
					}
					return v;
				} else {
					var v = arr[index];
					if (prefix) {
						v += delta;
						arr[index] = v;
					} else
						arr[index] = v + delta;
					return v;
				}
			default:
				return error(EInvalidOp((delta > 0) ? "++" : "--"));
		}
	}
}