package idl;

import sys.FileSystem;
import sys.io.File;

using StringTools;
using Lambda;

private var _defines = new Map<String, String>();
private var _hxCppDir:String;
private var _relBuildDir:String;
private var _absBuildDir:String;
private var _launchDir:String;
private var _tags = new Map<String, Bool>();

private function resolveString(s:String, ignoreMissing = false):String {
	while (s.contains("${") && s.contains("}")) {
		var start = s.indexOf("${");
		var end = s.indexOf("}", start);
		var key = s.substring(start + 2, end);
		var replace = resolveDefine(key, ignoreMissing);
		if (replace == null) {
			replace = resolveDefine(key.toLowerCase(), ignoreMissing);
		}
		if (replace == null) {
			if (ignoreMissing) {
				replace = "";
			} else {
				replace = "<" + key + ">";
			}
		}
		s = s.substring(0, start) + replace + s.substring(end + 1);
	}
	return s;
}

private function resolveDefine(key:String, ignoreMissing = false):String {
	var value = _defines.get(key);
	if (value == null) {
		return null;
	}
	return resolveString(value, ignoreMissing);
}

private function cleanPath(path:String):String {
	path = path.replace("\\", "/");
	path = path.replace("//", "/");
	if (path.endsWith('/'))
		path = path.substring(0, path.length - 1);
	if (Sys.systemName() == "Windows") {
		// path = path.replace("/", "\\");
	}
	return path;
}

private function isAbsolutePath(path:String):Bool {
	if (Sys.systemName() == "Windows") {
		static final reDriveLetter = new EReg("^[a-zA-Z]:[\\/\\\\]", "i");
		static final reUNC = new EReg("^\\\\\\\\", "i");

		if (reDriveLetter.match(path) || reUNC.match(path)) {
			return true;
		}
		//		trace('Not an absolute path: "${path}"');
		return false;
	} else if (Sys.systemName() == "Mac" || Sys.systemName() == "Linux") {
		return path.startsWith("/");
	}
	throw('Unknown system: ${Sys.systemName()}');
}

private function resolveSourcePath(file:Xml, files:Xml):String {
	var name = file.get('name');
	var dir = files.get('dir');
	var tried = [];
	var ignored = [];
	if (name == null) {
		trace(file);
		trace(files);
		throw('File element must have a name attribute');
	}
	if (name == "${resourceFile}")
		return null;

	name = cleanPath(resolveString(name));
	if (isAbsolutePath(name)) {
		if (FileSystem.exists(name))
			return name;
		tried.push(name);
	} else {
		ignored.push(name);
	}

	if (dir == null) {
		if (FileSystem.exists(name))
			return name;
		tried.push(name);
		// try build dir
		var buildPath = '${_absBuildDir}/${name}';
	} else {
		ignored.push("directory is not empty");
	}
	if (dir != null) {
		dir = resolveString(dir);
		var path = cleanPath('${dir}/${name}');
		if (FileSystem.exists(path))
			return path;
		tried.push(path);
	}

	var parentPath = files.get('path');
	if (parentPath != null) {
		var dir = parentPath.split('/').slice(0, -1).join('/');
		var path = '${dir}/${name}';
		path = cleanPath(path.replace("${HXCPP}", _hxCppDir));
		if (FileSystem.exists(path))
			return path;
		tried.push(path);
	} else {
		ignored.push("parent path is empty");
	}

	trace('Cannot resolve source path for ${name} in dir ${dir}');
	trace('from ${file}');
	trace('within ${files}');
	trace('Tried:');
	for (t in tried) {
		trace('\t${t}');
	}
	trace('Ignored:');
	for (i in ignored) {
		trace('\t${i}');
	}
	throw('Cannot resolve source path for ${name}');

	return cleanPath(name);
}

class NodeCriteria {
	public function new(tags:Array<String>, condUnless:String, condIf:String) {
		this.tags = tags;
		this.condIf = condIf;
		this.condUnless = condUnless;
	}

	public var tags:Array<String>;
	public var condUnless:String;
	public var condIf:String;

	public static function matchNode(e:Xml):Bool {
		var criteria = NodeCriteria.fromNode(e);
		if (criteria != null && !criteria.match()) {
			return false;
		}
		return true;
	}

