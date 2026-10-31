import Foundation

enum CookProcess: String, Codable, Hashable {
    case fry
    case stirfry
    case noodle
    case other

    var label: String {
        switch self {
        case .fry: "튀김"
        case .stirfry: "볶음"
        case .noodle: "면"
        case .other: "기타"
        }
    }
}

struct Robot: Decodable, Identifiable, Hashable {
    struct Size: Decodable, Hashable {
        let w: Double
        let d: Double
        let h: Double
    }

    struct Power: Decodable, Hashable {
        let voltage: String
        let kw: Double
        let note: String?
    }

    struct Rental: Decodable, Hashable {
        let monthlyKrw: Double
        let months: Int
        let type: String
        let note: String?
    }

    struct Source: Decodable, Hashable {
        let fields: [String]
        let title: String
    }

    struct Maintenance: Decodable, Hashable {
        let monthlyKrw: Double
        let freeMonths: Int
    }

    let id: String
    let displayName: String
    let productName: String
    let supplier: String?
    let process: CookProcess
    let isBaseline: Bool
    let throughputPerHour: Double?
    let sizeCm: Size?
    let power: Power?
    let requiresThreePhase: Bool?
    let requiresExhaust: Bool?
    let purchasePriceKrw: Double?
    let priceIncludesVat: Bool?
    let rental: Rental?
    let installCostKrw: Double?
    let maintenance: Maintenance?
    let domestic: Bool?
    let robotTasks: [String]
    let humanTasks: [String]
    let sources: [Source]?
}

enum Catalog {
    static let robots: [Robot] = {
        guard let url = Bundle.main.url(forResource: "catalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data) else { return [] }
        return file.robots
    }()

    static var baseline: Robot? {
        robots.first(where: \.isBaseline) ?? robots.first
    }

    private struct File: Decodable {
        let robots: [Robot]
    }
}
