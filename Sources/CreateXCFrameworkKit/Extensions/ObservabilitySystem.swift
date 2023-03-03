import Basics

extension ObservabilitySystem {
    static let shared = ObservabilitySystem { _, diagnostics in
        logger.verbose("\(diagnostics.severity): \(diagnostics.message)")
    }
}
