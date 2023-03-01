import Basics

extension ObservabilitySystem {
    static let shared = ObservabilitySystem { _, diagnostics in
        logger.log("\(diagnostics.severity): \(diagnostics.message)")
    }
}
