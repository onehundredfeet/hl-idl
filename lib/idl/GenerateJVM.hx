package idl;

import haxe.macro.Expr.Function;
import idl.Data;
import idl.Options;

using StringTools;

class GenerateJVM extends GenerateBase {
	public function new(opts:Options) {
		super(opts);
	}

	public function generateGlue() : Void {

	}
    public function generateHX() : Void {

	}
	
	static final HELPER_TEXT = "
	#ifndef __JVM_IDL_HELPERS_H_
#define __JVM_IDL_HELPERS_H_

/*
#include <hl.h>
#include <string>

void hl_cache_string_type( vstring *str);
vstring * hl_utf8_to_hlstr( const char *str);
vstring * hl_utf8_to_hlstr( const std::string &str);

#pragma once



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
*/
#endif
	";

	static var HEADER_JVM = "
	#include <jni.h>

	static JNIEnv *__s_haxe_env = nullptr;
	static jclass __s_h_float = 0;
	static jmethodID __s_h_float_floatValue = 0;
	static jclass __s_h_int = 0;
	static jmethodID __s_h_int_intValue = 0;

	static inline void cacheJavaEnv(JNIEnv *p ) {
		if (__s_haxe_env == nullptr) {
			__s_haxe_env = p;
			__s_h_float = p->FindClass(\"java/lang/Float\");
			__s_h_float_floatValue = p->GetMethodID(__s_h_float, \"floatValue\", \"()F\");
			__s_h_int = p->FindClass(\"java/lang/Integer\");
			__s_h_int_intValue = p->GetMethodID(__s_h_int, \"intValue\", \"()I\");			
		} else if (__s_haxe_env != p) {
			printf(\"ERROR: Java env changed!\\n\");
		}
	}

	
// Float vector
struct _h_float2 {
	float x;
	float y;
};

struct _h_float3 {
	float x;
	float y;
	float z;
};

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

struct _h_double3 {
	double x;
	double y;
	double z;
};

struct _h_double4 {
	double x;
	double y;
	double z;
	double w;
};


inline jobject _returnPointer( void *p ) {
	return 0;
}

template<class T>
inline T *h_aptr( jobject p ) {
	return nullptr;
}

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
            delete []_ptr;
    }
};
	";

	/*
		#include <hl.h>
		#include \"hl-idl-helpers.hpp\"
		// Need to link in helpers
		//HL_API hl_type hltx_ui16;
		//HL_API hl_type hltx_ui8;
		JNIEXPORT hl_type hltx_ui16 = { HUI16 };
		JNIEXPORT hl_type hltx_ui8 = { HUI8 };

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

		JNIEXPORT vstring * JNICALL getdllversion)(vstring * haxeversion) {
		strType = haxeversion->t;
		return haxeversion;
		}
	 */
	static var HEADER_NO_GC = "

#define alloc_ref(r, _) r
#define alloc_ref_const(r,_) r
#define _ref(t)			t
#define _unref(v)		v
#define free_ref(v) delete (v)
#define HL_CONST const

	";

	static var HEADER_GC = "
#define free_ref(v)
#define _unref(v) v
#define alloc_ref(r,_) (nullptr)
	";

	#if i_were_hl
	/*
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

		inline void testvector(_hl_float3 *v) {
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
	 */
	#end
	static var HEADER_NATIVE_TYPES = "
	";

	static final JNI_PARAMETER_PREFIX = "JNIEnv *__env";

	static function makeJNIFunctionDeclaration(jniName:String) {
		return 'JNIEXPORT void JNICALL ${jniName}';
	}

	static function makeJNIFunctionName(packageName:String, className:String, functionName) {
		return 'Java_${packageName}_${className}_${functionName}';
	}

	static function initOpts(opts:Options) {
		if (opts.glueDir == null)
			opts.glueDir = "";
		else if (!StringTools.endsWith(opts.glueDir, "/"))
			opts.glueDir += "/";
	}

	public static function generateCpp(opts:Options) {
		sys.io.File.saveContent(opts.glueDir + "jvm-idl-helpers.hpp", HELPER_TEXT);

		var file = opts.idlFile;
		var content = sys.io.File.getBytes(file);
		var parse = new idl.Parser();
		var decls = null;
		var gc = opts.autoGC;
		try {
			decls = parse.parseFile(file, new haxe.io.BytesInput(content));
		} catch (msg:String) {
			throw msg + "(" + file + " line " + parse.line + ")";
		}
		var output = new StringBuf();
		var outputJava = new Map<String, StringBuf>();
		function add(str:String) {
			output.add(str.split("\r\n").join("\n") + "\n");
		}
		var packageName = opts.packageName;

		function addJava(className:String, str:String) {
			var strbuf = outputJava.get(className);
			if (strbuf == null) {
				strbuf = new StringBuf();
				outputJava.set(className, strbuf);
				strbuf.add('package ${packageName};\n');
				strbuf.add("\n");
				strbuf.add('public class ${className} {\n');
				strbuf.add('\t private long _this;\n');
			}
			strbuf.add(str.split("\r\n").join("\n") + "\n");
		}

		add("");
		//		add('#define JNICALL x) ${opts.nativeLib}_##x');
		add(StringTools.trim(HEADER_JVM));
		add(StringTools.trim(gc ? HEADER_GC : HEADER_NO_GC));
		add("");
		if (opts.customCode != null) {
			add("");
			add(StringTools.trim(opts.customCode.getJVMInclude()));
		}
		add("");
		add("");
		add(StringTools.trim(HEADER_NATIVE_TYPES));
		add("");
		add("");
		add('extern "C" {');
		add("");

		if (opts.version == null) {
			opts.version = "undefined";
		}

		// Java_ClassName_MethodName
		add('JNIEXPORT jstring JNICALL Java_${packageName}_Init_getdllversion(JNIEnv *env) {
			return env->NewStringUTF(\"${opts.version}\");
		}');
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

					add('static jclass __h_c_${name};');
					add('static jfieldID __h_f_${name}_this;');
					add('static jmethodID __h_m_${name}_ctor;');

					add('static inline void cache__h_c_${name}( JNIEnv *env){
						if (__h_c_${name} == nullptr){
							__h_c_${name} = env->FindClass(\"${packageName}/${name}\");
							__h_f_${name}_this = env->GetFieldID(__h_c_${name} , \"_this\", \"J\");
							__h_m_${name}_ctor = env->GetMethodID(__h_c_${name} ,\"<init>\", \"()V\");
						}
					}\n');
					// Create the object of the class UserData
					//    jclass userDataClass = env->FindClass("com/baeldung/jni/UserData");

					// Get the UserData fields to be set
					//  jfieldID nameField = env->GetFieldID(userDataClass , "name", "Ljava/lang/String;");
					// jfieldID balanceField = env->GetFieldID(userDataClass , "balance", "D");

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
					// var refFullName = "pref<" + prefix + intName + ">*";
					var refFullName = "jobject";
					typeNames.set(name, {
						full: prefix + intName,
						constructor: prefix + intName,
						isInterface: true,
						isEnum: false,
						decl: refFullName
					});
					if (!(attrs.indexOf(ANoDelete) >= 0)) {
						addJava(name, '@Override\npublic native void finalize();');
						var freeRefText = 'free_ref(_this ${deleteName != null ? "," + deleteName : ""})';
						if (destructExpr != null) {
							freeRefText = '${destructExpr}(_this->value )';
						}
						// add('JNIEXPORT void JNICALL ${makeJNIFunctionName(packageName, name, "finalize")} ( ${JNI_PARAMETER_PREFIX} ) { $freeRefText; }');
						// add('JNIEXPORT void JNICALL ${makeJNIFunctionName(packageName, name, "dispose")}( ${JNI_PARAMETER_PREFIX} ) {\n\t$freeRefText;\n}');
					}

				//					add('DEFINE_PRIM(_VOID, ${name}_delete, _IDL);');
				case DEnum(name, attrs, values, _):
					enumNames.set(name, true);
					typeNames.set(name, {
						full: "int",
						constructor: null,
						isInterface: true,
						isEnum: true,
						decl: "int"
					});

					var etname = name;
					for (a in attrs) {
						switch (a) {
							case AInternal(iname): etname = iname;
							case APrefix(prefix): values = values.map((x) -> prefix + x);
							default:
						}
					}
					add('static $etname ${name}__values[] = { ${values.join(",")} };');
					add('JNIEXPORT int JNICALL ${name}_toValue(${JNI_PARAMETER_PREFIX}, int idx ) {\n\treturn ${name}__values[idx];\n}');
					//					add('DEFINE_PRIM(_I32, ${name}_toValue0, _I32);');
					add('JNIEXPORT int JNICALL ${name}_indexToValue(${JNI_PARAMETER_PREFIX}, int idx ) {\n\treturn ${name}__values[idx];\n}');
					//					add('DEFINE_PRIM(_I32, ${name}_indexToValue1, _I32);');
					add('JNIEXPORT int JNICALL ${name}_valueToIndex(${JNI_PARAMETER_PREFIX}, int value ) {\n\tfor( int i = 0; i < ${values.length}; i++ ) if ( value == (int)${name}__values[i]) return i; return -1;\n}');
					//					add('DEFINE_PRIM(_I32, ${name}_valueToIndex1, _I32);');
					add('JNIEXPORT int JNICALL ${name}_fromValue(${JNI_PARAMETER_PREFIX}, int value ) {\n\tfor( int i = 0; i < ${values.length}; i++ ) if ( value == (int)${name}__values[i]) return i; return -1;\n}');
					//					add('DEFINE_PRIM(_I32, ${name}_fromValue1, _I32);');
					add('JNIEXPORT int JNICALL ${name}_fromIndex(${JNI_PARAMETER_PREFIX}, int index ) {return index;}');
				//					add('DEFINE_PRIM(_I32, ${name}_fromIndex1, _I32);');
				case DTypeDef(name, attrs, type, dtype):
				case DImplements(_):
					
			}
		}

		function getEnumName(t:idl.Data.Type) {
			return switch (t) {
				case TCustom(id): enumNames.exists(id) ? id : null;
				default: null;
			}
		}

		function makeNativeTypeRaw(t:idl.Data.Type, isReturn:Bool = false) {
			return switch (t) {
				case TChar: "jcharr";
				case TFloat: "jfloat";
				case TDouble: "jdouble";
				case TShort: "jshort";
				case TInt64: "jlong";
				case TUInt: "jint";
				case TInt: "jint";
				case TVoid: "void";
				case TAny, TVoidPtr: "void*";
				case TArray(t, size):
					switch (t) {
						case TFloat: "jfloatArray";
						case TInt: "jintArray";
						case TShort: "jshortArray";
						case TChar: "jcharArray";
						case TDouble: "jdoubleArray";
						default: "jarray";
					}
				case TDynamic: "vdynamic*";
				case TType: "hl_type*";
				case TPointer(t): "jobject";
				case TBool: "jboolean";
				case TEnum(_): "jint";
				case TBytes: "jobject";
				case TIOBytes: "jobject";
				case TCustom(id): {
						var t = typeNames.get(id);
						if (t == null) {
							throw "Unsupported type " + id;
						} else {
							typeNames.get(id).decl;
						}
					}
				case TVector(vt, vdim): "jobject";
				/*
					case TVector(vt, vdim):
						switch (vt) {
							case TFloat: "_h_float" + vdim + "*";
							case TDouble: "_h_double" + vdim + "*";
							case TInt: "_h_int" + vdim + "*";
							default: throw "Unsupported vector type";
				}*/
				default:
					throw "Unknown type " + t;
			}
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
				case TChar: "jchar";
				case TFloat: "jfloat";
				case TDouble: "jdouble";
				case TShort: "jshort";
				case TInt64: "jlong";
				case TUInt: "jint";
				case TInt: "jint";
				case TVoid: "void";
				case TAny, TVoidPtr: "void*";
				case TArray(t, size):
					switch (t) {
						case TFloat: "jfloatArray";
						case TInt: "jintArray";
						case TShort: "jshortArray";
						case TChar:
							"jcharArray";
						case TDouble: "jdoubleArray";
						default: "jarray";
					}
				case TDynamic: "vdynamic*";
				case TType: "hl_type*";
				case TPointer(t): "jobject";
				case TBool: "jboolean";
				case TEnum(_): "jint";
				case THString: "jstring";
				case TBytes: "jobject";
				case TIOBytes: "jobject";
				case TCustom(id): {
						var t = typeNames.get(id);
						if (t == null) {
							throw "Unsupported type " + id;
						} else {
							typeNames.get(id).decl;
						}
					}
				case TVector(vt, vdim): "jobject";
				/*
					case TVector(vt, vdim):
						switch (vt) {
							case TFloat: "_h_float" + vdim + "*";
							case TDouble: "_h_double" + vdim + "*";
							case TInt: "_h_int" + vdim + "*";
							default: throw "Unsupported vector type";
				}*/
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
				case TPointer(at), TArray(at, _): {t: at, attr: t.attr};
				default: throw "Not an array type: " + t.t.getName() + " : " + t.t.getParameters();
			}
		}

		function makeElementType(t:idl.Data.TypeAttr, isReturn = false) {
			return switch (t.t) {
				case TPointer(at), TArray(at, _): makeType({t: at, attr: t.attr}, isReturn);
				default: throw "Not an array type: " + t.t.getName() + " : " + t.t.getParameters();
			}
		}

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
				case TFunction(ret, ta):
					var args = (ta == null || ta.length == 0) ? "_NO_ARG" : ta.map((x) -> defType(x)).join(" ");
					"_FUN(" + defType(ret) + ',${args})';
				case TCustom(name): enumNames.exists(name) ? "_I32" : t.attr.contains(ACStruct) ? "_STRUCT" : "_IDL";
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
							prefix += "/*CONST*/ ";
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
					var intName = name;

					for (a in attrs)
						switch (a) {
							case AInternal(iname): intName = iname;
							default:
						}

					for (f in fields) {
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

								var isConstr = f.name == name;
								if (isConstr) {
									f.name = "nativeNew";
								}
								var args = (ret.attr.indexOf(AStatic) >= 0) ? margs : [
									{
										name: "_obj",
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

								var tret = isConstr ? {t: TVoid, attr: []} : ret; // {t: TCustom(name), attr: []}
								var isIndexed = tret.attr.contains(AIndexed);
								var isReturnArray = false;
								var rapIdx:String = null;
								var ralIdx:String = null;
								var rapArg:FArg = null;
								var ralArg:FArg = null;
								var return_converter = switch (tret.t) {
									case THString: "hl_utf8_to_hlstr";
									default: "";
								}

								for (ta in tret.attr) {
									switch (ta) {
										case AReturnArray(pIdx, lengthIdx):
											rapIdx = pIdx;
											ralIdx = lengthIdx;
											isReturnArray = true;
											rapArg = findArg(rapIdx);
											ralArg = findArg(ralIdx);
										case AGet(name): return_converter = name;
										default:
									}
								}

								// Static functions needs the exact number of arguments as function suffix. Otherwise C++ compilation will fail.

								f.name.replace("_", "_1");
								var funName = makeJNIFunctionName(packageName, name, isConstr ? "nativeNew" : f.name);
								// var staticPrefix = (attrs.indexOf(AStatic) >= 0) ? "static" : ""; ${staticPrefix}
								output.add('JNIEXPORT ${makeTypeDecl(returnField == null ? tret : returnType, true)} JNICALL $funName(${JNI_PARAMETER_PREFIX}');
								var first = false;

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
										switch(a.t.t) {
											case TCustom(id):
												output.add('/* ${id} */');
											case TArray(t, _):
												output.add('/* ${t} */');
											default:
										}
										
									}
								}
								add(') {');

								// preamble
								add('\tcache__h_c_${name}(__env);');
								if (!isConstr) {
									add('\t${intName} *_this = (${intName}*)__env->GetLongField(_obj, __h_f_${name}_this);');
								}

								function addCall(margs:Array<{name:String, opt:Bool, t:TypeAttr}>) {
									var isCustomType = ret.t.match(TCustom(_));
									var enumName = getEnumName(tret.t);

									// preamble
									var preamble = returnField != null || isReturnArray || (isCustomType && enumName == null);

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
												case TCustom(id):
													preamble = true;
													var t = typeNames.get(id);
													if (t == null) {
														throw "Unsupported type " + id;
													} else {
														typeNames.get(id).decl;
													}
													if (!enumNames.exists(id)) {
														output.add('cache__h_c_${id}(__env);\n');
														add('\t${id} *_${a.name} = (${id}*)__env->GetLongField(${a.name}, __h_f_${id}_this);');
													} else {
														add('\tauto _${a.name} = ${a.name};');
													}
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

									var isRef = ret.attr.contains(ARef);
									var isValue = ret.attr.contains(AValue);
									var isConst = ret.attr.contains(AConst);

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
											output.add('auto ___retvalue = ${retCast}(${constructorExpr}(');
										} else {
											output.add('auto *_this = ${retCast}(${constructorExpr}(');
										}
									} else {
										if (tret.t != TVoid) {
											if (preamble) {
												if (returnField == null) {
													output.add('auto ___retvalue = ${retCast}');
												}
											} else
												output.add('return ${return_converter}');
										}
										if (isRef || isValue || isCustomType) {
											refRet = switch (tret.t) {
												case TCustom(id): id;
												default: throw "assert";
											}
										}

										if (enumName != null) {
											output.add('${enumName}_valueToIndex(nullptr, ');
										} else if (isCustomType) {
											if (returnField == null) {
												if ((isRef || addressOfReturn) && isConst) {
													output.add('${retCast}${getter}&('); // we shouldn't call delete() on this one !
												} else if (isValue) {
													output.add('${retCast}new ${typeNames.get(refRet).constructor}(${getter}(');
												} else if (isConst) {
													output.add('${retCast}${getter}(');
												} else {
													output.add('');
													if (derefReturn)
														output.add('*');
													if (addressOfReturn)
														output.add('&');
													output.add('${retCast}${getter}(');
												}
											}
										} else {
											if (returnField == null) {
												output.add('${retCast}${getter}');
											}
										}

										switch (f.name) {
											case "op_mul":
												output.add("*_this * (");
											case "op_add":
												output.add("*_this + (");
											case "op_sub":
												output.add("*_this - (");
											case "op_div":
												output.add("*_this / (");
											case "op_mulq":
												output.add("*_this *= (");
											default:
												var callName = f.name;

												for (a in ret.attr) {
													switch (a) {
														case AInternal(name):
															callName = name;
														default:
													}
												}

												if (ret.attr.contains(AStatic))
													output.add(callName + "(");
												else if (ret.attr.indexOf(ACObject) >= 0)
													output.add(callName + "( _this ");
												else if (ret.attr.indexOf(ACObjectRef) >= 0)
													output.add(callName + "( *_this ");
												else
													output.add("_this->" + callName + (isIndexed ? "[" : "("));
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
													argCast = "(" + makeNativeTypeRaw(t) + "*)";
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
											var e = getEnumName(a.t.t);
											if (e != null)
												output.add('${e}__values[${a.name}]');
											else
												switch (a.t.t) {
													case TArray(t, sizefield):
														switch (t) {
															case TVector(vt, vdim):
																switch (vt) {
																	case TFloat: output.add('h_aptr<${"_h_float" + vdim}>(${a.name})');
																	case TDouble: output.add('h_aptr<${"_h_double" + vdim}>(${a.name})');
																	case TInt: output.add('h_aptr<${"_h_int" + vdim}>(${a.name})');
																	default: throw "Unsupported vector type";
																}
															default: output.add('h_aptr<${makeTypeDecl({t: t, attr : a.t.attr})}>(${a.name})');
														}
													case TPointer(t):
														// (${makeTypeDecl({t: t, attr : a.t.attr})} *)
														output.add('${a.name}');
													case TCustom(st):
														if (argAddressOf.length > 0)
															output.add('_${a.name}');
														else
															output.add('_${a.name}');
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
										output.add('))');
									else if (refRet != null && returnField == null)
										output.add((isIndexed ? "]" : ")") + (isValue ? ')' : '') + ')');
									else if (returnField == null)
										output.add(')');

									add(";");

									// post amble
									if (preamble) {
										if (!isConstr && isCustomType && enumName == null) {
											var retTypeName = switch (ret.t) {
												case TCustom(id): id;
												case defualt: "Error";
											};

											output.add('cache__h_c_${retTypeName}(__env);\n');
											output.add('\tauto _new_obj = __env->NewObject( __h_c_${retTypeName}, __h_m_${retTypeName}_ctor);\n');
											output.add('\t__env->SetLongField(_new_obj, __h_f_${retTypeName}_this, (long long)___retvalue);\n');
										}
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
													throw "Unsupported array type";
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
												if (isCustomType && enumName == null) {
													add('\treturn _new_obj;');
												} else {
													add('\treturn ${return_converter}(___retvalue);');
												}
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
								if (isConstr) {
									add('\t__env->SetLongField(_obj, __h_f_${name}_this, (long long)_this);');
								}
								add('}');
								/*
									//								output.add('DEFINE_PRIM(${defType(tret, true)}, $funName,');
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
									add(');'); */

								add('');

							case FAttribute(t):
								var isVal = t.attr.indexOf(AValue) >= 0;
								var isIndexed = t.attr.contains(AIndexed);
								var isReadOnly = t.attr.contains(AReadOnly);
								var needsGetter = true;
								var needsSetter = !isReadOnly;

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
								var enumName = getEnumName(t.t);
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
										default:
									}
								}
								var td = defType(t, true);

								// Get
								if (needsGetter) {
									if (isArray) {
										add('JNIEXPORT ${makeElementType(t, true)} JNICALL ${makeJNIFunctionName(packageName, name,'get_1${f.name}' )}( ${JNI_PARAMETER_PREFIX}, jobject _obj, int index ) {');
									} else
										add('JNIEXPORT ${makeTypeDecl(t, true)} JNICALL ${makeJNIFunctionName(packageName, name,'get_1${f.name}' )}( ${JNI_PARAMETER_PREFIX}, jobject _obj ) {');

									add('cache__h_c_${name}(__env);');
									add('${intName} *_this = (${intName}*)__env->GetLongField(_obj, __h_f_${name}_this);');

									if (isVector) {
										add('\treturn (${makeTypeDecl(t)} )${(getter == null) ? "" : getter}(${JNI_PARAMETER_PREFIX}, _this->${internalName});');

										//									add('\treturn _idc_alloc_array(${(getter == null) ? "" : getter}(_this->${internalName}),${vdim});');
									} else if (getter != null)
										add('\treturn ${getter}(_this->${internalName});');
									else if (enumName != null)
										add('\treturn ${enumName}_valueToIndex(nullptr, _this->${internalName});');
									else if (isVal) {
										var fname = typeNames.get(tname).constructor;
										add('\treturn alloc_ref(new $fname(_this->${internalName}),$tname);');
									} else if (isRef)
										add('\treturn alloc_ref${isConst ? '_const' : ''}(_this->${internalName},$tname);');
									else if (isPointer) {
										add('\treturn _returnPointer(&_this->${internalName}[0]);');
									} else if (isArray) {
										add('\treturn ${getCast}_this->${internalName}[index];');
										//										add('\treturn _idc_alloc_array(&_this->${internalName}[0], _this->${al}); // This is wrong, needs to copy');
									} else {
										add('\treturn ${getCast}_this->${internalName};');
									}
									add('}');

									if (isVector) {
										// Add vector getter
										add('JNIEXPORT void JNICALL ${name}_get${f.name}v( ${JNI_PARAMETER_PREFIX}, ${typeNames.get(name).full} _this, ${makeTypeDecl(t)} value ) {');
										add('\t ${makeTypeDecl(vta)} *src = (${makeTypeDecl(vta)}*) & ${(getter == null) ? "" : getter}(_this->${internalName})[0];');
										add('\t ${makeTypeDecl(vta)} *dst = (${makeTypeDecl(vta)}*) value;');
										add('\t${[for (c in 0...vdim) 'dst[$c] = src[${c}];'].join(' ')}');
										add('}');

										//										add('DEFINE_PRIM(_VOID,${name}_get${f.name}v,_IDL _STRUCT  );');
									}

									/*
										if (isArray)
											add('DEFINE_PRIM(${defElementType(t, true)},${name}_get_${f.name},_IDL _I32);');
										else
											add('DEFINE_PRIM(${defType(t, true)},${name}_get_${f.name},_IDL);');
									 */
								}

								if (needsSetter) {
									// Set
									if (isArray) {
										add('JNIEXPORT ${makeElementType(t)} JNICALL ${makeJNIFunctionName(packageName, name,'set_1${f.name}' )}(${JNI_PARAMETER_PREFIX}, jobject _obj, int index, ${makeElementType(t)} value ) {');
									} else
										add('JNIEXPORT ${makeTypeDecl(t)} JNICALL ${makeJNIFunctionName(packageName, name,'set_1${f.name}' )}(${JNI_PARAMETER_PREFIX}, jobject _obj, ${makeTypeDecl(t)} value ) {');
									add('cache__h_c_${name}(__env);');
									add('${intName} *_this = (${intName}*)__env->GetLongField(_obj, __h_f_${name}_this);');

									if (isVector) {
										add('\t ${makeTypeDecl(vta)} *dst = (${makeTypeDecl(vta)}*) & ${(getter == null) ? "" : getter}(_this->${internalName})[0];');
										add('\t ${makeTypeDecl(vta)} *src = (${makeTypeDecl(vta)}*) value;');
										add('\t${[for (c in 0...vdim) 'dst[$c] = src[${c}];'].join(' ')}');
										//									add('\t_idc_copy_array( ${(getter == null) ? "" : getter}(_this->${internalName}),value, ${vdim} );');
									} else if (isArray) {
										var enumName = getEnumName(getElementType(t).t);

										if (enumName != null)
											add('\t_this->${internalName}[index] = (${enumName})(${enumName}__values[value]);');
										else
											add('\t_this->${internalName}[index] = ${setCast != null ? "(" + setCast + ")" : ""}${isVal ? "*" : ""}${isRef ? "_unref" : ""}(value);');
										//										add('\t// this is probably unwise. Need to know how to properly deallocate this memory');
										//										add('\tif (_this->${internalName} != nullptr) delete _this->${internalName};');
										//										add('\t_this->${internalName} = new ${makeTypeDecl({t : at, attr: []})}[ value->size ];');
										//										add('\t_idc_copy_array(_this->${internalName}, value);');
										//										add('\t_this->${al} = (value->size);');
									} else if (isPointer) {
										add('\t_this->${internalName} = (${makeTypeDecl({t : pt, attr: []})}*(value);');
									} else if (setter != null)
										add('\t_this->${internalName} = ${setter}(${isVal ? "*" : ""}${isRef ? "_unref" : ""}(value));');
									else if (enumName != null)
										add('\t_this->${internalName} = (${enumName})${enumName}_indexToValue(nullptr, value);');
									else if (isRef)
										add('\t_this->${internalName} = ${setCast != null ? "(" + setCast + ")" : ""}${isVal ? "*" : ""}${isRef ? "_unref_ptr_safe" : ""}(value);');
									else
										add('\t_this->${internalName} = ${setCast != null ? "(" + setCast + ")" : ""}${isVal ? "*" : ""}${isRef ? "_unref" : ""}(value);');
									add('\treturn value;');
									add('}');

									if (isVector) {
										// Add componentwise setter

										var vparams = [for (c in 0...vdim) ' ${makeTypeDecl(vta)} value${c}'].join(',');
										add('JNIEXPORT void JNICALL ${name}_set${f.name}${vdim}(${JNI_PARAMETER_PREFIX}, ${typeNames.get(name).full} _this, ${vparams} ) {');
										add('\t ${makeTypeDecl(vta)} *p = ${(getter == null) ? "" : getter}(_this->${internalName});');

										var vcopy = [for (c in 0...vdim) 'p[$c] = value${c};'].join(' ');
										add('\t${vcopy}');
										add('}');
										var vprim = [for (c in 0...vdim) '${defType(vta)}'].join(' ');
										// add('DEFINE_PRIM(_VOID,${name}_set${f.name}${vdim},_IDL ${vprim} );');
									}

									if (isArray) {
										// add('DEFINE_PRIM(${defElementType(t)},${name}_set_${f.name},_IDL _I32 ${defElementType(t)}); // Array setter');
									} else {
										// add('DEFINE_PRIM(${defType(t)},${name}_set_${f.name},_IDL ${defType(t)});');
									}
									add('');
								}

							case DConst(_, _, _):
						}
					}
				case DTypeDef(name, attrs, type, dtype):
				case DEnum(_), DImplements(_):
			
			}
		}
		add("}"); // extern C
		sys.io.File.saveContent(opts.glueDir + "idl_jvm.cpp", output.toString());
		/*
			for (kv in outputJava.keyValueIterator()) {
				kv.value.add("}");
				sys.io.File.saveContent(opts.glueDir + "/" + opts.packageName + '/${kv.key}.java', kv.value.toString());
			}
		 */
	}
}
