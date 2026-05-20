//
//  AppContainer.swift
//  audioWaveRecorder
//
//  Created by Sreejesh C on 20/05/26.
//
import Foundation

@MainActor
final class AppContainer: ObservableObject {
    let recordingsRepository: RecordingsRepositoryProtocol
    let recordingService: AudioRecordingServiceProtocol
    let playbackSession: PlaybackSession

    init(
        recordingsRepository: RecordingsRepositoryProtocol = RecordingsRepository(),
        recordingService: AudioRecordingServiceProtocol = AudioRecordingService(),
        playbackSession: PlaybackSession? = nil
    ) {
        self.recordingsRepository = recordingsRepository
        self.recordingService = recordingService
        self.playbackSession = playbackSession ?? PlaybackSession()
    }

    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(
            repository: recordingsRepository,
            recordingService: recordingService,
            playbackSession: playbackSession
        )
    }
}
