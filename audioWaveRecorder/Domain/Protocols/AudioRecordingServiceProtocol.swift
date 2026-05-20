//
//  AudioRecordingServiceProtocol.swift
//  audioWaveRecorder
//
//  Created by Sreejesh C on 20/05/26.
//

import Foundation

protocol AudioRecordingServiceProtocol: AnyObject {
    var isRecording: Bool { get }
    var isPaused: Bool { get }
    var currentDuration: TimeInterval { get }
    var onMeterLevel: ((Float) -> Void)? { get set }
    var onFrequencyBands: (([Float]) -> Void)? { get set }
    var onDurationUpdate: ((TimeInterval) -> Void)? { get set }

    func requestPermission() async -> Bool
    func startRecording() throws -> URL
    func pauseRecording()
    func resumeRecording()
    func stopRecording() throws -> (url: URL, duration: TimeInterval, samples: [Float])
    func cancelRecording()
}
