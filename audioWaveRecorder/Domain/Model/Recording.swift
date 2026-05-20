//
//  Recording.swift
//  audioWaveRecorder
//
//  Created by Sreejesh C on 20/05/26.
//

import Foundation

struct Recording: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var title: String
    let fileName: String
    let createdAt: Date
    let duration: TimeInterval
    var isStarred: Bool
    var isShared: Bool
    var waveformSamples: [Float]

    var fileURL: URL {
        RecordingsDirectory.url.appendingPathComponent(fileName)
    }
}

enum RecordingFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case shared = "Shared"
    case starred = "Starred"

    var id: String { rawValue }
}

enum RecordingsDirectory {
    static var url: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("Recordings", isDirectory: true)
    }
}
