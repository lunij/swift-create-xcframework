
import Foundation
import Xcodeproj

extension Xcode.Project {
    var frameworkTargets: [Xcode.Target] {
        targets.filter { $0.productType == .framework }
    }
}