	public static function fromNode(e:Xml):NodeCriteria {
		var tags = e.get('tags');
		var condUnless = e.get('unless');
		var condIf = e.get('if');

		if (tags == null && condUnless == null && condIf == null)
			return null;

		if (tags != null && tags.length == 0)
			tags = null;
		var tagsArray = null;
		if (tags != null) {
			tagsArray = tags.split(',').map((t) -> t.trim());
		}
		return new NodeCriteria(tagsArray, condUnless, condIf);
	}

	public function match():Bool {
		if (condIf != null) {
			var conds = condIf.split('||');
			var any = false;

			for (c in conds) {
				if (resolveDefine(condIf) != null)
					any = true;
			}

			if (!any)
				return false;
		}
		if (condUnless != null) {
			if (resolveDefine(condUnless) != null)
				return false;
		}
		if (tags != null) {
			//			trace('Checking tags: ${tags}');
			for (t in tags) {
				if (!_tags.exists(t)) {
					trace('Missing tag: ${t}');
					return false;
				}
			}
		}
		return true;
	}

	@:keep
	public function toString() {
		var tagInfo = tags != null ? tags.join(',') : "";
		var unlessInfo = condUnless != null ? 'unless:${condUnless}' : '';
		var ifInfo = condIf != null ? 'if:${condIf}' : '';
		return '${tagInfo} ${unlessInfo} ${ifInfo}';
	}
}

private function collapseSections(n:Xml) {
	var sectionsKeep = [];
	var sectionsRemove = [];

	for (e in n.elementsNamed('section')) {
		if (!NodeCriteria.matchNode(e)) {
			sectionsRemove.push(e);
			continue;
		}
		sectionsKeep.push(e);
		sectionsRemove.push(e);
	}

	for (e in sectionsKeep) {
		for (c in e.elements()) {
			n.addChild(c);
		}
	}

	for (e in sectionsRemove) {
		n.removeChild(e);
	}
}

class CompileBlock {
	function new(root:Xml, files:Array<Xml>) {
		this.id = root.get('id');
		this.root = root;
		this.files = files;
	}

	public var root:Xml;
	public var files:Array<Xml>;
	public var id:String;

	public static function fromXml(root:Xml):CompileBlock {
		collapseSections(root);
		var blockCriteria = NodeCriteria.fromNode(root);
		if (blockCriteria != null && !blockCriteria.match()) {
			return null;
		}
		var files = [for (f in root.elements()) f].filter((f) -> {
			if (f.nodeName != 'file')
				return false;
			var fileCriteria = NodeCriteria.fromNode(f);
			if (fileCriteria != null && !fileCriteria.match()) {
				return false;
			}
			return true;
		});

		// if (files.length == 0)
		// 	return null;

		for (f in files) {
			var srcPath = resolveSourcePath(f, root);
			if (srcPath == "${resourceFile}")
				return continue;

			if (srcPath == null) {
				throw('Cannot resolve source path for ${f} on ${root}');
			}
			if (!srcPath.startsWith('/')) {
				srcPath = FileSystem.absolutePath(srcPath);
			}
			f.set('srcPath', srcPath);
		}
		return new CompileBlock(root, files);
	}
}

class Target {
	function new(root:Xml) {
		this.root = root;
	}

	public var root:Xml;

	public function merge(otherRoot:Xml) {
		for (a in otherRoot.attributes()) {
			this.root.set(a, otherRoot.get(a));
		}
		for (e in otherRoot.elements()) {
			this.root.addChild(e);
		}
	}

	public static function fromXml(root:Xml):Target {
		collapseSections(root);

		return new Target(root);
	}
}

class CMakeGenerateHXCPP {
	static var _builder:StringBuf;

	static function addLine(line:String) {
		_builder.add(line);
		_builder.add('\n');
	}

	static function resolvePath(path:String, required = true) {
		path = resolveString(path);
		if (FileSystem.exists(path)) {
			#if (cmake_idl_verbose > 1)
			trace('Found path: ${path}');
			#end
			return path;
		}
		//        trace('Resolving path: ${path}');

		if (FileSystem.exists(path))
			return path;
		if (path.startsWith('/'))
			return path;
		// try prepending hxcpp dir
		#if (cmake_idl_verbose > 2)
		trace('defaulting ${path}');
		#end
		path = '${_hxCppDir}/${path}';
		if (FileSystem.exists(path))
			return path;
		if (required) {
			throw('Cannot resolve path: ${path}');
		}
		return path;
	}

