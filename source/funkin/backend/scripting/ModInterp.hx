package funkin.backend.scripting;

import crowplexus.iris.Iris;
import crowplexus.hscript.Expr;
import crowplexus.hscript.Tools;
import crowplexus.hscript.Interp;

import funkin.backend.FunkinSprite;

enum Exit { // all of this because Stop IS PRIVATW AHHHHHHHHH
	Continue;
	Return;
	Break;
}

class ModInterp extends Interp {
	public var hscript:HScript;
	
	override function setVar(name:String, v:Dynamic) {
		if (variables.exists(name)) {
			variables.set(name, v);
			return;
		}
		
		if (hscript.interceptArray != null) {
			for (obj in hscript.interceptArray) {
				var prop:Dynamic = Reflect.getProperty(obj, name);
				if (Reflect.hasField(obj, name) || prop != null) {
					Reflect.setProperty(obj, name, v);
					return;
				}
			}
		}
		if (hscript.defaultVars != null) {
			if (hscript.defaultVars.exists(name)) {
				hscript.defaultVars.set(name, v);
				return;
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
		
		if (hscript.interceptArray != null) {
			for (obj in hscript.interceptArray) {
				var prop:Dynamic = Reflect.getProperty(obj, id);
				if (Reflect.hasField(obj, id) || prop != null)
					return prop;
			}
		}
		if (hscript.defaultVars != null) {
			if (hscript.defaultVars.exists(id))
				return hscript.defaultVars.get(id);
		}

		error(EUnknownVariable(id));
		return null;
	}
	override function get(o:Dynamic, f:String):Dynamic {
		if (o == null)
			error(EInvalidAccess(f));
		
		if (variables.get('experimentalVars') == true) {
			if (Std.isOfType(o, ISpriteVars)) {
				var spr:ISpriteVars = cast o;
				if (o.hasVar(f))
					return o.getVar(f);
			}
		}
		
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
			case EBreak:
				throw Break;
			case EContinue:
				throw Continue;
			case EReturn(e):
				returnValue = (e == null ? null : expr(e));
				throw Return;
			case EFunction(params, fexpr, name, _):
				var capturedLocals = duplicate(locals);
				var minParams:Int = 0;
				var me = this;
				for (p in params) {
					if (!p.opt)
						minParams ++;
				}
				
				var f = function(args: Array<Dynamic>) {
					if (((args == null) ? 0 : args.length) != params.length) {
						if (args.length < minParams) {
							var str = "Invalid number of parameters. Got " + args.length + ", required " + minParams;
							if (name != null)
								str += " for function '" + name + "'";
							error(ECustom(str));
						}
						// make sure mandatory args are forced
						var args2 = [];
						var extraParams = args.length - minParams;
						var pos = 0;
						for (p in params) {
							if (p.opt) {
								if (extraParams > 0) {
									args2.push(args[pos++]);
									extraParams--;
								} else {
									args2.push(expr(p.value));
								}
							} else {
								args2.push(args[pos++]);
							}
						}
						args = args2;
					}
					var old = me.locals, depth = me.depth;
					me.depth ++;
					me.locals = me.duplicate(capturedLocals);
					for (i in 0...params.length)
						me.locals.set(params[i].name, {r: args[i], const: false});
					var r = null;
					var oldDecl = declared.length;
					if (inTry)
						try {
							r = me.exprReturn(fexpr);
						} catch (e:Dynamic) {
							me.locals = old;
							me.depth = depth;
							#if neko
							neko.Lib.rethrow(e);
							#else
							throw e;
							#end
						}
					else {
						r = me.exprReturn(fexpr);
					}
					restore(oldDecl);
					me.locals = old;
					me.depth = depth;
					return r;
				};
				var f = Reflect.makeVarArgs(f);
				if (name != null) {
					if (depth == 0) {
						// global function
						variables.set(name, f);
					} else {
						// function-in-function is a local function
						declared.push({n: name, old: locals.get(name)});
						var ref:LocalVar = {r: f, const: false};
						locals.set(name, ref);
						capturedLocals.set(name, ref); // allow self-recursion
					}
				}
				return f;
			default:
		}
		return super.expr(e);
	}
	override function exprReturn(e): Dynamic {
		try {
			return expr(e);
		} catch (e:Exit) {
			switch (e) {
				case Break:
					throw "Invalid break";
				case Continue:
					throw "Invalid continue";
				case Return:
					var v = returnValue;
					returnValue = null;
					return v;
			}
		}
		return null;
	}
	
	override function doWhileLoop(eCond, e) {
		var old: Int = declared.length;
		do {
			try {
				expr(e);
			} catch (err:Exit) {
				switch (err) {
					case Continue:
					case Break: break;
					case Return: throw err;
				}
			}
		} while (expr(eCond) == true);
		restore(old);
	}
	override function whileLoop(eCond, e) {
		var old: Int = declared.length;
		while (expr(eCond) == true) {
			try {
				expr(e);
			} catch (err:Exit) {
				switch (err) {
					case Continue:
					case Break: break;
					case Return: throw err;
				}
			}
		}
		restore(old);
	}
	override function forLoop(n, v, itExpr, e): Void {
		var old: Int = declared.length;
		declared.push({n: n, old: locals.get(n)});
		var keyValue: Bool = false;
		if (v != null) {
			keyValue = true;
			declared.push({n: v, old: locals.get(v)});
		}
		var it: Dynamic = (keyValue ? makeKVIterator : makeIterator)(expr(itExpr));
		var _itHasNext: Dynamic = it.hasNext;
		var _itNext: Dynamic = it.next;
		
		while (_itHasNext()) {
			if (keyValue) {
				var next = _itNext();
				if (next.key == null || next.value == null) {
					var nulled: String = (next.key == null ? 'key' : 'value');
					error(ECustom('${Std.isOfType(next, Int) ? 'Int' : Type.getClassName(Type.getClass(next))} has no field $nulled'));
				}
				locals.set(n, {r: next.key, const: false});
				locals.set(v, {r: next.value, const: false});
			} else {
				locals.set(n, {r: _itNext(), const: false});
			}
			
			try {
				expr(e);
			} catch (err:Exit) {
				switch (err) {
					case Continue:
					case Break:
						break;
					case Return:
						throw err;
				}
			}
		}
		restore(old);
	}
}