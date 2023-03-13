import struct Foundation.URL

struct Config {
    let options: Command.Options
    let packageDirectory: URL
    let buildDirectory: URL

    var projectBuildDirectory: URL {
        buildDirectory
            .appendingPathComponent("swift-create-xcframework")
            .absoluteURL
    }

    var hasDistributionBuildXcconfig: Bool {
        xcconfigOverride != nil || options.stackEvolution == false
    }

    var xcconfigOverride: URL? {
        guard let path = options.xcconfig else { return nil }

        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path)
        } else if path.hasPrefix("./") {
            return packageDirectory.appendingPathComponent(String(path[path.index(path.startIndex, offsetBy: 2)...]))
        }

        return packageDirectory.appendingPathComponent(path)
    }

    init(options: Command.Options) {
        self.options = options
        packageDirectory = URL(fileURLWithPath: options.packagePath, isDirectory: true).absoluteURL
        buildDirectory = packageDirectory.appendingPathComponent(options.buildPath, isDirectory: true).absoluteURL
    }
}