	static function saveIfDifferent(path:String, content:String) {
		if (FileSystem.exists(path)) {
			var oldContent = File.getContent(path);
			if (oldContent == content) {
				trace('Skipping ${path} - no change');
				return;
			}
		}
		File.saveContent(path, content);
	}

	static function getFlatXML(path:String, included:Array<String>):Array<Xml> {
		var rpath = resolvePath(path);
		#if (cmake_idl_verbose > 1)
		trace('--> Processing ${rpath} XML');
		#end
		var xmlStr = File.getContent(rpath);
		var xmlRoot = Xml.parse(xmlStr).firstElement();
		var elements = [for (e in xmlRoot.elements()) e];

		if (included.contains(rpath)) {
			//            trace('Already included: ${rpath}');
			return [];
		}
		included.push(rpath);

		var finalElements = [];
		function resolveLocalDefines() {
			var this_dir = FileSystem.absolutePath(rpath).split('/').slice(0, -1).join('/');

			for (e in elements) {
				if (e.nodeName == 'set') {
					var value = e.get('value');
					if (value != null) {
						value.replace("${this_dir}", this_dir);
						value.replace("${THIS_DIR}", this_dir);
						e.set('value', value);
					}
				}
			}
		}
		resolveLocalDefines();

		for (e in elements) {
			if (e.nodeName == 'include') {
				var name = e.get('name');

				var actualPath = name;
				if (included.contains(actualPath)) {
					//					trace('Already included: ${actualPath}');
					continue;
				}

				//				trace('Recursing into include: ${name}');

				var includeElements = getFlatXML(actualPath, included);
				for (ie in includeElements) {
					finalElements.push(ie);
				}
				// var includePath = e.get('path');
				// var includeElements = getFlatXML(includePath);
				// finalElements = finalElements.concat(includeElements);
			} else {
				if (e.nodeName == 'files') {
					e.set('path', path);
				}
				finalElements.push(e);
			}
		}

		return finalElements;

		// var files = elements.filter(function(e) return e.nodeName == 'file');
		// var include = elements.filter(function(e) return e.nodeName == 'include');
		// var sets = elements.filter(function(e) return e.nodeName == 'set');

		// trace(elements.map(function(e) return e.nodeName));
	}

