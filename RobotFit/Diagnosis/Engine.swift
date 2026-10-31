import Foundation

enum Assumptions {
    static let hourlyLaborKrw = (2_156_880.0 / 174 * 1.2).rounded()
    static let businessDaysPerMonth = 26.0
    static let robotCostMonths = 36.0
    static let robotHoursPerDay = 10.0
    static let electricityKrwPerKwh = 150.0
    static let recommendMaxMonths = 24.0
    static let conditionalMaxMonths = 36.0
    static let minPeakRatio = 1.0
    static let handMinutesPerItem = 5.0
    static let handMinutesWithRobot = 2.0
    static let replacementRates = [0.4, 0.6, 0.8]
    static let cleaningMinutesPerDay = 20.0
    static let tightMarginCm = 20.0
    static let vatRate = 0.1
}

struct StoreProfile: Equatable {
    enum Region: Equatable {
        case gyeongbuk
        case other
    }

    enum Cleaner: Equatable {
        case owner
        case staff
    }

    struct Sales: Equatable {
        var weekday: Double
        var weekdayCount: Double
        var busyDay: Double
        var busyDayCount: Double
    }

    struct Line: Equatable {
        var w: Double
        var d: Double
    }

    var name: String
    var region: Region
    var processes: [CookProcess]
    var sales: Sales
    var peakPerHour: Double
    var soloLimitPerHour: Double
    var fryLineCm: Line
    var hasThreePhase: Bool
    var hasExhaustHood: Bool
    var reducedStaffHoursPerDay: Double
    var cleaningBy: Cleaner

    static let blank = StoreProfile(
        name: "우리 가게",
        region: .other,
        processes: [.fry],
        sales: Sales(weekday: 0, weekdayCount: 4, busyDay: 0, busyDayCount: 2),
        peakPerHour: 0,
        soloLimitPerHour: 9,
        fryLineCm: Line(w: 0, d: 0),
        hasThreePhase: false,
        hasExhaustHood: false,
        reducedStaffHoursPerDay: 0,
        cleaningBy: .owner
    )

    static let peakPerWeekdaySale = 15.0 / 40.0

    static let minsu = StoreProfile(
        name: "민수네 치킨",
        region: .gyeongbuk,
        processes: [.fry],
        sales: Sales(weekday: 40, weekdayCount: 4, busyDay: 60, busyDayCount: 2),
        peakPerHour: 15,
        soloLimitPerHour: 9,
        fryLineCm: Line(w: 280, d: 110),
        hasThreePhase: true,
        hasExhaustHood: true,
        reducedStaffHoursPerDay: 4,
        cleaningBy: .owner
    )
}

struct Kitchen: Equatable {
    var widthM: Double
    var depthM: Double
    var heightM: Double
    var worktableCm: Double

    var pyeong: Int {
        Int((widthM * depthM / 3.3058).rounded())
    }

    static let minsu = Kitchen(widthM: 2.2, depthM: 5.5, heightM: 2.7, worktableCm: 60)
}

enum Verdict: Int, Comparable {
    case recommend
    case conditional
    case check
    case notRecommended

    static func < (lhs: Verdict, rhs: Verdict) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .recommend: "추천"
        case .conditional: "조건부 추천"
        case .check: "확인 필요"
        case .notRecommended: "도입 비추천"
        }
    }
}

struct Check: Identifiable {
    enum Kind: String {
        case process
        case space
        case utility
        case throughput
        case cost
    }

    enum Status {
        case pass
        case fail
        case unknown
    }

    let id: Kind
    let status: Status
    let detail: String
}

struct Subsidy {
    enum Kind {
        case gyeongbuk
        case smartStore
        case none

        var short: String {
            switch self {
            case .gyeongbuk: "경북 바우처"
            case .smartStore: "스마트상점"
            case .none: "지원 없이"
            }
        }
    }

    let id: Kind
    let name: String
    let ratio: Double
    let capKrw: Double
    let isEligible: (Robot, StoreProfile) -> Bool

    static let smartStoreRobots: Set<String> = ["tuiibot-3", "tuiibot-2"]

