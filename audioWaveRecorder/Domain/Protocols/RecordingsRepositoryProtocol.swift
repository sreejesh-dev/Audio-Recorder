//
//  RecordingsRepositoryProtocol.swift
//  audioWaveRecorder
//
//  Created by Sreejesh C on 20/05/26.
//

import Foundation

protocol RecordingsRepositoryProtocol {
    func fetchAll() throws -> [Recording]
    func save(_ recording: Recording) throws
    func delete(_ recording: Recording) throws
    func update(_ recording: Recording) throws
}
