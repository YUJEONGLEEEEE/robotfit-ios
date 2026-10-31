import Observation
import RoomPlan
import UIKit
import SwiftUI

struct MenuItem: Hashable {
    let name: String
    let process: CookProcess
}

struct LayoutItem: Hashable {
    enum Kind: String {
        case fryer
        case sink
        case fridge
        case worktable
        case shelf
        case dishwasher
        case other
    }

    enum Wall: String {
        case left
        case right
        case back
    }

    let kind: Kind
    let wall: Wall
    let widthCm: Double
}

struct PhotoAnalysis {
    enum Source {
        case example
        case photo
    }

    let source: Source
    let menus: [MenuItem]
    var storeName: String? = nil
    let fryerCount: Int?
    let hasExhaustHood: Bool?
    var hasThreePhase: Bool? = nil
    var kitchen: Kitchen? = nil
    var fryLine: StoreProfile.Line? = nil
    var layout: [LayoutItem] = []
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
        storeName: "민수네 치킨",
        fryerCount: 2,
        hasExhaustHood: true,
        kitchen: Kitchen(widthM: 2.2, depthM: 5.5, heightM: 2.7, worktableCm: 60),
        fryLine: StoreProfile.Line(w: 280, d: 110),
        layout: [
            LayoutItem(kind: .worktable, wall: .left, widthCm: 150),
            LayoutItem(kind: .shelf, wall: .left, widthCm: 120),
            LayoutItem(kind: .fridge, wall: .left, widthCm: 120),
            LayoutItem(kind: .fryer, wall: .right, widthCm: 60),
            LayoutItem(kind: .fryer, wall: .right, widthCm: 60),
            LayoutItem(kind: .worktable, wall: .right, widthCm: 100),
            LayoutItem(kind: .sink, wall: .right, widthCm: 120),
            LayoutItem(kind: .shelf, wall: .back, widthCm: 120),
        ],
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

struct QuoteRecord: Identifiable, Codable, Hashable {
    var id: String
    var robotID: String
    var robotName: String
    var supplier: String
    var option: String
    var summary: String
    var date: Date
}

enum DiagnosisRoute: Hashable {
    case kitchenPhotos
    case menuPhotos
    case kitchenConfirm
    case kitchenEdit
    case storeInfo
    case analyzing
    case diagnosing
    case result
    case compare
    case basis(String)
    case notRecommended(String)
    case quote(String)
    case robot(String)
    case compareRobots([String])
}

enum EditedField: Hashable, CaseIterable {
    case region
    case kitchen
    case fryLine
    case threePhase
    case hood
    case weekday
    case busyDay
    case peak
    case soloLimit
    case reducedStaff

    static let required: [EditedField] = [.fryLine, .threePhase, .hood, .weekday, .reducedStaff]

    var label: String {
        switch self {
        case .region: "가게 위치"
        case .kitchen: "주방 크기"
        case .fryLine: "설치 가능 위치"
        case .threePhase: "3상 전원"
        case .hood: "배기 후드"
        case .weekday: "평일 판매량"
        case .busyDay: "금·토 판매량"
        case .peak: "피크타임 판매량"
        case .soloLimit: "혼자 튀길 수 있는 양"
        case .reducedStaff: "인력 감소 시간"
        }
    }
}

enum AppTab: Hashable {
    case diagnosis
    case quotes
    case community
    case my
}

@Observable
final class DiagnosisModel {
    var selectedTab = AppTab.diagnosis
    var path: [DiagnosisRoute] = []
    var store = StoreProfile.blank
    var kitchen = Kitchen.minsu
    var scannedModelURL: URL?
    var edited: Set<EditedField> = []
    var aiEstimated: Set<EditedField> = []
    var kitchenPhotos: [DiagnosisPhoto] = []
    var menuPhotos: [DiagnosisPhoto] = []
    var analysis = PhotoAnalysis.example
    var diagnosedAt: Date?
    var savedStores: [SavedStore] = [] {
        didSet { persistStores() }
    }

    var quoteRecords: [QuoteRecord] = [] {
        didSet { persistQuotes() }
    }

    private let storesKey = "diagnosis.savedStores"
    private let quotesKey = "diagnosis.quoteRecords"

