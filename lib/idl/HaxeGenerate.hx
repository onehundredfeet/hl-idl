package idl;

import haxe.macro.Printer;
import idl.Data;
import haxe.macro.Expr;
import haxe.io.Path;
using StringTools;
using idl.macros.MacroTools;

import idl.HaxeGenerationTargetHXCPP;
import idl.HaxeGenerationTarget;


class HaxeGenerate {
	var pack:Array<String>;
	var opts:Options;
	final nullPosition:haxe.macro.Expr.Position = {min: 0, max: 0, file: 'null'};
	var p:haxe.macro.Expr.Position = {min: 0, max: 0, file: 'null'};
	var types:Array<TypeDefinition> = [];
	var _typeInfos = new Map<String, HaxeGenerationTypeInfo>();
	var _printer = new Printer();
	//    var _inline = true;
	var _targets:Array<HaxeGenerationTarget>;
	var _currentTarget:HaxeGenerationTarget;

	public function new(opts:Options, targets:Array<HaxeGenerationTarget> = null) {
		this.pack = opts.packageName.split(".");
		this.opts = opts;
		_targets = targets != null ? targets : [
			new HaxeGenerationTargetHL(opts, _typeInfos),
			new HaxeGenerationTargetHXCPP(opts, _typeInfos)
		];
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

	dynamic function currentPosition():haxe.macro.Expr.Position {
		#if macro
		return Context.currentPos();
		#else
		return nullPosition;
		#end
	}

	dynamic function warning(msg:String, p:haxe.macro.Expr.Position) {
		#if macro
		Context.warning(msg, p);
		#else
		if (p != null)
			trace('${p}:' + msg);
		else
			trace(msg);
		#end
	}

	function seedTypeInfo(d:Definition) {
		var tp:TypePath;
		var t:TypeDefinition;
		switch (d.kind) {
			case DInterface(iname, _, _, _):
				tp = {pack: pack, name: iname};
				_typeInfos[iname] = new HaxeGenerationTypeInfo(tp, null, d.kind);
			case DEnum(name, _, _, _):
				tp = {pack: pack, name: name};
				_typeInfos[name] = new HaxeGenerationTypeInfo(tp, null, d.kind);
			case DTypeDef(name, _, _, _):
				tp = {pack: pack, name: name};
				_typeInfos[name] = new HaxeGenerationTypeInfo(tp, null, d.kind);

	
			default:
		}
	}
	public function buildTypes(opts:Options):Array<TypeDefinition> {
		var declarations = loadIDLDeclarations();

		if (declarations == null) {
			throw "Failed to load IDL declarations";
		}
		for (d in declarations) {
			seedTypeInfo(d);
		}

		for (d in declarations) {
			buildDecl(d);
		}

		return types;
	}

	function makeMacroPosition(pos:idl.Data.Position):haxe.macro.Expr.Position {
		if (pos == null)
			return nullPosition;
		return makePosition({min: pos.pos, max: pos.pos + 1, file: pos.file});
	}

	function makePosition(p:{min:Int, max:Int, file:String}):haxe.macro.Expr.Position {
		#if macro
		return Context.makePosition(p);
		#else
		return p;
		#end
	}

	function defVal(t:TypeAttr):Expr {
		return switch (t.t) {
			case TVoid: throw "assert";
			case TInt, TUInt, TShort, TInt64, TChar: {expr: EConst(CInt("0")), pos: p};
			case TFloat, TDouble: {expr: EConst(CFloat("0.")), pos: p};
			case TBool: {expr: EConst(CIdent("false")), pos: p};
			case TEnum(name): ECall(EField(EConst(CIdent(name)).at(p), "fromIndex").at(p), [EConst(CInt("0")).at(p)]).at(p); // { expr : , pos : p };
			case TCustom(id):
				var ex = {expr: EConst(CInt("0")), pos: p};
				var tp = TPath({pack: [], name: id});

				if (_typeInfos.exists(id)) {expr: ECast(ex, tp), pos: p}; else {expr: EConst(CIdent("null")), pos: p};
			default:
				{expr: EConst(CIdent("null")), pos: p};
		}
	}



	function makeNativeField(iname:String, hname:String, f:idl.Data.Field, args:Array<FArg>, ret:TypeAttr, pub:Bool):Field {
		return _currentTarget.makeNativeFieldRaw(iname, hname, makeMacroPosition(f.pos), args, ret, pub);
	}

	function filterArgs(args:Array<FArg>) {
		var b:Array<FArg> = [];

		for (a in args) {
			var skip = false;
			for (at in a.t.attr) {
				switch (at) {
					case AVirtual:
						skip = true;
					default:
				}
			}
			if (!skip)
				b.push(a);
		}
		return b;
	}

	function getElementType(t:TypeAttr) {
		return switch (t.t) {
			case TPointer(at), TArray(at, _): {t: at, attr: t.attr};
			default: throw "Not an array type: " + t.t.getName() + " : " + t.t.getParameters();
		}
	}

	function makeElementType(t:idl.Data.TypeAttr, isReturn = false) {
		return switch (t.t) {
			case TPointer(at), TArray(at, _): _currentTarget.makeType({t: at, attr: t.attr}, isReturn);
			default: throw "Not an array type: " + t.t.getName() + " : " + t.t.getParameters();
		}
	}

	function buildDecl(d:Definition) {
		var p = makeMacroPosition(d.pos);

		switch (d.kind) {
			case DInclude(_):

			case DInterface(iname, attrs, fields, ikind):
				var dfields:Array<Field> = [];
				var forceCamel = attrs.indexOf(AForceCamelCase) >= 0;
				var variants = new Map(); 
				var isObject = ikind == InterfaceKind.IKObject;
				var isNamespace = ikind == InterfaceKind.IKNamespace;
				var isAbstract = ikind.match(InterfaceKind.IKAbstract(_));

				function getVariants(name:String) : Array<MethodVariant> {
					if (variants.exists(name))
						return null;
					variants.set(name, true);
					var fl = [];
					for (f in fields)
						if (f.name == name)
							switch (f.kind) {
								case FMethod(args, ret):
									fl.push({args: filterArgs(args), ret: ret, pos: f.pos});
								default:
							}
					return fl;
				}

				for (f in fields) {
					var haxeName = forceCamel ? f.name.substr(0, 1).toLowerCase() + f.name.substr(1) : f.name;

					switch (f.kind) {
						case FMethod(args, ret):
							var vars = getVariants(f.name);
							if (vars == null)
								continue;
					
							if (isNamespace) {
								if (!ret.attr.contains(AStatic)) {
									ret.attr.push(AStatic);
								}
							}

							var isConstr = f.name == iname || f.name == "new";
							var fields = null;
							if (isConstr) {
								fields = _currentTarget.makeConstructor(f, iname, haxeName, vars, p);
							}
							else if (vars.length == 1) {
								fields = _currentTarget.addSimpleMethod(f, ikind, attrs,iname, haxeName, vars[0].args, vars[0].ret, p);
							}else {
								trace("Multiple variants for " + f.name + 'but is constr ${isConstr}');
								fields = _currentTarget.addInterfaceMethod(f, iname, haxeName,vars, p);
							}

							for (f in fields) {
								dfields.push(f);
							}
						case FAttribute(t):
							var attribFields = _currentTarget.addAttribute(iname, haxeName, f, t, p);

							for (af in attribFields) {
								dfields.push(af);
							}

						case DConst(name, type, value):
							var num = Std.parseInt(value);
							var vmac = num != null ? {expr: EConst(CInt(value)), pos: currentPosition()} : macro $i{value};

							dfields.push({
								pos: p,
								name: name,
								access: [APublic, AStatic, AInline],
								kind: FVar(_currentTarget.makeType({t: type, attr: []}, false), vmac)
							});
					}
				}

				if (isObject && attrs.indexOf(ANoDelete) < 0) {
					//dfields.push(makeNativeField(iname, "delete", {name: "delete", pos: null, kind: null}, [], {t: TVoid, attr: []}, true));
				}

				var tds = _currentTarget.getInterfaceTypeDefinitions(iname, attrs, pack, dfields, ikind, p);
				var tp:TypePath = {
					pack: pack,
					name: iname
				};
				_typeInfos[iname] = new HaxeGenerationTypeInfo(tp, tds[0], d.kind);


				// if (!hl) {
				// 	for (f in dfields)
				// 		if (f.meta != null)
				// 			for (m in f.meta)
				// 				if (m.name == ":hlNative") {
				// 					if (f.access == null)
				// 						f.access = [];
				// 					switch (f.kind) {
				// 						case FFun(df):
				// 							var call = opts.nativeLib + "._eb_" + switch (m.params[1].expr) {
				// 								case EConst(CString(name)): name;
				// 								default: throw "!";
				// 							};
				// 							var args:Array<Expr> = [for (a in df.args) {expr: EConst(CIdent(a.name)), pos: p}];
				// 							if (f.access.contains(AStatic)) {
				// 								args.unshift(macro this);
				// 							}
				// 							df.expr = macro return untyped $i{call}($a{args});
				// 						default: throw "assert";
				// 					}
				// 					if (f.access.indexOf(AInline) == -1)
				// 						f.access.push(AInline);
				// 					f.meta.remove(m);
				// 					break;
				// 				}
				// }

				for (t in tds)
					types.push(t);

			case DImplements(name, intf):
				var name = makeName(name);
				var intf = makeName(intf);
				var found = false;
				for (t in types)
					if (t.name == name) {
						found = true;
						switch (t.kind) {
							case TDAbstract(a, _):
								t.fields.push({
									pos: p,
									name: "_to" + intf,
									meta: [{name: ":to", pos: p}],
									access: [AInline],
									kind: FFun({
										args: [],
										expr: macro return cast this,
										ret: TPath({pack: [], name: intf}),
									}),
								});

								var toImpl = [intf];
								while (toImpl.length > 0) {
									var intf = toImpl.pop();
									var td = null;
									for (t2 in types) {
										if (t2.name == intf)
											switch (t2.kind) {
												case TDAbstract(a2, _, to):
													for (inheritedField in t2.fields) {
														// Search for existing field
														var fieldExists = false;
														for (existingField in t.fields) {
															if (inheritedField.name == existingField.name) {
																fieldExists = true;
																break;
															}
														}

														if (!fieldExists) {
															t.fields.push(inheritedField);
														}
													}
												default:
											}
									}
								}

							default:
								warning("Cannot have " + name + " extends " + intf, p);
						}
						break;
					}
				if (!found)
					warning("Class " + name + " not found for implements " + intf, p);
			case DEnum(name, attrs, values, fields):

			var tds = _currentTarget.makeEnum(name, attrs, values, fields, p);
			for (t in tds)
				types.push(t.def);

			var enumInfo = tds[0];
			_typeInfos[name] = new HaxeGenerationTypeInfo(enumInfo.path, enumInfo.def, d.kind);

			case DTypeDef(name, attrs, type, dtype):
				_currentTarget.makeAbstract(name, attrs, type, p);
				//_typeInfos[name] = new HaxeGenerationTypeInfo(tp, tds[0], d.kind);
		}
	}

	public function generate() {
		var targetMap = new Map<HaxeGenerationTarget, Array<TypeDefinition>>();
		var multiTypeMap = new Map<String, Map<HaxeGenerationTarget, TypeDefinition>>();
		for (target in _targets) {
			types = [];
			_typeInfos.clear();
			_currentTarget = target;
			// implicitly adds them to types
			buildTypes(opts);
			targetMap.set(target, types);

			for (t in types) {
				var name = t.name;
				if (!multiTypeMap.exists(name)) {
					multiTypeMap.set(name, new Map<HaxeGenerationTarget, TypeDefinition>());
				}
				multiTypeMap.get(name).set(target, t);
			}
		}

		var root = opts.hxDir + opts.packageName.split(".").join("/");
		var lastPartOfPackage = opts.packageName.split(".").pop();
		// Uppercase the first letter, lowercase the rest
		//var moduleName = lastPartOfPackage.charAt(0).toUpperCase() + lastPartOfPackage.substr(1).toLowerCase();

		trace('root ${root}');
		var builder = new StringBuf();
		
		builder.add('package ${opts.packageName};\n');

		for (target in _targets) {
			var targetTypes = targetMap.get(target);
			if (targetTypes != null) {
				builder.add(target.getTargetCondition());
				builder.add('\n\n');
				for (type in targetTypes) {
					builder.add(_printer.printTypeDefinition(type, false));
					builder.add('\n');
				}
				builder.add('\n#end\n');
			}
		}
		

		var fname = root + "/" + opts.nativeLib + ".hx";
		sys.io.File.saveContent(fname, builder.toString());
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

	function loadIDLDeclarations() {
		// load IDL
		var file = opts.idlFile;
		var resolutionQueue = [file];
		var decls = [];
		while (resolutionQueue.length > 0) {
			var currentFile = resolutionQueue.shift();
			trace('Loading ${currentFile} ${resolutionQueue.length} remaining');
			var content = try {
				sys.io.File.getBytes(currentFile);
			} catch (e:Dynamic) {
				error("" + e, p);
				return null;
			}
			// parse IDL
			var parse = new idl.Parser();
			try {
				var currentDecls = parse.parseFile(currentFile, new haxe.io.BytesInput(content));
				var localDecls = [];
				for (d in currentDecls) {
					switch( d.kind ) {
						case DInclude(path):
							var tryPath = Path.directory(currentFile) + "/" + path;
							if (!tryPath.contains(".idl") ) {
								tryPath += ".idl";
							}
							if (sys.FileSystem.exists(tryPath)) {
								trace('\tIncluding ${tryPath} ${resolutionQueue.length} remaining');
								resolutionQueue.push(tryPath);
							} else {
								error("Include file not found: " + tryPath, makePosition({min: 0, max: 0, file: currentFile}));
								return null;
							}
						default:
							localDecls.push(d);
					}
				}
				//trace('Prepending ${currentFile} ${localDecls.length} declarations to ${decls.length} ${resolutionQueue.length} remaining');
				decls = localDecls.concat(decls);

			} catch (msg:String) {
				var lines = content.toString().split("\n");
				var start = lines.slice(0, parse.line - 1).join("\n").length + 1;
				error(msg, makePosition({min: start, max: start + lines[parse.line - 1].length, file: file}));
				return null;
			}
				
		}
		
	
		return decls;
	}

	/**
	 * Capitalize the first letter of a string
	 * @param text The string to capitalize
	 */
	private static function capitalize(text:String) {
		return text.charAt(0).toUpperCase() + text.substring(1);
	}
}
