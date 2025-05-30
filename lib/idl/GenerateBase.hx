package idl;
import idl.Options;

abstract class GenerateBase {

    var opts:Options;
    public function new (opts:Options) {
        this.opts = opts;
    }

    abstract public function generateGlue() : Void;
    abstract public function generateHX() : Void;

    function loadIDL(opts:Options) {
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
        return decls;
    }

    function command(cmd, args:Array<String>) {
		Sys.println("> " + cmd + " " + args.join(" "));
		var ret = Sys.command(cmd, args);
		if (ret != 0)
			throw "Command '" + cmd + "' has exit with error code " + ret;
	}


    static function cleanDir(dir:String) {
        if (dir == null)
			dir = "";
        else if (!StringTools.endsWith(dir, "/"))
			dir += "/";
        return dir;
    }
    

    public static function generate(opts:Options) {
        opts.glueDir = cleanDir(opts.glueDir);
        opts.buildDir = cleanDir(opts.buildDir);
        opts.hxDir = cleanDir(opts.hxDir);
        opts.installDir = cleanDir(opts.installDir);

        switch (opts.target) {
            case TargetHL:
            case TargetJVM:
            case TargetHXCPP:opts.cppFlavour = CPP_HXCPP;
            case TargetEmscripten:opts.cppFlavour = CPP_EMSCRIPTEN;
            default:
                throw "Unsupported target: " + opts.target;
        }

        var generator =  switch(opts.target) {
            case TargetHL:new GenerateHL(opts);
            case TargetJVM:new GenerateHL(opts);
            case TargetHXCPP:new GenerateCPP(opts);
            case TargetEmscripten:new GenerateHL(opts);
            default:
                throw "Unsupported target: " + opts.target;
        }

        sys.FileSystem.createDirectory(opts.glueDir);
        trace('generating glue in ' + opts.glueDir);
        generator.generateGlue();
        if (opts.generateSource) {
            sys.FileSystem.createDirectory(opts.hxDir);
             generator.generateHX();
        }
    }
}