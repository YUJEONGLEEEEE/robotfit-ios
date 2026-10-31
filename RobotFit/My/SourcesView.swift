import SwiftUI

struct SourcesView: View {
    private struct Entry: Identifiable {
        var id: String { title }
        let title: String
        var tag: String?
        var tagColor: Color = Palette.warn
        var lines: [String]
    }

    private var basisEntries: [Entry] {
        let wage = Format.won(Assumptions.hourlyLaborKrw)
        let gyeongbuk = Subsidy.all.first { $0.id == .gyeongbuk }
        let smart = Subsidy.all.first { $0.id == .smartStore }
        return [
            Entry(title: "최저임금 (2026년 적용)", lines: ["고용노동부 최저임금위원회 고시 · 공공누리 제1유형", "시간당 10,320원, 인건비 단가 기준"]),
            Entry(title: "주휴수당 기준 (근로기준법 제18조제3항)", lines: ["국가법령정보센터 · 공공누리 제1유형", "주 15시간 이상 근무 시 주휴수당 포함 단가 \(wage) 적용"]),
            Entry(title: "2026 스마트상점 기술보급사업 공고", lines: ["중소벤처기업부·소상공인시장진흥공단 · 공공누리 제1유형", "지원율 \(Int((smart?.ratio ?? 0) * 100))%, 한도 \(Format.priceWon(smart?.capKrw ?? 0)), 대상 기술 조건, 2026.3.9 모집공고"]),
            Entry(title: "2026 경북 식품로봇 도입 바우처 공고", lines: ["경북ICT융합산업진흥협회 · 공공기관 공시 자료", "지원율 \(Int((gyeongbuk?.ratio ?? 0) * 100))%, 한도 \(Format.priceWon(gyeongbuk?.capKrw ?? 0)), 국내 제조 요건, 2026.10.16 마감"]),
            Entry(title: "치킨 전문점 종사자 현황", lines: ["통계청 「서비스업 조사」 · 공공누리 제1유형", "사장·가족 종사자 비율 65.6%"]),
            Entry(title: "전기 요금 단가 \(Int(Assumptions.electricityKrwPerKwh))원/kWh", tag: "적용 기준", lines: ["한국전력공사 전기 요금표 참고"]),
            Entry(title: "손작업 시간, 대체율", tag: "추정값", tagColor: Palette.assumed, lines: ["추정값 · 학교급식 튀김 작업 연구 참고", "손작업 1마리 \(Int(Assumptions.handMinutesPerItem))분, 대체율 60%, 세척 \(Int(Assumptions.cleaningMinutesPerDay))분"]),
            Entry(title: "4대보험·퇴직금 계수 1.2", tag: "적용 기준", lines: ["국민연금법·국민건강보험법·고용보험법·산재보험법, 근로자퇴직급여보장법", "사업주 부담 약 11% + 퇴직금 충당 8.3% ≈ 19% · 1.2로 반올림 · 퇴직금은 1년 이상 근속 기준"]),
        ]
    }

    private var robotEntries: [Entry] {
        let detailed = Catalog.robots.filter { $0.sizeCm != nil && $0.purchasePriceKrw != nil }
        var entries = detailed.map { robot -> Entry in
            var spec: [String] = []
            if let size = robot.sizeCm { spec.append("\(Format.number(size.w))×\(Format.number(size.d))cm") }
            if let rate = robot.throughputPerHour { spec.append("시간당 \(Format.number(rate))마리") }
            if let price = robot.purchasePriceKrw { spec.append(Format.priceWon(price)) }
            if robot.installCostKrw == nil && robot.maintenance == nil { spec.append("설치비·유지보수비 미공개") }
            let source = robot.sources?.first { $0.fields.contains("sizeCm") }?.title
                ?? robot.sources?.first?.title
            return Entry(
                title: [robot.productName, robot.supplier].compactMap { $0 }.joined(separator: " · "),
                lines: [source, spec.joined(separator: ", ")].compactMap { $0 }
            )
        }
        let rest = Catalog.robots.filter { !detailed.contains($0) }
        if !rest.isEmpty {
            entries.append(Entry(title: rest.map(\.productName).joined(separator: ", "), lines: ["공개 사양이 부족해 확인 필요로 표시했어요"]))
        }
        return entries
    }

    private let assetEntries = [
        Entry(title: "Pretendard", lines: ["SIL Open Font License 1.1"]),
        Entry(title: "아이콘·로봇 일러스트", lines: ["RobotFit 디자인 시스템 자체 제작"]),
        Entry(title: "주방·메뉴판 예시 이미지", lines: ["민수네 치킨 시연용 일러스트 · 해커톤 데모 전용", "실제 서비스 전환 시 저작권 확인 후 교체가 필요해요"]),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("판정과 계산에 쓴 자료예요. 데이터 최종 확인일은 2026년 10월이에요.")
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.sub)
                    .padding(.horizontal, 4)
                    .padding(.top, 4)

                section("판정·계산 근거 데이터", basisEntries)
                section("로봇 카탈로그", robotEntries)
                Note(text: "최신 사양과 가격은 공급사에 직접 확인해 주세요.")
                section("글꼴·이미지", assetEntries)

                Card {
                    HStack(alignment: .top, spacing: 12) {
                        IconTile(systemName: "info.circle.fill", tint: .blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("신청 전에 공고를 꼭 확인해 주세요")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Palette.ink)
                            Text("지원사업 내용은 해마다 바뀔 수 있어요. 판정과 회수 기간은 입력값과 공개 기준에 따른 추정치이며 결과를 보장하지 않아요.")
                                .font(.system(size: 14))
                                .foregroundStyle(Palette.sub)
                        }
                    }
                }
                .padding(.top, 12)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .screenChrome("출처·라이선스")
    }

    private func section(_ title: String, _ entries: [Entry]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 4)
                .padding(.top, 12)
            Card {
                ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(entry.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Palette.ink)
                            if let tag = entry.tag {
                                Text(tag)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(entry.tagColor)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(entry.tagColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 6))
                            }
                        }
                        ForEach(entry.lines, id: \.self) { line in
                            Text(line)
                                .font(.system(size: 13))
                                .foregroundStyle(Palette.sub)
                        }
                    }
                    .padding(.vertical, 12)
                    if index < entries.count - 1 { Divider() }
                }
            }
        }
    }
}