	public static function main() {
		var args = Sys.args();

		_launchDir = Sys.getCwd();
		var buildDir = args.shift();

		if (buildDir.startsWith('/')) {
			_absBuildDir = buildDir;
			_relBuildDir = buildDir.replace(_launchDir + "/", '');
		} else {
			_relBuildDir = buildDir;
			_absBuildDir = '${_launchDir}/${_relBuildDir}';
		}
		_absBuildDir = cleanPath(_absBuildDir);
		_relBuildDir = cleanPath(_relBuildDir);

		_defines.set('BUILD_DIR', _absBuildDir);
		_defines.set('LAUNCH_DIR', _launchDir);
		_defines.set('IDL_DIR', "IDL_DIR");
		_defines.set('exe_link', '1');
		//		_defines.set('HXCPP_M64', '1');
		if (Sys.systemName() == "Windows") {
			_defines.set('HXCPP_ARCH', 'x86_64');
			_defines.set('windows', '1');
			_defines.set('HXCPP_M64', '1');
			_defines.set('HXCPP_MSVC_VER', '190');

			var cl_version = 19;
			var cl_versionStr = '${cl_version}';
			_defines.set('MSVC_VER', cl_versionStr);
			if (cl_version >= 17)
				_defines.set("MSVC17+", "1");
			if (cl_version >= 18)
				_defines.set("MSVC18+", "1");
			if (cl_version >= 19)
				_defines.set("MSVC19", "1");
			//               BuildTool.sAllowNumProcs = cl_version >= 14;
			//    var threads = BuildTool.getThreadCount();
			//    if (threads>1 && cl_version>=18)
			//       ioDefines.set("HXCPP_FORCE_PDB_SERVER","1");
		} else {
			_defines.set('HXCPP_ARCH', 'arm64');
			_defines.set('HXCPP_ARM64', '1');
		}
		_defines.set('removeQuotes:hxcpp_api_level', '430');
		_defines.set('CPPIA_NO_JIT', '1');

		_tags.set('haxe', true);
		_tags.set('main', true);
		_tags.set('static', true);
		_tags.set('gc', true);
		_tags.set('hxstring', true);
		#if (cmake_idl_verbose > 1)
		trace('Build dir: ${_absBuildDir} | ${_relBuildDir}');
		#end

		var includeDirs = new Array<String>();
		var libDirs = new Array<String>();

		while (args.length > 0) {
			var arg = args.shift();
			switch (arg) {
				case "--I":
					includeDirs.push(args.shift());
				case "--L":
					libDirs.push(args.shift());
				default:
			}
		}
		trace('Building CMakeLists.txt in ${_relBuildDir} from ${_launchDir}');

		for (i in includeDirs) {
			trace('Include dir: ${sys.FileSystem.absolutePath(i)}');
		}
		_builder = new StringBuf();

		var optionsStr = File.getContent('${_relBuildDir}/Options.txt');

		for (o in optionsStr.split('\n')) {
			o = o.trim();
			if (o.length == 0)
				continue;
			var parts = o.split('=');
			var key = parts[0].trim();
			var value = parts[1].trim();
			_defines.set(key, value);
		}

		#if (cmake_idl_verbose > 1)
		for (o in _defines.keyValueIterator()) {
			trace('${o.key} = ${o.value}');
		}
		#else

		// var xmlStr = File.getContent('${outDir}/Build.xml');

		// var xmlRoot = Xml.parse(xmlStr).firstElement();
		// var elements = [for (e in xmlRoot.elements()) e];
		// var files = elements.filter(function(e) return e.nodeName == 'file');
		// var include = elements.filter(function(e) return e.nodeName == 'include');
		// var sets = elements.filter(function(e) return e.nodeName == 'set');

		if (resolveDefine('hxcpp') == null) {
			trace('hxcpp not set');
			return;
		}
		_hxCppDir = resolveDefine('hxcpp');
		if (_hxCppDir.endsWith('/')) {
			_hxCppDir = _hxCppDir.substring(0, _hxCppDir.length - 1);
		}
		#if (cmake_idl_verbose > 1)
		trace('hxcpp dir: ${_hxCppDir}');
		#end

		//        var xml = getFlatXML('${hxCppDir}/toolchain/setup.xml');  // not very meaningful
		var includes = [];
		var haxeTargetXML = getFlatXML('${_hxCppDir}/toolchain/haxe-target.xml', includes);
		var commonDefines = getFlatXML('${_hxCppDir}/toolchain/common-defines.xml', includes);
		var generatedBuildXMLPath = '${_relBuildDir}/Build.xml';

		var buildXML = getFlatXML(generatedBuildXMLPath, includes);

		var allElements = haxeTargetXML.concat(buildXML).concat(commonDefines);

		for (s in allElements.filter((e) -> e.nodeName == "set")) {
			if (NodeCriteria.matchNode(s)) {
				var name = s.get('name');
				var value = s.get('value');
				#if (cmake_idl_verbose > 1)
				trace('Setting ${name} = ${value}');
				#end
				_defines.set(name, value);
			}
		}
		var hxcppFileBlocks = new Map<String, CompileBlock>();
		for (e in allElements.filter((e) -> e.nodeName == "files")) {
			var filesCriteria = NodeCriteria.fromNode(e);
			var id = e.get('id');
			var block = CompileBlock.fromXml(e);
			if (block == null) {
				#if (cmake_idl_verbose > 1)
				trace('Skipping block ${id}');
				#end
				continue;
			}
			hxcppFileBlocks.set(id, block);

			//			trace('Found file block: ${id}');
			// for (f in block.files) {
			// 	var srcPath = f.get('srcPath');
			// 	trace('\t${srcPath}');
			// }
		}

		var targetMap = new Map<String, Target>();

		for (e in allElements.filter((e) -> e.nodeName == "target")) {
			var id = e.get('id');
			if (id == null) {
				trace('Target missing id');
				continue;
			}
			if (targetMap.exists(id)) {
				targetMap.get(id).merge(e);
			} else {
				targetMap.set(id, Target.fromXml(e));
			}
		}

		var haxeTarget = targetMap.get('haxe');

		if (haxeTarget == null) {
			trace('No haxe target');
			return;
		}

		var targetBlocks = [];

		var cppIncludeDirs = [];
		var cppLibDirs = [];
		var miscCompilerFlags = [];
		var cppWarnings = [];
		var cppDefines = [];
		var linkLibs = [];
		var findLibs = [];

		for (dir in includeDirs) {
			cppIncludeDirs.push(sys.FileSystem.absolutePath(dir));
		}

		if (Sys.systemName() == "Windows") {
			cppDefines.push('HX_WINDOWS');
			cppDefines.push('HXCPP_WIN');
			cppDefines.push('HXCPP_M64');
		} else if (Sys.systemName() == "Mac") {
			cppDefines.push('HX_MACOS');
			cppDefines.push('HXCPP_M64');
			cppWarnings.push('no-parentheses');
			cppWarnings.push('null-dereference');
			cppWarnings.push('unused-value');
			cppWarnings.push('format-extra-args');
			cppWarnings.push('overflow');
			cppWarnings.push('no-invalid-offsetof');
			cppWarnings.push('no-return-type-c-linkage');
		} else if (Sys.systemName() == "Linux") {
			cppDefines.push('HX_LINUX');
			cppDefines.push('HXCPP_LINUX');
			cppDefines.push('HXCPP_M64');
		}

		function addFlag(n:Xml) {
			var value = resolveString(n.get("value"));
			if (value.startsWith('-I')) {
				value = value.substring(2);
				if (!cppIncludeDirs.contains(value))
					cppIncludeDirs.push(cleanPath(value));
			} else if (value.startsWith('-L')) {
				cppLibDirs.push(value.substring(2));
			} else if (value.startsWith('-W')) {
				cppWarnings.push(value.substring(2));
			} else if (value.startsWith('-D')) {
				value = value.substring(2);
				if (!cppDefines.contains(value))
					cppDefines.push(value);
			} else if (value.startsWith('-l')) {
				linkLibs.push(value.substring(2));
			} else {
				miscCompilerFlags.push(value);
			}
		}

		function addFlags(elements:Iterator<Xml>) {
			for (cf in elements) {
				if (!NodeCriteria.matchNode(cf)) {
					// trace('Skipping flag: ${cf.get('value')}');
					continue;
				}

				if (cf.nodeName == 'findlib') {
					#if (cmake_idl_verbose > 1)
					trace('Adding findlib: ${cf.get('value')} at ${cf.get('dir')}');
					#end
					findLibs.push({name: cf.get('value'), dir: cf.get('dir'), link: cf.get('link') == 'true', raw:cf.get('raw') == 'true'});
					continue;
				}

				if (cf.nodeName != 'compilerflag' && cf.nodeName != 'flag' && cf.nodeName != 'cppflag') {
					continue;
				}
				#if (cmake_idl_verbose > 1)
				trace('Adding flag: ${cf.get('value')}');
				#end
				addFlag(cf);
			}
		}

		addFlags(allElements.iterator());

		for (e in haxeTarget.root.elements()) {
			if (!NodeCriteria.matchNode(e)) {
				continue;
			}
			switch (e.nodeName) {
				case 'files':
					var block = hxcppFileBlocks.get(e.get('id'));
					if (block == null) {
						trace('No block for ${e.get('id')}');
						continue;
					}
					addFlags(block.root.elements());

					if (block.files.length == 0) {
						continue;
					}
				// trace('Adding files from ${e.get('id')}');
				// for (f in block.files) {
				//     trace('\t${f.get('srcPath')}');
				// }
				case 'lib':
					var libName = e.get('name');

					trace('Adding lib: ${libName}');
					linkLibs.push(libName);
				case 'options':
				default:
					trace('Unknown node: ${e.nodeName}');
			}
		}
		if (Sys.systemName() == "Mac") {
			miscCompilerFlags.push(resolveString("-arch ${HXCPP_ARCH}"));
		}

		#if (cmake_idl_verbose > 1)
		trace('Include dirs: ${cppIncludeDirs.join(',')}');
		trace('Lib dirs: ${cppLibDirs.join(',')}');
		trace('Misc compiler flags: ${miscCompilerFlags.join(',')}');
		trace('Compiler warnings: ${cppWarnings.join(',')}');
		trace('Compiler defines: ${cppDefines.join(',')}');
		#end
		var outputName = resolveString(haxeTarget.root.get('output'), true);
		addLine('cmake_minimum_required(VERSION 3.20)');
		addLine('\n');
		addLine('project(${outputName} C CXX)');
		addLine('\n');
		addLine('set(CMAKE_CXX_STANDARD 20)');
		addLine('\n');
		addLine('add_executable(${outputName}');

		for (f in haxeTarget.root.elementsNamed('files')) {
			if (!NodeCriteria.matchNode(f)) {
				//				trace('Skipping block: ${f.get('id')}');
				continue;
			}

			#if (cmake_idl_verbose > 1)
			trace('Looking for files in ${f.get('id')}');
			#end
			var block = hxcppFileBlocks.get(f.get('id'));
			if (block == null) {
				continue;
			}

			for (f in block.files) {
				var fpath = cleanPath(f.get('srcPath'));

				if (!NodeCriteria.matchNode(f)) {
					trace('Skipping file: ${fpath}');
					continue;
				}
				//				trace('Adding file: ${f.get('srcPath')}');
				addLine('\t${fpath}');
			}
		}

		addLine(')');

		if (findLibs.length > 0) {
			addLine('');
			for (fl in findLibs) {
				var rdir = resolvePath(fl.dir);
				if (rdir == null) {
					trace('Cannot resolve dir: ${fl.dir}');
					continue;
				}
				var adir = FileSystem.absolutePath(rdir);
				if (fl.raw) {
					cppLibDirs.push(adir);
				} else {
					#if (cmake_idl_verbose > 1)
					trace('Adding findlib: ${fl.name} at ${fl.dir}');
					#end
					addLine('set (${fl.name}_DIR ${adir})');
					addLine('find_package(${fl.name} REQUIRED)');
				}
			}
			addLine('');

			addLine('target_link_libraries(${outputName}');
			for (fl in findLibs) {
				if (fl.link) {
					if (fl.raw) {
						addLine('\t${fl.name}');
					} else {
						addLine('\t${fl.name}::${fl.name}');
					}
				}
			}
			for (ll in linkLibs) {
				addLine('\t${ll}');
			}
			addLine(')');
		}

		addLine ('target_link_directories(${outputName} PRIVATE');
		for (d in cppLibDirs) {
			var rd = resolvePath(d);
			if (FileSystem.exists(rd)) {
				var absDir = FileSystem.absolutePath(rd);
				#if (cmake_idl_verbose > 1)
				trace('Adding library dir: ${absDir}');
				#end
				addLine('\t${absDir}');
			} else {
				trace('Library dir not found: ${rd}');
			}
		}
		addLine(')');

		addLine('target_include_directories(${outputName} PRIVATE');

		cppIncludeDirs.push(resolvePath("${BUILD_DIR}/include"));
		for (d in cppIncludeDirs) {
			var rd = resolvePath(d);
			if (FileSystem.exists(rd)) {
				var absDir = FileSystem.absolutePath(rd);
				#if (cmake_idl_verbose > 1)
				trace('Adding include dir: ${absDir}');
				#end
				addLine('\t${absDir}');
			} else {
				trace('Include dir not found: ${rd}');
			}
		}
		addLine(')');

		addLine('target_compile_options(${outputName} PRIVATE');
		for (f in miscCompilerFlags) {
			addLine('\t${f}');
		}
		for (f in cppWarnings) {
			addLine('\t-W${f}');
		}
		addLine(')');

		addLine('target_compile_definitions(${outputName} PRIVATE');
		for (f in cppDefines) {
			addLine('\t${f}');
		}
		addLine(')');

		saveIfDifferent('${_relBuildDir}/CMakeLists.txt', _builder.toString());
	}
}

