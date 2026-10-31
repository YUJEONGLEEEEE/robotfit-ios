import SwiftUI

struct ResultView: View {
    @Environment(DiagnosisModel.self) private var model
    @State private var showsPhotoInfo = false

    var body: some View {
        let store = model.store
        let analysis = model.analysis
        let evaluation = model.evaluation
        let diag = evaluation.diag
        let top = Engine.compare(evaluation.results).compared.first
        let hasFry = store.processes.contains(.fry)
        let canSave = diag.removedStaffMonthlyKrw > 0
        let minutes = Int(diag.handMinutesPerDay.rounded())
        let monthlyHours = Int((diag.handMinutesPerDay * Assumptions.businessDaysPerMonth / 60 / 10).rounded() * 10)
        let workDays = Int(store.sales.weekdayCount + store.sales.busyDayCount)
        let backlog = store.peakPerHour - store.soloLimitPerHour

        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Headline(
                    title: !hasFry ? "로봇이 맡을 튀김 공정이 없어요" : canSave ? "튀김 과정이 가장 오래 걸려요" : "튀김이 오래 걸리지만 줄일 인건비가 없어요",
                    sub: "사진에서 읽은 정보와 입력값으로 계산했어요.\n틀린 부분은 고칠 수 있어요."
                )
                .padding(.top, 8)
                .padding(.bottom, 8)

                Card {
                    HStack(spacing: 10) {
                        Image(systemName: "frying.pan.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Palette.action)
                            .frame(width: 36, height: 36)
                            .background(Palette.action.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                        Text("튀김 과정 하루 작업 시간")
                            .font(.system(size: 15))
                            .foregroundStyle(Palette.sub)
                        Spacer()
                        Text("병목 1순위")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Palette.ink, in: Capsule())
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("약")
                            .font(.system(size: 17))
                        if minutes >= 60 {
                            Text("\(minutes / 60)")
                                .font(.system(size: 44, weight: .heavy))
                            Text("시간")
                                .font(.system(size: 20, weight: .bold))
                        }
                        Text("\(minutes % 60)")
                            .font(.system(size: 44, weight: .heavy))
                        Text("분")
                            .font(.system(size: 20, weight: .bold))
                    }
                    .foregroundStyle(Palette.ink)
                    .padding(.top, 16)
                    Text("한 달이면 약 \(monthlyHours)시간을 튀김기 앞에서 보내고 있어요")
                        .font(.system(size: 15))
                        .foregroundStyle(Palette.ink)
                        .padding(.top, 12)
                    HStack(spacing: 8) {
                        AssumedTag(text: "추정값")
                        Text("1마리 \(Int(Assumptions.handMinutesPerItem))분 × 하루 \(Format.number(diag.averageDailySales))마리 (주 \(workDays)일 기준)")
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.sub)
                    }
                    .padding(.top, 12)
                    HStack(spacing: 8) {
                        ForEach(analysis.processes, id: \.self) { process in
                            chip(process.label)
                        }
                        chip("소스 버무리기")
                    }
                    .padding(.top, 16)
                }

                Card {
                    Text(diag.peakOverSolo ? "금토 바쁠 땐 사장님 혼자 감당하기 벅차요" : "피크 때도 사장님 혼자 감당할 수 있어요")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Palette.ink)
                    bar(label: "금토 저녁 피크 주문", value: "시간당 \(Format.number(store.peakPerHour))마리", ratio: 1, color: Palette.ink)
                        .padding(.top, 20)
                    bar(
                        label: "사장님 혼자 튀길 수 있는 양",
                        value: "시간당 \(Format.number(store.soloLimitPerHour))마리",
                        ratio: min(1, store.soloLimitPerHour / max(store.peakPerHour, 1)),
                        color: Palette.disabled
                    )
                    .padding(.top, 20)
                    if diag.peakOverSolo {
                        HStack(spacing: 8) {
                            AssumedTag(text: "추정값")
                            Text("피크 때 시간당 \(Format.number(backlog))마리가 밀려요")
                                .font(.system(size: 13))
                                .foregroundStyle(Palette.sub)
                        }
                        .padding(.top, 16)
                    }
                }

                Card {
                    Button {
                        withAnimation(.snappy) { showsPhotoInfo.toggle() }
                    } label: {
                        HStack {
                            Text("사진에서 읽은 정보")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(Palette.ink)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundStyle(Palette.faint)
                                .rotationEffect(.degrees(showsPhotoInfo ? 180 : 0))
                        }
                    }
                    .buttonStyle(.plain)
                    if showsPhotoInfo {
                        VStack(alignment: .leading, spacing: 0) {
                            LineRow(label: "메뉴", value: analysis.menus.map(\.name).joined(separator: ", "))
                            if let fryers = analysis.fryerCount {
                                LineRow(label: "튀김기", value: "\(fryers)대")
                            }
                            if let hood = analysis.hasExhaustHood {
                                LineRow(label: "배기 후드", value: hood ? "있음" : "안 보임")
                            }
                            ForEach(analysis.notes, id: \.self) { note in
                                Text("· \(note)")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Palette.sub)
                                    .padding(.vertical, 2)
                            }
                            Text(analysis.source == .example ? "민수네 치킨 예시 사진의 저장된 분석 결과예요." : "사진 판독은 참고용이에요. 치수는 직접 잰 값을 써요.")
                                .font(.system(size: 12))
                                .foregroundStyle(Palette.faint)
                                .padding(.top, 8)
                        }
                        .padding(.top, 12)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .screenChrome("AI 분석 결과")
        .safeAreaInset(edge: .bottom) {
            FooterButtons {
                if canSave {
                    PrimaryButton(title: "우리 주방에 로봇 놓아보기") { model.path.append(.compare) }
                } else if let baseline = Catalog.baseline {
                    PrimaryButton(title: "도입 비추천 이유 보기") { model.path.append(.notRecommended(baseline.id)) }
                }
                if let top {
                    Button("계산 근거 보기") { model.path.append(.basis(top.robot.id)) }
                        .font(.system(size: 15))
                        .foregroundStyle(Palette.sub)
                        .frame(minHeight: 36)
                }
            }
        }
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Palette.canvas, in: Capsule())
    }

    private func bar(label: String, value: String, ratio: Double, color: Color) -> some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.sub)
                Spacer()
                Text(value)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Palette.ink)
            }
            GeometryReader { proxy in
                Capsule()
                    .fill(color)
                    .frame(width: proxy.size.width * ratio)
            }
            .frame(height: 24)
        }
    }
}
