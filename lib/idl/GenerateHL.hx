package idl;

import haxe.macro.Expr.Function;
import idl.Data;
import idl.Options;

class GenerateHL extends GenerateBase {

	public function new(opts : Options) {
		super(opts);
	}

    public function generateHX() : Void {
		var haxehl = new HaxeGenerate(opts);
		haxehl.generate();
	}

	static final HELPER_TEXT = "
	#ifndef __HL_IDL_HELPERS_H_
#define __HL_IDL_HELPERS_H_

#include <hl.h>
#include <string>

void hl_cache_string_type( vstring *str);
vstring * hl_utf8_to_hlstr( const char *str);
vstring * hl_utf8_to_hlstr( const std::string &str);

#pragma once


// Float vector
struct _h_float2 {
	float x;
	float y;
};
typedef _h_float2 *h_float2;
typedef _h_float2 *h_float2_array;

struct _h_float3 {
	float x;
	float y;
	float z;
};
typedef _h_float3 *h_float3;
typedef _h_float3 *h_float3_array;

struct _h_float4 {
	float x;
	float y;
	float z;
	float w;
};

// int vector
struct _h_int2 {
	int x;
	int y;

};
typedef _h_int2 *h_int2;
typedef _h_int2 *h_int2_array;

struct _h_int3 {
	int x;
	int y;
	int z;
};

struct _h_int4 {
	int x;
	int y;
	int z;
	int w;
};

// double vector
struct _h_double2 {
	double x;
	double y;
};
typedef _h_double2 *h_double2;
typedef _h_double2 *h_double2_array;

struct _h_double3 {
	double x;
	double y;
	double z;
};

typedef _h_double3 *h_double3;
typedef _h_double3 *h_double3_array;

struct _h_double4 {
	double x;
	double y;
	double z;
	double w;
};


template<class T, class C>
class  IteratorWrapper {
	private:
		bool _initialized;
		typename C::iterator _it;
		C &_collection;
	public:	
		inline void reset() {
			_initialized = false;
		}
		inline IteratorWrapper( C&col ) : _collection(col) {
			reset();
		}
		inline bool next() {
			if (!_initialized) {
				_initialized = true;
				_it = _collection.begin();
			} else {
				_it++;
			}
			return  (_it != _collection.end());
		}
		inline T &get() {
			return *_it;
		}
        inline T *getPtr() {
			return &(*_it);
		}
};

#endif
	";
	static var HEADER_EMSCRIPTEN = "

#include <emscripten.h>
#define HL_PRIM
#define HL_NAME(n)	EMSCRIPTEN_KEEPALIVE eb_##n
#define DEFINE_PRIM(ret, name, args)
#define _OPT(t) t*
#define _GET_OPT(value,t) *value


";

	static var HEADER_HL = "

#include <hl.h>
#include \"hl-idl-helpers.hpp\"
// Need to link in helpers
//HL_API hl_type hltx_ui16;
//HL_API hl_type hltx_ui8;
HL_PRIM hl_type hltx_ui16 = { HUI16 };
HL_PRIM hl_type hltx_ui8 = { HUI8 };

#define _IDL _BYTES
#define _OPT(t) vdynamic *
#define _GET_OPT(value,t) (value)->v.t

static  hl_type *strType = nullptr;
void hl_cache_string_type( vstring *str) {
   strType = str->t;
}

vstring * hl_utf8_to_hlstr( const char *str) {
    int strLen = (int)strlen( str );
    uchar * ubuf = (uchar*)hl_gc_alloc_noptr((strLen + 1) << 1);
    hl_from_utf8( ubuf, strLen, str );

    vstring* vstr = (vstring *)hl_gc_alloc_raw(sizeof(vstring));

    vstr->bytes = ubuf;
    vstr->length = strLen;
    vstr->t = strType;
    return vstr;
}
vstring * hl_utf8_to_hlstr( const std::string &str) {
	return hl_utf8_to_hlstr(str.c_str());
}

HL_PRIM vstring * HL_NAME(getdllversion)(vstring * haxeversion) {
	strType = haxeversion->t;
	return haxeversion;
}
DEFINE_PRIM(_STRING, getdllversion, _STRING);

class HNativeBuffer {
    unsigned char *_ptr;
    int _size;

   public:
   inline unsigned char * ptr() { return _ptr; }
   inline int size() { return _size; }
   HNativeBuffer(unsigned char *ptr, int size) : _ptr(ptr), _size(size) {}
   HNativeBuffer(int size) : _ptr(new unsigned char[size]), _size(size) {}
    ~HNativeBuffer() {
        if (_ptr != nullptr)
            delete [] _ptr;
    }
};

inline static varray* _idc_alloc_array(float *src, int count) {
	if (src == nullptr) return nullptr;

	varray *a = NULL;
	float *p;
	a = hl_alloc_array(&hlt_f32, count);
	p = hl_aptr(a, float);

	for (int i = 0; i < count; i++) {
		p[i] = src[i];
	}
	return a;
}
";

	static var HEADER_NO_GC = "

#define alloc_ref(r, _) r
#define alloc_ref_const(r,_) r
#define _ref(t)			t
#define _unref(v)		v
#define free_ref(v) delete (v)
#define HL_CONST const

	";

