import SwiftUI

struct QuoteHistoryView: View {
    @Environment(DiagnosisModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Headline(title: "견적 기록", sub: "확인한 견적이 여기에 모여요.")
                        .padding(.top, 8)

                    if model.quoteRecords.isEmpty {
                        Card {
                            VStack(spacing: 10) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 28))
                                    .foregroundStyle(Palette.faint)
                                Text("아직 확인한 견적이 없어요")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Palette.ink)
                                Text("진단 결과의 로봇 상세에서 견적 비교 보기를 누르면 여기에 남아요.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Palette.sub)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                        }
                    } else {
                        ForEach(model.quoteRecords) { record in
                            Button {
                                open(record)
                            } label: {
                                card(record)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Palette.canvas.ignoresSafeArea())
        }
    }

    private func card(_ record: QuoteRecord) -> some View {
        Card {
            HStack(alignment: .top, spacing: 14) {
                RobotMark(size: 24)
                    .frame(width: 44, height: 44)
                    .background(Palette.action.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(record.robotName)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Palette.ink)
                        if !record.option.isEmpty {
                            SmallTag(text: record.option)
                        }
                    }
                    Text("\(record.supplier) 견적 확인")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.ink)
                    Text(record.date.formatted(.verbatim("\(year: .defaultDigits).\(month: .twoDigits).\(day: .twoDigits)", timeZone: .current, calendar: .current)) + " 확인")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.sub)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Palette.faint)
                    .padding(.top, 12)
            }
            Divider().padding(.vertical, 12)
            LineRow(label: "상태", value: "견적 확인함")
            Divider()
            LineRow(label: "견적 조건", value: record.summary)
        }
    }

    private func open(_ record: QuoteRecord) {
        guard model.result(for: record.robotID) != nil, model.edited.contains(.weekday) else { return }
        model.path = [.compare, .robot(record.robotID), .quote(record.robotID)]
        model.selectedTab = .diagnosis
    }
}
