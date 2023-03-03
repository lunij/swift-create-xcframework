import struct Foundation.CharacterSet

var logger: Logging = Logger()

protocol Logging {
    var level: LogLevel { get }
    func log(level: LogLevel, message: @autoclosure () throws -> String) rethrows
    func info(_ message: @autoclosure () throws -> String) rethrows
    func verbose(_ message: @autoclosure () throws -> String) rethrows
}

enum LogLevel: Int {
    case info
    case verbose
}

struct Logger: Logging {
    let level: LogLevel

    init(level: LogLevel = .info) {
        self.level = level
    }

    func log(level: LogLevel, message: @autoclosure () throws -> String) rethrows {
        guard level.rawValue <= self.level.rawValue else { return }
        print(try message())
    }

    func info(_ message: @autoclosure () throws -> String) rethrows {
        try log(level: .info, message: message())
    }

    func verbose(_ message: @autoclosure () throws -> String) rethrows {
        try log(level: .verbose, message: message())
    }
}

extension String {
    func log(level: LogLevel, separatedBy separator: CharacterSet = .newlines) {
        for message in components(separatedBy: separator) {
            logger.log(level: level, message: message)
        }
    }
}
