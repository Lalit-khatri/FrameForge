import CoreSpotlight
import MobileCoreServices
import Foundation

final class SpotlightIndexer {
    static let shared = SpotlightIndexer()
    private let domainID = "com.frameforge.projects"

    func indexProject(id: String, title: String, clipCount: Int, duration: TimeInterval) {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .movie)
        attributeSet.title = title
        attributeSet.contentDescription = "\(clipCount) clips • \(formatDuration(duration))"
        attributeSet.keywords = ["video", "project", "edit", title]

        let item = CSSearchableItem(
            uniqueIdentifier: "project_\(id)",
            domainIdentifier: domainID,
            attributeSet: attributeSet
        )
        item.expirationDate = Date.distantFuture

        CSSearchableIndex.default().indexSearchableItems([item])
    }

    func removeProject(id: String) {
        CSSearchableIndex.default().deleteSearchableItems(
            withIdentifiers: ["project_\(id)"]
        )
    }

    func removeAllProjects() {
        CSSearchableIndex.default().deleteSearchableItems(
            withDomainIdentifiers: [domainID]
        )
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
