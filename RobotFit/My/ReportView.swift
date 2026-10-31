import SwiftUI

struct ReportView: View {
    @Environment(DiagnosisModel.self) private var model

    private struct Bar: Identifiable {
        var id: String { label }
        let label: String
        let value: Double
        let text: String
        let isAfter: Bool
    }

    var body: some View {
        let usesDiagnosis = model.isReady
        let store = usesDiagnosis ? model.store : .minsu
        let evaluation = Engine.results(for: store)
        let diag = evaluation.diag
        let robot = Engine.compare(evaluation.results).compared.first?.robot ?? Catalog.baseline
        let robotRate = robot?.throughputPerHour ?? store.soloLimitPerHour

        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    SmallTag(text: usesDiagnosis ? "예상" : "샘플")
                    Text(usesDiagnosis
                         ? "\(store.name) 진단값으로 계산한 예상 데이터예요. 실제로 도입하면 매달 실제 기록이 쌓여요."
                         : "민수네 치킨 시나리오로 만든 가상 데이터예요. 실제로 도입하면 매달 실제 기록이 쌓여요.")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.sub)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text([store.name, robot?.displayName, "도입 후 2개월"].compactMap { $0 }.joined(separator: " · "))
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.sub)
                    Text("도입 후 이렇게 달라졌어요")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Palette.ink)
                }
                .padding(.horizontal, 4)
                .padding(.top, 12)

                Card(padding: 20) {
                    HStack(spacing: 8) {
                        summary("줄어든 인건비", "월 \(Format.manWon(diag.removedStaffMonthlyKrw))")
                        summary("하루 순 절약", "약 \(duration(diag.netMinutesSaved))")
                    }
                }

                HStack(spacing: 16) {
                    legend("도입 전", color: Self.before)
                    legend("도입 후", color: Palette.action)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 8)

                chart(
                    "알바 인건비",
                    caption: "월 기준",
                    before: diag.removedStaffMonthlyKrw,
                    after: 0,
                    format: { $0 == 0 ? "0원" : Format.manWon($0) }
                )
                chart(
                    "튀김기 앞 손작업 시간",
                    caption: "하루 기준 · 로봇 세척 \(Int(Assumptions.cleaningMinutesPerDay))분은 별도예요",
                    before: diag.handMinutesPerDay,
                    after: diag.handMinutesWithRobot,
                    format: duration
                )
                chart(
                    "저녁에 튀길 수 있는 양",
                    caption: "시간당 · 도입 후는 로봇 최대 처리량",
                    before: store.soloLimitPerHour,
                    after: robotRate,
                    format: { "\(Format.number($0))마리" }
                )

                NavigationLink {
                    SourcesView()
                } label: {
                    Text("출처·라이선스 보기")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.sub)
                        .underline()
                        .padding(.horizontal, 4)
                        .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .screenChrome("성과 리포트")
    }

    private static let before = Color(white: 0.8)

    private func summary(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Palette.sub)
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Palette.ink)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Palette.canvas, in: RoundedRectangle(cornerRadius: 14))
    }

    private func legend(_ text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 12, height: 12)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Palette.sub)
        }
    }

    private func chart(_ title: String, caption: String, before: Double, after: Double, format: @escaping (Double) -> String) -> some View {
        let bars = [
            Bar(label: "도입 전", value: before, text: format(before), isAfter: false),
            Bar(label: "1개월 차", value: after, text: format(after), isAfter: true),
            Bar(label: "2개월 차", value: after, text: format(after), isAfter: true),
        ]
        let top = max(bars.map(\.value).max() ?? 0, 1)

        return Card {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Palette.ink)
            Text(caption)
                .font(.system(size: 13))
                .foregroundStyle(Palette.sub)
                .padding(.top, 16)
            HStack(alignment: .bottom, spacing: 16) {
                ForEach(bars) { bar in
                    VStack(spacing: 4) {
                        Text(bar.text)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(bar.isAfter ? Palette.action : Self.before)
                            .frame(width: 40, height: max(2, 100 * bar.value / top))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 148, alignment: .bottom)
            .padding(.top, 16)
            Divider()
            HStack(spacing: 16) {
                ForEach(bars) { bar in
                    Text(bar.label)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.sub)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 8)
        }
    }

    private func duration(_ minutes: Double) -> String {
        let total = max(0, Int(minutes.rounded()))
        let hours = total / 60
        let rest = total % 60
        if hours == 0 { return "\(rest)분" }
        return rest == 0 ? "\(hours)시간" : "\(hours)시간 \(rest)분"
    }
}
