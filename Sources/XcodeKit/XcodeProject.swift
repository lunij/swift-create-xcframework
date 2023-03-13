import TSCBasic

public struct XcodeProject2 {
    public let path: AbsolutePath
    private let project: Xcode.Project

    private var frameworkTargets: [Xcode.Target] {
        project.targets.filter { $0.productType == .framework }
    }

    init(path: AbsolutePath, project: Xcode.Project) {
        self.path = path
        self.project = project
    }

    /// This is the group that is normally created in Xcodeproj.xcodeProject() when you specify an xcconfigOverride
    var configGroup: Xcode.Group {
        let name = "Configs"

        if let group = project.mainGroup.subitems.lazy.compactMap({ $0 as? Xcode.Group }).first(where: { $0.name == name }) {
            return group
        }

        return project.mainGroup.addGroup(path: "", name: name)
    }

    public func enableDistribution(targets: [String], xcconfig: AbsolutePath) {
        let group = configGroup
        let ref = group.addFileReference(
            path: xcconfig.pathString,
            name: xcconfig.basename
        )

        for target in project.targets where targets.contains(target.name) {
            target.buildSettings.xcconfigFileRef = ref
        }
    }

    public func save() throws {
        try path.appending(component: "project.pbxproj").open { stream in
            // Serialize the project model we created to a plist, and return
            // its string description.
            let str = try "// !$*UTF8*$!\n" + project.generatePlist().description
            stream(str)
        }

        for target in frameworkTargets {
            // For framework targets, generate target.c99Name_Info.plist files in the
            // directory that Xcode project is generated
            let name = "\(target.name.spm_mangledToC99ExtendedIdentifier())_Info.plist"
            try path.appending(RelativePath(name)).open { print in
                print(
                    """
                    <?xml version="1.0" encoding="UTF-8"?>
                    <plist version="1.0">
                    <dict>
                    <key>CFBundleDevelopmentRegion</key>
                    <string>en</string>
                    <key>CFBundleExecutable</key>
                    <string>$(EXECUTABLE_NAME)</string>
                    <key>CFBundleIdentifier</key>
                    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
                    <key>CFBundleInfoDictionaryVersion</key>
                    <string>6.0</string>
                    <key>CFBundleName</key>
                    <string>$(PRODUCT_NAME)</string>
                    <key>CFBundlePackageType</key>
                    <string>FMWK</string>
                    <key>CFBundleShortVersionString</key>
                    <string>1.0</string>
                    <key>CFBundleSignature</key>
                    <string>????</string>
                    <key>CFBundleVersion</key>
                    <string>$(CURRENT_PROJECT_VERSION)</string>
                    <key>NSPrincipalClass</key>
                    <string></string>
                    </dict>
                    </plist>
                    """
                )
            }
        }
    }
}
