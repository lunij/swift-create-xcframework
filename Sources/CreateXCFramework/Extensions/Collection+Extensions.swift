
extension Collection {
    var nonEmpty: Self? {
        return self.isEmpty ? nil : self
    }
}
