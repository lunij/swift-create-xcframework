enum CommandError: Error, CustomStringConvertible {
    case nonZeroExit(Int32, [String])
    case signalExit(Int32, [String])
    case errorThrown(Error, [String])

    var description: String {
        switch self {
        case let .nonZeroExit(code, arguments):
            return "Command exited with code \(code)\n    \(arguments.joined)"
        case let .signalExit(signal, arguments):
            return "Command exited due to signal \(signal)\n    \(arguments.joined)"
        case let .errorThrown(error, arguments):
            return "Command returned error: \(error)\n    \(arguments.joined)"
        }
    }
}

private extension [String] {
    var joined: String {
        joined(separator: " ")
    }
}