    static let all: [Subsidy] = [
        Subsidy(id: .gyeongbuk, name: "경북 식품로봇 바우처", ratio: 0.7, capKrw: 30_000_000) { robot, store in
            store.region == .gyeongbuk && robot.domestic == true
        },
        Subsidy(id: .smartStore, name: "스마트상점 구입형", ratio: 0.7, capKrw: 5_000_000) { robot, _ in
            smartStoreRobots.contains(robot.id)
        },
        Subsidy(id: .none, name: "지원 없이", ratio: 0, capKrw: 0) { _, _ in true },
    ]
}

struct SubsidyResult: Identifiable {
    var id: Subsidy.Kind { subsidy }
    let subsidy: Subsidy.Kind
    let name: String
    let capKrw: Double
    let selfPayKrw: Double
    let robotMonthlyKrw: Double
    let monthlyDiffKrw: Double
    let paybackMonths: Double?
    let firstYearCashKrw: Double
    let verdict: Verdict
}

struct RobotResult: Identifiable {
    var id: String { robot.id }
    let robot: Robot
    let checks: [Check]
    let costIsMinimum: Bool
    let electricityMonthlyKrw: Double?
    let subsidies: [SubsidyResult]
    let best: SubsidyResult?
    let verdict: Verdict
    let reason: String

    func check(_ kind: Check.Kind) -> Check? {
        checks.first { $0.id == kind }
    }

    var badgeText: String {
        if (verdict == .recommend || verdict == .conditional), let best, best.subsidy != .none {
            return "\(best.subsidy.short) 선정 시 \(verdict.label)"
        }
        return verdict.label
    }
}

struct DiagnosisSummary {
    let averageDailySales: Double
    let handMinutesPerDay: Double
    let handMinutesWithRobot: Double
    let netMinutesSaved: Double
    let peakOverSolo: Bool
    let removedStaffMonthlyKrw: Double
    let cleaningStaffMonthlyKrw: Double
}

struct Comparison {
    let compared: [RobotResult]
    let others: [(result: RobotResult, reason: String)]
}

enum Engine {
    static func diagnose(_ store: StoreProfile) -> DiagnosisSummary {
        let s = store.sales
        let average = (s.weekday * s.weekdayCount + s.busyDay * s.busyDayCount) / (s.weekdayCount + s.busyDayCount)
        let hand = average * Assumptions.handMinutesPerItem
        let withRobot = average * Assumptions.handMinutesWithRobot
        let cleaning = store.cleaningBy == .staff
            ? Assumptions.cleaningMinutesPerDay / 60 * Assumptions.hourlyLaborKrw * Assumptions.businessDaysPerMonth
            : 0
        return DiagnosisSummary(
            averageDailySales: average,
            handMinutesPerDay: hand,
            handMinutesWithRobot: withRobot,
            netMinutesSaved: hand - withRobot - Assumptions.cleaningMinutesPerDay,
            peakOverSolo: store.peakPerHour > store.soloLimitPerHour,
            removedStaffMonthlyKrw: store.reducedStaffHoursPerDay * Assumptions.hourlyLaborKrw * Assumptions.businessDaysPerMonth,
            cleaningStaffMonthlyKrw: cleaning
        )
    }

    static func economicVerdict(_ payback: Double?) -> Verdict {
        guard let payback, payback <= Assumptions.conditionalMaxMonths else { return .notRecommended }
        return payback <= Assumptions.recommendMaxMonths ? .recommend : .conditional
    }

