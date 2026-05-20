//
//  HomeViewModel.swift
//  audioWaveRecorder
//
//  Created by Sreejesh C on 20/05/26.
//

import Foundation
import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var recordings: [Recording] = []
    @Published var searchText = ""
    @Published var selectedFilter: RecordingFilter = .all
    @Published var isRecordingSessionActive = false
    @Published var isRecordingPaused = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var liveMeterLevel: Float = 0
    @Published var liveFrequencyBands: [Float] = [Float](
        repeating: 0,
        count: WaveformSmoothing.spectrumBandCount
    )
    @Published var liveWaveformHistory: [Float] = []
    @Published var selectedRecording: Recording?
    @Published var alertMessage: String?

    private let repository: RecordingsRepositoryProtocol
    private let recordingService: AudioRecordingServiceProtocol
    private let playbackSession: PlaybackSession
    private var pendingFileURL: URL?
    private var pendingRecordingSave: PendingRecordingSave?
    private var waveformHistory: [Float] = []

    var hasPendingSave: Bool {
        pendingRecordingSave != nil
    }

    init(
        repository: RecordingsRepositoryProtocol,
        recordingService: AudioRecordingServiceProtocol,
        playbackSession: PlaybackSession
    ) {
        self.repository = repository
        self.recordingService = recordingService
        self.playbackSession = playbackSession
        bindServices()
    }

    var filteredRecordings: [Recording] {
        recordings.filter { recording in
            let matchesSearch = searchText.isEmpty ||
                recording.title.localizedCaseInsensitiveContains(searchText)
            let matchesFilter: Bool
            switch selectedFilter {
            case .all:
                matchesFilter = true
            case .shared:
                matchesFilter = recording.isShared
            case .starred:
                matchesFilter = recording.isStarred
            }
            return matchesSearch && matchesFilter
        }
    }

    func onAppear() {
        reloadRecordings()
    }

    func reloadRecordings() {
        do {
            recordings = try repository.fetchAll()
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func startRecording() async {
        guard !isRecordingSessionActive else { return }
        closePlayback()

        let granted = await recordingService.requestPermission()
        guard granted else {
            alertMessage = RecordingError.permissionDenied.localizedDescription
            return
        }

        guard !isRecordingSessionActive else { return }

        do {
            let url = try recordingService.startRecording()
            pendingFileURL = url
            isRecordingSessionActive = true
            isRecordingPaused = false
            recordingDuration = 0
            waveformHistory = []
            liveWaveformHistory = []
            liveFrequencyBands = [Float](repeating: 0, count: WaveformSmoothing.spectrumBandCount)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func toggleRecordingPause() {
        guard isRecordingSessionActive else { return }
        if isRecordingPaused {
            recordingService.resumeRecording()
            isRecordingPaused = false
        } else {
            recordingService.pauseRecording()
            isRecordingPaused = true
        }
    }

    func beginSaveRecording() {
        guard isRecordingSessionActive else { return }

        do {
            let result = try recordingService.stopRecording()
            let savedAt = Date()
            pendingRecordingSave = PendingRecordingSave(
                url: result.url,
                duration: result.duration,
                samples: result.samples,
                createdAt: savedAt
            )
            isRecordingSessionActive = false
            isRecordingPaused = false
            recordingDuration = 0
            pendingFileURL = nil
            waveformHistory = []
            liveWaveformHistory = []
            liveFrequencyBands = [Float](repeating: 0, count: WaveformSmoothing.spectrumBandCount)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func suggestedTitleForPendingSave() -> String {
        guard let pending = pendingRecordingSave else { return "" }
        return defaultTitle(for: pending.createdAt)
    }

    func commitSaveRecording(title: String) {
        guard let pending = pendingRecordingSave else { return }
        let finalTitle = resolvedTitle(title, at: pending.createdAt)
        pendingRecordingSave = nil

        Task {
            var samples = pending.samples.isEmpty ? [] : pending.samples
            if samples.count < 12 {
                let generated = await WaveformSampleGenerator.generate(from: pending.url)
                if !generated.isEmpty { samples = generated }
            }

            let recording = Recording(
                id: UUID(),
                title: finalTitle,
                fileName: pending.url.lastPathComponent,
                createdAt: pending.createdAt,
                duration: pending.duration,
                isStarred: false,
                isShared: false,
                waveformSamples: samples
            )
            do {
                try repository.save(recording)
                reloadRecordings()
            } catch {
                alertMessage = error.localizedDescription
            }
        }
    }

    func cancelSaveRecording() {
        if let pending = pendingRecordingSave {
            try? FileManager.default.removeItem(at: pending.url)
        }
        pendingRecordingSave = nil
    }

    func cancelRecording() {
        recordingService.cancelRecording()
        isRecordingSessionActive = false
        isRecordingPaused = false
        recordingDuration = 0
        pendingFileURL = nil
        waveformHistory = []
        liveWaveformHistory = []
        liveFrequencyBands = [Float](repeating: 0, count: WaveformSmoothing.spectrumBandCount)
    }

    func selectRecording(_ recording: Recording) {
        do {
            try playbackSession.load(recording: recording)
            selectedRecording = recording
        } catch {
            playbackSession.unload()
            alertMessage = error.localizedDescription
        }
    }

    func closePlayback() {
        playbackSession.unload()
        selectedRecording = nil
    }

    func toggleStar(for recording: Recording) {
        var updated = recording
        updated.isStarred.toggle()
        persistUpdate(updated)
    }

    func renameRecording(_ recording: Recording, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            alertMessage = "Title cannot be empty."
            return
        }

        var updated = recording
        updated.title = String(trimmed.prefix(120))

        if selectedRecording?.id == recording.id {
            selectedRecording = updated
        }

        persistUpdate(updated)
    }

    func deleteRecording(_ recording: Recording) {
        do {
            if selectedRecording?.id == recording.id {
                closePlayback()
            }
            try repository.delete(recording)
            reloadRecordings()
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func bindServices() {
        recordingService.onMeterLevel = { [weak self] level in
            Task { @MainActor in
                guard let self else { return }
                self.liveMeterLevel = level
                self.waveformHistory.append(level)
                if self.waveformHistory.count > 140 {
                    self.waveformHistory.removeFirst(self.waveformHistory.count - 140)
                }
                self.liveWaveformHistory = self.waveformHistory
            }
        }

        recordingService.onFrequencyBands = { [weak self] bands in
            Task { @MainActor in
                self?.liveFrequencyBands = bands
            }
        }

        recordingService.onDurationUpdate = { [weak self] duration in
            Task { @MainActor in
                self?.recordingDuration = duration
            }
        }
    }

    private func persistUpdate(_ recording: Recording) {
        do {
            try repository.update(recording)
            reloadRecordings()
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func resolvedTitle(_ title: String, at date: Date) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return defaultTitle(for: date)
        }
        return String(trimmed.prefix(120))
    }

    private func defaultTitle(for date: Date) -> String {
        "Recording \(date.recordingListDate) \(date.recordingListTime)"
    }
}

private struct PendingRecordingSave {
    let url: URL
    let duration: TimeInterval
    let samples: [Float]
    let createdAt: Date
}
