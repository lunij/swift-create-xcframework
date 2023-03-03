@testable import CreateXCFrameworkKit

class LoggerMock: Logging {
    enum Call: Equatable {
        case log(LogLevel, String)
        case info(String)
        case verbose(String)
    }

    var calls: [Call] = []

    var level: LogLevel = .info

    func log(level: LogLevel, message: @autoclosure () throws -> String) rethrows {
        calls.append(.log(level, try message()))
    }

    func info(_ message: @autoclosure () throws -> String) rethrows {
        calls.append(.info(try message()))
    }

    func verbose(_ message: @autoclosure () throws -> String) rethrows {
        calls.append(.verbose(try message()))
    }
}

extension LoggerMock {
    var infoCalls: [Call] {
        calls.filter {
            if case .info = $0 { return true }
            return false
        }
    }
}
