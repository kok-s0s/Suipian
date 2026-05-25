import AVFoundation
import Combine

// MARK: - File helpers

enum AudioStore {
    static var directory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("audio", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func url(for fileName: String) -> URL {
        directory.appendingPathComponent(fileName)
    }

    static func delete(_ fileName: String) {
        try? FileManager.default.removeItem(at: url(for: fileName))
    }

    static func duration(of fileName: String) -> TimeInterval {
        let url = url(for: fileName)
        return (try? AVAudioPlayer(contentsOf: url))?.duration ?? 0
    }
}

// MARK: - Recorder

@MainActor
final class AudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording = false
    @Published var elapsedSeconds: Int = 0

    private var recorder: AVAudioRecorder?
    private var timer: AnyCancellable?
    private var currentFileName: String?

    func requestPermissionAndStart() async -> Bool {
        let granted: Bool
        if #available(iOS 17, *) {
            granted = await AVAudioApplication.requestRecordPermission()
        } else {
            granted = await withCheckedContinuation { cont in
                AVAudioSession.sharedInstance().requestRecordPermission { cont.resume(returning: $0) }
            }
        }
        guard granted else { return false }
        start()
        return true
    }

    private func start() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
        try? session.setActive(true)

        let fileName = UUID().uuidString + ".m4a"
        let url = AudioStore.url(for: fileName)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        guard let rec = try? AVAudioRecorder(url: url, settings: settings) else { return }
        rec.delegate = self
        rec.record()
        recorder = rec
        currentFileName = fileName
        elapsedSeconds = 0
        isRecording = true
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.elapsedSeconds += 1 }
    }

    func stop() -> String? {
        timer?.cancel()
        recorder?.stop()
        recorder = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        let name = currentFileName
        currentFileName = nil
        return name
    }

    func cancel() {
        if let name = stop() { AudioStore.delete(name) }
    }
}

// MARK: - Player

@MainActor
final class AudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0

    private var player: AVAudioPlayer?
    private var timer: AnyCancellable?
    private(set) var fileName: String = ""

    func load(fileName: String) {
        guard fileName != self.fileName else { return }
        stop()
        self.fileName = fileName
        let url = AudioStore.url(for: fileName)
        player = try? AVAudioPlayer(contentsOf: url)
        player?.delegate = self
        player?.prepareToPlay()
        duration = player?.duration ?? 0
        currentTime = 0
    }

    func togglePlay() {
        guard let player else { return }
        if isPlaying {
            player.pause()
            timer?.cancel()
            isPlaying = false
        } else {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback)
            try? session.setActive(true)
            if currentTime >= duration { player.currentTime = 0; currentTime = 0 }
            player.play()
            isPlaying = true
            timer = Timer.publish(every: 0.1, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    guard let self, let p = self.player else { return }
                    self.currentTime = p.currentTime
                }
        }
    }

    func seek(to time: TimeInterval) {
        player?.currentTime = time
        currentTime = time
    }

    func stop() {
        player?.stop()
        timer?.cancel()
        isPlaying = false
        currentTime = 0
        player = nil
        fileName = ""
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        timer?.cancel()
        currentTime = duration
    }
}
