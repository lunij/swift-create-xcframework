
import PackageModel

extension ProductType {
    var isLibrary: Bool {
        if case .library = self {
            return true
        }
        return false
    }
}

extension Manifest {
    var libraryProductNames: [String] {
        return self.products
            .compactMap { product in
                guard product.type.isLibrary else { return nil }
                return product.name
            }
    }
}
