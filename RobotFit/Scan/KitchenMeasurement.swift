import Foundation
import RoomPlan
import simd

struct KitchenMeasurement {
    struct Fixture: Identifiable {
        let id = UUID()
        let name: String
        let widthCm: Double
        let depthCm: Double
    }

    enum Fit {
        case fits
        case tight
        case noFit
        case unknown

        var label: String {
            switch self {
            case .fits: "들어가요"
            case .tight: "빠듯해요"
            case .noFit: "안 들어가요"
            case .unknown: "치수 확인 필요"
            }
        }
    }

    static let aisleCm = 90.0

    let widthCm: Double
    let depthCm: Double
    let heightCm: Double
    let fixtures: [Fixture]

    init(room: CapturedRoom) {
        let floorSides = room.floors.first.map { floor in
            [floor.dimensions.x, floor.dimensions.y, floor.dimensions.z].map(Double.init).sorted(by: >)
        }
        if let floorSides, floorSides[1] > 0 {
            widthCm = floorSides[0] * 100
            depthCm = floorSides[1] * 100
        } else {
            let xs = room.walls.map { Double($0.transform.columns.3.x) }
            let zs = room.walls.map { Double($0.transform.columns.3.z) }
            let spanX = (xs.max() ?? 0) - (xs.min() ?? 0)
            let spanZ = (zs.max() ?? 0) - (zs.min() ?? 0)
            widthCm = max(spanX, spanZ) * 100
            depthCm = min(spanX, spanZ) * 100
        }
        heightCm = Double(room.walls.map(\.dimensions.y).max() ?? 0) * 100
        fixtures = room.objects.map { object in
            Fixture(
                name: Self.name(for: object.category),
                widthCm: Double(object.dimensions.x) * 100,
                depthCm: Double(object.dimensions.z) * 100
            )
        }
    }

    var areaPyeong: Double {
        widthCm * depthCm / 10_000 / 3.3058
    }

    func fit(for robot: Robot) -> Fit {
        guard let size = robot.sizeCm, widthCm > 0, depthCm > 0 else { return .unknown }
        let long = max(size.w, size.d)
        let short = min(size.w, size.d)
        let heightOK = heightCm == 0 || size.h <= heightCm
        guard heightOK, long <= widthCm, short <= depthCm else { return .noFit }
        return short + Self.aisleCm <= depthCm ? .fits : .tight
    }

    private static func name(for category: CapturedRoom.Object.Category) -> String {
        switch category {
        case .storage: "수납장·작업대"
        case .refrigerator: "냉장고"
        case .stove: "화구"
        case .oven: "오븐"
        case .sink: "싱크대"
        case .dishwasher: "식기세척기"
        case .table: "테이블"
        default: "기타 설비"
        }
    }
}
