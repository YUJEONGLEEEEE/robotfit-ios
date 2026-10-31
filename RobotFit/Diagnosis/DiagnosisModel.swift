import Observation
import UIKit
import SwiftUI

struct MenuItem: Hashable {
    let name: String
    let process: CookProcess
}

struct PhotoAnalysis {
    enum Source {
        case example
        case photo
    }

    let source: Source
    let menus: [MenuItem]
    let fryerCount: Int?
    let hasExhaustHood: Bool?
    let notes: [String]

    var processes: [CookProcess] {
        var seen: [CookProcess] = []
        for menu in menus where !seen.contains(menu.process) {
            seen.append(menu.process)
        }
        return seen
    }

    static let example = PhotoAnalysis(
        source: .example,
        menus: ["후라이드치킨", "양념치킨", "간장치킨", "매운양념치킨", "순살후라이드", "순살양념치킨", "청양갈릭치킨"]
            .map { MenuItem(name: $0, process: .fry) },
        fryerCount: 2,
        hasExhaustHood: true,
        notes: ["튀김기 위에 배기 후드가 있어요", "튀김기 옆 작업대 폭이 좁아요"]
    )
}

struct DiagnosisPhoto: Identifiable {
    let id = UUID()
    let image: UIImage?
    let sampleName: String?

    var isExample: Bool { sampleName != nil }

    static let kitchenExample = DiagnosisPhoto(image: nil, sampleName: "SampleKitchen")
    static let menuExample = DiagnosisPhoto(image: nil, sampleName: "SampleMenu")
}

enum DiagnosisRoute: Hashable {
    case kitchenPhotos
    case menuPhotos
    case storeInfo
    case analyzing
    case result
    case compare
    case size
    case detail(String)
    case basis(String)
    case notRecommended(String)
}

enum EditedField: Hashable {
    case region
    case kitchen
    case fryLine
    case weekday
    case busyDay
    case peak
    case soloLimit
    case reducedStaff
}

@Observable
final class DiagnosisModel {
    var path: [DiagnosisRoute] = []
    var store = StoreProfile.minsu
    var kitchen = Kitchen.minsu
    var edited: Set<EditedField> = []
    var kitchenPhotos: [DiagnosisPhoto] = []
    var menuPhotos: [DiagnosisPhoto] = []
    var analysis = PhotoAnalysis.example

    static let maxPhotos = 4

    var evaluation: (diag: DiagnosisSummary, results: [RobotResult]) {
        Engine.results(for: store)
    }

    var comparison: Comparison {
        Engine.compare(evaluation.results)
    }

    func result(for robotID: String) -> RobotResult? {
        evaluation.results.first { $0.robot.id == robotID }
    }

    func isAssumed(_ field: EditedField) -> Bool {
        !edited.contains(field)
    }

    func start() {
        store = .minsu
        kitchen = .minsu
        edited = []
        kitchenPhotos = []
        menuPhotos = []
        analysis = .example
        path = [.kitchenPhotos]
    }

    func applyAnalysis(_ analysis: PhotoAnalysis) {
        self.analysis = analysis
        if !analysis.processes.isEmpty {
            store.processes = analysis.processes
        }
        if let hood = analysis.hasExhaustHood {
            store.hasExhaustHood = hood
        }
    }

    func applyScan(_ measurement: KitchenMeasurement) {
        guard measurement.widthCm > 0, measurement.depthCm > 0 else { return }
        kitchen.widthM = (measurement.widthCm / 10).rounded() / 10
        kitchen.depthM = (measurement.depthCm / 10).rounded() / 10
        edited.insert(.kitchen)
    }

    func rediagnose() {
        path = [.storeInfo]
    }
}
