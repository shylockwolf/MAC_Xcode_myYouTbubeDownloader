import Foundation

class YtDlpLocator {
    static let shared = YtDlpLocator()
    
    private let fileManager = FileManager.default
    private let userDefaultsKey = "yt_dlp_path"
    
    private init() {}
    
    private var candidatePaths: [String] {
        var paths = [
            "/opt/homebrew/bin/yt-dlp",
            "/usr/local/bin/yt-dlp",
            "/usr/bin/yt-dlp",
            "/bin/yt-dlp"
        ]
        
        if let pythonVersions = try? fileManager.contentsOfDirectory(atPath: "/Library/Frameworks/Python.framework/Versions") {
            for version in pythonVersions {
                paths.append("/Library/Frameworks/Python.framework/Versions/\(version)/bin/yt-dlp")
            }
        }
        
        return paths
    }
    
    func locate() throws -> String {
        if let cachedPath = UserDefaults.standard.string(forKey: userDefaultsKey),
           fileManager.isExecutableFile(atPath: cachedPath) {
            return cachedPath
        }
        
        if let cachedPath = UserDefaults.standard.string(forKey: userDefaultsKey) {
            UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        }
        
        for path in candidatePaths {
            if fileManager.isExecutableFile(atPath: path) {
                UserDefaults.standard.set(path, forKey: userDefaultsKey)
                return path
            }
        }
        
        if let pathFromPath = findInSystemPath() {
            UserDefaults.standard.set(pathFromPath, forKey: userDefaultsKey)
            return pathFromPath
        }
        
        throw NSError(
            domain: "YtDlpLocator",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "yt-dlp 未找到，请先安装: brew install yt-dlp"]
        )
    }
    
    private func findInSystemPath() -> String? {
        let process = Process()
        let outputPipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["bash", "-lc", "which yt-dlp || command -v yt-dlp"]
        process.standardOutput = outputPipe
        
        var environment = ProcessInfo.processInfo.environment
        let originalPath = environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + originalPath
        process.environment = environment
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !output.isEmpty,
               fileManager.isExecutableFile(atPath: output) {
                return output
            }
        } catch {
            print("[YtDlpLocator] 通过 PATH 查找失败: \(error)")
        }
        
        return nil
    }
    
    func clearCache() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
    
    var cachedPath: String? {
        return UserDefaults.standard.string(forKey: userDefaultsKey)
    }
}
