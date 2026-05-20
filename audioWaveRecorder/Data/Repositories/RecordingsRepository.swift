//
//  RecordingsRepository.swift
//  audioWaveRecorder
//
//  Created by Sreejesh C on 20/05/26.
//

import Foundation

final class RecordingsRepository: RecordingsRepositoryProtocol {
    private let metadataURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        metadataURL = RecordingsDirectory.url.appendingPathComponent("recordings.json")
        try? FileManager.default.createDirectory(at: RecordingsDirectory.url, withIntermediateDirectories: true)
    }

    func fetchAll() throws -> [Recording] {
        guard FileManager.default.fileExists(atPath: metadataURL.path) else { return [] }
        let data = try Data(contentsOf: metadataURL)
        let recordings = try decoder.decode([Recording].self, from: data)
        return recordings.sorted { $0.createdAt > $1.createdAt }
    }

    func save(_ recording: Recording) throws {
        var all = try fetchAll()
        all.insert(recording, at: 0)
        try persist(all)
    }

    func delete(_ recording: Recording) throws {
        var all = try fetchAll()
        all.removeAll { $0.id == recording.id }
        try persist(all)
        if FileManager.default.fileExists(atPath: recording.fileURL.path) {
            try FileManager.default.removeItem(at: recording.fileURL)
        }
    }

    func update(_ recording: Recording) throws {
        var all = try fetchAll()
        guard let index = all.firstIndex(where: { $0.id == recording.id }) else { return }
        all[index] = recording
        try persist(all)
    }

    private func persist(_ recordings: [Recording]) throws {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(recordings)
        try data.write(to: metadataURL, options: .atomic)
    }
}
