import Foundation
import UIKit

enum PhotoAnalysisClient {
    static let endpoint = URL(string: "https://robotfit.pages.dev/api/analyze")!

    private struct Response: Decodable {
        struct Menu: Decodable {
            let name: String
            let process: String
        }

        let ok: Bool
        let menus: [Menu]?
        let fryerCount: Int?
        let hasExhaustHood: Bool?
        let notes: [String]?
    }

    static func analyze(kitchen: [UIImage], menu: [UIImage]) async -> PhotoAnalysis {
        guard !kitchen.isEmpty || !menu.isEmpty else { return .example }
        do {
            var request = URLRequest(url: endpoint, timeoutInterval: 25)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode([
                "kitchen": kitchen.compactMap(encode),
                "menu": menu.compactMap(encode),
            ])
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return fallback }
            let decoded = try JSONDecoder().decode(Response.self, from: data)
            guard decoded.ok, let menus = decoded.menus, !menus.isEmpty else { return fallback }
            return PhotoAnalysis(
                source: .photo,
                menus: menus.map { MenuItem(name: $0.name, process: CookProcess(rawValue: $0.process) ?? .other) },
                fryerCount: decoded.fryerCount,
                hasExhaustHood: decoded.hasExhaustHood,
                notes: decoded.notes ?? []
            )
        } catch {
            return fallback
        }
    }

    private static var fallback: PhotoAnalysis {
        let example = PhotoAnalysis.example
        return PhotoAnalysis(
            source: .example,
            menus: example.menus,
            fryerCount: example.fryerCount,
            hasExhaustHood: example.hasExhaustHood,
            notes: ["사진 분석에 실패해 예시 결과를 보여 드려요"] + example.notes
        )
    }

    private static func encode(_ image: UIImage) -> String? {
        let longest = max(image.size.width, image.size.height)
        let scale = min(1, 1280 / max(longest, 1))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.7)?.base64EncodedString()
    }
}
