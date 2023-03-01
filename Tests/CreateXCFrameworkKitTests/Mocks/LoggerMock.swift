@testable import CreateXCFrameworkKit

class LoggerMock: Logging {
    enum Call: Equatable {
        case log(String)
    }

    var calls: [Call] = []

    func log(_ message: @autoclosure () -> String) {
        calls.append(.log(message()))
    }
}
