extension Collection {
    var isNotEmpty: Bool {
        !isEmpty
    }

    var nonEmpty: Self? {
        isEmpty ? nil : self
    }
}

extension Collection where Element: Hashable {
    func removeDuplicates() -> [Element] {
        spm_uniqueElements()
    }
}