    static func evaluate(_ robot: Robot, store: StoreProfile, diag: DiagnosisSummary? = nil) -> RobotResult {
        let diag = diag ?? diagnose(store)
        let missing = missingCosts(robot)
        let costCheck: Check
        if robot.purchasePriceKrw == nil {
            costCheck = Check(id: .cost, status: .unknown, detail: "구입가가 공개되지 않음")
        } else if !missing.isEmpty {
            costCheck = Check(id: .cost, status: .unknown, detail: "\(missing.joined(separator: "·"))가 공개되지 않음")
        } else {
            costCheck = Check(id: .cost, status: .pass, detail: "구입가·설치비·유지보수비 공개")
        }
        let hasProcess = store.processes.contains(robot.process)
        let checks = [
            Check(id: .process, status: hasProcess ? .pass : .fail, detail: hasProcess ? "가게에 있는 공정" : "가게에 없는 공정"),
            checkSpace(robot, store),
            checkUtility(robot, store),
            checkThroughput(robot, store),
            costCheck,
        ]

        let electricity = robot.power.map {
            $0.kw * Assumptions.robotHoursPerDay * Assumptions.electricityKrwPerKwh * Assumptions.businessDaysPerMonth
        }
        let subsidies = subsidyResults(robot, store: store, diag: diag, electricity: electricity ?? 0)
        let best = subsidies.min { ($0.paybackMonths ?? .infinity) < ($1.paybackMonths ?? .infinity) }

        func result(_ verdict: Verdict, _ reason: String) -> RobotResult {
            RobotResult(
                robot: robot,
                checks: checks,
                costIsMinimum: !missing.isEmpty,
                electricityMonthlyKrw: electricity,
                subsidies: subsidies,
                best: best,
                verdict: verdict,
                reason: reason
            )
        }

        if let failed = checks.first(where: { $0.status == .fail }) {
            return result(.notRecommended, failed.detail)
        }
        if let best, best.paybackMonths == nil {
            return result(.notRecommended, "로봇이 줄여 줄 근무가 없어 회수할 수 없음")
        }
        if let best, best.verdict == .notRecommended {
            return result(.notRecommended, "가장 유리한 지원으로도 회수 \(Int(Assumptions.conditionalMaxMonths))개월 초과")
        }
        let unknown = checks.filter { $0.status == .unknown }
        guard unknown.isEmpty, let best, let payback = best.paybackMonths else {
            return result(.check, unknown.map(\.detail).joined(separator: ", "))
        }
        return result(best.verdict, "\(best.name) 적용 시 회수 약 \(Int(payback.rounded()))개월")
    }

    static func results(for store: StoreProfile) -> (diag: DiagnosisSummary, results: [RobotResult]) {
        let diag = diagnose(store)
        let results = Catalog.robots.filter { $0.process == .fry }.map { evaluate($0, store: store, diag: diag) }
        return (diag, results)
    }

    static func compare(_ results: [RobotResult], size: Int = 2) -> Comparison {
        var groups: [String: [RobotResult]] = [:]
        var order: [String] = []
        for result in results {
            let key = result.robot.supplier ?? result.robot.id
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(result)
        }
        var reps: [RobotResult] = []
        var others: [(result: RobotResult, reason: String)] = []
        for key in order {
            let sorted = groups[key, default: []].sorted(by: ranksBefore)
            guard let rep = sorted.first else { continue }
            reps.append(rep)
            for other in sorted.dropFirst() {
                others.append((other, "\(rep.robot.displayName)와 같은 회사 다른 모델. \(other.reason)"))
            }
        }
        reps.sort(by: ranksBefore)
        for rep in reps.dropFirst(size) {
            others.append((rep, rep.reason))
        }
        others.sort { $0.result.robot.displayName < $1.result.robot.displayName }
        return Comparison(compared: Array(reps.prefix(size)), others: others)
    }

    static func ranked(_ results: [RobotResult]) -> [RobotResult] {
        results.sorted(by: ranksBefore)
    }

    static func breakEvenPerDay(_ sub: SubsidyResult, diag: DiagnosisSummary, replacementRate: Double) -> Int {
        let savingPerItem = Assumptions.handMinutesPerItem * replacementRate * (Assumptions.hourlyLaborKrw / 60)
        return Int(((sub.robotMonthlyKrw + diag.cleaningStaffMonthlyKrw) / (savingPerItem * Assumptions.businessDaysPerMonth)).rounded(.up))
    }

    static func robotAsStaffHours(_ sub: SubsidyResult) -> Double {
        sub.robotMonthlyKrw / Assumptions.hourlyLaborKrw / Assumptions.businessDaysPerMonth
    }

    private static func ranksBefore(_ a: RobotResult, _ b: RobotResult) -> Bool {
        if a.verdict != b.verdict { return a.verdict < b.verdict }
        let unknownA = a.checks.filter { $0.status == .unknown }.count
        let unknownB = b.checks.filter { $0.status == .unknown }.count
        if unknownA != unknownB { return unknownA < unknownB }
        return (a.best?.paybackMonths ?? .infinity) < (b.best?.paybackMonths ?? .infinity)
    }

