import XCTest

extension XCTestCase {
    func catchError(_ closure: () throws -> Void) throws -> Error? {
        do {
            try closure()
            return nil
        } catch {
            return error
        }
    }

    func catchError<E: Error>(_ closure: () throws -> Void) throws -> E? {
        do {
            try closure()
            return nil
        } catch let error as E {
            return error
        }
    }
}
