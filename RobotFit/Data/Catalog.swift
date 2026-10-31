import Foundation

struct Robot: Decodable, Identifiable, Hashable {
    struct Size: Decodable, Hashable {
        let w: Double
        let d: Double
        let h: Double
    }

    let id: String
    let displayName: String
    let sizeCm: Size?
}

enum Catalog {
    static let robots: [Robot] = {
        guard let url = Bundle.main.url(forResource: "catalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data) else { return [] }
        return file.robots
    }()

    private struct File: Decodable {
        let robots: [Robot]
    }
}
