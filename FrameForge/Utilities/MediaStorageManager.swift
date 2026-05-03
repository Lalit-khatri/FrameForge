import Foundation

final class MediaStorageManager {
    static let shared = MediaStorageManager()

    private let fileManager = FileManager.default

    private lazy var mediaDirectory: URL = {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let mediaDir = docs.appendingPathComponent("FrameForgeMedia", isDirectory: true)
        if !fileManager.fileExists(atPath: mediaDir.path) {
            try? fileManager.createDirectory(at: mediaDir, withIntermediateDirectories: true)
        }
        return mediaDir
    }()

    private init() {}

    func persistMedia(from temporaryURL: URL, projectID: UUID) -> URL? {
        let projectDir = mediaDirectory.appendingPathComponent(projectID.uuidString, isDirectory: true)
        if !fileManager.fileExists(atPath: projectDir.path) {
            try? fileManager.createDirectory(at: projectDir, withIntermediateDirectories: true)
        }

        let fileName = temporaryURL.lastPathComponent
        let destination = projectDir.appendingPathComponent(fileName)

        if fileManager.fileExists(atPath: destination.path) {
            return destination
        }

        do {
            try fileManager.copyItem(at: temporaryURL, to: destination)
            return destination
        } catch {
            return nil
        }
    }

    func deleteProjectMedia(projectID: UUID) {
        let projectDir = mediaDirectory.appendingPathComponent(projectID.uuidString, isDirectory: true)
        try? fileManager.removeItem(at: projectDir)
    }

    func mediaExists(at url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path)
    }

    func resolveMediaURL(_ url: URL, projectID: UUID) -> URL {
        if fileManager.fileExists(atPath: url.path) { return url }
        let fileName = url.lastPathComponent
        let resolved = mediaDirectory
            .appendingPathComponent(projectID.uuidString, isDirectory: true)
            .appendingPathComponent(fileName)
        if fileManager.fileExists(atPath: resolved.path) { return resolved }
        return url
    }
}
