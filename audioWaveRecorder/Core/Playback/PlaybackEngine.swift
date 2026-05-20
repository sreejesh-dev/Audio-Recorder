//
//  PlaybackEngine.swift
//  audioWaveRecorder
//
//  Created by Sreejesh C on 20/05/26.
//

import Foundation
import AVFAudio

final class PlaybackEngine {
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var audioFile: AVAudioFile?
    private let spectrumAnalyzer = FrequencySpectrumAnalyzer()
    private var isTapInstalled = false

    private var segmentStartTime: TimeInterval = 0
    private var segmentSampleRate: Double = 44_100
    private var segmentIsScheduled = false
    private var storedTime: TimeInterval = 0
    private var playbackGeneration: UInt = 0

    private(set) var isRunning = false
    private(set) var duration: TimeInterval = 0

    var onSpectrumBands: (([Float]) -> Void)?


    func prepare(url: URL) throws {
        teardown()

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)

        let file = try AVAudioFile(forReading: url)
        audioFile = file
        duration = Double(file.length) / file.processingFormat.sampleRate
        storedTime = 0

        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: file.processingFormat)
        installSpectrumTapIfNeeded()

        audioEngine.prepare()
        try audioEngine.start()

        reschedule(from: 0)
        pause()
    }

    func teardown() {
        playbackGeneration &+= 1
        isRunning = false

        playerNode.stop()
        removeSpectrumTapIfInstalled()

        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.reset()

        if audioEngine.attachedNodes.contains(playerNode) {
            audioEngine.detach(playerNode)
        }

        audioFile = nil
        duration = 0
        storedTime = 0
        segmentStartTime = 0
        segmentIsScheduled = false

        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }

    var playheadTime: TimeInterval {
        guard isRunning,
              segmentIsScheduled,
              let nodeTime = playerNode.lastRenderTime,
              let playerTime = playerNode.playerTime(forNodeTime: nodeTime),
              playerTime.sampleRate > 0 else {
            return min(max(storedTime, 0), duration)
        }

        let elapsed = Double(playerTime.sampleTime) / playerTime.sampleRate
        let live = segmentStartTime + elapsed
        storedTime = min(max(live, 0), duration)
        return storedTime
    }

    func seek(to time: TimeInterval) {
        let clamped = min(max(time, 0), duration)
        pause()
        storedTime = clamped
        reschedule(from: clamped)
    }

    func play() {
        guard audioFile != nil, segmentIsScheduled else { return }
        if !playerNode.isPlaying {
            playerNode.play()
        }
        isRunning = true
    }

    func pause() {
        if playerNode.isPlaying {
            playerNode.pause()
        }
        if isRunning,
           segmentIsScheduled,
           let nodeTime = playerNode.lastRenderTime,
           let playerTime = playerNode.playerTime(forNodeTime: nodeTime),
           playerTime.sampleRate > 0 {
            let elapsed = Double(playerTime.sampleTime) / playerTime.sampleRate
            storedTime = min(max(segmentStartTime + elapsed, 0), duration)
        }
        isRunning = false
    }

    private func reschedule(from time: TimeInterval) {
        guard let file = audioFile else { return }

        playbackGeneration &+= 1
        let generation = playbackGeneration

        playerNode.stop()
        segmentIsScheduled = false

        let sampleRate = file.processingFormat.sampleRate
        let startFrame = AVAudioFramePosition(time * sampleRate)
        let remaining = AVAudioFrameCount(max(0, file.length - startFrame))
        guard remaining > 0 else { return }

        segmentStartTime = time
        segmentSampleRate = sampleRate
        storedTime = time
        segmentIsScheduled = true

        playerNode.scheduleSegment(
            file,
            startingFrame: startFrame,
            frameCount: remaining,
            at: nil,
            completionCallbackType: .dataPlayedBack
        ) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, self.playbackGeneration == generation else { return }
                self.isRunning = false
                self.segmentIsScheduled = false
                self.storedTime = self.duration
                self.onPlaybackFinished?()
            }
        }
    }

    var onPlaybackFinished: (() -> Void)?

    private func installSpectrumTapIfNeeded() {
        guard !isTapInstalled else { return }
        audioEngine.mainMixerNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] buffer, _ in
            guard let self, self.isRunning else { return }
            let bands = WaveformSmoothing.normalizedSpectrumBands(
                self.spectrumAnalyzer.analyze(buffer: buffer)
            )
            DispatchQueue.main.async {
                self.onSpectrumBands?(bands)
            }
        }
        isTapInstalled = true
    }

    private func removeSpectrumTapIfInstalled() {
        guard isTapInstalled else { return }
        audioEngine.mainMixerNode.removeTap(onBus: 0)
        isTapInstalled = false
    }
}
