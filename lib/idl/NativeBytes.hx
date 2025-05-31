package idl;

class NativeBytes {
    #if cpp
    public static inline function fromIO(bytes:haxe.io.Bytes):cpp.Pointer<cpp.UInt8> {
        return cpp.Pointer.ofArray(bytes.getData());
    }
    #end
}