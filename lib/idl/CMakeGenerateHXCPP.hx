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

enum ToolChain {
	UNKNOWN;
	OSX;
}

var _toolChainName = [ToolChain.UNKNOWN => "", ToolChain.OSX => "mac"];

private function resolveString(s:String, ignoreMissing = false, preserve = false):String {
	var head = 0;
	while ((s.indexOf("${", head) >= 0) && (s.indexOf("}", head + 2) >= 0)) {
		var start = s.indexOf("${", head);
		var end = s.indexOf("}", start);
		var key = s.substring(start + 2, end);
		var replace = resolveDefine(key, ignoreMissing);
		if (replace == null) {
			replace = resolveDefine(key.toLowerCase(), ignoreMissing);
		}
		if (replace == null) {
			if (ignoreMissing) {
				replace = preserve ? null : "";
			} else {
				replace = "<" + key + ">";
			}
		}
		if (replace != null) {
			s = s.substring(0, start) + replace + s.substring(end + 1);
			head = start + replace.length;
		} else {
			head = end + 1;
		}
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

	var xmlPath = file.get('_xml_path');
	if (xmlPath == null) {
		xmlPath = files.get('_xml_path');
	}
	if (xmlPath != null) {
		var xmlDir = sys.FileSystem.absolutePath(haxe.io.Path.directory(xmlPath));
		_defines.set('this_dir', xmlDir);
	}

	function cleanReturn(s:String):String {
		_defines.remove('this_dir');
		return cleanPath(FileSystem.absolutePath(s));
	}

	name = cleanPath(resolveString(name));
	if (isAbsolutePath(name)) {
		if (FileSystem.exists(name))
			return cleanReturn(name);
		tried.push(name);
	} else {
		ignored.push(name);
	}

	if (dir == null) {
		if (FileSystem.exists(name))
			return cleanReturn(name);
		tried.push(name);
		// try build dir
		var buildPath = '${_absBuildDir}/${name}';
		if (FileSystem.exists(buildPath)) {
			return cleanReturn(buildPath);
		}
		tried.push(buildPath);
	} else {
		ignored.push("directory is not empty");
	}
	if (dir != null) {
		dir = resolveString(dir);
		var path = cleanPath('${dir}/${name}');
		if (FileSystem.exists(path))
			return cleanReturn(path);
		tried.push(path);
	}

	var parentPath = files.get('path');
	if (parentPath != null) {
		var dir = parentPath.split('/').slice(0, -1).join('/');
		var path = '${dir}/${name}';
		path = cleanPath(path.replace("${HXCPP}", _hxCppDir));
		if (FileSystem.exists(path))
			return cleanReturn(path);
		tried.push(path);
	} else {
		ignored.push("parent path is empty");
	}

	trace('1 Cannot resolve source path for ${name} in dir ${dir}');
	//	trace('from ${file}');
	//	trace('within ${files}');
	trace('Tried:');
	for (t in tried) {
		trace('\t${t}');
	}
	trace('Ignored:');
	for (i in ignored) {
		trace('\t${i}');
	}
	throw('2 Cannot resolve source path for ${file}');

	return cleanReturn(name);
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
		// collapseSections(root);
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
				throw('3 Cannot resolve source path for ${f} on ${root}');
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

	static function resolvePath(path:String, required = true, context:Xml = null) {
		if (context != null) {
			// {
			// 	var node = context;
			// 	var dir:String = null;
			// 	while (node != null && dir == null) {
			// 		dir = node.get('dir');
			// 		node = node.parent;
			// 		if (node != null && node.nodeType != Xml.Element) {
			// 			node = null;
			// 		}
			// 	}

			// 	if (dir != null) {
			// 		throw('We have a directory!');
			// 	}
			// }
			var xmlPath = context.get('_xml_path');
			if (xmlPath != null) {
				var xmlDir = sys.FileSystem.absolutePath(haxe.io.Path.directory(xmlPath));
				_defines.set('this_dir', xmlDir);
			}
		}

		path = cleanPath(path);
		path = resolveString(path);

		_defines.remove('this_dir');

		if (haxe.io.Path.isAbsolute(path)) {
			if (FileSystem.exists(path)) {
				//				trace('Resolved absolute path: ${path}');
				return path;
			} else {
				trace('Failed to resolve absolute path: ${path}');
			}
		}

		if (context != null) {
			// {
			// 	var node = context;
			// 	var dir:String = null;
			// 	while (node != null && dir == null) {
			// 		dir = node.get('dir');
			// 		node = node.parent;
			// 		if (node != null && node.nodeType != Xml.Element) {
			// 			node = null;
			// 		}
			// 	}

			// 	if (dir != null) {
			// 		throw('We have a directory!');
			// 	}
			// }
			var xmlPath = context.get('_xml_path');
			if (xmlPath != null) {
				var xmlDir = sys.FileSystem.absolutePath(haxe.io.Path.directory(xmlPath));
				// try prepending xml dir
				var xmlPathResolved = cleanPath('${xmlDir}/${path}');
				if (FileSystem.exists(xmlPathResolved)) {
					return xmlPathResolved;
				} else {
					//					trace('Failed to resolve relative path: ${path} to ${xmlPathResolved}');
				}
			}
		}

		if (FileSystem.exists(path)) {
			#if (cmake_idl_verbose > 1)
			//			trace('Found path: ${path}');
			#end
			return path;
		}
		//        trace('Resolving path: ${path}');

		if (FileSystem.exists(path))
			return path;
		if (path.startsWith('/'))
			return path;

		//		trace('Continuing to Resolving relative path: ${path} in ${context}');
		// try prepending hxcpp dir
		#if (cmake_idl_verbose > 2)
		trace('defaulting to hxcpp path: ${path}');
		#end
		path = '${_hxCppDir}/${path}';
		if (FileSystem.exists(path))
			return path;
		if (required) {
			throw('Cannot resolve path: ${path} - ${context}');
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

	static function loadXML(path:String):Array<Xml> {
		#if (cmake_idl_verbose > 0)
		trace('Inflating XML from ${path}');
		#end

		var rpath = resolvePath(path);
		#if (cmake_idl_verbose > 1)
		//		trace('--> Processing ${rpath} XML');
		#end

		var xmlStr = File.getContent(rpath);
		var xmlRoot = Xml.parse(xmlStr).firstElement();
		var this_dir = FileSystem.absolutePath(rpath).split('/').slice(0, -1).join('/');

		function stampPath(x:Xml) {
			x.set('_xml_path', rpath);
			for (e in x.elements()) {
				stampPath(e);
			}
		}
		stampPath(xmlRoot);

		return [for (e in xmlRoot.elements()) e];
	}

	// static function inflateXML(path:String, included = null):Array<Xml> {
	// 	if (included == null) {
	// 		included = [];
	// 	}
	// 	var localIncluded = [];
	// 	function resolveLocalDefines(le:Xml) {
	// 		//			trace('Resolving local defines in ${le}');
	// 		for (a in le.attributes()) {
	// 			var value = le.get(a);
	// 			if (value == null)
	// 				continue;
	// 			if (value.contains("${")) {
	// 				value = value.replace("${this_dir}", this_dir);
	// 				value = value.replace("${THIS_DIR}", this_dir);
	// 				value = resolveString(value, true, true);
	// 				//					trace('\tResolved value: ${value} in ${a} in ${le}');
	// 				le.set(a, value);
	// 			}
	// 		}
	// 		for (ce in le.elements()) {
	// 			resolveLocalDefines(ce);
	// 		}
	// 	}
	// 	for (e in xmlRoot.elements()) {
	// 		resolveLocalDefines(e);
	// 	}
	// 	var remove = [];
	// 	var added = [];
	// 	// it's not recursing into the files to get the subincludes
	// 	for (e in xmlRoot.elements()) {
	// 		if (e.nodeName == 'include') {
	// 			remove.push(e);
	// 			var fileName = e.get('name');
	// 			// if (!NodeCriteria.matchNode(e)) {
	// 			// 	trace('SKIPPING include: ${fileName} - does not match criteria');
	// 			// 	continue;
	// 			// }
	// 			if (fileName.toUpperCase().contains("HXCPP_CONFIG")) {
	// 				//						trace('Skipping include: ${fileName} - HXCPP_CONFIG');
	// 				continue;
	// 			}
	// 			fileName = resolvePath(fileName, true, e);
	// 			if (fileName.contains("${")) {
	// 				throw('Cannot resolve include name: ${fileName} in ${e}');
	// 			}
	// 			if (included.contains(fileName.toLowerCase()) || localIncluded.contains(fileName.toLowerCase())) {
	// 				//						trace('Skipping already included file: ${fileName}');
	// 				continue;
	// 			}
	// 			trace('Embedding include: ${fileName}');
	// 			localIncluded.push(fileName.toLowerCase());
	// 			var includeElements = inflateXML(fileName, included);
	// 			for (ie in includeElements) {
	// 				//						trace('embedding ${ie.nodeName}');
	// 				added.push(ie);
	// 				if (ie.nodeName == 'pragma') {
	// 					if (ie.get('once') == 'true') {
	// 						included.push(fileName.toLowerCase());
	// 					}
	// 				}
	// 			}
	// 		}
	// 		//					trace('Found set
	// 	}
	// 	for (e in remove) {
	// 		parent.removeChild(e);
	// 	}
	// 	for (e in added) {
	// 		parent.addChild(e);
	// 	}
	// 	for (e in xmlRoot.elements()) {
	// 		trace('Element: ${e.nodeName} - ${e.get('id')}');
	// 	}
	// 	return [for (e in xmlRoot.elements()) e];
	// 	// var files = elements.filter(function(e) return e.nodeName == 'file');
	// 	// var include = elements.filter(function(e) return e.nodeName == 'include');
	// 	// var sets = elements.filter(function(e) return e.nodeName == 'set');
	// 	// trace(elements.map(function(e) return e.nodeName));
	// }

	static function attrList(n:Xml) {
		var attrs = [];
		for (a in n.attributes()) {
			var value = n.get(a);
			if (value == null)
				continue;
			attrs.push('${a}="${value}"');
		}
		return attrs;
	}

	static final validElements = [
		'file',
		'include',
		'set',
		'section',
		'files',
		'target',
		'options',
		'compilerflag',
		'cppflag',
		'flag',
		'findlib',
		'copy'
	];
	static var allowedFileIDs = [];

	static function walkElements(root:Xml, callback:Xml->Bool, depth = 1000) {
		for (e in root.elements()) {
			if (NodeCriteria.matchNode(e)) {
				if (!callback(e))
					continue;
				if (e.nodeName == 'files') {
					if (!allowedFileIDs.contains(e.get('id'))) {
						//						trace('SKIPPING files element with ID: ${e.get('id')} - not in allowed list');
						continue;
					}
				}
				if (depth > 0) {
					walkElements(e, callback, depth - 1);
				}
			}
		}
	}

	static function walkRootElements(root:Xml, callback:Xml->Bool) {
		walkElements(root, callback, 0);
	}

	static function walkTree(root:Xml, callback:Xml->Bool) {
		walkElements(root, callback, 1000);
	}

	static function cbProcessSets(x:Xml) {
		if (x.nodeName == 'set') {
			var defineName = resolveString(x.get('name'));
			var value = resolveString(x.get('value'));
			if (!_defines.exists(defineName)) {
				//				trace('Setting define: ${defineName} = ${value}');
				_defines.set(defineName, value);
			} else {
				trace('Warning - define ${defineName} already exists with value ${_defines.get(defineName)}');
				_defines.set(defineName, value);
			}
			return false;
		}
		return true;
	}

	static function walkSets(root:Xml, depth = 1000) {
		var anyChange = false;
		var changed = true;
		while (changed) {
			walkElements(root, (x:Xml) -> {
				changed = false;
				if (x.nodeName == 'set') {
					var defineName = resolveString(x.get('name'));
					var value = resolveString(x.get('value'));
					if (!_defines.exists(defineName)) {
						//						trace('Setting define: ${defineName} = ${value}');
						_defines.set(defineName, value);
						changed = true;
						anyChange = true;
					} else {
						if (value != _defines.get(defineName)) {
							trace('Warning - overriding define ${defineName} with value ${value} (was ${_defines.get(defineName)})');
							_defines.set(defineName, value);
							changed = true;
							anyChange = true;
						}
					}
					return false;
				}
				if (x.nodeName == 'section') {
					return true;
				}
				return false;
			}, depth);
		}
		return anyChange;
	}

	static var included = [];

	static function addIncludes(root:Xml, recurseFiles = true, depth = 1000) {
		var anyChanged = false;
		var changed = true;
		while (changed) {
			changed = false;
			var to_remove = [];
			var to_add = new Array<{p:Xml, n:Xml}>();
			// gather includes
			walkElements(root, (x:Xml) -> {
				if (x.nodeName == 'include') {
					var included = x.parent.get('__included') == null ? [] : x.parent.get('__included').split(';');

					var fileName = x.get('name');
					to_remove.push(x);

					if (fileName.toUpperCase().contains("HXCPP_CONFIG")) {
						//	trace('Skipping include: ${fileName} - HXCPP_CONFIG');
						return false;
					}

					fileName = resolvePath(fileName, true, x);

					if (fileName.contains("${")) {
						throw('Cannot resolve include name: ${fileName} in ${x}');
					}

					if (included.contains(fileName.toLowerCase())) {
						//						trace('Skipping already included file: ${fileName}');
						return false;
					}

					anyChanged = true;
					included.push(fileName.toLowerCase());

					for (e in loadXML(fileName)) {
						to_add.push({p: x.parent, n: e});
					}
					x.parent.set('__included', included.join(';'));
				}
				if (x.nodeName == 'section') {
					return true;
				}
				if (recurseFiles && x.nodeName == 'files' && allowedFileIDs.contains(x.get('id'))) {
					return true;
				}
				return false;
			}, depth);

			for (x in to_remove) {
				x.parent.removeChild(x);
			}
			for (pn in to_add) {
				pn.p.addChild(pn.n);
			}
		}

		return anyChanged;
	}

	static function gatherTargets(root:Xml, depth = 1000) {
		var haxeTargets = [];
		walkElements(root, (x:Xml) -> {
			if (x.nodeName == 'target') {
				if (x.get('id') != null && x.get('id') == 'haxe') {
					if (!haxeTargets.contains(x)) {
						haxeTargets.push(x);
					}
				}
				return false;
			}
			return true;
		});

		return haxeTargets;
	}

	static function libPackageName(n:String) {
		if (n.contains('::')) {
			return n.split('::')[0];
		}
		return n;
	}

	public static function main() {
		var args = Sys.args();
		var toolChain = switch (Sys.systemName().toLowerCase()) {
			case "mac", "osx", "darwin": ToolChain.OSX;
			default: ToolChain.UNKNOWN;
		};
		if (toolChain == ToolChain.UNKNOWN) {
			throw('Unknown system: ${Sys.systemName()}');
		}
		var toolChainName = _toolChainName.get(toolChain);

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
		_defines.set('toolchain', toolChainName);

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

		// <include name="${HXCPP}/build-tool/BuildCommon.xml"/>
		// <include name="${HXCPP}/src/hx/libs/std/Build.xml"/>
		// <include name="${HXCPP}/src/hx/libs/std/Build.xml"/>

		function buildXMLSkeleton() {
			var toolchainXml = loadXML('${_hxCppDir}/toolchain/setup.xml').concat(loadXML('${_hxCppDir}/toolchain/${toolChainName}-toolchain.xml'))
				.concat(loadXML('${_hxCppDir}/toolchain/common-defines.xml'))
				.concat(loadXML('${_hxCppDir}/toolchain/finish-setup.xml'));
			// var haxeTargetXML = inflateXML('${_hxCppDir}/toolchain/haxe-target.xml');
			var generatedBuildXMLPath = '${_relBuildDir}/Build.xml';

			var buildXML = loadXML(generatedBuildXMLPath);

			// var allElements = haxeTargetXML.concat(commonDefines).concat(buildXML);
			var allBaseElements = toolchainXml.concat(buildXML);
			var rootXML = Xml.createElement('root');
			for (e in allBaseElements) {
				rootXML.addChild(e);
			}
			return rootXML;
		}

		var targetFilesFilters = [];
		var targetBlocks = [];
		var cppIncludeDirs = [];
		var cppLibDirs = [];
		var miscCompilerFlagsAll = [];
		var miscCompilerFlagsC = [];
		var cppWarnings = [];
		var cppDefines = new Map<String, Array<String>>();
		var linkLibs = [];
		var findLibs = [];
		var copies = [];

		cppDefines.set('haxe', []);
		var coreDefines = cppDefines.get('haxe');

		if (Sys.systemName() == "Windows") {
			coreDefines.push('HX_WINDOWS');
			coreDefines.push('HXCPP_WIN');
			coreDefines.push('HXCPP_M64');
		} else if (Sys.systemName() == "Mac") {
			coreDefines.push('HX_MACOS');
			coreDefines.push('HXCPP_M64');
			cppWarnings.push('no-parentheses');
			cppWarnings.push('null-dereference');
			cppWarnings.push('unused-value');
			cppWarnings.push('format-extra-args');
			cppWarnings.push('overflow');
			cppWarnings.push('no-invalid-offsetof');
			cppWarnings.push('no-return-type-c-linkage');
			miscCompilerFlagsAll.push(resolveString("-arch ${HXCPP_ARCH}"));
		} else if (Sys.systemName() == "Linux") {
			coreDefines.push('HX_LINUX');
			coreDefines.push('HXCPP_LINUX');
			coreDefines.push('HXCPP_M64');
		}

		for (dir in includeDirs) {
			cppIncludeDirs.push(sys.FileSystem.absolutePath(dir));
		}
		cppIncludeDirs.push('${_hxCppDir}/include');
		// ${HXCPP}/include

		var rootXML = buildXMLSkeleton();
		while (walkSets(rootXML) || addIncludes(rootXML)) {};

		#if (cmake_idl_verbose > 2)
		for (d in _defines.keyValueIterator()) {
			trace('Define: ${d.key} = ${d.value}');
		}
		#end

		var haxeTargets = gatherTargets(rootXML);

		for (t in haxeTargets) {
			//			trace('Processing target: ${t}');
			walkElements(t, (x:Xml) -> {
				if (x.nodeName == 'files') {
					var children = [for (x in x.elements()) x];
					if (children.length == 0) {
						var id = x.get('id');
						if (!allowedFileIDs.contains(id)) {
							#if (cmake_idl_verbose > 1)
							trace('Adding file ID to allowed list: ${id}');
							#end
							allowedFileIDs.push(id);
						}
					}
				}

				return false;
			});
		}

		while (walkSets(rootXML) || addIncludes(rootXML)) {};

		var targetFiles = new Map<String, Array<Xml>>();
		targetFiles.set('haxe', []);

		walkElements(rootXML, (x:Xml) -> {
			if (x.nodeName == 'cache') {
				if (x.get('asLibrary') == 'true') {
					if (x.parent.get('__library') == null) {
						var libName = x.parent.get('id');
						x.parent.set('__library', libName);
						targetFiles.set(libName, []);
					}
				}
			}
			return true;
		});

		function addFlag(n:Xml) {
			var libname = n.parent.get('__library');
			if (libname == null || n.get('_xml_path') != n.parent.get('_xml_path')) {
				libname = 'haxe';
			} else {
				//				trace('flag is unique to library: ${libname} - ${n}');
			}

			var value = resolveString(n.get("value"));
			if (value.startsWith('-I')) {
				value = value.substring(2);
				value = resolvePath(value, true, n);
				if (!cppIncludeDirs.contains(value)) {
					//					trace('Adding include dir: ${value}');
					cppIncludeDirs.push(value);
				}
			} else if (value.startsWith('-L')) {
				cppLibDirs.push(value.substring(2));
			} else if (value.startsWith('-W')) {
				cppWarnings.push(value.substring(2));
			} else if (value.startsWith('-D')) {
				if (!cppDefines.exists(libname)) {
					cppDefines.set(libname, []);
				}
				value = value.substring(2);
				if (!cppDefines.get(libname).contains(value))
					cppDefines.get(libname).push(value);
			} else if (value.startsWith('-l')) {
				linkLibs.push(value.substring(2));
			} else {
				if (value.startsWith('-std=c99')) {
					miscCompilerFlagsC.push(value);
				} else {
					miscCompilerFlagsAll.push(value);
				}
			}
		}

		function processCommon(x:Xml) {
			switch (x.nodeName) {
				case 'copy':
					#if (cmake_idl_verbose > 1)
					trace('YAY --> Adding copy: ${x.get('value')}');
					#end
					copies.push({src: x.get('src'), dst: x.get('dest')});
				case 'compilerflag', 'flag', 'cppflag':
					#if (cmake_idl_verbose > 1)
					trace('Adding flag: ${x.get('value')}');
					#end
					addFlag(x);
				case 'findlib':
					var dir = x.get('dir');
					dir = dir == null ? null : resolvePath(dir, true, x);
					#if (cmake_idl_verbose > 1)
					trace('Adding findlib: ${x.get('value')} at ${dir}');
					#end
					for (f in findLibs) {
						if (f.name == x.get('value') && f.dir == dir) {
							trace('Skipping duplicate findlib: ${x.get('value')} at ${dir}');
							return true;
						}
					}
					findLibs.push({
						name: x.get('value'),
						dir: dir,
						link: x.get('link') == 'true',
						raw: x.get('raw') == 'true'
					});
				case 'set':
					var defineName = resolveString(x.get('name'));
					var value = resolveString(x.get('value'));
					if (!_defines.exists(defineName)) {
						throw('Found set not set before: ${defineName} = ${value}');
					}
				default:
					return false;
			}
			return true;
		}

		// find flags
		walkElements(rootXML, (x:Xml) -> {
			if (processCommon(x)) {
				return false;
			}

			return true;
		});

		// return;

		// trace('walking root XML to find files blocks');

		walkElements(rootXML, (x:Xml) -> {
			switch (x.nodeName) {
				case 'file':
					// var id = x.parent.get('id');
					// trace('Processing file element in files block with id ${id} : ${x}');
					x.set('_abs_path', resolveSourcePath(x, x.parent));

					var libName = x.parent.get('__library');
					if (libName == null) {
						libName = 'haxe';
					}
					targetFiles.get(libName).push(x);
				default:
					//					trace('\tSkipping element: ${x.nodeName}');
			}
			return true;
		});
		#if (cmake_idl_verbose > 2)
		for (t in targetFiles.keys()) {
			trace('taret ${t}');
			var allFiles = targetFiles.get(t);
			for (f in allFiles) {
				trace('\tFile: ${f.get('_abs_path')}');
			}
		}
		#end
		#if (cmake_idl_verbose > 1)
		trace('Include dirs: ${cppIncludeDirs.join(',')}');
		trace('Lib dirs: ${cppLibDirs.join(',')}');
		trace('Misc compiler flags: ${miscCompilerFlagsAll.join(',')}');
		trace('Compiler warnings: ${cppWarnings.join(',')}');

		for (t in cppDefines.keys()) {
			trace('Defines for ${t}: ${cppDefines.get(t).join(',')}');
		}

		trace('findLibs : ${findLibs.map((l) -> '${libPackageName(l.name)} (${l.dir})').join(', ')}');
		#end

		var outputName = resolveString("${HAXE_OUTPUT}", true);
		addLine('cmake_minimum_required(VERSION 3.20)');
		addLine('\n');
		addLine('project(${outputName} C CXX)');
		addLine('\n');
		addLine('set(CMAKE_CXX_STANDARD 20)');
		addLine('\n');
		addLine('add_executable(${outputName}');

		{
			var allFiles = targetFiles.get('haxe');
			for (f in allFiles) {
				var srcPath = resolveSourcePath(f, f.parent);
				addLine('\t${srcPath}');
			}
		}

		addLine(')');

		for (t in targetFiles.keys()) {
			if (t == 'haxe')
				continue;
			var allFiles = targetFiles.get(t);
			if (allFiles.length == 0)
				continue;
			addLine('add_library(_lib_${t} STATIC');
			for (f in allFiles) {
				var srcPath = resolveSourcePath(f, f.parent);
				addLine('\t${srcPath}');
			}
			addLine(')');
		}

		if (findLibs.length > 0) {
			addLine('');
			for (fl in findLibs) {
				var packageName = libPackageName(fl.name);
				if (fl.dir == null) {
					addLine('find_package(${packageName} REQUIRED)');
				} else {
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
						trace('Adding findlib: ${packageName} at ${fl.dir}');
						#end
						addLine('set (${packageName}_DIR ${adir})');
						addLine('find_package(${packageName} REQUIRED)');
					}
				}
			}
			addLine('');

			addLine('target_link_libraries(${outputName}');
			for (fl in findLibs) {
				if (fl.link) {
					if (fl.raw) {
						addLine('\t${fl.name}');
					} else {
						if (fl.name.contains('::')) {
							addLine('\t${fl.name}');
						} else {
							addLine('\t${fl.name}::${fl.name}');
						}
					}
				}
			}

			for (f in targetFiles.keys()) {
				if (f == 'haxe')
					continue;
				addLine('\t_lib_${f}');
			}
			for (ll in linkLibs) {
				addLine('\t${ll}');
			}
			addLine(')');
		}

		addLine('target_link_directories(${outputName} PRIVATE');
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

		function dumpIncludeDirs() {
			for (d in cppIncludeDirs) {
				//				trace('d ${d}');

				var rd = resolvePath(d);
				if (FileSystem.exists(rd)) {
					var absDir = FileSystem.absolutePath(rd);
					#if (cmake_idl_verbose > 1)
					trace('Adding include dir: ${absDir} to cmake');
					#end
					addLine('\t${absDir}');
				} else {
					trace('Include dir not found: ${rd}');
				}
			}
		}
		function makeTargetTag(targetName:String):String {
			return targetName == 'haxe' ? targetName = outputName : '_lib_' + targetName;
		}
		for (t in targetFiles.keys()) {
			var t = makeTargetTag(t);
			addLine('target_include_directories (${t} PRIVATE');
			dumpIncludeDirs();
			addLine(')');
		}

		function dumpCompileOptions(targetName:String) {
			var targetTag = targetName == 'haxe' ? targetName = outputName : '_lib_' + targetName;

			addLine('target_compile_options(${targetTag} PRIVATE');
			for (f in miscCompilerFlagsAll) {
				addLine('\t${f}');
			}
			for (f in cppWarnings) {
				addLine('\t-W${f}');
			}
			addLine(')');

			addLine('target_compile_options(${targetTag} PRIVATE');
			for (f in miscCompilerFlagsAll) {
				addLine('\t${f}');
			}
			for (f in cppWarnings) {
				addLine('\t-W${f}');
			}
			addLine(')');

			addLine('target_compile_options(${targetTag} PRIVATE  ' + "$<$<COMPILE_LANGUAGE:C>:");
			for (f in miscCompilerFlagsC) {
				addLine('\t${f}');
			}
			addLine('>)');

			addLine('target_compile_definitions(${targetTag} PRIVATE');
			for (f in cppDefines.get('haxe')) {
				addLine('\t${f}');
			}
			if (targetName != 'haxe') {
				if (cppDefines.get(targetName) != null) {
					for (f in cppDefines.get(targetName)) {
						addLine('\t${f}');
					}
				}
			}
			addLine(')');
		}

		for (t in targetFiles.keys()) {
			dumpCompileOptions(t);
		}

		for (f in copies) {
			var src = resolvePath(f.src);
			var dst = resolveString(f.dst);
			// addLine('add_custom_command(TARGET ${outputName} POST_BUILD');
			// addLine('\tCOMMAND ${CMAKE_COMMAND} -E copy ${src} ${dst}');
			// addLine(')');
			trace('Adding copy: ${src} -> ${dst}');
			addLine('configure_file( "${src}" "' + "${CMAKE_CURRENT_BINARY_DIR}/" + '${dst}" COPYONLY)');
		}

		saveIfDifferent('${_relBuildDir}/CMakeLists.txt', _builder.toString());

		return;
		// var hxcppFileBlocks = new Map<String, CompileBlock>();
		// for (e in allElements.filter((e) -> e.nodeName == "files")) {
		// 	var filesCriteria = NodeCriteria.fromNode(e);
		// 	var id = e.get('id');

		// 	#if (cmake_idl_verbose > 1)
		// 	trace('---->|| adding block ${id}');
		// 	#end
		// 	hxcppFileBlocks.set(id, block);
		// return;

		// 	//			trace('Found file block: ${id}');
		// 	// for (f in block.files) {
		// 	// 	var srcPath = f.get('srcPath');
		// 	// 	trace('\t${srcPath}');
		// 	// }
		// }

		// var targetMap = new Map<String, Target>();

		// for (e in allElements.filter((e) -> e.nodeName == "target")) {
		// 	var id = e.get('id');
		// 	if (id == null) {
		// 		trace('Target missing id');
		// 		continue;
		// 	}
		// 	if (targetMap.exists(id)) {
		// 		targetMap.get(id).merge(e);
		// 	} else {
		// 		targetMap.set(id, Target.fromXml(e));
		// 	}
		// }

		// var haxeTarget = targetMap.get('haxe');

		// if (haxeTarget == null) {
		// 	trace('No haxe target');
		// 	return;
		// }

		/*

			function addFlags(elements:Iterator<Xml>) {
				for (cf in elements) {
					if (!NodeCriteria.matchNode(cf)) {
						// trace('Skipping flag: ${cf.get('value')}');
						continue;
					}


					if (cf.nodeName == 'copy') {
						#if (cmake_idl_verbose > 1)
						trace('Adding copy: ${cf.get('value')}');
						#end
						copies.push({src: cf.get('src'), dst: cf.get('dest')});
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

			// for (e in allElements) {
			// 	trace('all element ${e.nodeName}');
			// }
			addFlags(allElements.iterator());

			for (e in haxeTarget.root.elements()) {
				if (!NodeCriteria.matchNode(e)) {
					continue;
				}
				switch (e.nodeName) {
					case 'files':
						var id = e.get('id');
						trace('Processing files block: ${id}');
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


			// for (d in _defines.keyValueIterator()) {
			// 	trace('Adding define: ${d.key} = ${d.value}');
			// }



			#if (cmake_idl_verbose > 1)
			trace('------ Adding files for target: ${outputName}');
			#end
			for (f in haxeTarget.root.elementsNamed('files')) {
				if (!NodeCriteria.matchNode(f)) {
					#if (cmake_idl_verbose > 1)
					trace('Skipping block: ${f.get('id')}');
					#end
					continue;
				}

				#if (cmake_idl_verbose > 1)
				trace('Looking for files in ${f.get('id')}');
				#end
				var block = hxcppFileBlocks.get(f.get('id'));
				if (block == null) {
					#if (cmake_idl_verbose > 1)
					trace('No block found for ${f.get('id')}');
					#end
					continue;
				}

				#if (cmake_idl_verbose > 1)
				if (block.files.length == 0) {
					trace('Block ${f.get('id')} is empty');
				}
				#end

				for (f in block.files) {
					var fpath = cleanPath(f.get('srcPath'));
					#if (cmake_idl_verbose > 3)
					trace('Adding file: ${fpath}');
					#end

					if (!NodeCriteria.matchNode(f)) {
						#if (cmake_idl_verbose > 1)
						trace('Skipping file: ${fpath}');
						#end
						continue;
					}
					//				trace('Adding file: ${f.get('srcPath')}');
					addLine('\t${fpath}');
				}
			}

			addLine(')');




			// configure_file(
			//   ${SOURCE_FILE}
			//   ${DESTINATION_FILE}
			//   COPYONLY
			// )

			saveIfDifferent('${_relBuildDir}/CMakeLists.txt', _builder.toString());
		 */
	}
} // - Parsing include: /Users/rcleven/git/hxcpp/toolchain/setup.xml
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
