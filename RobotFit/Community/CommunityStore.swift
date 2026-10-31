import CloudKit
import Observation

@Observable
final class CommunityStore {
    private(set) var reviews: [Review] = []
    private(set) var isLoading = false
    var message: String?

    private let database = CKContainer(identifier: "iCloud.com.aspyn.robotfit").publicCloudDatabase
    private let cacheKey = "community.cache"

    init() {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let cached = try? JSONDecoder().decode([Review].self, from: data) {
            reviews = cached
        }
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        let query = CKQuery(recordType: Review.recordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        do {
            let (results, _) = try await database.records(matching: query, resultsLimit: 100)
            reviews = results.compactMap { try? $0.1.get() }.compactMap(Review.init(record:))
            message = nil
            saveCache()
        } catch {
            message = "후기를 불러오지 못했어요. 마지막으로 받은 후기를 보여 드려요."
        }
    }

    func post(_ draft: ReviewDraft, authorName: String, authorID: String) async -> Bool {
        let record = CKRecord(recordType: Review.recordType)
        record["robotName"] = draft.robotName
        record["storeType"] = draft.storeType.trimmingCharacters(in: .whitespaces)
        record["paybackMonths"] = draft.paybackMonths
        record["rating"] = draft.rating
        record["body"] = draft.body.trimmingCharacters(in: .whitespacesAndNewlines)
        record["authorName"] = authorName
        record["authorID"] = authorID
        record["createdAt"] = Date.now
        do {
            let saved = try await database.save(record)
            if let review = Review(record: saved) {
                reviews.insert(review, at: 0)
                saveCache()
            }
            message = nil
            return true
        } catch let error as CKError where error.code == .notAuthenticated {
            message = "후기를 올리려면 iPhone 설정에서 iCloud에 로그인해 주세요."
        } catch {
            message = "후기를 올리지 못했어요. 인터넷 연결을 확인해 주세요."
        }
        return false
    }

    func delete(_ review: Review) async {
        do {
            try await database.deleteRecord(withID: CKRecord.ID(recordName: review.id))
            reviews.removeAll { $0.id == review.id }
            saveCache()
        } catch {
            message = "후기를 지우지 못했어요."
        }
    }

    func reviews(by authorID: String?) -> [Review] {
        reviews.filter { $0.authorID == authorID }
    }

    func averagePayback(for robotName: String) -> (months: Double, count: Int)? {
        let matched = reviews.filter { $0.robotName == robotName }
        guard !matched.isEmpty else { return nil }
        let total = matched.reduce(0) { $0 + $1.paybackMonths }
        return (Double(total) / Double(matched.count), matched.count)
    }

    private func saveCache() {
        if let data = try? JSONEncoder().encode(reviews) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }
}
