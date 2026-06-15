import AVFoundation
import Foundation
import Photos
import UniformTypeIdentifiers
import UIKit

enum LocalMediaStore {
    static let identifierPrefix = "local-media://"

    private static var mediaDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("LocalMedia", isDirectory: true)
    }

    static func isLocalIdentifier(_ identifier: String) -> Bool {
        identifier.hasPrefix(identifierPrefix)
    }

    static func url(for identifier: String) -> URL? {
        guard isLocalIdentifier(identifier) else { return nil }
        let name = String(identifier.dropFirst(identifierPrefix.count))
        guard !name.isEmpty else { return nil }
        return mediaDirectory.appendingPathComponent(name)
    }

    static func copyAssetIfNeeded(identifier: String) async throws -> String {
        guard !isLocalIdentifier(identifier) else { return identifier }

        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = assets.firstObject else { return identifier }
        guard let resource = preferredResource(for: asset) else { return identifier }

        try ensureDirectory()
        let ext = fileExtension(for: resource)
        let fileName = "\(UUID().uuidString).\(ext)"
        let destination = mediaDirectory.appendingPathComponent(fileName)

        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHAssetResourceManager.default().writeData(for: resource, toFile: destination, options: options) { error in
                if let error {
                    try? FileManager.default.removeItem(at: destination)
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
        return identifierPrefix + fileName
    }

    static func delete(identifier: String) {
        guard let url = url(for: identifier) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    static func thumbnail(for identifier: String, targetSize: CGSize) -> UIImage? {
        guard let url = url(for: identifier) else { return nil }
        if isVideoURL(url) {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }

    static func isVideoIdentifier(_ identifier: String) -> Bool {
        guard let url = url(for: identifier) else { return false }
        return isVideoURL(url)
    }

    private static func ensureDirectory() throws {
        try FileManager.default.createDirectory(at: mediaDirectory, withIntermediateDirectories: true)
    }

    private static func preferredResource(for asset: PHAsset) -> PHAssetResource? {
        let resources = PHAssetResource.assetResources(for: asset)
        if asset.mediaType == .video {
            return resources.first { $0.type == .fullSizeVideo }
                ?? resources.first { $0.type == .video }
                ?? resources.first
        }
        return resources.first { $0.type == .photo }
            ?? resources.first { $0.type == .fullSizePhoto }
            ?? resources.first
    }

    private static func fileExtension(for resource: PHAssetResource) -> String {
        if let type = UTType(resource.uniformTypeIdentifier),
           let ext = type.preferredFilenameExtension {
            return ext
        }
        let ext = (resource.originalFilename as NSString).pathExtension
        return ext.isEmpty ? "dat" : ext
    }

    private static func isVideoURL(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .movie) || type.conforms(to: .video) || type.conforms(to: .mpeg4Movie)
    }
}
