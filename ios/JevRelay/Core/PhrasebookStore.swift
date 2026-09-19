import Combine
import Foundation

@MainActor
final class PhrasebookStore: ObservableObject {
    @Published private(set) var builtIn: [Phrase] = []
    @Published private(set) var saved: [SavedPhrase] = []
    @Published private(set) var storageError: String?

    private let fileManager: FileManager
    private let storageURL: URL?

    init(
        bundle: Bundle = .main,
        fileManager: FileManager = .default,
        storageURL: URL? = nil,
        builtIn overridePhrases: [Phrase]? = nil
    ) {
        self.fileManager = fileManager
        if let storageURL { self.storageURL = storageURL }
        else if let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            self.storageURL = base.appending(path: "com.taekwon.jevrelay", directoryHint: .isDirectory).appending(path: "saved-phrases.json")
        } else {
            self.storageURL = nil
            self.storageError = "Saved phrase storage is unavailable on this device."
        }

        if let overridePhrases { builtIn = overridePhrases }
        else if let url = bundle.url(forResource: "memory", withExtension: "json"),
                let data = try? Data(contentsOf: url),
                let phrases = try? JSONDecoder().decode([Phrase].self, from: data) {
            builtIn = phrases
        }
        loadSavedPhrases()
    }

    func save(english: String, dutch: String) {
        let source = english.trimmingCharacters(in: .whitespacesAndNewlines)
        let output = dutch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty, !output.isEmpty,
              !saved.contains(where: { $0.english.caseInsensitiveCompare(source) == .orderedSame && $0.dutch.caseInsensitiveCompare(output) == .orderedSame }) else { return }
        var updated = saved
        updated.insert(SavedPhrase(id: UUID(), english: source, dutch: output, savedAt: Date()), at: 0)
        persist(updated)
    }

    func delete(_ phrase: SavedPhrase) {
        persist(saved.filter { $0.id != phrase.id })
    }

    func deleteAll() {
        guard let storageURL else { storageError = "Saved phrase storage is unavailable on this device."; return }
        do {
            if fileManager.fileExists(atPath: storageURL.path) { try fileManager.removeItem(at: storageURL) }
            saved = []
            storageError = nil
        } catch {
            storageError = "Saved phrases could not be deleted: \(error.localizedDescription)"
        }
    }

    func contains(english: String, dutch: String) -> Bool {
        saved.contains { $0.english == english && $0.dutch == dutch }
    }

    private func loadSavedPhrases() {
        guard let storageURL else { return }
        guard fileManager.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            saved = try JSONDecoder().decode([SavedPhrase].self, from: data)
            try protectAndExcludeFromBackup(storageURL)
            storageError = nil
        } catch {
            saved = []
            storageError = "Saved phrases could not be read: \(error.localizedDescription)"
        }
    }

    private func persist(_ phrases: [SavedPhrase]) {
        guard let storageURL else { storageError = "Saved phrase storage is unavailable on this device."; return }
        do {
            let directory = storageURL.deletingLastPathComponent()
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.complete])
            var directoryValues = URLResourceValues()
            directoryValues.isExcludedFromBackup = true
            var mutableDirectory = directory
            try mutableDirectory.setResourceValues(directoryValues)

            let data = try JSONEncoder().encode(phrases)
            try data.write(to: storageURL, options: .atomic)
            try protectAndExcludeFromBackup(storageURL)
            saved = phrases
            storageError = nil
        } catch {
            storageError = "Saved phrases could not be updated: \(error.localizedDescription)"
        }
    }

    private func protectAndExcludeFromBackup(_ url: URL) throws {
        try fileManager.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableURL = url
        try mutableURL.setResourceValues(values)
    }
}
