import Foundation

enum Format {
    private static let grouped: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter
    }()

    static func number(_ value: Double) -> String {
        grouped.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func manWon(_ krw: Double) -> String {
        "\(number((krw / 10_000 * 10).rounded() / 10))만 원"
    }

    static func priceWon(_ krw: Double) -> String {
        krw == 0 ? "0원" : "\(number((krw / 10_000).rounded()))만 원"
    }

    static func won(_ krw: Double) -> String {
        "\(number(krw.rounded()))원"
    }

    static func signedManWon(_ krw: Double) -> String {
        "\(krw >= 0 ? "+" : "−")\(priceWon(abs(krw)))"
    }

    static func aboutMonths(_ months: Double?) -> String {
        guard let months else { return "회수 불가" }
        return "약 \(Int(months.rounded()))개월"
    }

    static func cm(_ value: Double) -> String {
        "\(number((value * 10).rounded() / 10))cm"
    }
}
