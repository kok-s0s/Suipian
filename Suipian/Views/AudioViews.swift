import SwiftUI
import AVFoundation

// MARK: - Recorder row (used in FragmentEditView)

struct AudioRecorderRow: View {
    @Binding var audioFileNames: [String]
    @Binding var audioData: [Data]
    @StateObject private var recorder = AudioRecorder()
    @State private var permissionDenied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Recorded clips
            ForEach(audioFileNames, id: \.self) { name in
                HStack(spacing: 10) {
                    Image(systemName: "waveform")
                        .foregroundStyle(.secondary)
                    Text(formatDuration(AudioStore.duration(of: name)))
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Button {
                        if let idx = audioFileNames.firstIndex(of: name) {
                            AudioStore.delete(name)
                            audioFileNames.remove(at: idx)
                            // audioData and audioFileNames must stay in sync; guard bounds
                            if idx < audioData.count {
                                audioData.remove(at: idx)
                            } else if !audioData.isEmpty {
                                audioData.removeLast()
                            }
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.8))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 16)
            }

            // Record button row
            HStack(spacing: 12) {
                Button {
                    if recorder.isRecording {
                        if let name = recorder.stop() {
                            audioFileNames.append(name)
                            if let data = AudioStore.data(for: name) { audioData.append(data) }
                        }
                    } else {
                        Task {
                            let ok = await recorder.requestPermissionAndStart()
                            if !ok { permissionDenied = true }
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: recorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.title2)
                            .foregroundStyle(recorder.isRecording ? .red : Color.accentColor)
                            .symbolEffect(.pulse, isActive: recorder.isRecording)
                        Text(recorder.isRecording
                             ? "停止录音 \(formatDuration(TimeInterval(recorder.elapsedSeconds)))"
                             : "录制语音")
                            .font(.subheadline)
                            .foregroundStyle(recorder.isRecording ? .red : Color.accentColor)
                    }
                }

                if recorder.isRecording {
                    Button("取消") { recorder.cancel() }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
        }
        .alert("无法访问麦克风", isPresented: $permissionDenied) {
            Button("去设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("请在系统设置中允许碎片访问麦克风。")
        }
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        let s = Int(t)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: - Player card (used in FragmentDetailView)

struct AudioPlayerCard: View {
    let fileName: String
    var fallbackData: Data? = nil
    @StateObject private var player = AudioPlayer()

    var body: some View {
        HStack(spacing: 12) {
            Button { player.togglePlay() } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Slider(
                    value: Binding(
                        get: { player.duration > 0 ? player.currentTime / player.duration : 0 },
                        set: { player.seek(to: $0 * player.duration) }
                    )
                )
                .tint(Color(red: 0.780, green: 0.624, blue: 0.384))

                HStack {
                    Text(formatTime(player.currentTime))
                    Spacer()
                    Text(formatTime(player.duration))
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .onAppear { player.load(fileName: fileName, fallbackData: fallbackData) }
        .onDisappear { player.stop() }
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let s = Int(t)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
