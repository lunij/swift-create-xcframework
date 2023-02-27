extension Collection {
    var isNotEmpty: Bool {
        !isEmpty
    }

    var nonEmpty: Self? {
        isEmpty ? nil : self
    }
}