    init() {
        if let data = UserDefaults.standard.data(forKey: storesKey),
           let stores = try? JSONDecoder().decode([SavedStore].self, from: data) {
            savedStores = stores
        }
        if let data = UserDefaults.standard.data(forKey: quotesKey),
           let records = try? JSONDecoder().decode([QuoteRecord].self, from: data) {
            quoteRecords = records
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

    var missingFields: [EditedField] {
        EditedField.required.filter { !edited.contains($0) }
    }

    var isReady: Bool { missingFields.isEmpty }

    var kitchenKnown: Bool { edited.contains(.kitchen) }

    var displayKitchen: Kitchen {
        guard !kitchenKnown else { return kitchen }
        let line = store.fryLineCm
        return Kitchen(
            widthM: max(2.0, (line.d + kitchen.worktableCm + 90) / 100),
            depthM: max(3.0, (line.w + 60) / 100),
            heightM: kitchen.heightM,
            worktableCm: kitchen.worktableCm
        )
    }

    private func mark(_ field: EditedField) {
        edited.insert(field)
        aiEstimated.insert(field)
    }

    func confirm(_ field: EditedField) {
        edited.insert(field)
        aiEstimated.remove(field)
    }

    func fillExample() {
        store = .minsu
        if !kitchenKnown {
            kitchen = .minsu
        }
        edited.formUnion(EditedField.allCases)
        aiEstimated = []
    }

    func setWeekday(_ value: Double) {
        store.sales.weekday = value
        edited.insert(.weekday)
        if !edited.contains(.busyDay) {
            store.sales.busyDay = value
        }
        if !edited.contains(.peak) {
            store.peakPerHour = max(1, (value * StoreProfile.peakPerWeekdaySale).rounded())
        }
    }

    private func reset() {
        store = .blank
        kitchen = .minsu
        scannedModelURL = nil
        edited = []
        aiEstimated = []
    }

    private func prefill(_ saved: SavedStore) {
        store.name = saved.name
        if saved.address != nil {
            store.region = saved.isGyeongbuk ? .gyeongbuk : .other
            edited.insert(.region)
        }
        if let busy = saved.busyDay {
            store.sales.busyDay = busy
            edited.insert(.busyDay)
        }
        if let peak = saved.peak {
            store.peakPerHour = peak
            edited.insert(.peak)
        }
        if let weekday = saved.weekday {
            setWeekday(weekday)
        }
    }

    func start() {
        reset()
        if let saved = savedStores.last(where: \.isComplete) ?? savedStores.last {
            prefill(saved)
        }
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
        if let name = analysis.storeName, !name.isEmpty, store.name == StoreProfile.blank.name {
            store.name = name
        }
        if let hood = analysis.hasExhaustHood, !edited.contains(.hood) {
            store.hasExhaustHood = hood
            mark(.hood)
        }
        if let power = analysis.hasThreePhase, !edited.contains(.threePhase) {
            store.hasThreePhase = power
            mark(.threePhase)
        }
        if let estimate = analysis.kitchen, scannedModelURL == nil, !edited.contains(.kitchen),
           estimate.widthM > 0, estimate.depthM > 0 {
            kitchen = Kitchen(
                widthM: (estimate.widthM * 10).rounded() / 10,
                depthM: (estimate.depthM * 10).rounded() / 10,
                heightM: estimate.heightM > 0 ? (estimate.heightM * 10).rounded() / 10 : kitchen.heightM,
                worktableCm: kitchen.worktableCm
            )
            mark(.kitchen)
        }
        if let line = analysis.fryLine, !edited.contains(.fryLine), line.w > 0, line.d > 0 {
            store.fryLineCm = .init(w: (line.w / 10).rounded() * 10, d: (line.d / 10).rounded() * 10)
            mark(.fryLine)
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
        confirm(.kitchen)
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
        reset()
        prefill(saved)
        kitchenPhotos = []
        menuPhotos = []
        analysis = .example
        path = [.kitchenPhotos]
    }

    var requestSummary: String {
        let size = "주방 \(Format.number(kitchen.widthM))×\(Format.number(kitchen.depthM))m"
        let line = store.fryLineCm.w > 0 ? ", 튀김 라인 \(Format.number(store.fryLineCm.w))×\(Format.number(store.fryLineCm.d))cm" : ""
        return size + line
    }

    func recordQuote(_ robot: Robot) {
        quoteRecords.removeAll { $0.robotID == robot.id }
        quoteRecords.insert(
            QuoteRecord(
                id: UUID().uuidString,
                robotID: robot.id,
                robotName: robot.displayName,
                supplier: robot.supplier ?? "공급사",
                option: "",
                summary: requestSummary,
                date: .now
            ),
            at: 0
        )
    }

    func showQuotes() {
        selectedTab = .quotes
    }

    private func persistQuotes() {
        if let data = try? JSONEncoder().encode(quoteRecords) {
            UserDefaults.standard.set(data, forKey: quotesKey)
        }
    }

    private func persistStores() {
        if let data = try? JSONEncoder().encode(savedStores) {
            UserDefaults.standard.set(data, forKey: storesKey)
        }
    }
}
