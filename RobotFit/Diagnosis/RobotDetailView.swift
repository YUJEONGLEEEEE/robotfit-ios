import SwiftUI

struct RobotDetailView: View {
    @Environment(DiagnosisModel.self) private var model
    let robotID: String

    var body: some View {
        if let result = model.result(for: robotID) {
            content(result)
        } else {
            ContentUnavailableView("로봇 정보를 찾을 수 없어요", systemImage: "questionmark.circle")
        }
    }

    private func content(_ result: RobotResult) -> some View {
        let diag = model.evaluation.diag
        let robot = result.robot

        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    VerdictBadge(verdict: result.verdict, text: result.badgeText, large: true)
                    Text(heroTitle(result))
                        .font(.title3.bold())
                        .padding(.top, 16)
                    VStack(alignment: .leading, spacing: 4) {
                        if let best = result.best, best.subsidy != .none {
                            Text("지원사업 적용 시 예상치예요 (다음 공고 기준).")
                        }
                        if result.costIsMinimum {
                            Text("공개된 비용만으로 계산해 실제 회수 기간은 더 길 수 있어요.")
                        }
                        if let range = paybackRange(result) {
                            HStack(spacing: 6) {
                                AssumedTag()
                                Text(range)
                            }
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 12)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Palette.verdict(result.verdict), lineWidth: 2))

                if !result.subsidies.isEmpty {
                    Card {
                        Text("구매 방법별 투자 회수 기간").font(.headline)
                        ForEach(result.subsidies) { sub in
                            let shownVerdict: Verdict = result.costIsMinimum && sub.verdict != .notRecommended ? .check : sub.verdict
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(sub.name).font(.footnote).foregroundStyle(.secondary)
                                    Text(Format.aboutMonths(sub.paybackMonths) + (result.costIsMinimum && sub.paybackMonths != nil ? " 이상" : ""))
                                        .font(.headline)
                                }
                                Spacer()
                                VerdictBadge(verdict: shownVerdict, text: shownVerdict.label)
                            }
                            .padding(.vertical, 10)
                        }
                    }
                }

                if let best = result.best, best.paybackMonths != nil {
                    DisclosureCard(title: "본전 마릿수", assumed: true) {
                        Text("하루 이만큼 팔면 로봇 월 비용(\(best.subsidy.short) 기준)을 아낀 손작업으로 메워요. 지금 하루 평균은 \(Int(diag.averageDailySales.rounded()))마리예요.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 4)
                        ForEach(Assumptions.replacementRates.reversed(), id: \.self) { rate in
                            LineRow(
                                label: "로봇이 손작업의 \(Int(rate * 100))%를 대신하면",
                                value: "하루 \(Engine.breakEvenPerDay(best, diag: diag, replacementRate: rate))마리",
                                strong: rate == 0.6
                            )
                        }
                    }
                }

                Card {
                    HStack(spacing: 8) {
                        IconTile(systemName: "clock", tint: Palette.warn)
                        Text("로봇 도입 시 바뀌는 시간").font(.headline)
                    }
                    .padding(.bottom, 4)
                    LineRow(label: "튀김 손작업", value: "하루 \(Int(diag.handMinutesPerDay.rounded()))분 → \(Int(diag.handMinutesWithRobot.rounded()))분")
                    LineRow(label: "로봇 세척 추가", value: "하루 +\(Int(Assumptions.cleaningMinutesPerDay))분")
                    LineRow(label: "하루 순 절약", value: "약 \(Int(diag.netMinutesSaved.rounded()))분", strong: true)
                    HStack(spacing: 6) {
                        AssumedTag()
                        Text("로봇: \(robot.robotTasks.isEmpty ? "공개 자료 없음" : robot.robotTasks.joined(separator: "·")) / 사람: \(robot.humanTasks.isEmpty ? "공개 자료 없음" : robot.humanTasks.joined(separator: "·"))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Card(padding: 8) {
                    link("실제 크기로 보기", icon: "ruler", tint: .accentColor) { model.path.append(.size) }
                    Divider()
                    link("계산 근거 보기", icon: "doc.text", tint: Palette.good) { model.path.append(.basis(robotID)) }
                    Divider()
                    link("비추천되는 경우 보기", icon: "exclamationmark.triangle", tint: Palette.bad) { model.path.append(.notRecommended(robotID)) }
                }
                Note(text: "판정 기준은 공급기업 이용료와 무관해요.")
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(robot.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            FooterButtons {
                PrimaryButton(title: "판매처 조건 비교 보기") { model.path.append(.quote(robotID)) }
            }
        }
    }

    private func heroTitle(_ result: RobotResult) -> String {
        switch result.verdict {
        case .notRecommended: return result.reason
        case .check: return "\(result.reason)라 도입 전 확인이 필요해요"
        default:
            guard let best = result.best else { return result.verdict.label }
            let when = best.subsidy == .none ? "지원 없이도" : "\(best.subsidy.short)에 선정되면"
            return "\(when) 투자 회수 기간은 \(Format.aboutMonths(best.paybackMonths))이에요"
        }
    }

    private func paybackRange(_ result: RobotResult) -> String? {
        let store = model.store
        guard let best = result.best, store.reducedStaffHoursPerDay > 0 else { return nil }
        func months(_ hours: Double) -> Double? {
            var changed = store
            changed.reducedStaffHoursPerDay = hours
            return Engine.evaluate(result.robot, store: changed).subsidies.first { $0.subsidy == best.subsidy }?.paybackMonths
        }
        let lo = max(1, store.reducedStaffHoursPerDay - 1)
        let hi = store.reducedStaffHoursPerDay + 1
        guard let loMonths = months(lo), let hiMonths = months(hi) else { return nil }
        return "줄어드는 근무가 하루 \(Format.number(lo))~\(Format.number(hi))시간이면 \(Int(loMonths.rounded()))~\(Int(hiMonths.rounded()))개월"
    }

    private func link(_ title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                IconTile(systemName: icon, tint: tint)
                Text(title).foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .padding(12)
        }
    }
}
