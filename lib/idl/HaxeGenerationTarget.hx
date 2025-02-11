package idl;

import idl.Data;
import haxe.macro.Expr;

using StringTools;
using idl.macros.MacroTools;

typedef MethodVariant = {args : Array<FArg>, ret : TypeAttr, pos: idl.Data.Position};


class HaxeGenerationTypeInfo {
	public final path:haxe.macro.TypePath;
	public final defn:haxe.macro.TypeDefinition;
	public final kind:idl.Data.DefinitionKind;

	public function new(path:haxe.macro.TypePath, defn:haxe.macro.TypeDefinition, kind:idl.Data.DefinitionKind) {
		this.path = path;
		this.defn = defn;
		this.kind = kind;
	}
}

abstract class HaxeGenerationTarget {
	var opts:Options;
	var _typeInfos:Map<String, HaxeGenerationTypeInfo>;
	var defaultPos:haxe.macro.Expr.Position = {file: "unknown", min: 0, max: 0};
	var _pack:Array<String>;

	public function new(opts:Options, typeInfos:Map<String, HaxeGenerationTypeInfo>) {
		this.opts = opts;
		_pack = opts.packageName.split(".");
		this._typeInfos = typeInfos;
	}

	public abstract function makeNativeMeta(iname:String, midfix:String, fname:String, argc:Null<Int>,  attrs:Array<Attrib>, p:Position):Array<MetadataEntry>;

	public abstract function makeType(t:TypeAttr, isReturn:Bool):ComplexType;

	public abstract function makeVectorType(t:TypeAttr, vt:Type, vdim:Int, isReturn:Bool):ComplexType;

	public abstract function getTargetCondition():String;

	public abstract function getInterfaceTypeDefinitions(iname:String, attrs:Array<Attrib>, pack:Array<String>, dfields:Array<Field>, ikind:InterfaceKind, p:Position):Array<TypeDefinition>;

	function attribsFromField(f:idl.Data.Field):Array<Attrib> {
		switch(f.kind) {
			case FMethod(_, ret): return ret.attr;
			case FAttribute(t): return t.attr;
			case DConst(_, _, _): return [];
		}
		return [];
	}
	public function addAttribute(iname:String, haxeName:String, f:idl.Data.Field, t:TypeAttr, p:Position):Array<haxe.macro.Field> {
		var attribFields:Array<Field> = [];
		var attribs = attribsFromField(f);

		switch (t.t) {
			case TArray(at, sizeField):
				var et = t.getElementType();
				var cetr = makeType(et, true);
				var cet = makeType(et, false);

				attribFields.push({
					pos: p,
					name: "get" + haxeName,
					meta: makeNativeMeta(iname, "_get_", haxeName, null, attribs, p),
					kind: externalFunction(attribs, [
						{
							name: "index",
							type: macro :Int
						}
					], cetr, macro return ${defVal(et)}),
					access: [APublic]
				});
				attribFields.push({
					pos: p,
					name: "set" + haxeName,
					meta: makeNativeMeta(iname, "_set_", haxeName, null, attribs, p),
					kind: externalFunction(attribs, [
						{
							name: "index",
							type: macro :Int
						},
						{name: "_v", type: cet}
					], cetr, macro return ${defVal(et)}),
					access: [APublic]
				});

			default:
				var hasSet = t.attr == null || t.attr.indexOf(AReadOnly) < 0;
				var tt = makeType(t, false);

				var fkind = hasSet ? FProp("get", "set", tt) : FProp("get", "never", tt);
				attribFields.push({
					pos: p,
					name: haxeName,
					kind: fkind,
					access: [APublic],
				});
				attribFields.push({
					pos: p,
					name: "get_" + haxeName,
					meta: makeNativeMeta(iname, "_get_", haxeName, null, attribs, p),
					kind: externalFunction(attribs, [], makeType(t, true), macro return ${defVal(t)}),
				});
				if (hasSet) {
					attribFields.push({
						pos: p,
						name: "set_" + haxeName,
						meta: makeNativeMeta(iname, "_set_", haxeName, null, attribs, p),
						kind: externalFunction(attribs, [
							{
								name: "_v",
								type: tt
							}
						], tt, macro return ${defVal(t)})
					});
				}
				var vt:Type = null;
				var vta:TypeAttr = null;
				var vdim = 0;

				var isVector = switch (t.t) {
					case TVector(vvt, vvdim):
						vt = vvt;
						vdim = vvdim;
						vta = {t: vt, attr: t.attr};
						true;
					default: false;
				}

				if (isVector && false) {
					attribFields.push({
						pos: p,
						name: "set" + haxeName + vdim,
						meta: makeNativeMeta(iname, "_set", haxeName + vdim, null, attribs, p),
						access: [APublic, AInline],
						kind: FFun({
							ret: macro :Void,
							expr: macro return,
							args: [for (c in 0...vdim) {name: "_v" + c, type: makeType(vta, false)}],
						}),
					});
				}
		}

		return attribFields;
	}

