import Foundation
import RoomPlan
import simd

struct KitchenMeasurement {
    let widthCm: Double
    let depthCm: Double
    let heightCm: Double

    init(room: CapturedRoom) {
        let floorSides = room.floors.first.map { floor in
            [floor.dimensions.x, floor.dimensions.y, floor.dimensions.z].map(Double.init).sorted(by: >)
        }
        if let floorSides, floorSides[1] > 0 {
            widthCm = floorSides[1] * 100
            depthCm = floorSides[0] * 100
        } else {
            let xs = room.walls.map { Double($0.transform.columns.3.x) }
            let zs = room.walls.map { Double($0.transform.columns.3.z) }
            let spanX = (xs.max() ?? 0) - (xs.min() ?? 0)
            let spanZ = (zs.max() ?? 0) - (zs.min() ?? 0)
            widthCm = min(spanX, spanZ) * 100
            depthCm = max(spanX, spanZ) * 100
        }
        heightCm = Double(room.walls.map(\.dimensions.y).max() ?? 0) * 100
    }
}
