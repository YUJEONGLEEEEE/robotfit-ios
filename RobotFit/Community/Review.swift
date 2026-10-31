import CloudKit
import Foundation

struct Review: Identifiable, Codable, Hashable {
    static let recordType = "Review"

    let id: String
    let robotName: String
    let storeType: String
    let paybackMonths: Int
    let rating: Int
    let body: String
    let authorName: String
    let authorID: String
    let createdAt: Date
}

extension Review {
    init?(record: CKRecord) {
        guard let robotName = record["robotName"] as? String,
              let storeType = record["storeType"] as? String,
              let paybackMonths = record["paybackMonths"] as? Int,
              let rating = record["rating"] as? Int,
              let body = record["body"] as? String,
              let authorName = record["authorName"] as? String,
              let authorID = record["authorID"] as? String else { return nil }
        self.id = record.recordID.recordName
        self.robotName = robotName
        self.storeType = storeType
        self.paybackMonths = paybackMonths
        self.rating = rating
        self.body = body
        self.authorName = authorName
        self.authorID = authorID
        self.createdAt = record["createdAt"] as? Date ?? record.creationDate ?? .now
    }
}

struct ReviewDraft {
    var robotName = Catalog.robots.first?.displayName ?? ""
    var storeType = ""
    var paybackMonths = 12
    var rating = 5
    var body = ""

    var isValid: Bool {
        !storeType.trimmingCharacters(in: .whitespaces).isEmpty
            && !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
