import XCTest

@MainActor
final class PhrasebookTests: XCTestCase {
    func testPhrasebookPersistsProtectedExcludedBackupFileAndDeletes() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "PhrasebookTests-\(UUID())", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let storageURL = root.appending(path: "saved-phrases.json")
        let builtIn = [Phrase(id: "repeat", english: "Could you repeat that?", dutch: "Kunt u dat herhalen?")]
        let store = PhrasebookStore(storageURL: storageURL, builtIn: builtIn)
        XCTAssertEqual(store.builtIn.count, 1)

        store.save(english: "Hello", dutch: "Hallo")
        store.save(english: "hello", dutch: "hallo")
        XCTAssertEqual(store.saved.count, 1)
        XCTAssertNil(store.storageError)
        XCTAssertTrue(FileManager.default.fileExists(atPath: storageURL.path))

        let attributes = try FileManager.default.attributesOfItem(atPath: storageURL.path)
        XCTAssertEqual(attributes[.protectionKey] as? FileProtectionType, .complete)
        XCTAssertEqual(try storageURL.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)

        let reloaded = PhrasebookStore(storageURL: storageURL, builtIn: builtIn)
        XCTAssertEqual(reloaded.saved.first?.dutch, "Hallo")
        reloaded.deleteAll()
        XCTAssertTrue(reloaded.saved.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: storageURL.path))
    }

    func testStorageFailureIsReportedAndDoesNotPretendMutationSucceeded() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "PhrasebookFailure-\(UUID())", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let storageURL = root.appending(path: "saved-phrases.json")
        let store = PhrasebookStore(storageURL: storageURL, builtIn: [])
        store.save(english: "Hello", dutch: "Hallo")
        let saved = try XCTUnwrap(store.saved.first)

        try FileManager.default.removeItem(at: root)
        try Data("not a directory".utf8).write(to: root)
        store.delete(saved)

        XCTAssertEqual(store.saved, [saved])
        XCTAssertNotNil(store.storageError)
    }
}
