import Observation
import RoomPlan
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

struct SavedStore: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var isGyeongbuk: Bool
    var regionLabel: String
    var address: String?
    var weekday: Double?
    var busyDay: Double?
    var peak: Double?

    var isComplete: Bool { weekday != nil }
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
    case quote(String)
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

enum AppTab: Hashable {
    case diagnosis
    case scan
    case community
    case my
}

@Observable
final class DiagnosisModel {
    var selectedTab = AppTab.diagnosis
    var path: [DiagnosisRoute] = []
    var store = StoreProfile.minsu
    var kitchen = Kitchen.minsu
    var scannedModelURL: URL?
    var edited: Set<EditedField> = []
    var kitchenPhotos: [DiagnosisPhoto] = []
    var menuPhotos: [DiagnosisPhoto] = []
    var analysis = PhotoAnalysis.example
    var savedStores: [SavedStore] = [] {
        didSet { persistStores() }
    }

    private let storesKey = "diagnosis.savedStores"

    init() {
        if let data = UserDefaults.standard.data(forKey: storesKey),
           let stores = try? JSONDecoder().decode([SavedStore].self, from: data) {
            savedStores = stores
        }
    }

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
        scannedModelURL = nil
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

    func applyScan(_ room: CapturedRoom) {
        let measurement = KitchenMeasurement(room: room)
        guard measurement.widthCm > 0, measurement.depthCm > 0 else { return }
        kitchen.widthM = (measurement.widthCm / 10).rounded() / 10
        kitchen.depthM = (measurement.depthCm / 10).rounded() / 10
        if measurement.heightCm > 0 {
            kitchen.heightM = (measurement.heightCm / 10).rounded() / 10
        }
        edited.insert(.kitchen)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("kitchen-\(UUID().uuidString).usdz")
        if (try? room.export(to: url, exportOptions: .model)) != nil {
            scannedModelURL = url
        }
    }

    func rediagnose() {
        path = [.storeInfo]
    }

    func save(_ saved: SavedStore) {
        savedStores.removeAll { $0.id == saved.id }
        savedStores.append(saved)
    }

    func diagnose(_ saved: SavedStore) {
        let base = StoreProfile.minsu
        let weekday = saved.weekday ?? base.sales.weekday
        let peakRatio = base.peakPerHour / base.sales.weekday
        var profile = base
        profile.name = saved.name
        profile.region = saved.isGyeongbuk ? .gyeongbuk : .other
        profile.sales.weekday = weekday
        profile.sales.busyDay = saved.busyDay ?? weekday
        profile.peakPerHour = saved.peak ?? max(1, (weekday * peakRatio).rounded())
        store = profile
        kitchen = .minsu
        scannedModelURL = nil
        var given: Set<EditedField> = [.region]
        if saved.weekday != nil { given.insert(.weekday) }
        if saved.busyDay != nil { given.insert(.busyDay) }
        if saved.peak != nil { given.insert(.peak) }
        edited = given
        kitchenPhotos = []
        menuPhotos = []
        analysis = .example
        path = [.kitchenPhotos]
    }

    private func persistStores() {
        if let data = try? JSONEncoder().encode(savedStores) {
            UserDefaults.standard.set(data, forKey: storesKey)
        }
    }
}
