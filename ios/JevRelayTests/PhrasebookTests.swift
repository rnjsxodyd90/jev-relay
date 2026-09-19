import XCTest

private final class RecordingFileManager: FileManager {
    struct AttributeRequest {
        let attributes: [FileAttributeKey: Any]
        let path: String
    }

    private(set) var attributeRequests: [AttributeRequest] = []

    override func setAttributes(_ attributes: [FileAttributeKey: Any], ofItemAtPath path: String) throws {
        attributeRequests.append(AttributeRequest(attributes: attributes, path: path))
        try super.setAttributes(attributes, ofItemAtPath: path)
    }
}

private func normalizedProtectionValue(_ value: Any?) -> String? {
    if let protection = value as? FileProtectionType { return protection.rawValue }
    if let rawValue = value as? String { return rawValue }
    return nil
}

@MainActor
final class PhrasebookTests: XCTestCase {
    func testPhrasebookPersistsDeduplicatesExcludesBackupAndDeletes() throws {
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
        XCTAssertEqual(try storageURL.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)

        let reloaded = PhrasebookStore(storageURL: storageURL, builtIn: builtIn)
        XCTAssertEqual(reloaded.saved.first?.dutch, "Hallo")
        reloaded.deleteAll()
        XCTAssertTrue(reloaded.saved.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: storageURL.path))
    }

    func testPhrasebookRequestsCompleteProtectionForIntendedSavedFile() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "PhrasebookProtectionRequest-\(UUID())", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let storageURL = root.appending(path: "saved-phrases.json")
        let fileManager = RecordingFileManager()
        let store = PhrasebookStore(fileManager: fileManager, storageURL: storageURL, builtIn: [])

        store.save(english: "Hello", dutch: "Hallo")

        XCTAssertNil(store.storageError)
        let request = try XCTUnwrap(fileManager.attributeRequests.last(where: { $0.path == storageURL.path }))
        XCTAssertEqual(normalizedProtectionValue(request.attributes[.protectionKey]), FileProtectionType.complete.rawValue)
    }

    func testSavedFileProtectionMetadataOnHardware() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "PhrasebookProtectionMetadata-\(UUID())", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let storageURL = root.appending(path: "saved-phrases.json")
        let store = PhrasebookStore(storageURL: storageURL, builtIn: [])

        store.save(english: "Hello", dutch: "Hallo")
        XCTAssertNil(store.storageError)
        let attributes = try FileManager.default.attributesOfItem(atPath: storageURL.path)
        guard let protection = normalizedProtectionValue(attributes[.protectionKey]) else {
#if targetEnvironment(simulator)
            throw XCTSkip("The iOS simulator did not expose file-protection metadata. Verify NSFileProtectionComplete metadata with this test on a physical device.")
#else
            XCTFail("A physical device must expose protection metadata for the saved phrase file.")
            return
#endif
        }
        XCTAssertEqual(protection, FileProtectionType.complete.rawValue, "The saved phrase file must use complete protection on hardware.")
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