// - Parsing include: /Users/rcleven/git/hxcpp/toolchain/setup.xml
// - Parsing include: /Users/rcleven/.hxcpp_config.xml (section "vars")
// - Running process: xcode-select --print-path
// - Parsing include: /Users/rcleven/git/hxcpp/toolchain/finish-setup.xml
// - Parsing makefile: /Users/rcleven/git/hl-idl/example/bin/cpp/Build.xml
// - Parsing include: /Users/rcleven/git/hxcpp/build-tool/BuildCommon.xml
// - Parsing include: /Users/rcleven/git/hxcpp/toolchain/haxe-target.xml
// - Parsing include: /Users/rcleven/git/hxcpp/src/hx/libs/zlib/Build.xml
// - Parsing include: /Users/rcleven/git/hl-idl/example/sample.xml
// - Parsing include: /Users/rcleven/git/hl-idl/example/sample.xml
// - Parsing include: /Users/rcleven/git/hxcpp/toolchain/mac-toolchain.xml
// - Parsing include: /Users/rcleven/git/hxcpp/toolchain/gcc-toolchain.xml
// - Adding path: /Applications/Xcode.app/Contents/Developer/usr/bin
// - Parsing compiler: /Users/rcleven/git/hxcpp/toolchain/common-defines.xml
// - Parsing include: /Users/rcleven/.hxcpp_config.xml (section "exes")
// - Parsing include: ${hxCppDir}/toolchain/setup.xml
// - Parsing include: /Users/rcleven/.hxcpp_config.xml (section "vars")
// - Running process: xcode-select --print-path
// - Parsing include: ${hxCppDir}/toolchain/finish-setup.xml
// - Parsing makefile: /Users/rcleven/git/hl-idl/example/bin/cpp/Build.xml
// - Parsing include: ${hxCppDir}/build-tool/BuildCommon.xml
// - Parsing include: ${hxCppDir}/toolchain/haxe-target.xml
// - Parsing include: /Users/rcleven/git/hl-idl/example/sample.xml
// - Parsing include: /Users/rcleven/git/hl-idl/example/sample.xml
// - Parsing include: ${hxCppDir}/toolchain/mac-toolchain.xml
// - Parsing include: ${hxCppDir}/toolchain/gcc-toolchain.xml
// - Adding path: /Applications/Xcode.app/Contents/Developer/usr/bin
// - Parsing compiler: ${hxCppDir}/toolchain/common-defines.xml
// - Parsing include: /Users/rcleven/.hxcpp_config.xml (section "exes")
// trace(elements);
//         <target id="haxe" tool="linker" toolid="${haxelink}" output="${HAXE_OUTPUT_FILE}">
//   <files id="haxe"/>
//   <options name="Options.txt"/>
//   <ext value="${LIBEXTRA}.a" if="iphoneos" unless="dll_import" />
//   <ext value="${LIBEXTRA}.a" if="iphonesim" unless="dll_import" />
//   <ext value="${LIBEXTRA}.a" if="appletvos" unless="dll_import" />
//   <ext value="${LIBEXTRA}.a" if="appletvsim" unless="dll_import" />
//   <ext value="${LIBEXTRA}.a" if="watchos" unless="dll_import" />
//   <ext value="${LIBEXTRA}.a" if="watchsimulator" unless="dll_import" />
//   <section if="android">
//      <ext value="${LIBEXTRA}.so" />
//      <ext value="${LIBEXTRA}.a"  if="static_link" />
//      <ext value="${LIBEXTRA}" if="exe_link" />
//   </section>
//   <fullouput name="${HAXE_FULL_OUTPUT_NAME}" if="HAXE_FULL_OUTPUT_NAME" />
//   <fullunstripped name="${HAXE_FULL_UNSTRIPPED_NAME}" if="HAXE_FULL_UNSTRIPPED_NAME" />
//   <files id="__main__" unless="static_link" />
//   <files id="__lib__" if="static_link"/>
//   <files id="__resources__" />
//   <files id="__externs__" />
//   <files id="runtime" unless="dll_import" />
//   <files id="cppia" if="scriptable" />
//   <files id="tracy" if="HXCPP_TRACY" />
//   <files id="rc" unless="static_link" />
//   <lib name="-lpthread" if="linux" unless="static_link" />
//   <lib name="-ldl" if="linux" unless="static_link" />
// </target>
// /lib/idl/GenerateCMakeHXCPP.hx:345: Setting hxcpp_api_level = ${HXCPP_API_LEVEL}
// ../lib/idl/GenerateCMakeHXCPP.hx:345: Setting CPPIA_JIT = 1
// ../lib/idl/GenerateCMakeHXCPP.hx:345: Setting EXESUFFIX = .exe
// ../lib/idl/GenerateCMakeHXCPP.hx:345: Setting HAXE_OUTPUT_PART = ${HAXE_OUTPUT}
// ../lib/idl/GenerateCMakeHXCPP.hx:345: Setting HAXE_OUTPUT_FILE = ${LIBPREFIX}${HAXE_OUTPUT_PART}${DBG}
// ../lib/idl/GenerateCMakeHXCPP.hx:345: Setting magiclibs = 1
// ../lib/idl/GenerateCMakeHXCPP.hx:345: Setting HXCPP_API_LEVEL = 430
// ../lib/idl/GenerateCMakeHXCPP.hx:345: Setting HAXE_OUTPUT = SampleMain
// ../lib/idl/GenerateCMakeHXCPP.hx:345: Setting ZLIB_DIR = ${HXCPP}/project/thirdparty/zlib-1.2.13
