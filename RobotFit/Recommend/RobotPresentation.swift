import Foundation

struct RobotPresentation {
    let result: RobotResult
    let rank: Int
    let store: StoreProfile
    let kitchen: Kitchen
    let kitchenKnown: Bool
    let diag: DiagnosisSummary

    var robot: Robot { result.robot }
    var maker: String { robot.supplier ?? "공급사 미공개" }
    var isTop: Bool { rank == 0 }
    var steps: [String] { robot.robotTasks }

    var monthlyValue: String {
        guard let best = result.best else { return robot.rental.map { "렌탈 월 \(Format.priceWon($0.monthlyKrw))" } ?? "가격 미공개" }
        return "월 \(Format.priceWon(best.robotMonthlyKrw))"
    }

    var priceLine: String {
        guard let price = robot.purchasePriceKrw else { return "구입가 미공개" }
        return "총 \(Format.priceWon(price))"
    }

    var capacityChip: String {
        robot.throughputPerHour.map { "시간당 \(Format.number($0))마리" } ?? "처리량 미공개"
    }

    var subsidyNote: String? {
        guard let best = result.best, best.subsidy != .none else { return nil }
        return "\(best.subsidy.short) 기준"
    }

    var laborText: String { "월 \(Format.manWon(diag.removedStaffMonthlyKrw))" }

    var marginW: Double? { robot.sizeCm.map { store.fryLineCm.w - $0.w } }
    var marginD: Double? { robot.sizeCm.map { ((store.fryLineCm.d - $0.d) * 10).rounded() / 10 } }
    var frontWidth: Double? {
        guard kitchenKnown else { return nil }
        return robot.sizeCm.map { ((min(kitchen.widthM, kitchen.depthM) * 100 - $0.d) * 10).rounded() / 10 }
    }

    var fitShort: String {
        guard let w = marginW else { return "현장 확인 필요" }
        return w >= 0 ? "가로 \(Format.number(w))cm 여유" : "가로 \(Format.number(-w))cm 넘쳐요"
    }

    var fitLong: String {
        guard let w = marginW, let d = marginD else { return "크기 미공개, 현장 확인 필요" }
        if w >= 0 && d >= 0 { return "가로 \(Format.number(w))cm, 깊이 \(Format.number(d))cm 여유" }
        return w < 0 ? "가로 \(Format.number(-w))cm 넘쳐요" : "깊이 \(Format.number(-d))cm 넘쳐요"
    }

    var fitLine: String {
        guard let w = marginW, let d = marginD else { return "크기가 공개되지 않아 현장 확인이 필요해요" }
        return w >= 0 && d >= 0 ? "설치 자리에 들어가요" : "설치 자리를 넘쳐요"
    }

    var points: [String] {
        var lines: [String] = []
        if let throughput = robot.throughputPerHour {
            let ratio = throughput / max(store.peakPerHour, 1)
            lines.append(ratio >= 1
                ? "피크 1시간 \(Format.number(store.peakPerHour))마리를 \(ratio >= 2 ? "여유 있게 " : "")튀겨요"
                : "피크 1시간 \(Format.number(store.peakPerHour))마리 중 \(Format.number(store.peakPerHour - throughput))마리가 밀려요")
        } else {
            lines.append("처리량이 공개되지 않았어요")
        }
        if robot.purchasePriceKrw == nil {
            lines.append("구입가가 공개되지 않았어요")
        } else if let install = robot.installCostKrw, let care = robot.maintenance {
            lines.append("설치비 \(Format.priceWon(install)), \(care.freeMonths)개월 무상 유지보수")
        } else {
            lines.append("설치비와 유지보수비는 미공개")
        }
        return lines
    }

    var headline: String {
        switch result.verdict {
        case .notRecommended: return result.reason
        case .check: return "\(result.reason)라 도입 전 확인이 필요해요"
        default:
            guard let best = result.best else { return result.verdict.label }
            let when = best.subsidy == .none ? "지원 없이도" : "\(best.subsidy.short)에 선정되면"
            return "\(when) 투자 회수 기간은 \(Format.aboutMonths(best.paybackMonths))이에요"
        }
    }

    var detailBadge: String {
        isTop ? "사장님 가게에 가장 잘 맞아요" : "추천 \(rank + 1)위"
    }

    var sizeText: String {
        robot.sizeCm.map { "\(Format.number($0.w))×\(Format.number($0.d))×\(Format.number($0.h))cm" } ?? "크기 미공개"
    }

    var installFeeText: String { robot.installCostKrw.map(Format.priceWon) ?? "미공개" }
    var careText: String { robot.maintenance.map { $0.monthlyKrw == 0 ? "\($0.freeMonths)개월 무상" : "월 \(Format.priceWon($0.monthlyKrw))" } ?? "미공개" }
    var paybackText: String { result.best.map { Format.aboutMonths($0.paybackMonths) } ?? "계산 불가" }

    var placed: PlacedRobot? {
        robot.sizeCm.map { PlacedRobot(widthCm: $0.w, depthCm: $0.d, heightCm: $0.h, isPrimary: true) }
    }

    static func all(model: DiagnosisModel) -> [RobotPresentation] {
        let evaluation = model.evaluation
        return Engine.ranked(evaluation.results).enumerated().map { index, result in
            RobotPresentation(result: result, rank: index, store: model.store, kitchen: model.kitchen, kitchenKnown: model.kitchenKnown, diag: evaluation.diag)
        }
    }
}