	public function externalFunction(attribs:Array<Attrib>, args:Array<FunctionArg>, ret:ComplexType = null, expr:Expr = null):FieldType {
		return FFun({
			ret: ret,
			expr: needsStubs(attribs) ? expr : null,
			args: args,
		});
	}

	public function embeddedFunction(args:Array<FunctionArg>, ret:ComplexType = null, expr:Expr = null):FieldType {
		return FFun({
			ret: ret,
			expr: expr,
			args: args,
		});
	}

	public function makeStubs( attribs:Array<Attrib> ) : Bool {
		for (a in attribs) {
			switch (a) {
				case AStatic:
					return false;
				default:
			}
		}
		return true;
	}
	public function needsStubs(attribs:Array<Attrib>):Bool {
		return true;
	}

	private static function capitalize(text:String) {
		return text.charAt(0).toUpperCase() + text.substring(1);
	}

	function makeName(name:String) {
		// name - list of comma separated prefixes
		if (opts.chopPrefix != null) {
			var prefixes = opts.chopPrefix.split(',');
			for (prefix in prefixes) {
				if (StringTools.startsWith(name, prefix)) {
					name = name.substr(prefix.length);
				}
			}
		}
		return capitalize(name);
	}

	function defVal(t:TypeAttr, p:Position = null):Expr {
		if (p == null)
			p = defaultPos;
		return switch (t.t) {
			case TVoid: throw "assert";
			case TInt, TUInt, TShort, TInt64, TChar: {expr: EConst(CInt("0")), pos: p};
			case TFloat, TDouble: {expr: EConst(CFloat("0.")), pos: p};
			case TBool: {expr: EConst(CIdent("false")), pos: p};
			case TEnum(name): EConst(CInt("0")).at(p); //(EField(EConst(CIdent(name)).at(p), "fromIndex").at(p), [EConst(CInt("0")).at(p)]).at(p); // { expr : , pos : p };
			case TCustom(id):
				var ex = {expr: EConst(CInt("0")), pos: p};
				var tp = TPath({pack: [], name: id});

				if (_typeInfos.exists(id)) {expr: ECast(ex, tp), pos: p}; else {expr: EConst(CIdent("null")), pos: p};
			default:
				{expr: EConst(CIdent("null")), pos: p};
		}
	}

	public function makeAbstract(name:String, attrs:Array<Attrib>, type:String, p:haxe.macro.Expr.Position) :Array<TypeDefinition>{

		var abstractDefn:TypeDefinition = {
			pos: p,
			pack: _pack,
			name: makeName(name),
			meta: [],
			kind: TDAbstract(type.asComplexType(), []),
			fields: [],
		};

		trace('makeAbstract ${name} ${type} ${abstractDefn}');


		return [abstractDefn];
	}

