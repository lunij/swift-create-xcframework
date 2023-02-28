import TSCBasic

extension AbsolutePath {
    /// Writes the contents to the file specified.
    ///
    /// This method doesn't rewrite the file in case the new and old contents of
    /// file are same.
    func open(body: ((String) -> Void) throws -> Void) throws {
        let stream = BufferedOutputByteStream()
        try body { line in
            stream <<< line
            stream <<< "\n"
        }
        // If the file exists with the identical contents, we don't need to rewrite it.
        //
        // This avoids unnecessarily triggering Xcode reloads of the project file.
        if let contents = try? localFileSystem.readFileContents(self), contents == stream.bytes {
            return
        }

        // Write the real file.
        try localFileSystem.writeFileContents(self, bytes: stream.bytes)
    }
}
