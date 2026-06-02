import CoreData
import SwiftUI

@Observable
final class CloudKitSyncMonitor {
    enum SyncState { case idle, syncing, succeeded, failed }

    private(set) var state: SyncState = .idle
    private(set) var lastSyncDate: Date? = nil
    private var observer: NSObjectProtocol?

    init() {
        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handle(notification)
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    private func handle(_ notification: Notification) {
        guard let event = notification.userInfo?[
            NSPersistentCloudKitContainer.eventNotificationUserInfoKey
        ] as? NSPersistentCloudKitContainer.Event,
              event.type == .import || event.type == .export
        else { return }

        if event.endDate == nil {
            state = .syncing
        } else if event.succeeded {
            lastSyncDate = event.endDate
            state = .succeeded
            // Auto-hide the success indicator after 3 seconds
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if self?.state == .succeeded { self?.state = .idle }
            }
        } else {
            state = .failed
        }
    }
}
