//
//  HomeView.swift
//  audioWaveRecorder
//
//  Created by Sreejesh C on 20/05/26.
//

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    @EnvironmentObject private var playback: PlaybackSession
    @State private var recordingToRename: Recording?
    @State private var renameDraft = ""
    @State private var recordingToDelete: Recording?
    @State private var showSaveTitleAlert = false
    @State private var saveTitleDraft = ""
    @State private var isRecordingSheetExpanded = true

    init(viewModel: HomeViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                searchBar
                filterChips
                recordingsList
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if viewModel.isRecordingSessionActive {
                RecordingSheetContainer {
                    RecordingSessionSheet(
                        isExpanded: $isRecordingSheetExpanded,
                        duration: viewModel.recordingDuration,
                        isPaused: viewModel.isRecordingPaused,
                        frequencyBands: viewModel.liveFrequencyBands,
                        onTogglePause: viewModel.toggleRecordingPause,
                        onDone: handleRecordingDone
                    )
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay(alignment: .bottom) {
            if let recording = viewModel.selectedRecording, !viewModel.isRecordingSessionActive {
                PlaybackSheetView(
                    recording: recording,
                    currentTime: playback.currentTime,
                    duration: playback.duration,
                    isPlaying: playback.isPlaying,
                    isScrubbing: playback.isScrubbing,
                    showsPauseControl: playback.showsPauseControl,
                    frequencyBands: playback.displaySpectrumBands,
                    progress: playback.progress,
                    onTogglePlay: { playback.togglePlayPause() },
                    onScrubBegan: { playback.beginScrub() },
                    onScrubChanged: { playback.updateScrub(progress: $0) },
                    onScrubEnded: { playback.endScrub(at: $0) },
                    onClose: { viewModel.closePlayback() }
                )
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.88), value: viewModel.isRecordingSessionActive)
        .animation(.spring(response: 0.38, dampingFraction: 0.88), value: viewModel.selectedRecording?.id)
        .onChange(of: viewModel.isRecordingSessionActive) { _, isActive in
            if isActive {
                isRecordingSheetExpanded = true
            }
        }
        .onAppear(perform: viewModel.onAppear)
        .alert("Notice", isPresented: alertBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.alertMessage ?? "")
        }
        .alert("Save Recording", isPresented: $showSaveTitleAlert) {
            TextField("Name your recording", text: $saveTitleDraft)
            Button("Save") {
                viewModel.commitSaveRecording(title: saveTitleDraft)
            }
            Button("Cancel", role: .cancel) {
                viewModel.cancelSaveRecording()
            }
        } message: {
            Text("Enter a title for this recording.")
        }
        .alert("Rename Recording", isPresented: renameAlertBinding) {
            TextField("Title", text: $renameDraft)
            Button("Save") {
                if let recording = recordingToRename {
                    viewModel.renameRecording(recording, to: renameDraft)
                }
                recordingToRename = nil
            }
            Button("Cancel", role: .cancel) {
                recordingToRename = nil
            }
        } message: {
            Text("Enter a new name for this recording.")
        }
        .alert("Delete Recording?", isPresented: deleteAlertBinding) {
            Button("Delete", role: .destructive) {
                if let recording = recordingToDelete {
                    viewModel.deleteRecording(recording)
                }
                recordingToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                recordingToDelete = nil
            }
        } message: {
            if let recording = recordingToDelete {
                Text("\"\(recording.title)\" will be permanently deleted.")
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("Recorder")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(AppTheme.primaryText)

            Spacer()

            HStack(spacing: 18) {
                Button {
                    Task { await viewModel.startRecording() }
                } label: {
                    Image("plus_icon")
                        .resizable()
                        .frame(width: 20, height: 20)
                }
                .disabled(viewModel.isRecordingSessionActive)
                .opacity(viewModel.isRecordingSessionActive ? 0.35 : 1)

                Image("icon")
                    .resizable()
                    .frame(width: 20, height: 20)
                Image("settings_icon")
                    .resizable()
                    .frame(width: 20, height: 20)
                
            }
            .foregroundStyle(AppTheme.primaryText)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image("search_icon")
                .resizable()
                .frame(width: 20, height: 20)


            TextField("", text: $viewModel.searchText,
                      prompt: Text("Search").foregroundStyle(Color.gray))
                .textFieldStyle(.plain)
                .foregroundStyle(AppTheme.primaryText)

            HStack(spacing: 6) {
                Image("ai_icon")
                    .resizable()
                    .frame(width: 17, height: 17)

                Text("Ask AI")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(AppTheme.primaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white)
            .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(AppTheme.searchBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
    }

    private var filterChips: some View {
        HStack(spacing: 10) {
            ForEach(RecordingFilter.allCases) { filter in
                FilterChipView(
                    title: filter.rawValue,
                    isSelected: viewModel.selectedFilter == filter
                ) {
                    viewModel.selectedFilter = filter
                }
            }
            Spacer()
        }
    }

    private var recordingsList: some View {
        LazyVStack(spacing: 0) {
            if viewModel.filteredRecordings.isEmpty {
                emptyState
            } else {
                ForEach(viewModel.filteredRecordings) { recording in
                    RecordingRowView(
                        recording: recording,
                        onRowTap: { viewModel.selectRecording(recording) },
                        onPlayTap: { viewModel.selectRecording(recording) },
                        onStarTap: { viewModel.toggleStar(for: recording) },
                        onRenameTap: {
                            renameDraft = recording.title
                            recordingToRename = recording
                        },
                        onDeleteTap: {
                            recordingToDelete = recording
                        }
                    )

                    if recording.id != viewModel.filteredRecordings.last?.id {
                        Divider().overlay(AppTheme.divider)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 40)

            Text("No recordings yet")
                .font(.headline)
                .foregroundStyle(AppTheme.secondaryText)

            Button {
                Task { await viewModel.startRecording() }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.15))
                        .frame(width: 88, height: 88)
                    Circle()
                        .fill(Color.red)
                        .frame(width: 64, height: 64)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Record")

            Text("Tap to record")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)

            Spacer(minLength: 80)
        }
        .frame(maxWidth: .infinity)
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.alertMessage != nil },
            set: { if !$0 { viewModel.alertMessage = nil } }
        )
    }

    private func handleRecordingDone() {
        viewModel.beginSaveRecording()
        guard viewModel.hasPendingSave else { return }
        saveTitleDraft = ""
        showSaveTitleAlert = true
    }

    private var renameAlertBinding: Binding<Bool> {
        Binding(
            get: { recordingToRename != nil },
            set: { if !$0 { recordingToRename = nil } }
        )
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { recordingToDelete != nil },
            set: { if !$0 { recordingToDelete = nil } }
        )
    }
}

#Preview {
    HomeView(viewModel: AppContainer().makeHomeViewModel())
}