	public function makeEnum(name:String, attrs:Array<Attrib>, values:Array<String>, fields:Array<idl.Data.Field>, p:haxe.macro.Expr.Position) : Array<{def: haxe.macro.TypeDefinition, path: haxe.macro.TypePath}> {
		var index = 0;
		function cleanEnum(v:String):String {
			return v.replace(":", "_");
		}
		var cfields = [
			for (v in values)
				{pos: p, name: cleanEnum(v), kind: FVar(null, {expr: EConst(CInt("" + (index++))), pos: p})}
		];

		// Add Int Conversion
		var ta:TypeAttr = {t: TInt, attr: [AStatic]};
		var toValue = makeNativeFieldRaw(name, "indexToValue", p, [{name: "index", opt: false, t: {t: TInt, attr: []}}], ta, true);
		cfields.push(toValue);

		ta = {t: TInt, attr: [AStatic]};
		var toIndex = makeNativeFieldRaw(name, "valueToIndex", p, [{name: "value", opt: false, t: {t: TInt, attr: []}}], ta, true);
		cfields.push(toIndex);

		ta = {t: TEnum(name), attr: [AStatic]};
		var fromValue = makeNativeFieldRaw(name, "fromValue", p, [{name: "value", opt: false, t: {t: TInt, attr: []}}], ta, true);
		cfields.push(fromValue);

		ta = {t: TEnum(name), attr: [AStatic]};
		var fromIndex = makeNativeFieldRaw(name, "fromIndex", p, [{name: "index", opt: false, t: {t: TInt, attr: []}}], ta, true);
		cfields.push(fromIndex);

		ta = {t: TInt, attr: []};
		var toValue = makeNativeFieldRaw(name, "toValue", p, [], ta, true);
		cfields.push(toValue);

		var enumT:TypeDefinition = {
			pos: p,
			pack: _pack,
			name: makeName(name),
			meta: [],
			kind: TDAbstract(macro :Int, [AbEnum]),
			fields: cfields,
		};

		var enumTP:TypePath = {
			pack: _pack,
			name: enumT.name
		};

		return [{def: enumT, path: enumTP}];
	}

	function getFieldAccess(isStatic : Bool, isPublic : Bool, isInline = false) :Array<Access> {
		var access = [];
		if (isStatic) 
			access.push(AStatic);
		if (isPublic)
			access.push(APublic);
		if (isInline)
			access.push(AInline);
		return access;
	}

	function makeReturnExpression(ret:TypeAttr, pos:Position) {
		return  (ret.t == TVoid) ? {expr: EBlock([]), pos: pos} :  {expr: EReturn(defVal(ret)), pos: pos};

	}
	public function makeNativeFieldRaw(iname:String, fname:String, pos:Position, args:Array<FArg>, ret:TypeAttr, pub:Bool, external = true):Field {
		var name = fname;
		var isConstr = name == iname || fname == "new";
		if (isConstr) {
			name = "new";
			ret = {t: TCustom(iname), attr: []};
		}

		var expr = if (ret.t == TVoid) {expr: EBlock([]), pos: pos}; else {expr: EReturn(defVal(ret)), pos: pos};

		var access:Array<Access> = getFieldAccess(isConstr || ret.attr.contains(AStatic), pub);

		var fnargs = [
			for (a in args) {
				// This pattern is brutallly bad There must be a cleaner way to do this
				var sub = false;
				for (aattr in a.t.attr) {
					switch (aattr) {
						case ASubstitute(_):
							sub = true;
							break;
						default:
					}
				}
				if (a.t.attr.contains(AReturn) || sub) {
					continue;
				}
				{name: a.name, opt: a.opt, type: makeType(a.t, false)}
			}
		];

		
		var x = {
			pos: pos,
			name: pub ? name : name + args.length,
			meta: makeNativeMeta(iname, null, name, args.length, ret.attr, pos),
			access: access,
			kind: external ? externalFunction(ret.attr, fnargs, makeType(ret, true), expr) : embeddedFunction(fnargs, makeType(ret, true), expr),
		};

		return x;
	}

	public function makeNativeField(iname:String, hname:String, f:idl.Data.Field, args:Array<FArg>, ret:TypeAttr, pub:Bool):Field {
		return makeNativeFieldRaw(iname, hname, f.pos.asMacroPos(), args, ret, pub);
	}

	function makeEither(arr:Array<ComplexType>) {
		var i = 0;
		var t = arr[i++];
		while (i < arr.length) {
			var t2 = arr[i++];
			t = TPath({pack: ["haxe", "extern"], name: "EitherType", params: [TPType(t), TPType(t2)]});
		}
		return t;
	}

