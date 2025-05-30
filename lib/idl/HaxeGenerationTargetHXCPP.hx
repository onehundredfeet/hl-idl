package idl;

import haxe.io.UInt8Array;
import haxe.macro.Printer;
import idl.Data;
import haxe.macro.Expr;

using StringTools;
using idl.macros.MacroTools;

import idl.HaxeGenerationTarget;

class HaxeGenerationTargetHXCPP extends HaxeGenerationTarget {
	static final PROXY_NEW_NAME = "alloc";
	static final PROXY_DELETE_NAME = "free";
	static final PROXY_STRUCT_MAKE = "make";
	static final REDIRECT_PREFIX = "_r_";

	function getTargetCondition():String {
		return "#if cpp";
	}

	public function makeNativeMeta(iname:String, midfix:String, name:String, argc:Null<Int>, attrs:Array<Attrib>,
			p:haxe.macro.Expr.Position):Array<MetadataEntry> {
		for (a in attrs) {
			switch (a) {
				case AInternal(iname):
					var nativeMeta:MetadataEntry = {name: ":native", params: [iname.asConstExpr()], pos: p};
					return [nativeMeta];
				default:
			}
		}
		return null;
	}

	function makeVectorType(t:TypeAttr, vt:Type, vdim:Int, isReturn:Bool):ComplexType {
		var isOut = t.attr != null && t.attr.contains(AOut);

		return switch (vt) {
			case TFloat:
				switch (vdim) {
					case 2: macro :hvector.Vec2;
					case 3: macro :hvector.Vec3;
					case 4: macro :hvector.Vec4;
					default: throw "Unsupported vector dimension" + vdim;
				}
			case TInt:
				switch (vdim) {
					case 2: macro :hvector.Int2;
					case 3: macro :hvector.Int3;
					case 4: macro :hvector.Int4;
					default: throw "Unsupported vector dimension" + vdim;
				}
			case TDouble:
				switch (vdim) {
					case 2: macro :hvector.Float2;
					case 3: macro :hvector.Float3;
					case 4: macro :hvector.Float4;
					default: throw "Unsupported vector dimension" + vdim;
				}

			default: throw "Unsupported vector type " + vt;
		};
	}

	function makeType(t:TypeAttr, isReturn:Bool):ComplexType {
		var isOut = t.attr != null && t.attr.contains(AOut);

		return switch (t.t) {
			case TVoid: macro :Void;
			case TChar: macro :cpp.Char;
			case TInt, TUInt: (isOut) ? macro :cpp.Pointer<Int> : macro :Int;
			case TInt64: ((isOut ? (macro :cpp.Pointer<haxe.Int64>) : (macro :haxe.Int64)));
			case TShort: macro :cpp.Char;
			case TFloat: ((isOut ? (macro :cpp.Pointer<Single>) : (macro :Single)));
			case TDouble: ((isOut ? (macro :cpp.Pointer<Float>) : (macro :Float)));
			case TBool: ((isOut ? (macro :cpp.Pointer<Bool>) : (macro :Bool)));
			case TDynamic: macro :Dynamic;
			case TType: throw "Unsupported type TType";
			case THString: isReturn && false ? macro :hl.Bytes : macro :String;
			case TCString: macro :cpp.ConstPointer<cpp.Char>;
			case TStdString: macro :cpp.StdStringRef;
			case TAny: macro :idl.Types.Any;
			case TEnum(enumName): isReturn ? enumName.asComplexType() : macro :Int;
			case TStruct: throw "Unsupported type TType";
			case TBytes: macro :cpp.Pointer<cpp.UInt8>;
			case TIOBytes: macro :haxe.io.Bytes;
			case TVector(vt, vdim): makeVectorType(t, vt, vdim, isReturn);
			case TPointer(pt):
				switch (pt) {
					case TChar: macro :cpp.Pointer<cpp.Char>;
					case TInt: macro :cpp.Pointer<Int>;
					case TUInt: macro :cpp.Pointer<UInt>;
					case TFloat: macro :cpp.Pointer<Single>;
					case TDouble: macro :cpp.Pointer<Float>;
					case TBool: macro :cpp.Pointer<Bool>;
					case TShort: macro :cpp.Pointer<cpp.UInt16>;
					case TVector(vt, dim):
						switch (vt) {
							case TFloat: macro :cpp.Pointer<Single>;
							case TDouble: macro :cpp.Pointer<Float>;
							case TInt: macro :cpp.Pointer<Int>;
							default: throw "Unsupported array vector type " + vt;
						}
					case TCustom(id):
						// var x : TypeParam;
						// TPath({pack: ["cpp"], name: "Pointer", params: [TPType(TPath(_typeInfos[id].path))]});
						(id + "Ptr").asComplexType();
					default:
						throw 'Unsupported array type. Sorry ${pt}';
				}
			case TArray(at, _):
				switch (at) {
					case TChar: macro :Array<cpp.Char>;
					case TInt: macro :Array<Int>;
					case TUInt: macro :Array<UInt>;
					case TFloat: macro :Array<Single>;
					case TDouble: macro :Array<Float>;
					case TBool: macro :Array<Bool>;
					case TShort: macro :Array<cpp.UInt16>;
					case TVector(t, dim): switch (t) {
							case TInt: switch (dim) {
									case 2: macro :hvector.Int2Array;
									case 3: macro :hvector.Int3Array;
									case 4: macro :hvector.Int4Array;
									default: macro :Array<Int>;
								}
							case TFloat:
								switch (dim) {
									case 2: macro :hvector.Vec2Array;
									case 3: macro :hvector.Vec3Array;
									case 4: macro :hvector.Vec4Array;
									default: macro :Array<Single>;
								}
							case TDouble:
								switch (dim) {
									case 2: macro :hvector.Float2Array;
									case 3: macro :hvector.Float3Array;
									case 4: macro :hvector.Float4Array;
									default: macro :Array<Float>;
								}
							default: throw "Unsupported array type. Sorry";
						}
					case TCustom(id):
						if (_typeInfos.exists(id)) TPath({pack: ["cpp"], name: "NativeArray", params: [TPType(TPath(_typeInfos[id].path))]}); else
							TPath({pack: ["cpp"], name: "NativeArray", params: [TPType(TPath({pack: [], name: makeName(id)}))]});

					default:
						throw "Unsupported array type. Sorry";
				}
			//			var tt = makeType({ t : t, attr : [] });
			//			macro : idl.Types.NativePtr<$tt>;
			case TVoidPtr: macro :idl.Types.VoidPtr;
			case TFunction(ret, ta):
				var retT = makeType(ret, false);

				var args = ta.map((x) -> makeType(x, false));
				//			macro : GameControllerPtr -> hl.Bytes -> $retT;
				TFunction(args, retT);
			case TCustom(id):
				if (_typeInfos.exists(id)) {
					var ti:HaxeGenerationTypeInfo = _typeInfos.get(id);
					// trace('custom type ${id} has ${ti}');

					switch (ti.kind) {
						case DInterface(name, attrs, _, _):
							var ict = name.asComplexType();
							macro :$ict;
						default:
							TPath(ti.path);
					}
				} else {
					trace('no info for ${id}');
					TPath({pack: [], name: makeName(id)});
				}
		}
	}

