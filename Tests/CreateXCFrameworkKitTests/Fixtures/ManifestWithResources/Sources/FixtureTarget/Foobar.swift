import Foundation

public class Foobar {
    func loadResource() throws -> String? {
        guard let url = Bundle.module.url(forResource: "Fake", withExtension: "json") else {
            return nil
        }
        return try String(contentsOf: url)
    }
}
