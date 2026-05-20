//
//  PlaybackSession.swift
//  audioWaveRecorder
//
//  Created by Sreejesh C on 20/05/26.
//

import Foundation
import QuartzCore
import SwiftUI

@MainActor
final class PlaybackSession: ObservableObject {
    enum Transport: Equatable {
        case idle
        case paused
        case playing
        case scrubbing(playOnRelease: Bool)
    }

    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var transport: Transport = .idle
    @Published private(set) var liveSpectrumBands: [Float] = [Float](
        repeating: 0,
        count: WaveformSmoothing.spectrumBandCount
    )

    private let engine: PlaybackEngine
    private var displayLink: CADisplayLink?
    private var waveformSamples: [Float] = []
    private var lastSpectrumPublish: CFAbsoluteTime = 0

    init(engine: PlaybackEngine = PlaybackEngine()) {
        self.engine = engine
        bindEngine()
    }


    var progress: Double {
        guard duration > 0,
              duration.isFinite,
              currentTime.isFinite else { return 0 }
        let ratio = currentTime / duration
        guard ratio.isFinite else { return 0 }
        return min(max(ratio, 0), 1)
    }

    var isPlaying: Bool {
        transport == .playing
    }

    var isScrubbing: Bool {
        if case .scrubbing = transport { return true }
        return false
    }

    var showsPauseControl: Bool {
        switch transport {
        case .playing:
            return true
        case .scrubbing(let playOnRelease):
            return playOnRelease
        case .paused, .idle:
            return false
        }
    }

    var displaySpectrumBands: [Float] {
        if isPlaying, !isScrubbing {
            return liveSpectrumBands
        }
        return WaveformSmoothing.playbackBandsFromWaveform(
            samples: waveformSamples,
            currentTime: currentTime,
            duration: duration
        )
    }

    func load(recording: Recording) throws {
        stopDisplayLink()
        transport = .idle
        currentTime = 0
        duration = 0
        waveformSamples = recording.waveformSamples
        try engine.prepare(url: recording.fileURL)
        duration = engine.duration
        currentTime = 0
        transport = .paused
        refreshSpectrumPreview()
    }

    func unload() {
        stopDisplayLink()
        transport = .idle
        engine.teardown()
        duration = 0
        currentTime = 0
        liveSpectrumBands = Array(repeating: 0, count: WaveformSmoothing.spectrumBandCount)
    }


    func togglePlayPause() {
        if isScrubbing {
            toggleScrubPlayOnRelease()
            return
        }

        switch transport {
        case .playing:
            pause()
        case .paused, .idle:
            play()
        case .scrubbing:
            break
        }
    }

    func play() {
        guard duration > 0 else { return }
        engine.seek(to: currentTime)
        engine.play()
        transport = .playing
        startDisplayLink()
        reconcileWithEngine()
    }

    func pause() {
        engine.pause()
        transport = .paused
        stopDisplayLink()
        currentTime = engine.playheadTime
        duration = engine.duration
        refreshSpectrumPreview()
    }


    func beginScrub() {
        stopDisplayLink()

        let wasPlaying = transport == .playing
        if wasPlaying {
            engine.pause()
        }

        currentTime = engine.playheadTime
        duration = engine.duration
        transport = .scrubbing(playOnRelease: true)
        refreshSpectrumPreview()
    }

    func updateScrub(progress: Double) {
        guard isScrubbing, duration > 0 else { return }
        currentTime = duration * min(max(progress, 0), 1)
        refreshSpectrumPreview()
    }

    func endScrub(at progress: Double) {
        guard duration > 0 else { return }

        let playOnRelease: Bool
        if case .scrubbing(let willPlay) = transport {
            playOnRelease = willPlay
        } else {
            playOnRelease = true
        }

        let time = duration * min(max(progress, 0), 1)
        currentTime = time

        engine.seek(to: time)

        if playOnRelease {
            engine.play()
            transport = .playing
            startDisplayLink()
        } else {
            transport = .paused
            refreshSpectrumPreview()
        }

        reconcileWithEngine()
    }


    private func bindEngine() {
        engine.onSpectrumBands = { [weak self] bands in
            Task { @MainActor in
                guard let self, self.isPlaying, !self.isScrubbing else { return }
                let now = CFAbsoluteTimeGetCurrent()
                guard now - self.lastSpectrumPublish >= 1.0 / 20 else { return }
                self.lastSpectrumPublish = now
                self.liveSpectrumBands = bands
            }
        }

        engine.onPlaybackFinished = { [weak self] in
            Task { @MainActor in
                self?.handlePlaybackFinished()
            }
        }
    }

    private func handlePlaybackFinished() {
        guard transport == .playing else { return }
        stopDisplayLink()
        engine.pause()
        transport = .paused
        currentTime = engine.duration
        duration = engine.duration
        refreshSpectrumPreview()
    }

    private func toggleScrubPlayOnRelease() {
        guard case .scrubbing(let current) = transport else { return }
        transport = .scrubbing(playOnRelease: !current)
    }

    private func startDisplayLink() {
        stopDisplayLink()
        let link = CADisplayLink(target: DisplayLinkTarget { [weak self] in
            Task { @MainActor in
                self?.displayTick()
            }
        }, selector: #selector(DisplayLinkTarget.tick))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    private func displayTick() {
        guard transport == .playing else { return }
        currentTime = engine.playheadTime
        duration = engine.duration

        if !engine.isRunning {
            transport = .paused
            stopDisplayLink()
            refreshSpectrumPreview()
        }
    }

    private func reconcileWithEngine() {
        duration = engine.duration
        if !isScrubbing {
            currentTime = engine.playheadTime
        }
    }

    private func refreshSpectrumPreview() {
        liveSpectrumBands = WaveformSmoothing.playbackBandsFromWaveform(
            samples: waveformSamples,
            currentTime: currentTime,
            duration: duration
        )
    }
}


private final class DisplayLinkTarget: NSObject {
    private let handler: () -> Void

    init(handler: @escaping () -> Void) {
        self.handler = handler
    }

    @objc func tick() {
        handler()
    }
}