	// public override function makeConstructor(f:idl.Data.Field, iname:String, haxeName:String, variants: Array<MethodVariant>, p:Position):Array<haxe.macro.Expr.Field> {
	// 	if (variants.length != 1) {
	// 		throw "Unsupported number of variants for constructor";
	// 	}
	// 	trace('makeConstructor ${iname} ${haxeName} ${variants}');
	// 	return [makeNativeField(iname, haxeName, f, variants[0].args, variants[0].ret, true)];
	// 	//return addSimpleMethod(f, iname, haxeName, variants[0].args, variants[0].ret, p);
	// 	// var name = fname;
	// 	// var isConstr = name == iname || fname == "new";
	// 	// if (isConstr) {
	// 	// 	name = "new";
	// 	// 	ret = {t: TCustom(iname), attr: []};
	// 	// }
	// 	// var expr = if (ret.t == TVoid) {expr: EBlock([]), pos: pos}; else {expr: EReturn(defVal(ret)), pos: pos};
	// 	// var access:Array<Access> = getFieldAccess(isConstr || ret.attr.contains(AStatic), pub);
	// 	// var fnargs = [
	// 	// 	for (a in args) {
	// 	// 		// This pattern is brutallly bad There must be a cleaner way to do this
	// 	// 		var sub = false;
	// 	// 		for (aattr in a.t.attr) {
	// 	// 			switch (aattr) {
	// 	// 				case ASubstitute(_):
	// 	// 					sub = true;
	// 	// 					break;
	// 	// 				default:
	// 	// 			}
	// 	// 		}
	// 	// 		if (a.t.attr.contains(AReturn) || sub) {
	// 	// 			continue;
	// 	// 		}
	// 	// 		{name: a.name, opt: a.opt, type: makeType(a.t, false)}
	// 	// 	}
	// 	// ];
	// 	// var x = {
	// 	// 	pos: pos,
	// 	// 	name: pub ? name : name + args.length,
	// 	// 	meta: makeNativeMeta(iname, null, name, args.length, ret.attr, pos),
	// 	// 	access: access,
	// 	// 	kind: external ? externalFunction(fnargs, makeType(ret, true), expr) : embeddedFunction(fnargs, makeType(ret, true), expr),
	// 	// };
	// 	// return [x];
	// }
	// dispatch only on args count
	function makeSimpleCall(self:Bool, iname:String, haxeName:String, args:Array<FArg>, ret:TypeAttr, p):Expr {
		var ident = (haxeName).asFieldAccess(p);

		var typical_args = [
			for (i in 0...args.length)
				{expr: ECast({expr: EConst(CIdent(args[i].name)), pos: p}, null), pos: p}
		];

		var thisExpr = macro asPtr();
		// EConst(CIdent("this"))
		var e:Expr = {
			expr: ECall(ident, (self ? [{expr: thisExpr.expr, pos: p}] : []).concat(typical_args)),
			pos: p
		};
		if (ret.t != TVoid)
			e = {expr: EReturn(e), pos: p};

		return e;
	}

