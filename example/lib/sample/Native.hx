package sample;

#if hl
typedef Native = haxe.macro.MacroType<[idl.ModuleHL.build({ idlFile : "sample.idl", target: "hl",packageName: "sample", autoGC : true, nativeLib : "sample" })]>;
#elseif (java || jvm)
typedef Native = haxe.macro.MacroType<[idl.ModuleJVM.build({ idlFile : "sample.idl", target: "jvm", packageName: "sample", autoGC : true, nativeLib : "sample" })]>;
#else
#error "Unsupported target host"
#end

