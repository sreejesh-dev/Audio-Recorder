//
//  AudioRecordingService.swift
//  audioWaveRecorder
//
//  Created by Sreejesh C on 20/05/26.
//

import Foundation
import AVFAudio

import AVFAudio
import Foundation
import MediaPlayer
import UIKit

final class AudioRecordingService: NSObject, AudioRecordingServiceProtocol {
    private let audioEngine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private var outputURL: URL?
    private var sampleBuffer = WaveformSampleBuffer(capacity: 140)
    private let spectrumAnalyzer = FrequencySpectrumAnalyzer()
    private var isTapInstalled = false

    private var recordedFrames: Int64 = 0
    private var streamSampleRate: Double = 44_100
    private var durationPublishCounter = 0
    private var wasInterruptedWhileRecording = false

    private(set) var isRecording = false
    private(set) var isPaused = false

    var currentDuration: TimeInterval = 0
    var onMeterLevel: ((Float) -> Void)?
    var onFrequencyBands: (([Float]) -> Void)?
    var onDurationUpdate: ((TimeInterval) -> Void)?

    override init() {
        super.init()
        registerForSessionNotifications()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        clearNowPlayingInfo()
    }

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func startRecording() throws -> URL {
        guard !isRecording else {
            if let url = outputURL { return url }
            throw RecordingError.alreadyRecording
        }

        try RecordingAudioSession.activateForRecording()
        prepareEngineForNewSession()

        let fileName = "recording-\(UUID().uuidString).caf"
        let url = RecordingsDirectory.url.appendingPathComponent(fileName)
        try FileManager.default.createDirectory(at: RecordingsDirectory.url, withIntermediateDirectories: true)

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        audioFile = try AVAudioFile(forWriting: url, settings: format.settings)
        outputURL = url
        sampleBuffer.reset()
        recordedFrames = 0
        streamSampleRate = format.sampleRate
        currentDuration = 0
        durationPublishCounter = 0
        isPaused = false
        isRecording = true
        wasInterruptedWhileRecording = false

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self, self.isRecording, !self.isPaused else { return }
            self.process(buffer: buffer)
        }
        isTapInstalled = true

        audioEngine.prepare()
        try audioEngine.start()
        updateNowPlayingInfo()
        publishDurationIfNeeded(force: true)
        return url
    }

    func pauseRecording() {
        guard isRecording, !isPaused else { return }
        isPaused = true
        audioEngine.pause()
        updateNowPlayingInfo()
    }

    func resumeRecording() {
        guard isRecording, isPaused else { return }
        do {
            try RecordingAudioSession.activateForRecording()
            try audioEngine.start()
            isPaused = false
            updateNowPlayingInfo()
        } catch {
            //if engine fails
        }
    }

    func stopRecording() throws -> (url: URL, duration: TimeInterval, samples: [Float]) {
        guard let url = outputURL else {
            throw RecordingError.noActiveRecording
        }

        tearDownEngine(deactivateSession: true)
        let samples = sampleBuffer.drain().map { min(max($0, 0.02), 1) }
        return (url, currentDuration, samples)
    }

    func cancelRecording() {
        tearDownEngine(deactivateSession: true)
        if let url = outputURL {
            try? FileManager.default.removeItem(at: url)
        }
        outputURL = nil
        sampleBuffer.reset()
    }


    private func prepareEngineForNewSession() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        removeTapIfInstalled()
        audioEngine.reset()
    }

    private func tearDownEngine(deactivateSession: Bool) {
        isRecording = false
        isPaused = false
        wasInterruptedWhileRecording = false

        if audioEngine.isRunning {
            audioEngine.stop()
        }
        removeTapIfInstalled()
        audioEngine.reset()
        audioFile = nil
        clearNowPlayingInfo()

        if deactivateSession {
            RecordingAudioSession.deactivateIfIdle()
        }
    }

    private func removeTapIfInstalled() {
        guard isTapInstalled else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        isTapInstalled = false
    }


    private static func meterLevel(from rms: Float) -> Float {
        guard rms > 0.01 else { return 0 }
        let linear = min(max(rms * 28, 0), 1)
        return pow(linear, 0.55)
    }

    private func process(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }

        recordedFrames += Int64(frameLength)
        currentDuration = Double(recordedFrames) / streamSampleRate

        var sum: Float = 0
        for index in 0..<frameLength {
            let sample = channelData[index]
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(frameLength))
        let rawLevel = Self.meterLevel(from: rms)
        let bands = WaveformSmoothing.normalizedSpectrumBands(
            spectrumAnalyzer.analyze(buffer: buffer)
        )
        sampleBuffer.append(level: rawLevel)

        publishDurationIfNeeded(force: false)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.onMeterLevel?(rawLevel)
            self.onFrequencyBands?(bands)
        }

        if let audioFile {
            try? audioFile.write(from: buffer)
        }
    }

    private func publishDurationIfNeeded(force: Bool) {
        durationPublishCounter += 1
        guard force || durationPublishCounter % 6 == 0 else { return }

        let duration = currentDuration
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.onDurationUpdate?(duration)
            self.updateNowPlayingInfo()
        }
    }


    private func registerForSessionNotifications() {
        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
        center.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )
        center.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            guard isRecording, !isPaused else { return }
            wasInterruptedWhileRecording = true
            pauseRecording()
        case .ended:
            guard wasInterruptedWhileRecording else { return }
            wasInterruptedWhileRecording = false
            let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                resumeRecording()
            }
        @unknown default:
            break
        }
    }

    @objc private func handleRouteChange(_ notification: Notification) {
        guard isRecording, !isPaused,
              let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

        switch reason {
        case .oldDeviceUnavailable, .categoryChange:
            if !audioEngine.isRunning {
                try? RecordingAudioSession.activateForRecording()
                try? audioEngine.start()
            }
        default:
            break
        }
    }

    @objc private func handleAppDidBecomeActive() {
        guard isRecording, !isPaused, !audioEngine.isRunning else { return }
        try? RecordingAudioSession.activateForRecording()
        try? audioEngine.start()
        updateNowPlayingInfo()
    }


    private func updateNowPlayingInfo() {
        guard isRecording else { return }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: isPaused ? "Recording Paused" : "Recording",
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentDuration,
            MPNowPlayingInfoPropertyPlaybackRate: isPaused ? 0 : 1,
        ]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func clearNowPlayingInfo() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}

enum RecordingError: LocalizedError {
    case noActiveRecording
    case permissionDenied
    case alreadyRecording

    var errorDescription: String? {
        switch self {
        case .noActiveRecording:
            return "No active recording session."
        case .permissionDenied:
            return "Microphone permission is required to record audio."
        case .alreadyRecording:
            return "A recording session is already in progress."
        }
    }
}
