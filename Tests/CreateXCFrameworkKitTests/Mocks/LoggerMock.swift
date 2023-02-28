@testable import CreateXCFrameworkKit

class LoggerMock: Logging {
    enum Call: Equatable {
        case log(String)
    }

    var calls: [Call] = []

    func log(_ message: @autoclosure () throws -> String) rethrows {
        calls.append(.log(try message()))
    }
}
