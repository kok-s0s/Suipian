import SwiftUI
import Combine
import Speech
import AVFoundation

struct VoiceInputView: View {
    let onCommit: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    @StateObject private var recorder = VoiceRecorder()
    @State private var barHeights: [CGFloat] = Array(repeating: 4, count: 26)
    @State private var animTimer: Timer?

    var body: some View {
        ZStack {
            // Deep ink-blue instead of pure black — warmer and consistent with dark mode theme
            Color(red: 0.07, green: 0.08, blue: 0.14).opacity(0.96).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Text(recorder.statusText)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.65))
                    .padding(.bottom, 24)

                // Waveform
                HStack(alignment: .center, spacing: 3) {
                    ForEach(barHeights.indices, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.65))
                            .frame(width: 3, height: barHeights[i])
                            .animation(.easeInOut(duration: 0.12), value: barHeights[i])
                    }
                }
                .frame(height: 56)
                .padding(.bottom, 28)

                // Transcript
                ScrollView {
                    Text(recorder.transcript.isEmpty ? "开始说话…" : recorder.transcript)
                        .font(.title3)
                        .foregroundStyle(recorder.transcript.isEmpty ? .white.opacity(0.28) : .white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 36)
                        .frame(maxWidth: .infinity)
                        .animation(.easeOut, value: recorder.transcript)
                }
                .scrollIndicators(recorder.transcript.isEmpty ? .hidden : .visible)
                .frame(maxHeight: 180)
                .padding(.bottom, 36)

                Spacer()

                // Controls
                HStack(spacing: 44) {
                    // Cancel
                    Button {
                        recorder.stop()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 54, height: 54)
                            .background(.white.opacity(0.12), in: Circle())
                    }

                    // Record / Stop
                    Button {
                        if recorder.isRecording {
                            recorder.stop()
                        } else {
                            recorder.start()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 70, height: 70)
                                .shadow(color: .red.opacity(0.4), radius: 12, y: 4)
                            if recorder.isRecording {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(.white)
                                    .frame(width: 22, height: 22)
                            } else {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 24, height: 24)
                            }
                        }
                    }
                    .scaleEffect(recorder.isRecording ? 1.08 : 1.0)
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                               value: recorder.isRecording)

                    // Confirm
                    Button {
                        let text = recorder.transcript
                        recorder.stop()
                        dismiss()
                        if !text.isEmpty { onCommit(text) }
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(recorder.transcript.isEmpty ? .white.opacity(0.3) : .white)
                            .frame(width: 54, height: 54)
                            .background(
                                recorder.transcript.isEmpty
                                    ? AnyShapeStyle(.white.opacity(0.1))
                                    : AnyShapeStyle(Color.accentColor.opacity(0.8)),
                                in: Circle()
                            )
                    }
                    .disabled(recorder.transcript.isEmpty)
                }
                .padding(.bottom, 56)
            }
        }
        .onAppear {
            recorder.setup()
            recorder.start()
            startWaveAnimation()
        }
        .onDisappear {
            recorder.stop()
            animTimer?.invalidate()
            animTimer = nil
        }
    }

    private func startWaveAnimation() {
        animTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { _ in
            if recorder.isRecording {
                barHeights = (0..<26).map { _ in CGFloat.random(in: 6...52) }
            } else {
                withAnimation(.easeOut(duration: 0.3)) {
                    barHeights = Array(repeating: 4, count: 26)
                }
            }
        }
    }
}

// MARK: - Voice recorder

@MainActor
final class VoiceRecorder: ObservableObject {
    @Published var transcript = ""
    @Published var isRecording = false
    @Published var statusText = "准备就绪"

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func setup() {
        SFSpeechRecognizer.requestAuthorization { status in
            Task { @MainActor in
                if status == .denied || status == .restricted {
                    self.statusText = "请在设置中开启语音识别权限"
                }
            }
        }
    }

    func start() {
        guard !isRecording else { return }
        transcript = ""
        statusText = "正在聆听…"

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            statusText = "无法启动麦克风"
            return
        }

        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request else { return }
        request.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024,
                             format: inputNode.outputFormat(forBus: 0)) { [weak self] buf, _ in
            self?.request?.append(buf)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            statusText = "麦克风启动失败"
            return
        }

        task = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                }
                if result?.isFinal == true {
                    self.statusText = "识别完成"
                    self.stop()
                } else if let error {
                    let nsErr = error as NSError
                    if nsErr.code != 301 { // 301 = cancelled
                        self.statusText = "识别中断"
                        self.stop()
                    }
                }
            }
        }

        isRecording = true
    }

    func stop() {
        guard isRecording else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        isRecording = false
        if statusText == "正在聆听…" { statusText = "准备就绪" }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
