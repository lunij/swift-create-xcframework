import ArgumentParser

/// A representation of a build setting in an Xcode project, e.g.
/// `IPHONEOS_DEPLOYMENT_TARGET=13.0`
struct BuildSetting: ExpressibleByArgument {
    /// The name of the build setting, e.g. `IPHONEOS_DEPLOYMENT_TARGET`
    let name: String
    /// The value of the build setting
    let value: String

    init?(argument: String) {
        let components = argument.components(separatedBy: "=")
        guard components.count == 2 else { return nil }
        name = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
        value = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