	public override function addSimpleMethod(f, iname, haxeName, args, ret:TypeAttr, p):Array<haxe.macro.Expr.Field> {
		var isCStyleCall = false;
		var isStatic = false;

		for (a in ret.attr) {
			switch (a) {
				case AStatic:
					isStatic = true;
				case ACObject:
					isCStyleCall = true;
				default:
			}
		}
		if (!isCStyleCall) {
			return [makeNativeField(iname, haxeName, f, args, ret, true)];
		}

		var redirectName = REDIRECT_PREFIX + haxeName;
		// var redirectField = makeNativeField(iname, redirectName, f, args, ret, true);

		var name = haxeName;
		var isConstr = name == iname || haxeName == "new";
		if (isConstr) {
			throw "Unsupported C-style constructor";
		}
		if (isConstr) {
			name = "new";
			ret = {t: TCustom(iname), attr: []};
		}

		var typical_args:Array<FunctionArg> = [
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

		var redirect_args:Array<FunctionArg> = [{name: "This", type: makeType({t: TPointer(TCustom(iname)), attr: []}, false)}].concat(typical_args);

		var blank_expr = if (ret.t == TVoid) {expr: EBlock([]), pos: p}; else {expr: EReturn(defVal(ret)), pos: p};

		var redirect_field = {
			pos: p,
			name: redirectName,
			meta: makeNativeMeta(iname, null, name, args.length, ret.attr, p),
			access: getFieldAccess(true, false),
			kind: externalFunction(null, redirect_args, makeType(ret, true), blank_expr),
		};

		var external = true;
		var makeStubs = true;

		var x = {
			pos: p,
			name: name,
			meta: null,
			access: getFieldAccess(isConstr || isStatic, true, true),
			kind: embeddedFunction(typical_args, makeType(ret, true), makeStubs ? makeSimpleCall(true, iname, redirectName, args, ret, p) : null),
		};

		return [redirect_field, x];
	}

	public override function makeNativeFieldRaw(iname:String, fname:String, pos:Position, args:Array<FArg>, ret:TypeAttr, pub:Bool, external = true):Field {
		var name = fname;
		var isConstr = name == iname || fname == "new";

		if (isConstr) {
			name = "new";
			ret = {t: TCustom(iname), attr: []};
		}

		var expr = if (ret.t == TVoid) {expr: EBlock([]), pos: pos}; else {expr: EReturn(defVal(ret)), pos: pos};

		var access:Array<Access> = getFieldAccess(isConstr || ret.attr.contains(AStatic), pub);

		access.push(AExtern);
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

		for (a in ret.attr) {
			switch (a) {
				case AStatic:
					expr = null;
				default:
			}
		}

		var x = {
			pos: pos,
			name: pub ? name : name + args.length,
			meta: makeNativeMeta(iname, null, name, args.length, ret.attr, pos),
			access: access,
			kind: external ? externalFunction(ret.attr, fnargs, makeType(ret, true), expr) : embeddedFunction(fnargs, makeType(ret, true), expr),
		};

		return x;
	}

	function getMacroBuilderExpr():Expr {
		var idlPathExpr = ("${" + opts.packageName.toUpperCase() + "_IDL_DIR}/" + opts.packageName + ".idl").asConstExpr();
		var macroBuildExpr = macro idl.macros.MacroTools.buildHXCPPIDLType($idlPathExpr);
		return macroBuildExpr;
	}

	function getMacroBuilderMeta(p:haxe.macro.Expr.Position):MetadataEntry {
		return {name: ":build", params: [getMacroBuilderExpr()], pos: p};
	}

	public function getInterfaceTypeDefinitions(iname:String, attrs:Array<Attrib>, pack:Array<String>, dfields:Array<Field>, ikind:InterfaceKind,
			p:Position):Array<TypeDefinition> {
		var abstractNewField:Field = null;
		var staticNew:Field = null;
		var staticDelete:Field = null;
		var statics:Array<Field> = [];
		var intName = iname;
		var nativeName = makeName(intName);
		var haxeName = makeName(iname);
		// var proxyName = isObject ? haxeName + "Native" : haxeName;
		var proxyName = haxeName;
		var fullProxyName = pack.join(".") + "." + proxyName;
		var isObject = false;
		var isNamespace = false;
		var isAbstract = false;
		var abstractType = switch (ikind) {
			case IKAbstract(name):
				isAbstract = true;
				name;
			case IKObject:
				isObject = true;
				null;
			case IKNamespace:
				isNamespace = true;
				null;
			default: null;
		}
		var abstractCT = null;
		if (isAbstract) {
			abstractCT = makeType({t: abstractType, attr: []}, false);
		}
		var proxyCT = fullProxyName.asComplexType();
		var proxyCP = fullProxyName.asTypePath();
		var ptrCT = 'cpp.Pointer'.asComplexType([TPType(proxyCT)]);
		var structCT = 'cpp.Struct'.asComplexType([TPType(proxyCT)]);
		var shortPtrName = haxeName + "Ptr";
		var shortRefName = haxeName + "Ref";
		var shortStructName = haxeName + "Struct";
		var arrayDataName = haxeName + "ArrayData";
		var arrayName = haxeName + "Array";
		var arrayCT = arrayName.asComplexType();
		var arrayDataCT = arrayDataName.asComplexType();
		var arrayDataCP = arrayDataName.asTypePath();
		var arrayCP = arrayName.asTypePath();

		var fullPtrName = pack.join(".") + "." + shortPtrName;
		var fullRefName = pack.join(".") + "." + shortRefName;
		var fullStructName = pack.join(".") + "." + shortStructName;
		var fullPtrCT = fullPtrName.asComplexType();

		var allowArray = false;
		for (a in attrs)
			switch (a) {
				// case APrefix(name): prefix = name;
				case AInternal(iname):
					intName = iname;
				// case ANew(name): newName = name;
				// case ADelete(name): deleteName = name;
				// case ADestruct(expression): destructExpr = expression;
				case AAllowArray:
					allowArray = true;
				default:
			}

//		trace('Interface ${ikind} ${iname}');
		if (isObject) {
			for (df in dfields) {
				if (df.name == "new") {
					abstractNewField = df;
				} else if (df.name.startsWith("new")) {
					staticNew = df;
				} else if (df.access.contains(AStatic) && df.access.contains(APublic)) {
					// statics.push(df);
				}
			}
		}
		var hasNew = abstractNewField != null || staticNew != null;

		if (abstractNewField != null) {
			dfields.remove(abstractNewField);
		}
		if (isObject) {
			for (s in statics) {
				dfields.remove(s);
				// switch(s.kind) {
				// 	case FFun(f):
				// 		f.expr = macro return null;
				// 	default:
				// }
			}
		}

		var newArgs = null;

		if (staticNew != null) {
			dfields.remove(staticNew);
			staticNew.name = staticNew.name = PROXY_NEW_NAME;
			staticNew.access = [APublic, AStatic, AExtern];
			var newMeta:MetadataEntry = {name: ":native", params: ['new ${intName}'.asConstExpr()], pos: p};
			if (staticNew.meta == null) {
				staticNew.meta = [newMeta];
			} else {
				staticNew.meta = staticNew.meta.concat([newMeta]);
			}
			switch (staticNew.kind) {
				case FFun(f):
					var classNameExpr = iname.asComplexType();
					f.ret = fullPtrCT;
					f.expr = null; // macro return null;
					newArgs = f.args;
				default:
					throw "Unsupported kind for new field";
			}

			staticDelete = {
				pos: p,
				name: PROXY_DELETE_NAME,
				meta: [{name: ":native", params: ['delete '.asConstExpr()], pos: p}],
				access: [APublic, AExtern],
				kind: FFun({args: [], ret: macro :Void, expr: null}),
			};
		}
		// var e : MetadataEntry;

		// var nativeName = makeName(iname) + "Extern";
		// var includes = opts.includes.map((x) -> {name: ":include", params:[x.asConstExpr()], pos: p});
		// var proxyDefn = {
		// 	pos: p,
		// 	pack: pack,
		// 	name: nativeName,
		// 	meta: includes.concat([{name: ":native", params:[makeName(iname).asConstExpr()], pos: p}]),
		// 	isExtern: true,
		// 	kind: TDClass(), //TDAbstract(macro :idl.Types.Ref, [], [macro :idl.Types.Ref], [macro :idl.Types.Ref]),
		// 	fields: dfields,
		// };

		// var proxyCT = nativeName.asComplexType();

		// var abstractDefn = {
		// 	pos: p,
		// 	pack: pack,
		// 	name: makeName(iname),
		// 	meta: [{name: ":forward", pos: p}, {name: ":forwardStatics", pos: p}],
		// 	isExtern: false,
		// 	kind: TDAbstract(proxyCT, [], [proxyCT], [proxyCT]),
		// 	fields: abstractNewField != null ? [abstractNewField] : [],
		// };
		// return [proxyDefn, abstractDefn];

		var includes = opts.includes.map((x) -> {name: ":include", params: [x.asConstExpr()], pos: p});
		var buildXML = "${" + opts.packageName.toUpperCase() + "_IDL_DIR}/" + opts.packageName + ".xml";

		var objFields = null;
		if (isObject) {
			var asPtrFieldClass:Field = {
				pos: p,
				name: "asPtr",
				meta: [],
				access: [APublic, AInline],
				kind: FFun({args: [], ret: fullPtrCT, expr: macro return cpp.Pointer.addressOf(this)}),
			};
			objFields = [asPtrFieldClass];

			if (hasNew) {
				var structMake = {
					pos: p,
					name: PROXY_STRUCT_MAKE,
					meta: [{name: ":native", params: [${intName}.asConstExpr()], pos: p}],
					access: [APublic, AStatic],
					kind: FFun({args: newArgs, ret: fullProxyName.asComplexType(), expr: null}), // macro {return null;}
				};

				objFields.push(structMake);
			}

			if (allowArray) {
				var arrayRet = macro :Array<$proxyCT>;
				var arrayAlloc = {
					pos: p,
					name: "array",
					meta: [],
					access: [APublic, AStatic, AInline],
					kind: FFun({
						args: [{name: "size", type: macro :Int},],
						ret: arrayRet,
						expr: macro return cpp.NativeArray.create(size)
					}), // macro {return null;}
				};
				objFields.push(arrayAlloc);
			}
			
		}

		var coreClassFields = isObject ? dfields.concat(objFields) : dfields;
		var classNativeDefn = {
			pos: p,
			pack: pack,
			name: proxyName,
			meta: [
				{name: ":native", params: [intName.asConstExpr()], pos: p},
				{name: ":structAccess", params: null, pos: p},
				{name: ":unreflective", params: null, pos: p},
				{name: ":nativeArrayAccess", params: null, pos: p},

				getMacroBuilderMeta(p),
				// {name: ":buildXml", params:['<include name="${buildXML}"/>'.asConstExpr()], pos: p},
			],
			isExtern: true,
			kind: isAbstract ? TDAbstract(abstractCT, [], [abstractCT],
				[abstractCT]) : TDClass(), // TDAbstract(macro :idl.Types.Ref, [], [macro :idl.Types.Ref], [macro :idl.Types.Ref]),
			fields: coreClassFields,
		}

		// ECall(EField(EConst(CIdent(name)).at(p), "fromIndex").at(p), [EConst(CInt("0")).at(p)]).at(p); // { expr : , pos : p };

		var fullConstructPath = fullProxyName + "." + PROXY_NEW_NAME;
		var proxyConstructExpr = fullConstructPath.asFieldAccess().asCallExpr([], p).asPrivateAccessExpr(p);
		var newWrapper = (macro this = $proxyConstructExpr).asPublicFunctionField("alloc", [], fullPtrCT, p);

		if (isObject) {
			var printer = new Printer();
			var redirects = dfields.filter(x -> x.name.startsWith(REDIRECT_PREFIX)).map(x -> x.name.substring(REDIRECT_PREFIX.length));

			var passthrough = dfields.filter(x -> !x.name.startsWith(REDIRECT_PREFIX)).filter(x -> {
				switch(x.kind) {
					case FFun(f):
						if (!redirects.contains(x.name)) {
							return true;
						}
					default:
				}
				return false;
			}).map(x -> x.name);

			//trace('redirects ${redirects}');
			// var stubs = dfields.filter(x -> redirects.contains(x.name));
			// var ptrRedirects = stubs;
			var ptrRedirects = dfields.filter(x -> redirects.contains(x.name)).map(x -> {
				var fun = switch (x.kind) {
					case FFun(f): f;
					default: throw "Unsupported kind for redirect field";
				}

				var y:Field = Reflect.copy(x);

				var yfun = Reflect.copy(fun);
				var callInfo = switch (yfun.expr.expr) {
					case ECall(ecall, params):
						{call: ecall, params: params, ret: false};
					case EReturn(rete):
						switch (rete.expr) {
							case ECall(ecall, params):
								{call: ecall, params: params, ret: true};
							default:
								throw "Unsupported return expression ${rete.expr.expr}";
						}
					default: throw 'Unsupported return expression ${yfun.expr.expr}';
				}
				var params = callInfo.params.copy();
				params.shift();
				params.unshift(EConst(CIdent("this")).at(p));

				var callExpr = (fullProxyName + "." + REDIRECT_PREFIX + y.name).asFieldAccess(p);

				trace('ptrRedirects ${x.name} ${printer.printExpr(callExpr)}');
				yfun.expr = switch (callInfo.ret) {
					case true:
						{expr: EReturn({expr: ECall(callExpr, params), pos: p}), pos: p};
					case false:
						{expr: ECall(callExpr, params), pos: p};
				}

				y.kind = FFun(yfun);
				y;
			});

			ptrRedirects = ptrRedirects.concat(dfields.filter(x -> passthrough.contains(x.name)).map(x -> {
				var fun = switch (x.kind) {
					case FFun(f): f;
					default: throw "Unsupported kind for redirect field";
				}

				var y:Field = Reflect.copy(x);
				y.access = Reflect.copy(y.access);
				y.access.push(AInline);
				y.access = y.access.filter(a ->a != AExtern);
				var yfun = Reflect.copy(fun);
				var hasRet = switch(fun.ret) {
					case TPath(p):
						if (p.pack.length == 0 && p.name == "Void") {
							false;
						} else {
							true;
						}
					default:
						true;
				};

				//trace('ptrRedirects passthrough ${x.name} hasRet ${hasRet}');
				var params = yfun.args == null ? [] : yfun.args.map(arg -> arg.name.asIdentExpr(p));
//				trace('params ${params}');
				var ecall = ECall(("this.ref." + x.name).asFieldAccess(p), params).at(p);

//				trace('ecall ${printer.printExpr(ecall)}');
				

				yfun.expr = hasRet ?  EReturn( ecall ).at(p) : ecall;

				y.kind = FFun(yfun);
				y;
			}));

			var asPtrFieldPtrClass:Field = {
				pos: p,
				name: "asPtr",
				meta: [],
				access: [APublic, AInline],
				kind: FFun({args: [], ret: fullPtrCT, expr: macro return this}),
			};
			var fromCast:Field = {
				pos: p,
				name: "fromCast",
				meta: [{name: ":from", params: [], pos: p}],
				access: [APublic, AStatic, AInline],
				kind: FFun({
					args: [
						{
							name: "self",
							type: macro :cpp.Reference<$proxyCT>,
						}
					],
					ret: fullPtrCT,
					expr: macro return cpp.Pointer.addressOf(self)
				}),
			};
//			trace('object fields - ptrRedirects ${ptrRedirects.length}');
			var ptrFields = statics.concat(staticNew != null ? [staticNew, staticDelete] : []).concat(ptrRedirects).concat([asPtrFieldPtrClass, fromCast]);
			var ptrDefn = {
				pos: p,
				pack: pack,
				name: shortPtrName,
				meta: [
					{name: ":forward", pos: p},
					{name: ":forwardStatics", pos: p},
					{name: ":unreflective", params: null, pos: p}
				],
				isExtern: true,
				kind: TDAbstract(ptrCT, [], [ptrCT], [ptrCT]),
				fields: ptrFields // abstractNewField != null ? [ newWrapper] : [],
			};

			// var refCT = 'cpp.Reference'.asComplexType([TPType(proxyCT)]);

			// var refDefn = {
			// 	pos: p,
			// 	pack: pack,
			// 	name: haxeName + "Ref",
			// 	meta: [{name: ":native", params: [intName.asConstExpr()], pos: p}],
			// 	isExtern: false,
			// 	kind: TDAbstract(refCT, [], [refCT], [refCT]),
			// 	fields: [] // abstractNewField != null ? [newWrapper] : [],
			// };

			// var structFields = hasNew ? [structMake] : [];
			// var structDefn = {
			// 	pos: p,
			// 	pack: pack,
			// 	name: shortStructName,
			// 	meta: [
			// 		{name: ":forward", pos: p},
			// 		{name: ":forwardStatics", pos: p},
			// 		// {name: ":unreflective", params: null, pos: p}
			// 	],
			// 	isExtern: false,
			// 	kind: TDAbstract(structCT, [], [structCT], [structCT]),
			// 	fields: structFields // abstractNewField != null ? [ newWrapper] : [],
			// };

			var abstractDefn = {
				pos: p,
				pack: pack,
				name: haxeName,
				meta: [{name: ":forward", pos: p}, {name: ":forwardStatics", pos: p}],
				isExtern: false,
				kind: TDAbstract(proxyCT, [], [proxyCT], [proxyCT]),
				fields: [] // abstractNewField != null ? [newWrapper] : [],
			};

			var refDefn = {
				pos: p,
				pack: pack,
				name: shortRefName,
				meta: [
					{name: ":native", params: [('cpp.Reference< ${intName} >').asConstExpr()], pos: p},
					//					{name: ":structAccess", params: null, pos: p},
					//				{name: ":unreflective", params: null, pos: p},
					//					getMacroBuilderMeta(p),
					// {name: ":buildXml", params:['<include name="${buildXML}"/>'.asConstExpr()], pos: p},
				],
				isExtern: true,
				kind: isAbstract ? TDAbstract(abstractCT, [], [abstractCT],
					[abstractCT]) : TDClass(fullProxyName.asTypePath()), // TDAbstract(macro :idl.Types.Ref, [], [macro :idl.Types.Ref], [macro :idl.Types.Ref]),
				fields: [],
			};

			var structDefn = {
				pos: p,
				pack: pack,
				name: shortStructName,
				meta: [
					{name: ":native", params: [('cpp.Struct< ${intName} >').asConstExpr()], pos: p},
					//					{name: ":structAccess", params: null, pos: p},
					//				{name: ":unreflective", params: null, pos: p},
					//					getMacroBuilderMeta(p),
					// {name: ":buildXml", params:['<include name="${buildXML}"/>'.asConstExpr()], pos: p},
				],
				isExtern: true,
				kind: isAbstract ? TDAbstract(abstractCT, [], [abstractCT],
					[abstractCT]) : TDClass(fullRefName.asTypePath()), // TDAbstract(macro :idl.Types.Ref, [], [macro :idl.Types.Ref], [macro :idl.Types.Ref]),
				fields: [],
			};


			var arrayDataDefn = macro class $arrayDataName {
				var _backing:Array<cpp.UInt8>;
				var _ptr:cpp.RawPointer<$proxyCT>;
				var _count:Int = 0;
				var _size:Int = 0;
				var _capacity:Int = 0;
				public function new(capacity:Int = 32) {
					_capacity = capacity;
					_size = cpp.Native.sizeof($i{proxyName});
					
					_backing = new Array<cpp.UInt8>();
					_backing.resize(_capacity * _size);
					_ptr = cast cpp.Pointer.ofArray(_backing).raw;
					_count = 0;
				}

				public var length(get, never):Int;
				inline function get_length():Int {
					return _count;
				}
				public inline function asPtr():cpp.Pointer<$proxyCT> {
					return cpp.Pointer.fromRaw(_ptr);
				}

				public inline function resize(newSize:Int) {
					if (newSize > _capacity) {
						_backing.resize(newSize * _size);
						_ptr = cast cpp.Pointer.ofArray(_backing).raw;
					}
					_count = newSize;
				}

				public inline function push( value:$proxyCT):Void {
					if (_count == _capacity) {
						var oldCapacity = _capacity;
						var newCapacity = _capacity * 2;
						_backing.resize(newCapacity * _size);
						_ptr = cast cpp.Pointer.ofArray(_backing).raw;
						_capacity = newCapacity;
					}
					_ptr[_count++] = value;
				}
			};
			
			// var arrayDataDefn = {
			// 	pos: p,
			// 	pack: pack,
			// 	name: arrayDataName,
			// 	meta: [],
			// 	isExtern: false,
			// 	kind: TDClass(arrayDataName.asTypePath()), // TDAbstract(macro :idl.Types.Ref, [], [macro :idl.Types.Ref], [macro :idl.Types.Ref]),
			// 	fields: [],
			// }

			var arrayProxyClass = macro class $arrayName {
				public function new(capacity:Int = 32) {
					this = new $arrayDataCP(capacity);
				}
				@:op([]) public inline function arrayRead(index:Int) : $proxyCT{
					if (index < 0 || index >= @:privateAccess this._count) {
						throw "Array index out of bounds";
					}
					return @:privateAccess this._ptr[index];
				}

				@:op([]) public inline function arrayWrite(index:Int, value:$proxyCT) {
					if (index < 0 || index >= @:privateAccess  this._count) {
						throw "Array index out of bounds";
					}
					return @:privateAccess this._ptr[index] = value;
				}
			};
			var arrayDefn = {
				pos: p,
				pack: pack,
				name: arrayName,
				meta: [{name: ":forward", pos: p}],
				isExtern: false,
				kind: TDAbstract(arrayDataCT, [], [arrayDataCT],
					[arrayDataCT]), // TDAbstract(macro :idl.Types.Ref, [], [macro :idl.Types.Ref], [macro :idl.Types.Ref]),
				fields: arrayProxyClass.fields,
			}

			
			/*

				@:generic
				@:nativeArrayAccess
				@:unreflective
				class NativeStructArrayData<T>  {
				var _backing:Array<T>;
				var _ptr:cpp.RawPointer<T>;
				var _ptr2:cpp.Pointer<T>;
				var _count:Int = 0;

				public function new(capacity:Int = 32) {
					_backing = cpp.NativeArray.create(capacity);
					_backing.resize(capacity);
					_ptr = cpp.Pointer.ofArray(_backing).raw;
				}

				// @:from
				// public static inline function fromArray<T>(array:Array<T>):Void {
				//     return 
				// }
				public var length(get,never):Int;
				inline function get_length():Int {
					return _count;
				}
				public inline function asPtr():cpp.Pointer<T> {
					return cpp.Pointer.fromRaw(_ptr);
				}
				public inline function asArray():Array<T> {
					return _backing;
				}
				public inline function push(value:T):Void {
					if (_count == _backing.length) {
						var length = _backing.length;
						_backing.resize(_backing.length * 2);
						_ptr = cpp.Pointer.ofArray(_backing).raw;
						_backing.resize(length);
					}
					_ptr[_count++] = value;
				}

				public inline function resize(newSize:Int):Void {
					_count = newSize;
				}

				}

				@:generic
				@:forward
				@:nativeArrayAccess
				abstract NativeStructArray<T>(NativeStructArrayData<T>) to NativeStructArrayData<T> from NativeStructArrayData<T> {
				public function new(capacity:Int) {
					this = new NativeStructArrayData<T>(capacity);
				}

				@:from public static inline function fromArray<S>(array:Array<S>) {
					var x : NativeStructArray<S> = new NativeStructArrayData<S>(array.length);
					for (i in 0...array.length) {
						x.push(array[i]);
					}
					return x;
				}
				@:op([]) public inline function arrayRead(index:Int) : T{
					return @:privateAccess this._ptr[index];
				}

				@:op([]) public inline function arrayWrite(index:Int, value:T) {
					return @:privateAccess this._ptr[index] = value;
				}
				}
			 */
			return allowArray ? [classNativeDefn, ptrDefn, arrayDataDefn, arrayDefn] : [classNativeDefn, ptrDefn]; // refDefn, structDefn
			/*
				package externs;

				import cpp.UInt8;
				import cpp.Pointer;

				@:include("./../lib/LibInclude.h")
				@:sourceFile("./../lib/RGB.cpp")
				@:native("RGB")
				extern class RGB
				{
				public var r:UInt8;
				public var g:UInt8;
				public var b:UInt8;

				public function getLuma():Int;
				public function toInt():Int;

				@:native("new RGB")
				public static function create(r:Int, g:Int, b:Int):Pointer<RGB>;

				@:native("~RGB")
				public function deleteMe():Void;
				}



				// By extending RGB we keep the same API as far as haxe is concerned, but store the data (not pointer)
				//  The native Reference class knows how to take the reference to the structure
				@:native("cpp.Reference<RGB>")
				extern class RGBRef extends RGB
				{
				}



				// By extending RGBRef, we can keep the same api, 
				//  rather than a pointer
				@:native("cpp.Struct<RGB>")
				extern class RGBStruct extends RGBRef
				{
				}




			 */
		}
		return [classNativeDefn];
	}

	// // By extending RGB we keep the same API as far as haxe is concerned, but store the data (not pointer)
	// //  The native Reference class knows how to take the reference to the structure
	// @:native("cpp.Reference<RGB>")
	// extern class RGBRef extends RGB
	// {
	// }
	// // By extending RGBRef, we can keep the same api,
	// //  rather than a pointer
	// @:native("cpp.Struct<RGB>")
	// extern class RGBStruct extends RGBRef
	// {
	// }

	public override function needsStubs(attribs:Array<Attrib>):Bool {
		if (attribs == null)
			return false;
		if (attribs.contains(AStatic))
			return true;
		return false;
	}

	public override function addAttribute(iname:String, haxeName:String, f:idl.Data.Field, t:TypeAttr, p:Position):Array<haxe.macro.Expr.Field> {
		var attribFields = [];
		var hasSet = t.attr == null || t.attr.indexOf(AReadOnly) < 0;
		var embed = t.attr != null && t.attr.indexOf(AEmbed) >= 0;
		var attribs = attribsFromField(f);

		var intName = null;
		for (a in attribs) {
			switch (a) {
				case AInternal(name):
					intName = name;
				default:
			}
		}
		switch (t.t) {
			case TArray(at, sizeField):
				throw "Unsupported array type. Sorry";

			default:
				var tt = makeType(t, false);

				// if (hasSet && !embed) {
				attribFields.push({
					pos: p,
					name: haxeName,
					meta: intName == null ? [] : [{name: ":native", params: [intName.asConstExpr()], pos: p}],
					kind: FVar(tt),
					access: [APublic],
				});
				// } else {
				// 	var fkind = hasSet ? FProp("get", "set", tt) : FProp("get", "never", tt);
				// 	attribFields.push({
				// 		pos: p,
				// 		name: haxeName,
				// 		kind: fkind,
				// 		meta: [],
				// 		access: [APublic],
				// 	});
				// 	attribFields.push({
				// 		pos: p,
				// 		name: "get_" + haxeName,
				// 		meta: [{name: ":native", params: [("get_" + haxeName).asConstExpr()], pos: p}],
				// 		kind: externalFunction([], makeType(t, true), macro return ${defVal(t)}),
				// 		access: [],
				// 	});
				// 	if (hasSet) {
				// 		attribFields.push({
				// 			pos: p,
				// 			name: "set_" + haxeName,
				// 			meta: [{name: ":native", params: [("set_" + haxeName).asConstExpr()], pos: p}],
				// 			access: [],
				// 			kind: externalFunction([
				// 				{
				// 					name: "_v",
				// 					type: tt
				// 				}
				// 			], tt, macro return ${defVal(t)})
				// 		});
				// 	}
				// }
		}

		return attribFields;
	}

	public override function makeEnum(name:String, attrs:Array<Attrib>, values:Array<String>, fields:Array<idl.Data.Field>,
			p:haxe.macro.Expr.Position):Array<{def:haxe.macro.Expr.TypeDefinition, path:haxe.macro.Expr.TypePath}> {
		var index = 0;
		function cleanEnum(v:String):String {
			return v.replace(":", "_");
		}
		var hasNamespace = true;
		var namespaceName = name;
		var prefix = "";
		var enumClass = attrs.contains(AClass);

		for (a in attrs) {
			switch (a) {
				case ANoNamespace:
					hasNamespace = !attrs.contains(ANoNamespace);
				case AInternal(namespace):
					namespaceName = namespace;
				case APrefix(prefixStr):
					prefix = prefixStr;
				default:
			}
		}
		var cfields:Array<haxe.macro.Expr.Field> = [
			for (v in values) {
				var fieldName = cleanEnum(v);
				var cppEnumName = hasNamespace ? namespaceName + "::" + prefix + fieldName : prefix + fieldName;
				{
					pos: p,
					name: fieldName,
					kind: FVar(null), // {expr: EConst(CInt("" + (index++))), pos: p}
					meta: [{name: ":native", params: [cppEnumName.asConstExpr()], pos: p}],
					// access: [APublic, AStatic, AFinal, AInline, AExtern]
					access: []
				}
			}
		];
		var enumType = makeName(name).asComplexType();

		var toStringSwitchExpr = ESwitch(EConst(CIdent("thisAsEnum")).at(), [
			for (v in values) {
				var c:Case = {
					values: [EConst(CIdent(cleanEnum(v))).at()],
					expr: EConst(CString(v)).at()
				};
				c;
			}
		], EConst(CString('Unknown ${makeName(name)}')).at()).at();

		var toString = {
			pos: p,
			name: "toString",
			kind: FFun({args: [], ret: macro :String, expr: macro {var thisAsEnum:$enumType = cast this; return $toStringSwitchExpr;}}),
			meta: [],
			access: [APublic, AInline],
		};

		var toInt = {
			pos: p,
			name: "toInt",
			kind: FFun({args: [], ret: macro :Int, expr: macro return this}),
			meta: [],
			access: [APublic, AInline],
		};

		// //		Add Int Conversion
		// 		var ta:TypeAttr = {t: TInt, attr: [AStatic]};
		// 		var fn : Function = {args : [{name: "index", opt: false, t: {t: TInt, attr: []}}], ret: {t: TEnum(name), attr: []}, expr: null}
		// 		var toValue : Field = {
		// 			pos: p,
		// 			name: "indexToValue",
		// 			kind: FFun(fn),
		// 			meta: [],
		// 			access: [APublic, AStatic, AInline]
		// 		};
		// 		// var toValue = makeNativeFieldRaw(name, "indexToValue", p, [{name: "index", opt: false, t: {t: TInt, attr: []}}], ta, true);
		// 		cfields.push(toValue);

		// ta = {t: TInt, attr: [AStatic]};
		// var toIndex = makeNativeFieldRaw(name, "valueToIndex", p, [{name: "value", opt: false, t: {t: TInt, attr: []}}], ta, true);
		// cfields.push(toIndex);

		// ta = {t: TEnum(name), attr: [AStatic]};
		// var fromValue = makeNativeFieldRaw(name, "fromValue", p, [{name: "value", opt: false, t: {t: TInt, attr: []}}], ta, true);
		// cfields.push(fromValue);

		// ta = {t: TEnum(name), attr: [AStatic]};
		// var fromIndex = makeNativeFieldRaw(name, "fromIndex", p, [{name: "index", opt: false, t: {t: TInt, attr: []}}], ta, true);
		// cfields.push(fromIndex);

		// ta = {t: TInt, attr: []};
		// var toValue = makeNativeFieldRaw(name, "toValue", p, [], ta, true);
		// cfields.push(toValue);

		var implName = makeName(name) + "Impl";

		for (f in fields) {
			var fname = f.name;
			switch (f.kind) {
				case FMethod(args, ret):
					var attr = ret.attr;
					var isStatic = attr.contains(AStatic);
					if (!isStatic) {
						throw "Unsupported non-static method in enum";
					}

					var retValue = defVal(ret);
					var fullFnName = '${namespaceName}::${fname}';
					var fieldMethod = {
						pos: p,
						name: fname,
						kind: FFun({args: [], ret: makeType(ret, true), expr: null}),
						meta: [{name: ":native", params: [fullFnName.asConstExpr()], pos: p}],
						access: [APublic, AStatic, AExtern],
					};

					cfields.push(fieldMethod);
				// trace('method ${fname} ${args} ${ret}');
				default:
					throw 'Unsupported field kind ${f.kind}';
			}
		}
		var enumT:TypeDefinition = {
			pos: p,
			pack: _pack,
			name: makeName(name),
			meta: [
				{name: ":native", params: [namespaceName.asConstExpr()], pos: p},
				//				{name: ":unreflective", params: null, pos: p},
				{name: ":notNull", params: null, pos: p},
				getMacroBuilderMeta(p),
			],
			kind: TDAbstract(enumClass ? implName.asComplexType() : macro :Int, [AbEnum]), // implName.asComplexType()
			isExtern: true,
			fields: cfields.concat([toString, toInt]),
		};

		/*
			@:unreflective
			@:native("Fire_Handle_Mesh")
			extern class FireMeshHandleImpl { 

			}
			@:unreflective
			extern enum abstract FireMeshHandle(FireMeshHandleImpl) {

			}
		 */

		if (enumClass) {
			var implT:TypeDefinition = {
				pos: p,
				pack: _pack,
				name: implName,
				meta: [
					{name: ":native", params: [namespaceName.asConstExpr()], pos: p},
					//					{name: ":unreflective", params: null, pos: p},
					{name: ":notNull", params: null, pos: p},
					getMacroBuilderMeta(p),
					//					@:scalar
					//					{name: ":stackOnly", params: null, pos: p},
				],
				kind: TDClass(),
				isExtern: true,
				fields: [],
			};

			return [
				{def: enumT, path: {pack: _pack, name: enumT.name}},
				{def: implT, path: {pack: _pack, name: implT.name}}
			];
		}
		return [
			{def: enumT, path: {pack: _pack, name: enumT.name}},
			//			{def: implT, path: {pack: _pack, name: implT.name}}
		];
	}
} // @:native - Used to inject platform-native code into a function.
// @:functionTailCode
// @:buildXml
// @:cppFileCode - Code to be injected into generated cpp file.
// @:cppInclude - File to be included in generated cpp file.
// @:cppNamespaceCode
// @:fileXml - Include a given XML attribute snippet in the Build.xml entry for the file.
// @:headerClassCode - Code to be injected into generated header file.
// @:headerCode - Code to be injected into generated header file.
// @:headerInclude - File to be included in generated header file.
// @:headerNamespaceCode - Code to be injected into generated header file.
// @:include
// @:noStack
// @:structAccess - Marks an extern class as using struct access (.) not pointer (->).
// @:stackOnly - Instances of this type can only appear on the stack.
// @:nonVirtual - Declares function to be non-virtual in cpp.
//    @:noDebug- Does not generate debug information even if --debug is set.
// @:nativeStaticExtension - Converts static function syntax into member call.
// @:nativeProperty - Use native properties which will execute even with dynamic usage.
// @:sourceFile - Source code filename for external class.
// @:objc
// @:objcProtocol
// @:decl
// extern
// @:native Rewrites the path of a type or class field during generation. See
// @:templatedCall - Indicates that the first parameter of static call should be treated as a template argument.
// @:unreflective - ?
// @:void - Use Cpp native void return type.
// @:nativeArrayAccess - When used on an extern class which implements haxe.ArrayAccess native array access syntax will be generated
// @:structAccess
// @:nativeArrayAccess
// @:include('vector')
// @:native('std::vector')
// extern class StdVector<T> implements ArrayAccess<cpp.Reference<T>> {
//     function new(size : Int);
//     function push_back(_v : T) : Void;
// }
// https://blog.aidanlee.uk/hxcpp-430/