	public function addSimpleMethod(f, iname, haxeName, args, ret, p) {
		return [makeNativeField(iname, haxeName, f, args, ret, true)];	
	}
	public function addInterfaceMethod(f:idl.Data.Field, iname:String, haxeName:String, variants: Array<MethodVariant>, p:Position):Array<haxe.macro.Field> {
//		trace('addInterfaceMethod ${iname} ${haxeName} ${variants} ${p}');
		var varFields = [];
		// create dispatching code
		var maxArgs = 0;
		for (v in variants)
			if (v.args.length > maxArgs)
				maxArgs = v.args.length;

		if (variants.length > 1 && maxArgs == 0)
			error("Duplicate method declaration", variants.pop().pos.asMacroPos());
		var attribs = attribsFromField(f);

		var targs:Array<FunctionArg> = [];
		var argsTypes = [];
		for (i in 0...maxArgs) {
			var types:Array<{t:TypeAttr, sign:String}> = [];
			var names = [];
			var opt = false;
			for (v in variants) {
				var a = v.args[i];
				if (a == null) {
					opt = true;
					continue;
				}
				var sign = haxe.Serializer.run(a.t);
				var found = false;
				for (t in types)
					if (t.sign == sign) {
						found = true;
						break;
					}
				if (!found)
					types.push({t: a.t, sign: sign});
				if (names.indexOf(a.name) < 0)
					names.push(a.name);
				if (a.opt)
					opt = true;
			}
			argsTypes.push(types);
			targs.push({
				name: names.join("_"),
				opt: opt,
				type: makeEither([for (t in types) makeType(t.t, false)]),
			});
		}

		// native impls
		var retTypes:Array<{t:TypeAttr, sign:String}> = [];
		for (v in variants) {
			var f = makeNativeField(iname, haxeName, f, v.args, v.ret, false);

			var sign = haxe.Serializer.run(v.ret);
			var found = false;
			for (t in retTypes)
				if (t.sign == sign) {
					found = true;
					break;
				}
			if (!found)
				retTypes.push({t: v.ret, sign: sign});

			varFields.push(f);
		}

		variants.sort(function(v1, v2) return v1.args.length - v2.args.length);

		final isConstr = false;

		// dispatch only on args count
		function makeCall(v:{args:Array<FArg>, ret:TypeAttr}):Expr {
			var ident = isConstr ? ((iname + "." + haxeName) + v.args.length).asFieldAccess(p) : ((haxeName) + v.args.length).asFieldAccess(p);
			var e:Expr = {
				expr: ECall(ident, [
					for (i in 0...v.args.length)
						{expr: ECast({expr: EConst(CIdent(targs[i].name)), pos: p}, null), pos: p}
				]),
				pos: p
			};
			if (v.ret.t != TVoid)
				e = {expr: EReturn(e), pos: p};
			else if (isConstr) {
				e = macro this = $e;
			}
			return e;
		}

		//trace('maxArgs ${maxArgs} iname ${iname} fname ${f.name}');
		var expr = makeCall(variants[variants.length - 1]);
		for (i in 1...variants.length) {
			var v = variants[variants.length - 1 - i];
			//trace ('${targs} vs v.args.length ${v.args.length}');
			var aname = targs[v.args.length].name;
			var call = makeCall(v);
			expr = macro if ($i{aname} == null) $call else $expr;
		}
		
		var interfaceCT = iname.asComplexType();


		// only constructors at the moment
		varFields.push({
			name: haxeName,
			pos: f.pos.asMacroPos(),
			access: [APublic, AInline],
			kind: isConstr ? embeddedFunction(targs, interfaceCT, expr) : externalFunction(attribs, targs, makeEither([for (t in retTypes) makeType(t.t, false)]), expr),
		});

		return varFields;
	}

	public function makeConstructor(f:idl.Data.Field, iname:String, haxeName:String, variants: Array<MethodVariant>, p:Position):Array<haxe.macro.Field> {
		return addInterfaceMethod(f, iname, haxeName, variants, p);
	}

	dynamic function error(msg:String, p:haxe.macro.Expr.Position) {
		#if macro
		Context.error(msg, p);
		#else
		if (p != null)
			trace('${p}:' + msg);
		else
			trace(msg);
		#end
	}
}
