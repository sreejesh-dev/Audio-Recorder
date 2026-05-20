//
//  RecordingAudioSession.swift
//  audioWaveRecorder
//
//  Created by Sreejesh C on 20/05/26.
//

import AVFAudio
import Foundation

enum RecordingAudioSession {
    static func activateForRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .spokenAudio,
            options: [.defaultToSpeaker, .allowBluetooth]
        )
        try session.setPreferredIOBufferDuration(0.005)
        try session.setActive(true, options: [])
    }

    static func deactivateIfIdle() {
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }
}