    private static func checkSpace(_ robot: Robot, _ store: StoreProfile) -> Check {
        guard let size = robot.sizeCm else { return Check(id: .space, status: .unknown, detail: "크기가 공개되지 않음") }
        let marginW = store.fryLineCm.w - size.w
        let marginD = store.fryLineCm.d - size.d
        let sizeText = "\(Format.number(size.w)) × \(Format.number(size.d))cm"
        if marginW < 0 || marginD < 0 {
            return Check(
                id: .space,
                status: .fail,
                detail: "\(sizeText)로 튀김 라인 \(Format.number(store.fryLineCm.w)) × \(Format.number(store.fryLineCm.d))cm보다 큼"
            )
        }
        let fit = marginW < Assumptions.tightMarginCm ? "빠듯" : "넉넉"
        return Check(id: .space, status: .pass, detail: "\(sizeText) · 폭 여유 \(Format.number(marginW))cm '\(fit)' · 깊이 여유 \(Format.number(marginD))cm")
    }

    private static func checkUtility(_ robot: Robot, _ store: StoreProfile) -> Check {
        var missing: [String] = []
        var unknown: [String] = []
        if !store.hasThreePhase {
            if robot.requiresThreePhase == true { missing.append("3상 전원") }
            else if robot.requiresThreePhase == nil { unknown.append("3상 전원 필요 여부") }
        }
        if !store.hasExhaustHood {
            if robot.requiresExhaust == true { missing.append("배기 후드") }
            else if robot.requiresExhaust == nil { unknown.append("배기 필요 여부") }
        }
        if !missing.isEmpty { return Check(id: .utility, status: .fail, detail: "\(missing.joined(separator: ", "))이 필요함") }
        if !unknown.isEmpty { return Check(id: .utility, status: .unknown, detail: "\(unknown.joined(separator: ", "))가 공개되지 않음") }
        return Check(id: .utility, status: .pass, detail: "가게 설비로 설치 가능")
    }

    private static func checkThroughput(_ robot: Robot, _ store: StoreProfile) -> Check {
        guard let throughput = robot.throughputPerHour else {
            return Check(id: .throughput, status: .unknown, detail: "처리량이 공개되지 않음")
        }
        let ratio = throughput / store.peakPerHour
        let detail = "시간당 \(Format.number(throughput))마리 = 피크 \(Format.number(store.peakPerHour))마리의 \(String(format: "%.1f", ratio))배"
        return Check(id: .throughput, status: ratio < Assumptions.minPeakRatio ? .fail : .pass, detail: detail)
    }

    private static func missingCosts(_ robot: Robot) -> [String] {
        var missing: [String] = []
        if robot.installCostKrw == nil { missing.append("설치비") }
        if robot.maintenance == nil { missing.append("유지보수비") }
        if robot.priceIncludesVat == nil { missing.append("부가세") }
        if robot.power == nil { missing.append("전력") }
        return missing
    }

    private static func subsidyResults(_ robot: Robot, store: StoreProfile, diag: DiagnosisSummary, electricity: Double) -> [SubsidyResult] {
        guard let price = robot.purchasePriceKrw else { return [] }
        let priceExVat = robot.priceIncludesVat == true ? price / (1 + Assumptions.vatRate) : price
        let netSaving = diag.removedStaffMonthlyKrw - electricity - diag.cleaningStaffMonthlyKrw
        return Subsidy.all.filter { $0.isEligible(robot, store) }.map { subsidy in
            let selfPay = price - min(priceExVat * subsidy.ratio, subsidy.capKrw)
            let monthly = selfPay / Assumptions.robotCostMonths + electricity
            let payback = netSaving > 0 ? selfPay / netSaving : nil
            return SubsidyResult(
                subsidy: subsidy.id,
                name: subsidy.name,
                capKrw: subsidy.capKrw,
                selfPayKrw: selfPay,
                robotMonthlyKrw: monthly,
                monthlyDiffKrw: diag.removedStaffMonthlyKrw - monthly - diag.cleaningStaffMonthlyKrw,
                paybackMonths: payback,
                firstYearCashKrw: 12 * netSaving - selfPay,
                verdict: economicVerdict(payback)
            )
        }
    }
}
