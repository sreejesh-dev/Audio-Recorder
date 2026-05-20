//
//  RecordingRowView.swift
//  audioWaveRecorder
//
//  Created by Sreejesh C on 20/05/26.
//

import SwiftUI

struct RecordingRowView: View {
    let recording: Recording
    let onRowTap: () -> Void
    let onPlayTap: () -> Void
    let onStarTap: () -> Void
    let onRenameTap: () -> Void
    let onDeleteTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 10) {
                Text(recording.createdAt.recordingMetadataLine)
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)

                Text(recording.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onRowTap)

            HStack(spacing: 12) {
                Button(action: onPlayTap) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.caption2)
                        Text(recording.duration.mmss)
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(AppTheme.primaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.durationPill)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Spacer()

                HStack(spacing: 14) {
                    Image("transcript_icon")
                        .resizable()
                        .frame(width: 31, height: 31)
//                        .foregroundStyle(AppTheme.secondaryText)

                    Image("share_icon")
                        .resizable()
                        .frame(width: 31, height: 31)

//                        .foregroundStyle(AppTheme.secondaryText)

                    Button(action: onStarTap) {
                        Image(systemName: recording.isStarred ? "star.fill" : "star")
                            .foregroundStyle(recording.isStarred ? .yellow : AppTheme.secondaryText)
                    }
                    .buttonStyle(.plain)

                    Menu {
                        Button {
                            onRenameTap()
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            onDeleteTap()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image("menu_icon")
                            .frame(width: 28, height: 28)
                    }
                }
                .font(.body)
            }
        }
        .padding(.vertical, 14)
    }
}
