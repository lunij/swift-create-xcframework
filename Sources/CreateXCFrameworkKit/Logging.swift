public var logger: Logging = Logger()

public protocol Logging {
    func log(_ message: @autoclosure () -> String)
}

struct Logger: Logging {
    func log(_ message: @autoclosure () -> String) {
        print(message())
    }
}
