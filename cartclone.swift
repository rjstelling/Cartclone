#! /usr/bin/env xcrun swift

import Foundation

/// *Standard Stream Protocol*
/// Defines the file handle used and simple print string and output data functions
protocol StandardStream {
	
	var stream: FileHandle { get }
	
	func print(_ str: String)
	func output(_ data: Data)
}

/// Default implementations of print(...) and output(...)
extension StandardStream {

	func print(_ str: String) {
	
		guard let data = (str + "\n").data(using: .utf8) else { return }
		stream.write(data)
	}
	
	func output(_ data: Data) {
		stream.write(data)
	}
}

struct Repo: CustomStringConvertible {
	
	let type: String
	let uri: String
	let version: String
	
	var directory: String {
		return (self.uri as NSString).lastPathComponent
	}
	
	var githubURL: String {
		return "http://github.com/\(self.uri)"
	}
	
	var description: String { 
		return "\(type) -> \(uri), version: \(version)"
	}
	
	init(withString: String) {
	
		let tokens = withString.components(separatedBy: .whitespacesAndNewlines) //static var punctuationCharacters
		
		//console.print("TOKENS: \(tokens)")
	
		type = tokens[0].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
		uri = tokens[1].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
		version = tokens[2].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
	}
}

struct LinkCommand {

	private let task = Process()

	@discardableResult
	init(from: String, to: String, complete: (() -> ())? = nil) {
	
		self.task.launchPath = "/bin/ln"
		self.task.arguments = ["-s", from, to]
		
		task.launch()
		task.waitUntilExit()
		
		complete?()
	}
}

struct MakeDirCommand {

	private let task = Process()

	@discardableResult
	init(_ path: String, complete: (() -> ())? = nil) {
	
		self.task.launchPath = "/bin/mkdir"
		self.task.arguments = ["-p", path]
		
		task.launch()
		task.waitUntilExit()
		
		complete?()
	}
}

struct RemoveDirCommand {

	private let task = Process()

	@discardableResult
	init(_ path: String, complete: (() -> ())? = nil) {
	
		self.task.launchPath = "/bin/rm"
		self.task.arguments = ["-fR", path]
		
		task.launch()
		task.waitUntilExit()
		
		complete?()
	}
}

struct GitCommand {

	private let task = Process()

	@discardableResult
	init(withArgumants args: [String], complete: (() -> ())?) {
	
		self.task.launchPath = "/usr/bin/git"
		self.task.arguments = args
		
		task.launch()
		task.waitUntilExit()
		
		complete?()
	}
}

// Standard Out - writes to `stdout`
struct StandardOut: StandardStream {
	
	var stream: FileHandle { return FileHandle.standardOutput }
}

// Standard Error - writes to `stderr`
struct StandardErr: StandardStream {

	var stream: FileHandle { return FileHandle.standardError }
}

let console = StandardOut()
let stderr = StandardErr()

let proc = ProcessInfo()
let switchOffset = proc.arguments.index(where: { return $0 == "--" }) ?? 0
let reposRequired = Array(proc.arguments[(switchOffset + 1)...])

let currentPath = FileManager.default.currentDirectoryPath

let reletiveCloneDir = currentPath + "/Carthage/Cartclone"
MakeDirCommand(reletiveCloneDir)

// Open Cartfile
guard let cartfile = FileManager.default.contents(atPath: currentPath + "/Cartfile.resolved") else {
	stderr.print("Error: Could not read Cartfile")
	exit(1)
}

guard let text = String(data: cartfile, encoding: .utf8) else {
	stderr.print("Error: Could not read Cartfile")
	exit(1)
}

let repoInfo: [String] = text.split(separator: "\n").compactMap {
	
	// remove comments
	guard !$0.hasPrefix("#") else {
		return nil
	}
	
	return String($0)
}

let repos = repoInfo.map { Repo(withString: $0) }

repos.filter { reposRequired.contains($0.uri) }.forEach {
		
	let cloneDir =  reletiveCloneDir + "/" + $0.directory
	let carthageCloneDir =  currentPath + "/Carthage/Checkouts/" + $0.directory
	
	let version = $0.version
	console.print("Clone \($0.uri) into \(cloneDir)")
	
	GitCommand(withArgumants: ["clone", $0.githubURL, cloneDir]) {
		
		// Decend into cloned repo folder
		FileManager.default.changeCurrentDirectoryPath(cloneDir)
		
		// Check out the required version
		GitCommand(withArgumants: ["checkout", version]) {
			console.print("...done")
		}
		
		RemoveDirCommand(carthageCloneDir) { 
		
			//delete carthage version of the repo, then sym-link 
			LinkCommand(from: cloneDir, to: carthageCloneDir)
		}
	}
}

exit(0)
