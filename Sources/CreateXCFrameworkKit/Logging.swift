public var logger: Logging = Logger()

public protocol Logging {
    func log(_ message: @autoclosure () throws -> String) rethrows
}

struct Logger: Logging {
    func log(_ message: @autoclosure () throws -> String) rethrows {
        print(try message())
    }
}

extension String {
    func log() {
        logger.log(self)
    }
}
