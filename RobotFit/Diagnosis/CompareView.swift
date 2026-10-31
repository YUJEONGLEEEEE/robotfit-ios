import SwiftUI

struct CompareView: View {
    @Environment(DiagnosisModel.self) private var model

    var body: some View {
        let results = model.evaluation.results
        let comparison = Engine.compare(results)

        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Headline(
                    title: "튀김로봇 \(results.count)종을 우리 가게 기준으로 확인했어요",
                    sub: "공급사마다 대표 모델 1대를 골라, 맞는 순서대로 2대를 나란히 보여 드려요."
                )
                ForEach(comparison.compared) { result in
                    RobotCard(result: result)
                }
                if !comparison.others.isEmpty {
                    DisclosureCard(title: "다른 후보 \(comparison.others.count)개") {
                        ForEach(comparison.others, id: \.result.id) { other in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(other.result.robot.displayName).bold()
                                    Spacer()
                                    VerdictBadge(verdict: other.result.verdict, text: other.result.badgeText)
                                }
                                Text(other.reason)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 8)
                            Divider()
                        }
                    }
                }
                Note(text: "판정은 공급기업 이용료와 무관해요. 카탈로그는 공개 자료로 만든 샘플 데이터예요.")
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("로봇 비교")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct RobotCard: View {
    @Environment(DiagnosisModel.self) private var model
    let result: RobotResult

    var body: some View {
        let robot = result.robot
        let store = model.store
        let marginW = robot.sizeCm.map { store.fryLineCm.w - $0.w }

        Card {
            HStack {
                Text(robot.displayName)
                    .font(.title3.bold())
                Spacer()
                VerdictBadge(verdict: result.verdict, text: result.badgeText)
            }
            .padding(.bottom, 4)
            keyValue(
                "들어가나",
                robot.sizeCm.map { "\(Format.number($0.w))×\(Format.number($0.d))cm" } ?? "크기 미공개",
                marginW.map { $0 >= 0 ? "폭 여유 \(Format.cm($0))" : "튀김 라인보다 커요" } ?? result.check(.space)?.detail
            )
            keyValue(
                "생산능력",
                robot.throughputPerHour.map { "시간당 \(Format.number($0))마리" } ?? "처리량 미공개",
                robot.throughputPerHour.map { "피크 \(Format.number(store.peakPerHour))마리의 \(String(format: "%.1f", $0 / store.peakPerHour))배" }
            )
            let cost = costLine(robot)
            keyValue("비용 공개", cost.value, cost.sub)
            keyValue("회수 기간", paybackValue, paybackSub)
            if result.verdict == .notRecommended {
                Text(result.reason)
                    .font(.footnote)
                    .foregroundStyle(Palette.bad)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.bad.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.top, 8)
            }
            HStack(spacing: 8) {
                small("실제 크기 보기") { model.path.append(.size) }
                small("자세히 보기") { model.path.append(.detail(robot.id)) }
            }
            .padding(.top, 16)
        }
    }

    private var paybackValue: String {
        guard let best = result.best else { return "계산 불가" }
        return Format.aboutMonths(best.paybackMonths) + (result.costIsMinimum && best.paybackMonths != nil ? " 이상" : "")
    }

    private var paybackSub: String {
        guard let best = result.best else { return "가격이 공개되지 않았어요" }
        return result.costIsMinimum ? "\(best.subsidy.short) 기준 · 공개 비용만으로 계산한 최소값" : "\(best.subsidy.short) 기준"
    }

    private func costLine(_ robot: Robot) -> (value: String, sub: String) {
        guard let price = robot.purchasePriceKrw else {
            return ("구입가 미공개", robot.rental.map { "렌탈 월 \(Format.priceWon($0.monthlyKrw))" } ?? "가격 정보 없음")
        }
        var missing: [String] = []
        if robot.installCostKrw == nil { missing.append("설치비") }
        if robot.maintenance == nil { missing.append("유지보수비") }
        let sub = missing.isEmpty
            ? "설치비 \(Format.priceWon(robot.installCostKrw ?? 0)) · 무상 A/S \(robot.maintenance?.freeMonths ?? 0)개월"
            : "\(missing.joined(separator: "·")) 미공개"
        return (Format.priceWon(price), sub)
    }

    private func keyValue(_ label: String, _ value: String, _ sub: String?) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.subheadline.bold())
                if let sub {
                    Text(sub).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private func small(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
