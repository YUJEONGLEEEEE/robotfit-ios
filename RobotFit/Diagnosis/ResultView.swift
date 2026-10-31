import SwiftUI

struct ResultView: View {
    @Environment(DiagnosisModel.self) private var model

    var body: some View {
        let store = model.store
        let analysis = model.analysis
        let evaluation = model.evaluation
        let diag = evaluation.diag
        let top = Engine.compare(evaluation.results).compared.first
        let hasFry = store.processes.contains(.fry)
        let canSave = diag.removedStaffMonthlyKrw > 0
        let peakRatio = min(1, store.soloLimitPerHour / max(store.peakPerHour, 1))

        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Headline(
                    title: !hasFry ? "로봇이 맡을 튀김 공정이 없어요" : canSave ? "튀김 공정이 병목 1순위예요" : "튀김이 병목이지만 줄일 인건비가 없어요",
                    sub: "사진에서 읽은 정보와 입력값으로 계산했어요. 틀린 부분은 이전 화면에서 고칠 수 있어요."
                )

                Card {
                    HStack(spacing: 8) {
                        IconTile(systemName: "flame.fill")
                        Text("튀김 공정 하루 손작업")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("병목 1순위")
                            .font(.caption.bold())
                            .foregroundStyle(Color(.systemBackground))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.primary, in: Capsule())
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("약").foregroundStyle(.secondary)
                        Text("\(Int(diag.handMinutesPerDay.rounded()))")
                            .font(.system(size: 36, weight: .heavy))
                        Text("분").foregroundStyle(.secondary)
                    }
                    .padding(.top, 12)
                    HStack(spacing: 6) {
                        AssumedTag()
                        Text("손작업 1마리 \(Int(Assumptions.handMinutesPerItem))분 × 하루 평균 \(Int(diag.averageDailySales.rounded()))마리")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)
                    HStack(spacing: 6) {
                        ForEach(analysis.processes, id: \.self) { process in
                            tag(process.label, brand: true)
                        }
                        tag("반죽·포장은 사람 몫", brand: false)
                    }
                    .padding(.top, 12)
                }

                Card {
                    Text(diag.peakOverSolo
                         ? "피크 \(Format.number(store.peakPerHour))마리가 혼자 한계 \(Format.number(store.soloLimitPerHour))마리를 넘어요"
                         : "피크 \(Format.number(store.peakPerHour))마리는 혼자서도 감당할 수 있어요")
                        .font(.headline)
                    bar(label: "금·토 저녁 피크 주문", value: "시간당 \(Format.number(store.peakPerHour))마리", ratio: 1, color: .primary)
                    bar(label: "사장님 혼자 튀길 수 있는 양", value: "시간당 \(Format.number(store.soloLimitPerHour))마리", ratio: peakRatio, color: Color(.systemGray4))
                    if diag.peakOverSolo {
                        HStack(spacing: 6) {
                            AssumedTag()
                            Text("피크 때 시간당 \(Format.number(store.peakPerHour - store.soloLimitPerHour))마리가 밀려요")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 12)
                    }
                }

                DisclosureCard(title: "사진에서 읽은 정보") {
                    LineRow(label: "메뉴", value: analysis.menus.map(\.name).joined(separator: ", "))
                    if let fryers = analysis.fryerCount {
                        LineRow(label: "튀김기", value: "\(fryers)대")
                    }
                    if let hood = analysis.hasExhaustHood {
                        LineRow(label: "배기 후드", value: hood ? "있음" : "안 보임")
                    }
                    ForEach(analysis.notes, id: \.self) { note in
                        Text("· \(note)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 2)
                    }
                    Text(analysis.source == .example ? "민수네 치킨 예시 사진의 저장된 분석 결과예요." : "사진 판독은 참고용이에요. 치수는 직접 잰 값을 써요.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("AI 분석 결과")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            FooterButtons {
                if canSave {
                    PrimaryButton(title: "우리 가게 기준 로봇 비교하기") { model.path.append(.compare) }
                } else {
                    if let baseline = Catalog.baseline {
                        PrimaryButton(title: "도입 비추천 이유 보기") { model.path.append(.notRecommended(baseline.id)) }
                    }
                    PrimaryButton(title: "그래도 로봇 비교 보기", style: .secondary) { model.path.append(.compare) }
                }
                if let top {
                    PrimaryButton(title: "계산 근거 보기", style: .ghost) { model.path.append(.basis(top.robot.id)) }
                }
            }
        }
    }

    private func tag(_ text: String, brand: Bool) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .foregroundStyle(brand ? Color.accentColor : .secondary)
            .background(brand ? Color.accentColor.opacity(0.15) : Color(.systemGray6), in: Capsule())
    }

    private func bar(label: String, value: String, ratio: Double, color: Color) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text(label).foregroundStyle(.secondary)
                Spacer()
                Text(value).bold()
            }
            .font(.footnote)
            GeometryReader { proxy in
                Capsule()
                    .fill(color)
                    .frame(width: proxy.size.width * ratio)
            }
            .frame(height: 16)
        }
        .padding(.top, 16)
    }
}