	static var HEADER_GC = "

template <typename T> struct pref {
	void (*finalize)( pref<T> * );
	T *value;
};

#define _ref(t) pref<t>
#define _unref(v) v->value
#define _unref_ptr_safe(v) (v != nullptr ? v->value : nullptr)
#define alloc_ref(r,t) _alloc_ref(r,finalize_##t)
#define alloc_ref_const(r, _) _alloc_const(r)
#define HL_CONST

template<typename T> void free_ref( pref<T> *r ) {
	if( !r->finalize ) hl_error(\"delete() is not allowed on const value.\");
	delete r->value;
	r->value = NULL;
	r->finalize = NULL;
}

template<typename T> void free_ref( pref<T> *r, void (*deleteFunc)(T*) ) {
	if( !r->finalize ) hl_error(\"delete() is not allowed on const value.\");
	deleteFunc( r->value );
	r->value = NULL;
	r->finalize = NULL;
}

inline void testvector(_h_float3 *v) {
  printf(\"v: %f %f %f\\n\", v->x, v->y, v->z);
}
template<typename T> pref<T> *_alloc_ref( T *value, void (*finalize)( pref<T> * ) ) {
	if (value == nullptr) return nullptr;
	pref<T> *r = (pref<T>*)hl_gc_alloc_finalizer(sizeof(pref<T>));
	r->finalize = finalize;
	r->value = value;
	return r;
}

template<typename T> pref<T> *_alloc_const( const T *value ) {
	if (value == nullptr) return nullptr;
	pref<T> *r = (pref<T>*)hl_gc_alloc_noptr(sizeof(pref<T>));
	r->finalize = NULL;
	r->value = (T*)value;
	return r;
}


inline static varray* _idc_alloc_array(unsigned char *src, int count) {
	if (src == nullptr) return nullptr;

	varray *a = NULL;
	float *p;
	a = hl_alloc_array(&hltx_ui8, count);
	p = hl_aptr(a, float);

	for (int i = 0; i < count; i++) {
		p[i] = src[i];
	}
	return a;
}

inline static varray* _idc_alloc_array( char *src, int count) {
	return _idc_alloc_array((unsigned char *)src, count);
}

inline static varray* _idc_alloc_array(int *src, int count) {
	if (src == nullptr) return nullptr;

	varray *a = NULL;
	int *p;
	a = hl_alloc_array(&hlt_i32, count);
	p = hl_aptr(a, int);

	for (int i = 0; i < count; i++) {
		p[i] = src[i];
	}
	return a;

}

inline static varray* _idc_alloc_array(double *src, int count) {
	if (src == nullptr) return nullptr;

	varray *a = NULL;
	double *p;
	a = hl_alloc_array(&hlt_f64, count);
	p = hl_aptr(a, double);

	for (int i = 0; i < count; i++) {
		p[i] = src[i];
	}
	return a;
}


inline static varray* _idc_alloc_array(const unsigned short *src, int count) {
	if (src == nullptr) return nullptr;

	varray *a = NULL;
	unsigned short *p;
	a = hl_alloc_array(&hltx_ui16, count);
	p = hl_aptr(a, unsigned short);

	for (int i = 0; i < count; i++) {
		p[i] = src[i];
	}
	return a;
}

inline static varray* _idc_alloc_array(unsigned short *src, int count) {
	if (src == nullptr) return nullptr;

	varray *a = NULL;
	unsigned short *p;
	a = hl_alloc_array(&hltx_ui16, count);
	p = hl_aptr(a, unsigned short);

	for (int i = 0; i < count; i++) {
		p[i] = src[i];
	}
	return a;
}

inline static void _idc_copy_array( float *dst, varray *src, int count) {
	float *p = hl_aptr(src, float);
	for (int i = 0; i < count; i++) {
		dst[i] = p[i];
	}
}

inline static void _idc_copy_array( varray *dst, float *src,  int count) {
	float *p = hl_aptr(dst, float);
	for (int i = 0; i < count; i++) {
		p[i] = src[i];
	}
}


inline static void _idc_copy_array( int *dst, varray *src, int count) {
	int *p = hl_aptr(src, int);
	for (int i = 0; i < count; i++) {
		dst[i] = p[i];
	}
}

inline static void _idc_copy_array( unsigned short *dst, varray *src) {
	unsigned short *p = hl_aptr(src, unsigned short);
	for (int i = 0; i < src->size; i++) {
		dst[i] = p[i];
	}
}

inline static void _idc_copy_array( const unsigned short *cdst, varray *src) {
	unsigned short *p = hl_aptr(src, unsigned short);
	unsigned short *dst = (unsigned short *)cdst;
	for (int i = 0; i < src->size; i++) {
		dst[i] = p[i];
	}
}

inline static void _idc_copy_array( varray *dst, int *src,  int count) {
	int *p = hl_aptr(dst, int);
	for (int i = 0; i < count; i++) {
		p[i] = src[i];
	}
}


inline static void _idc_copy_array( double *dst, varray *src, int count) {
	double *p = hl_aptr(src, double);
	for (int i = 0; i < count; i++) {
		dst[i] = p[i];
	}
}

inline static void _idc_copy_array( varray *dst, double *src,  int count) {
	double *p = hl_aptr(dst, double);
	for (int i = 0; i < count; i++) {
		p[i] = src[i];
	}
}


";

	static var HEADER_NATIVE_TYPES = "
	";



	public function generateGlue() {
		var output = new StringBuf();

		sys.io.File.saveContent(opts.glueDir + "hl-idl-helpers.hpp",HELPER_TEXT);
		var gc = opts.autoGC;
		var decls = loadIDL(opts);
		function add(str:String) {
			output.add(str.split("\r\n").join("\n") + "\n");
		}
		add("#ifdef EMSCRIPTEN");
		add("");
		add(StringTools.trim(HEADER_EMSCRIPTEN));
		add(StringTools.trim(HEADER_NO_GC));
		add("");
		add("#else");
		add("");
		add('#define HL_NAME(x) ${opts.nativeLib}_##x');
		add(StringTools.trim(HEADER_HL));
		add(StringTools.trim(gc ? HEADER_GC : HEADER_NO_GC));
		add("");
		add("#endif");
		if (opts.customCode != null) {
			add("");
			add(StringTools.trim(opts.customCode.getHLInclude()));
		}
		if (opts.includes != null) {
			for (i in opts.includes) {
				add("");
				add('#include "' + i + '"');
			}
		}
		add("");
		add("");
		add(StringTools.trim(HEADER_NATIVE_TYPES));
		add("");
		add("");
		add('extern "C" {');
		add("");

		var typeNames = new Map();
		var enumNames = new Map();

		// ignore "JSImplementation" interfaces (?)
		for (d in decls.copy())
			switch (d.kind) {
				case DInterface(_, attrs, _, _):
					for (a in attrs)
						switch (a) {
							case AJSImplementation(_):
								decls.remove(d);
								break;
							default:
						}
				default:
			}

		for (d in decls) {
			switch (d.kind) {
				case DInclude(_):
				case DInterface(name, attrs, _, _):
					var prefix = "";
					var intName = name;
					var newName = null;
					var deleteName = null;
					var destructExpr = null;
					for (a in attrs)
						switch (a) {
							case APrefix(name): prefix = name;
							case AInternal(iname): intName = iname;
							case ANew(name): newName = name;
							case ADelete(name): deleteName = name;
							case ADestruct(expression): destructExpr = expression;
							default:
						}

					//					var fullName = "_ref(" + prefix + intName + ")*"; // REF CHANGE [RC]
					var refFullName = "pref<" + prefix + intName + ">*";
					typeNames.set(name, {
						full: prefix + intName,
						constructor: prefix + intName,
						isInterface: true,
						isEnum: false,
						decl: refFullName,
						dtype : null
					});
					if (attrs.indexOf(ANoDelete) >= 0)
						continue;

					var freeRefText = 'free_ref(_this ${deleteName != null ? "," + deleteName : ""})';
					if (destructExpr != null) {
						freeRefText = '${destructExpr}(_this->value )';
					}
					add('static void finalize_$name( $refFullName _this ) { $freeRefText; }');
					add('HL_PRIM void HL_NAME(${name}_delete)( $refFullName _this ) {\n\t$freeRefText;\n}');
					add('DEFINE_PRIM(_VOID, ${name}_delete, _IDL);');
				case DEnum(name, attrs, values, _):
					typeNames.set(name, {
						full: "int",
						constructor: null,
						isInterface: true,
						isEnum: true,
						decl: "int",
						dtype : null
					});

					var etname = name;
					for (a in attrs) {
						switch (a) {
							case AInternal(iname): etname = iname;
							case APrefix(prefix): values = values.map((x) -> prefix + x);
							default:
						}
					}
					enumNames.set(name, etname);

					add('static $etname ${name}__values[] = { ${values.join(",")} };');
					add('HL_PRIM int HL_NAME(${name}_toValue0)( int idx ) {\n\treturn (int)${name}__values[idx];\n}');
					add('DEFINE_PRIM(_I32, ${name}_toValue0, _I32);');
					add('HL_PRIM int HL_NAME(${name}_indexToValue1)( int idx ) {\n\treturn (int)${name}__values[idx];\n}');
					add('DEFINE_PRIM(_I32, ${name}_indexToValue1, _I32);');
					add('HL_PRIM int HL_NAME(${name}_valueToIndex1)( int value ) {\n\tfor( int i = 0; i < ${values.length}; i++ ) if ( value == (int)${name}__values[i]) return i; return -1;\n}');
					add('DEFINE_PRIM(_I32, ${name}_valueToIndex1, _I32);');
					add('HL_PRIM int HL_NAME(${name}_fromValue1)( int value ) {\n\tfor( int i = 0; i < ${values.length}; i++ ) if ( value == (int)${name}__values[i]) return i; return -1;\n}');
					add('DEFINE_PRIM(_I32, ${name}_fromValue1, _I32);');
					add('HL_PRIM int HL_NAME(${name}_fromIndex1)( int index ) {return index;}');
					add('DEFINE_PRIM(_I32, ${name}_fromIndex1, _I32);');
				case DTypeDef(name, attrs, type, dtype):
					trace('typedef ' + name + ' ' + type + ' dtype ' + dtype);
					typeNames.set(name, {
						full: type,
						constructor: null,
						isInterface: false,
						isEnum: false,
						decl: type,
						dtype: {t:dtype, attr:attrs}
					});

				case DImplements(_):
			}
		}

		function getEnumShortName(t:idl.Data.Type) {
			return switch (t) {
				case TCustom(id): enumNames.exists(id) ? id : null;
				default: null;
			}
		}

		function getEnumTypeName(t:idl.Data.Type) {
			return switch (t) {
				case TCustom(id): enumNames.exists(id) ? enumNames.get(id) : null;
				default: null;
			}
		}


		function makeNativeTypeRaw(t:idl.Data.Type, isReturn:Bool = false) {
			return switch (t) {
				case TChar: "unsigned char";
				case TFloat: "float";
				case TDouble: "double";
				case TShort: "unsigned short";
				case TInt64: "int64_t";
				case TUInt: "unsigned int";
				case TInt: "int";
				case TVoid: "void";
				case TAny, TVoidPtr: "void*";
				case TArray(_, _): "varray*"; // makeType(t) + "vdynamic *"; // This is an array of OBJECTS, likely a bug here
				case TDynamic: "vdynamic*";
				case TType: "hl_type*";
				case TPointer(t): "vbyte*";
				case TBool: "bool";
				case TEnum(_): "int";
				case TBytes: "unsigned char*";
				case TIOBytes: "unsigned char*";
				case TCustom(id): {
						var t = typeNames.get(id);
						if (t == null) {
							throw "Unsupported type " + id;
						} else {
							typeNames.get(id).decl;
						}
					}
				case TVector(vt, vdim):
					switch (vt) {
						case TFloat: "h_float" + vdim;
						case TDouble: "h_double" + vdim;
						case TInt: "h_int" + vdim;
						default: throw "Unsupported vector type";
					}
				default:
					throw "Unknown type " + t;
			}
		}
		function makeNativeTypeRawPtr(t:idl.Data.Type) {
			var x = makeNativeTypeRaw(t);
			return switch (t) {
				case TVector(_): return x +"_array";
				default : return x + "*";
			};
		}

		function makeNativeType(t:idl.Data.TypeAttr, isReturn:Bool = false) {
			var x = switch (t.t) {
				case THString: t.attr.contains(ASTL) ? "std::string" : "const char*";
				default: makeNativeTypeRaw(t.t);
			}
			return t.attr.contains(AOut) ? x + "*" : x;
		}

		function makeType(t:idl.Data.TypeAttr, isReturn:Bool = false) {
			var x = switch (t.t) {
				case TChar: "unsigned char";
				case TFloat: "float";
				case TDouble: "double";
				case TShort: "unsigned short";
				case TInt64: "int64_t";
				case TUInt: "unsigned int";
				case TInt: "int";
				case TVoid: "void";
				case TAny, TVoidPtr: "void*";
				case TArray(_, _): "varray*"; // makeType(t) + "vdynamic *"; // This is an array of OBJECTS, likely a bug here
				case TDynamic: "vdynamic*";
				case TType: "hl_type*";
				case TPointer(t): "vbyte*";
				case TBool: "bool";
				case TEnum(_): "int";
				case THString: "vstring *";
				case TCString: "vbyte*";
				case TStdString: "vbyte*";
				case TBytes: "vbyte*";
				case TIOBytes: "vbyte*";
				case TCustom(id): {
						var t = typeNames.get(id);
						if (t == null) {
							throw "Unsupported type " + id;
						} else {
							typeNames.get(id).decl;
						}
					}
				case TVector(vt, vdim):
					switch (vt) {
						case TFloat: "h_float" + vdim;
						case TDouble: "h_double" + vdim;
						case TInt: "h_int" + vdim;
						default: throw "Unsupported vector type";
					}
				case TFunction(ret, ta): "vclosure*";
				default:
					throw "Unknown type " + t;
			}
			return (t.attr != null && t.attr.contains(AOut)) ? x + "*" : x;
		}

		
		function makeLocalType(t:idl.Data.TypeAttr) {
			return switch (t.t) {
				case TCustom(id): {
					var t = typeNames.get(id);
					if (t == null) {
						throw "Unsupported type " + id;
					} else {
						var x = typeNames.get(id);
						x.isInterface ? x.full + "*" : x.full;
					}
				}
				default: makeType(t);
			}
		}

		function makeAllocRefType(t:idl.Data.TypeAttr) {
			return switch (t.t) {
				case TCustom(id): {
					var t = typeNames.get(id);
					if (t == null) {
						throw "Unsupported type " + id;
					} else {
						 typeNames.get(id).full;
					}
				}
				default: makeType(t);
			}
		}

		

		function getElementType(t:TypeAttr) {
			return switch (t.t) {
				case TPointer(at), TArray(at, _):{t: at, attr: t.attr};
				default: throw "Not an array type: " + t.t.getName() + " : " + t.t.getParameters();
			}
		}
		
		function makeElementType(t:idl.Data.TypeAttr, isReturn = false) {
			return switch (t.t) {
				case TPointer(at), TArray(at, _): makeType({t: at, attr: t.attr}, isReturn);
				default: throw "Not an array type: " + t.t.getName() + " : " + t.t.getParameters();
			}
		}

// { var t : Type; var attr : Array<Attrib>; }
		function defType(t:TypeAttr, isReturn:Bool = false) {
			var x = switch (t.t) {
				case TChar: "_I8";
				case TFloat: "_F32";
				case TDouble: "_F64";
				case TShort: "_I16";
				case TInt64: "_I64";
				case TUInt: "_I32";
				case TInt: "_I32";
				case TEnum(_): "_I32";
				case TVoid: "_VOID";
				case TPointer(_), TAny, TVoidPtr: "_BYTES";
				case TArray(_, _): "_ARR";
				case TBool: "_BOOL";
				case TBytes: "_BYTES";
				case TIOBytes: "_BYTES";
				case TVector(t, dim): "_STRUCT";
				case TStruct: "_STRUCT";
				case THString: "_STRING";
				case TCString: "_BYTES";
				case TStdString: "_BYTES";
				case TFunction(ret, ta):
					var args = (ta == null || ta.length == 0) ? "_NO_ARG" : ta.map((x) -> defType(x)).join(" ");
					"_FUN(" + defType(ret) + ',${args})';
				case TCustom(name): 
					enumNames.exists(name) 		? "_I32" : 
					typeNames.exists(name) 		? {
						var td = typeNames.get(name);
						td.isInterface ? "_IDL" : defType(td.dtype, isReturn);
						} :
					t.attr.contains(ACStruct) 	? "_STRUCT" 
					: "_IDL";
				case TDynamic: "_DYN";
				case TType: "_TYPE";
			}

			return (t.attr != null && t.attr.contains(AOut)) ? "_REF(" + x + ")" : x;
		}

		inline function defElementType(t:TypeAttr, isReturn:Bool = false) {
			return switch (t.t) {
				case TPointer(at), TArray(at, _): defType({t: at, attr: t.attr}, isReturn);
				default: throw "Not an array type: " + t.t.getName() + " : " + t.t.getParameters();
			}
		}


		function dynamicAccess(t) {
			return switch (t) {
				case TChar: "c";
				case TFloat: "f";
				case TDouble: "d";
				case TShort: "ui16";
				case TInt64: "i64";
				case TInt: "i";
				case TUInt: "i";
				case TBool: "b";
				default: throw "assert";
			}
		}

		function makeTypeDecl(td:TypeAttr, isReturn:Bool = false) {
			var prefix = "";
			if (td.attr != null) {
				for (a in td.attr) {
					switch (a) {
						case AConst:
							prefix += "HL_CONST ";
						default:
					}
				}
			}

			return prefix + makeType(td, isReturn);
		}

		function isDyn(arg:{opt:Bool, t:TypeAttr}) {
			return arg.opt && !arg.t.t.match(TCustom(_));
		}

		for (d in decls) {
			switch (d.kind) {
				case DInclude(_):
				case DInterface(name, attrs, fields, _):
					var forceCamel = attrs.contains(AForceCamelCase);
					for (f in fields) {
						var haxeName = forceCamel ? f.name.substr(0, 1).toLowerCase() + f.name.substr(1) :  f.name;
						switch (f.kind) {
							case FMethod(margs, ret):
								function findArg(name:String) {
									for (a in margs) {
										if (a.name == name) {
											return a;
										}
									}
									return null;
								}

								var isConstr = f.name == name || f.name == "new";
								var args = (isConstr || ret.attr.indexOf(AStatic) >= 0) ? margs : [
									{
										name: "_this",
										t: {t: TCustom(name), attr: []},
										opt: false
									}
								].concat(margs);

								var returnField:String = null;
								var returnType:TypeAttr = null;
								var ignore:Array<String> = [];
								var argCount = ret.attr.contains(AStatic) ? 0 : -1;

								for (a in args) {
									var addToCount = true;

									for (attr in a.t.attr) {
										switch (attr) {
											case AReturn:
												returnField = a.name;
												returnType = a.t;
												ignore.push(a.name);
											case ASubstitute(_):
												ignore.push(a.name);
											case AVirtual: addToCount = false;
											case AIgnore: ignore.push(a.name);
											case ALocal: ignore.push(a.name);
											default:
										}
									}
									if (addToCount) {
										argCount++;
									}
								}

								var tret = isConstr ? {t: TCustom(name), attr: []} : ret;
								var isIndexed = tret.attr.contains(AIndexed);
								var isReturnArray = false;
								var rapIdx:String = null;
								var ralIdx:String = null;
								var rapArg:FArg = null;
								var ralArg:FArg = null;
								var return_converter = switch (tret.t) {
									case THString:"hl_utf8_to_hlstr";
									default:"";
								}

								for (ta in tret.attr) {
									switch (ta) {
										case AReturnArray(pIdx, lengthIdx):
											rapIdx = pIdx;
											ralIdx = lengthIdx;
											isReturnArray = true;
											rapArg = findArg(rapIdx);
											ralArg = findArg(ralIdx);
										case AGet(name):return_converter = name;
										default:
									}
								}

								// Static functions needs the exact number of arguments as function suffix. Otherwise C++ compilation will fail.

								var funName = name + "_" + (isConstr ? "new" + args.length : haxeName + argCount);

								// var staticPrefix = (attrs.indexOf(AStatic) >= 0) ? "static" : ""; ${staticPrefix}
								output.add('HL_PRIM ${makeTypeDecl(returnField == null ? tret : returnType, true)} HL_NAME($funName)(');
								var first = true;

								for (a in args) {
									var skipa = ignore.contains(a.name);

									for (attr in a.t.attr) {
										switch (attr) {
											case AVirtual: skipa = true;
											default:
										}
									}
									if (!skipa) {
										if (first)
											first = false
										else
											output.add(", ");
										switch (a.t.t) {
											case TArray(t, sizeField):
												output.add(makeType(a.t));
											default:
												if (isDyn(a)) {
													// output.add("_OPT(" + makeType(a.t.t) + ")");
													output.add("_OPT(" + makeType({t: a.t.t, attr: a.t.attr}) + ")");
												} else {
													// output.add(makeType(a.t.t));
													output.add(makeType({t: a.t.t, attr: a.t.attr}));
													// Add '&' for referenced primitive types
													for (attr in a.t.attr) {
														switch (attr) {
															case ARef:
																switch (a.t.t) {
																	case TChar, TInt, TShort, TFloat, TDouble,
																		TBool: output.add("&"); // Reference primitive types with &
																	default: output.add(""); // Do nothung for custom types
																}
															default:
														}
													}
												}
										}
										output.add(" " + a.name);
									}
								}
								add(') {');

								function addCall(margs:Array<{name:String, opt:Bool, t:TypeAttr}>) {
									// preamble
									var preamble = returnField != null || isReturnArray;

									if (returnField != null) {
										output.add(makeLocalType(returnType) + " __tmpret;\n");
									} else if (isReturnArray) {
										switch (tret.t) {
											case TVoidPtr:
												output.add(makeElementType(rapArg.t) + " *__tmparray = nullptr;\n");
												output.add("\t" + "int __tmpLength = -1;\n");
												output.add("\t" + makeType(tret) + " __tmpret;\n");
											case TPointer(at), TArray(at, _):
												output.add(makeType({t: at, attr: []}) + " *__tmparray = nullptr;\n");
												output.add("\t" + "int __tmpLength = -1;\n");
												output.add("\t" + makeType(tret) + " __tmpret;\n");
											default:
												throw "Needs to be array";
										}
									}

									for (a in margs) {
										if (a.t.attr.contains(ALocal)) {
											switch (a.t.t) {
												case THString:
													output.add(makeNativeType(a.t) + " " + a.name + "__cstr;\n");
												default:
													output.add(makeNativeType(a.t) + " " + a.name + ";\n");
											}
										} else {
											switch (a.t.t) {
												case TFunction(ret, ta):
													preamble = true;
													output.add('\tif (${a.name}->hasValue) hl_error(\"Only static callbacks supported\");\n');
												case THString:
													preamble = true;
													if (!a.t.attr.contains(AHString)) {
														output.add(makeNativeType(a.t) + " " + a.name + "__cstr = (" + a.name
															+ " == nullptr) ? \"\" : hl_to_utf8( " + a.name + "->bytes ); // Should be garbage collected\n\t");
													}
												default:
											}
										}
									}
									var retCast = "";
									var getter = "";
									var derefReturn = false;
									var addressOfReturn = false;
									var cloneReturn = false;
									var substitue = null;
									for (a in tret.attr) {
										switch (a) {
											case AValidate(expr):
												preamble = true;
											case ACast(t):
												retCast = "(" + t + ")";
											case AGet(g):
												getter = g;
											case ADeref:
												derefReturn = true;
											case AAddressOf:
												addressOfReturn = true;
											case AClone:
												cloneReturn = true;
											case ASubstitute(expression):
												substitue = expression;
											default:
										}
									}

									var refRet = null;
									var enumName = getEnumShortName(tret.t);

									var isRef = ret.attr.contains(ARef);
									var isValue = ret.attr.contains(AValue);
									var isConst = ret.attr.contains(AConst);
									var isCustomType = ret.t.match(TCustom(_));

									var initConstructor = false;
									if (isConstr) {
										refRet = name;
										var substitudeConstructor = null;
										for (a in ret.attr) {
											switch (a) {
												case ASubstitute(expression):
													substitudeConstructor = expression;
												case AInitialize:
													initConstructor = true;
													preamble = true;
												default:
											}
										}

										var constructorExpr = substitudeConstructor == null ? 'new ${typeNames.get(refRet).constructor}' : substitudeConstructor;

										if (preamble) {
											output.add('auto ___retvalue = alloc_ref(${retCast}(${constructorExpr}(');
										} else {
											output.add('return alloc_ref(${retCast}(${constructorExpr}(');
										}
									} else {
										if (tret.t != TVoid) {
											if (preamble) {
												if (returnField == null)
													output.add("auto ___retvalue = ");
											} else
												output.add('return ${return_converter}'); // 
										}
										if (isRef || isValue || isCustomType) {
											refRet = switch (tret.t) {
												case TCustom(id): id;
												default: throw "assert";
											}
										}

										if (enumName != null) {
											output.add('HL_NAME(${enumName}_valueToIndex1)(');
										} else if (isCustomType) {
											if (returnField == null) {
												if ((isRef || addressOfReturn) && isConst) {
													output.add('alloc_ref_const(${retCast}${getter}&('); // we shouldn't call delete() on this one !
												} else if (isValue) {
													output.add('alloc_ref(${retCast}new ${typeNames.get(refRet).constructor}(${getter}(');
												} else if (isConst) {
													output.add('alloc_ref_const(${retCast}${getter}(');
												} else {
													output.add('alloc_ref(');
													if (derefReturn)
														output.add('*');
													if (addressOfReturn)
														output.add('&');
													output.add('${retCast}${getter}(');
												}
											}
										} else {
											if (returnField == null) {
												output.add('${retCast}${getter}(');
											}
										}

										switch (f.name) {
											case "op_mul":
												output.add("*_unref(_this) * (");
											case "op_add":
												output.add("*_unref(_this) + (");
											case "op_sub":
												output.add("*_unref(_this) - (");
											case "op_div":
												output.add("*_unref(_this) / (");
											case "op_mulq":
												output.add("*_unref(_this) *= (");
											default:
												var callName = f.name;

												for (a in ret.attr) {
													switch (a) {
														case AInternal(name):
															callName = name;
														case AUpperCaseFirst:
															callName = callName.substr(0, 1).toUpperCase() + callName.substr(1);
														default:
													}
												}

												if (ret.attr.contains(AStatic))
													output.add(callName + "(");
												else if (ret.attr.indexOf(ACObject) >= 0)
													output.add(callName + "( _unref(_this) ");
												else if (ret.attr.indexOf(ACObjectRef) >= 0)
													output.add(callName + "( *_unref(_this) ");
												else
													output.add("_unref(_this)->" + callName + (isIndexed ? "[" : "("));
										}
									}
									var first = (ret.attr.indexOf(ACObject) >= 0 || ret.attr.indexOf(ACObjectRef) >= 0 ? false : true);

									// Actually process arguments for call
									for (a in margs) {
										var skip = false;
										if (first)
											first = false
										else
											output.add(", ");

										var argGetter = null;
										var isVirtual = false;

										var argCast = "";
										var argDeref = "";
										var argAddressOf = "";

										for (attr in a.t.attr) {
											switch (attr) {
												case ACast(type):
													argCast = "(" + type + ")"; // unref
												case ASubstitute(expression):
													output.add(expression);
													skip = true;
													break;
												case AGet(expr):
													argGetter = expr;
												case ADeref:
													argDeref = "*";
												case AAddressOf:
													argAddressOf = "&";
												case AVirtual:
													isVirtual = true;
												case ARef:
													switch (a.t.t) {
														case TChar, TInt, TShort, TFloat, TDouble,
															TBool: output.add(""); // Reference primitive types don't need any symbol
														default: output.add("*"); // Unreference custom type
													}

												default:
											}
										}

										switch (a.t.t) {
											case TPointer(t):
												if (isReturnArray && isVirtual && a.name == rapIdx) {
													// ??
												} else if (argCast == "") {
													argCast = "(" + makeNativeTypeRawPtr(t) + ")";
												}
											default:
										}

										if (skip)
											continue;

										output.add(argDeref + argCast + argAddressOf);

										if (argGetter != null) {
											output.add(argGetter + " (");
										}
										if (isReturnArray && isVirtual && a.name == rapIdx) {
											output.add('&__tmparray');
										} else if (a.name == returnField) {
											output.add('&__tmpret');
										} else {
											var e = getEnumShortName(a.t.t);
											if (e != null)
												output.add('${e}__values[${a.name}]');
											else
												switch (a.t.t) {
													case TArray(t, sizefield):
														switch(t) {
															case TVector(vt, vdim): 
																switch (vt) {
																	case TFloat:output.add('hl_aptr(${a.name},${"h_float" + vdim + "_array"})');
																	case TDouble: output.add('hl_aptr(${a.name},${"h_double" + vdim + "_array"})');
																	case TInt: output.add('hl_aptr(${a.name},${"h_int" + vdim + "_array"})');
																	default: throw "Unsupported vector type";
																}
															default: output.add('hl_aptr(${a.name},${makeTypeDecl({t: t, attr : a.t.attr})})');
														}
													case TPointer(t):
														// (${makeTypeDecl({t: t, attr : a.t.attr})} *)
														output.add('${a.name}');
													case TCustom(st):
														if (argAddressOf.length > 0)
															output.add('_unref(${a.name})');
														else
															output.add('_unref_ptr_safe(${a.name})');
													//														if (st == 'FloatArray' || st == "IntArray" || st == "CharArray" || st == "ShortArray") {
													//															output.add("->GetPtr()");
													//														}
													case TVector(vt, vdim):
														
														output.add('(${makeTypeDecl(a.t)})${a.name}');
													case THString:
														if (!a.t.attr.contains(AHString))
															output.add(a.name + "__cstr");
														else
															output.add(a.name);
													case TFunction(ret, ta):
														var args = ta.map((x) -> makeTypeDecl(x)).join(',');

														var fcast = '(${makeTypeDecl(ret)} (*)(${args}))';

														output.add(fcast + a.name + "->fun");
													default:
														if (isDyn(a)) {
															output.add("_GET_OPT(" + a.name + "," + dynamicAccess(a.t.t) + ")");
														} else
															output.add(a.name);
												}
										}

										if (argGetter != null) {
											output.add(")");
										}
									}

									if (enumName != null)
										output.add(')');
									else if (refRet != null && returnField == null)
										output.add((isIndexed ? "]" : ")") + (isValue ? ')' : '') + '),$refRet');
									else if (returnField == null)
										output.add(')');
									add(");");

									// post amble
									if (preamble) {
										if (initConstructor)
											output.add('\t*(___retvalue->value) = {};\n');

										for (a in margs) {
											switch (a.t.t) {
												case THString:
												// output.add("\tfree(" + a.name + "__cstr);\n");
												default:
											}
										}

										// Check for throw
										for (b in ret.attr) {
											switch (b) {
												case AValidate(expr):
													for (a in ret.attr) {
														switch (a) {
															case AThrow(msg):
																output.add("if (___retvalue != " + expr + ") hl_throw(" + msg + ");");
															default:
														}
													}
												default:
											}
										}

										if (tret.t != TVoid) {
											if (isReturnArray) {
												if (tret.t.match(TPointer(_)) || tret.t.match(TVoidPtr)) {
													add('\t__tmpret = __tmparray;');
												} else if (tret.t.match(TArray(_, _))) {
													add('\t__tmpret = _idc_alloc_array(__tmparray, __tmpLength);');
												} else {
													throw "Unsupported array type ${tret.t}";
												}
											}

											
											if (returnField != null || isReturnArray) {
												if (isCustomType) {
													if (isConst) 
														add('\treturn alloc_ref_const( __tmpret, ${makeAllocRefType(returnType)} );');
													else 
														add('\treturn alloc_ref(__tmpret, ${makeAllocRefType(returnType)} );');
												} else
													add('\treturn ${return_converter}(__tmpret);');
											} else {
												add('\treturn ${return_converter}(___retvalue);');
											}
										}
									}
								} // end add call

								var hasOpt = false;
								for (i in 0...margs.length)
									if (margs[i].opt) {
										hasOpt = true;
										break;
									}
								if (hasOpt) {
									for (i in 0...margs.length)
										if (margs[i].opt) {
											add("\tif( !" + margs[i].name + " )");
											output.add("\t\t");
											addCall(margs.slice(0, i));
											add("\telse");
										}
									output.add("\t\t");
									addCall(margs);
								} else {
									output.add("\t");
									addCall(margs);
								}
								add('}');
								output.add('DEFINE_PRIM(${defType(tret, true)}, $funName,');
								for (a in args) {
									var dskip = ignore.contains(a.name);
									for (attr in a.t.attr) {
										switch (attr) {
											case AVirtual:
												dskip = true;
											default:
										}
									}
									if (dskip)
										continue;

									output.add(' ' + (isDyn(a) ? "_NULL(" + defType(a.t) + ")" : defType(a.t)));
								}
								add(');');
								add('');

							case FAttribute(t):
								var isVal = t.attr.indexOf(AValue) >= 0;
								var isIndexed = t.attr.contains(AIndexed);
								var isReadOnly = t.attr.contains(AReadOnly);
								var needsGetter = true;
								var needsSetter = !isReadOnly;
								var addressOf = "";

								var tname = switch (t.t) {
									case TCustom(id): id;
									default: null;
								};

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

								var at:Type = null;
								var al:String = null;
								var isArray = switch (t.t) {
									case TArray(aat, aal):
										at = aat;
										al = aal;
										true;
									default: false;
								}

								var pt:Type = null;
								var isPointer = switch (t.t) {
									case TPointer(ppt):
										pt = ppt;
										true;
									default: false;
								}

								var isRef = tname != null;
								var enumName = getEnumShortName(t.t);
								var enumTypeName = getEnumTypeName(t.t);
								var isConst = t.attr.indexOf(AConst) >= 0;

								// Translate name
								var internalName = f.name;
								var getter:String = null;
								var setter:String = null;
								var setCast:String = null;
								var getCast:String = "";

								for (a in t.attr) {
									switch (a) {
										case AInternal(name): internalName = name;
										case AGet(name): getter = name;
										case ASet(name): setter = name;
										case ASetCast(type): setCast = type;
										case AGetCast(type): getCast = "(" + type + ")";
										case AAddressOf: addressOf = "&";
										default:
									}
								}
								var td = defType(t, true);

								// Get
								if (needsGetter) {
									if (isArray)  {
										add('HL_PRIM ${makeElementType(t, true)} HL_NAME(${name}_get_${haxeName})( ${typeNames.get(name).decl} _this, int index ) {');
									}else
										add('HL_PRIM ${makeTypeDecl(t, true)} HL_NAME(${name}_get_${haxeName})( ${typeNames.get(name).decl} _this ) {');

									if (isVector) {
										add('\treturn (${makeTypeDecl(t)} )${(getter == null) ? "" : getter}(_unref(_this)->${internalName});');

										//									add('\treturn _idc_alloc_array(${(getter == null) ? "" : getter}(_unref(_this)->${internalName}),${vdim});');
									} else if (getter != null)
										add('\treturn ${getter}(${addressOf}_unref(_this)->${internalName});');
									else if (enumName != null)
										add('\treturn HL_NAME(${enumName}_valueToIndex1)(_unref(_this)->${internalName});');
									else if (isVal) {
										var fname = typeNames.get(tname).constructor;
										add('\treturn alloc_ref(new $fname(_unref(_this)->${internalName}),$tname);');
									} else if (isRef)
										add('\treturn alloc_ref${isConst ? '_const' : ''}(${getCast}${addressOf}_unref(_this)->${internalName},$tname);');
									else if (isPointer) {
										add('\treturn (vbyte *)(&_unref(_this)->${internalName}[0]);');
									} else if (isArray) {
										add('\treturn ${getCast}_unref(_this)->${internalName}[index];');
//										add('\treturn _idc_alloc_array(&_unref(_this)->${internalName}[0], _unref(_this)->${al}); // This is wrong, needs to copy');
									} else {
										add('\treturn ${getCast}${addressOf}_unref(_this)->${internalName};');
									}
									add('}');

									if (isVector) {
										// Add vector getter
										add('HL_PRIM void HL_NAME(${name}_get${haxeName}v)( ${typeNames.get(name).decl} _this, ${makeTypeDecl(t)} value ) {');
										add('\t ${makeTypeDecl(vta)} *src = (${makeTypeDecl(vta)}*) & ${(getter == null) ? "" : getter}(_unref(_this)->${internalName})[0];');
										add('\t ${makeTypeDecl(vta)} *dst = (${makeTypeDecl(vta)}*) value;');
										add('\t${[for (c in 0...vdim) 'dst[$c] = src[${c}];'].join(' ')}');
										add('}');

										add('DEFINE_PRIM(_VOID,${name}_get${haxeName}v,_IDL _STRUCT  );');
									}

									if (isArray)
										add('DEFINE_PRIM(${defElementType(t, true)},${name}_get_${haxeName},_IDL _I32);');
									else
										add('DEFINE_PRIM(${defType(t, true)},${name}_get_${haxeName},_IDL);');
								}

								if (needsSetter) {
									// Set
									if (isArray)  {
										add('HL_PRIM ${makeElementType(t)} HL_NAME(${name}_set_${haxeName})( ${typeNames.get(name).decl} _this, int index, ${makeElementType(t)} value ) {');
									}
									else 
										add('HL_PRIM ${makeTypeDecl(t)} HL_NAME(${name}_set_${haxeName})( ${typeNames.get(name).decl} _this, ${makeTypeDecl(t)} value ) {');

									if (isVector) {
										add('\t ${makeTypeDecl(vta)} *dst = (${makeTypeDecl(vta)}*) & ${(getter == null) ? "" : getter}(_unref(_this)->${internalName})[0];');
										add('\t ${makeTypeDecl(vta)} *src = (${makeTypeDecl(vta)}*) value;');
										add('\t${[for (c in 0...vdim) 'dst[$c] = src[${c}];'].join(' ')}');
										//									add('\t_idc_copy_array( ${(getter == null) ? "" : getter}(_unref(_this)->${internalName}),value, ${vdim} );');
									} else if (isArray) {
										var enumName = getEnumShortName(getElementType(t).t);

										if (enumName != null) 
											add('\t_unref(_this)->${internalName}[index] = (${enumName})(${enumName}__values[value]);');
										else
											add('\t_unref(_this)->${internalName}[index] = ${setCast != null ? "(" + setCast + ")" : ""}${isVal ? "*" : ""}${isRef ? "_unref" : ""}(value);');
//										add('\t// this is probably unwise. Need to know how to properly deallocate this memory');
//										add('\tif (_unref(_this)->${internalName} != nullptr) delete _unref(_this)->${internalName};');
//										add('\t_unref(_this)->${internalName} = new ${makeTypeDecl({t : at, attr: []})}[ value->size ];');
//										add('\t_idc_copy_array(_unref(_this)->${internalName}, value);');
//										add('\t_unref(_this)->${al} = (value->size);');
									} else if (isPointer) {
										add('\t_unref(_this)->${internalName} = (${makeTypeDecl({t : pt, attr: []})}*)(value);');
									} else if (setter != null)
										add('\t_unref(_this)->${internalName} = ${setter}(${isVal ? "*" : ""}${isRef ? "_unref" : ""}(value));');
									else if (enumName != null)
										add('\t_unref(_this)->${internalName} = (${enumTypeName})HL_NAME(${enumName}_indexToValue1)(value);');
									else if (isRef )
										add('\t_unref(_this)->${internalName} = ${setCast != null ? "(" + setCast + ")" : ""}${isVal ? "*" : ""}${isRef ? "_unref_ptr_safe" : ""}(value);');
									else
										add('\t_unref(_this)->${internalName} = ${setCast != null ? "(" + setCast + ")" : ""}${isVal ? "*" : ""}${isRef ? "_unref" : ""}(value);');
									add('\treturn value;');
									add('}');

									if (isVector) {
										// Add componentwise setter

										var vparams = [for (c in 0...vdim) ' ${makeTypeDecl(vta)} value${c}'].join(',');
										add('HL_PRIM void HL_NAME(${name}_set${haxeName}${vdim})( ${typeNames.get(name).decl} _this, ${vparams} ) {');
										add('\t ${makeTypeDecl(vta)} *p = ${(getter == null) ? "" : getter}(_unref(_this)->${internalName});');

										var vcopy = [for (c in 0...vdim) 'p[$c] = value${c};'].join(' ');
										add('\t${vcopy}');
										add('}');
										var vprim = [for (c in 0...vdim) '${defType(vta)}'].join(' ');
										add('DEFINE_PRIM(_VOID,${name}_set${haxeName}${vdim},_IDL ${vprim} );');
									}

									if (isArray) {
										add('DEFINE_PRIM(${defElementType(t)},${name}_set_${haxeName},_IDL _I32 ${defElementType(t)}); // Array setter');
									} else 
										add('DEFINE_PRIM(${defType(t)},${name}_set_${haxeName},_IDL ${defType(t)});');
									add('');
								}

							case DConst(_, _, _):
						}
					}
				case DTypeDef(name, attrs, type,dtype):
				case DEnum(_), DImplements(_):
			}
		}
		add("}"); // extern C
		sys.io.File.saveContent(opts.glueDir + "idl_hl.cpp", output.toString());
	}

	

	
}
