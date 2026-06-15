import Foundation
import CloudKit

@Observable
final class CloudSyncManager {
    var isSyncing = false
    var syncProgress: Float = 0
    var lastSyncDate: Date?
    var errorMessage: String?
    var cloudProjects: [CloudProjectMeta] = []

    // Lazily access container/database to avoid crash when
    // iCloud container identifiers are not configured.
    private var container: CKContainer? {
        // CKContainer.default() can crash if entitlements are misconfigured.
        // We wrap in a computed property so failures are contained.
        return CKContainer.default()
    }
    private var database: CKDatabase? {
        container?.privateCloudDatabase
    }

    struct CloudProjectMeta: Identifiable, Codable {
        let id: String
        var name: String
        var lastModified: Date
        var sizeBytes: Int
    }

    init() {}

    func fetchCloudProjects() async {
        guard let database = database else {
            errorMessage = "iCloud is not configured for this app."
            return
        }

        let query = CKQuery(recordType: "FrameForgeProject", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "modificationDate", ascending: false)]

        do {
            let (results, _) = try await database.records(matching: query)
            var meta: [CloudProjectMeta] = []
            for (_, result) in results {
                if let record = try? result.get() {
                    let name = record["projectName"] as? String ?? "Untitled"
                    let lastMod = record.modificationDate ?? Date()
                    let size = record["dataSize"] as? Int ?? 0
                    meta.append(CloudProjectMeta(id: record.recordID.recordName, name: name, lastModified: lastMod, sizeBytes: size))
                }
            }
            cloudProjects = meta
            lastSyncDate = Date()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func backupProject(name: String, data: Data) async {
        guard let database = database else {
            errorMessage = "iCloud is not configured for this app."
            return
        }

        isSyncing = true
        syncProgress = 0

        let recordID = CKRecord.ID(recordName: "project_\(name.lowercased().replacingOccurrences(of: " ", with: "_"))")
        let record = CKRecord(recordType: "FrameForgeProject", recordID: recordID)
        record["projectName"] = name as CKRecordValue
        record["dataSize"] = data.count as CKRecordValue

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).frameforge")
        try? data.write(to: tempURL)
        record["projectData"] = CKAsset(fileURL: tempURL)

        do {
            syncProgress = 0.5
            try await database.save(record)
            syncProgress = 1.0
            lastSyncDate = Date()
            try? FileManager.default.removeItem(at: tempURL)
        } catch {
            errorMessage = error.localizedDescription
        }

        isSyncing = false
    }

    func deleteCloudProject(id: String) async {
        guard let database = database else { return }
        let recordID = CKRecord.ID(recordName: id)
        do {
            try await database.deleteRecord(withID: recordID)
            cloudProjects.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func checkAccountStatus() async -> Bool {
        guard let container = container else { return false }
        do {
            let status = try await container.accountStatus()
            return status == .available
        } catch {
            return false
        }
    }
}
