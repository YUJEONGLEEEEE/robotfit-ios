import SwiftUI

struct NotRecommendedView: View {
    @Environment(DiagnosisModel.self) private var model
    let robotID: String

    var body: some View {
        if let robot = model.result(for: robotID)?.robot {
            content(robot)
        } else {
            ContentUnavailableView("로봇 정보를 찾을 수 없어요", systemImage: "questionmark.circle")
        }
    }

    private func content(_ robot: Robot) -> some View {
        let store = model.store
        let actual = store.reducedStaffHoursPerDay == 0
        var aloneStore = store
        aloneStore.reducedStaffHoursPerDay = 0
        let alone = Engine.evaluate(robot, store: aloneStore)
        let none = alone.subsidies.first { $0.subsidy == .none }
        let gyeongbuk = alone.subsidies.first { $0.subsidy == .gyeongbuk }

        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if !actual {
                    HStack(alignment: .top, spacing: 8) {
                        Text("예시")
                            .font(.caption2.bold())
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                        Text("저녁 알바 없이 사장님 혼자 운영한다면 \(robot.displayName)의 판정이 어떻게 바뀌는지 보여 드려요.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 16))
                }

                VStack(alignment: .leading, spacing: 0) {
                    VerdictBadge(verdict: .notRecommended, text: "도입 비추천", large: true)
                    Text("줄일 인건비가 없어\n투자비가 돌아오지 않아요")
                        .font(.title3.bold())
                        .padding(.top, 16)
                    Text(actual ? "\(store.name), 입력한 가게 정보 기준" : "\(robot.displayName), 혼자 운영하는 경우")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Palette.bad, lineWidth: 2))

                Card {
                    VStack(alignment: .leading, spacing: 16) {
                        reason("person.fill", "저녁 알바 없이 혼자 운영한다면", "로봇이 대신할 유급 근무가 없어 판정이 바뀌어요.")
                        reason("exclamationmark.triangle", "줄어드는 인건비 0원", "매달 아끼는 돈이 0원 이하라 회수 기간 공식의 분모가 사라져요.")
                        VStack(alignment: .leading, spacing: 6) {
                            reason(
                                "exclamationmark.triangle",
                                "어떤 지원사업으로도 회수 불가",
                                (none.map { "지원 없이는 로봇 월 비용이 약 \(Format.manWon($0.robotMonthlyKrw))이에요. " } ?? "")
                                    + (gyeongbuk.map { "경북 바우처로 자부담을 \(Format.priceWon($0.selfPayKrw))까지 줄여도 회수 기간을 계산할 수 없어요." } ?? "")
                            )
                            if let price = robot.purchasePriceKrw {
                                HStack(spacing: 6) {
                                    AssumedTag()
                                    Text("구입가 \(Format.priceWon(price))" + (alone.electricityMonthlyKrw.map { ", 전기료 월 \(Format.manWon($0))" } ?? ""))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.leading, 48)
                            }
                        }
                    }
                }

                Card {
                    reason("info.circle", "이럴 때 다시 진단해 보세요", "저녁 알바를 다시 쓰게 되거나, 피크 주문이 혼자 한계(시간당 \(Format.number(store.soloLimitPerHour))마리)를 자주 넘으면 결과가 달라져요.", tint: Palette.good)
                }

                Card {
                    Text("지금 먼저 해 볼 방법").font(.headline)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            IconTile(systemName: "storefront", tint: Palette.good)
                            Text("배달앱 수수료 구간과 광고비를 먼저 점검해 보세요")
                        }
                        if store.region == .gyeongbuk {
                            HStack(spacing: 12) {
                                IconTile(systemName: "mappin.and.ellipse")
                                Text("포항 식품로봇 연구지원센터에서 튀김로봇을 직접 체험할 수 있어요")
                            }
                        }
                    }
                    .font(.subheadline)
                    .padding(.top, 12)
                }
                Note(text: "시연용 예시 데이터예요. 실제 가게 상황과 다를 수 있어요.")
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("도입 비추천 근거")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            FooterButtons {
                PrimaryButton(title: "가게 정보 바꿔서 다시 진단하기") { model.rediagnose() }
                if !actual {
                    PrimaryButton(title: "\(robot.displayName) 상세로 돌아가기", style: .secondary) {
                        if !model.path.isEmpty { model.path.removeLast() }
                    }
                }
            }
        }
    }

    private func reason(_ icon: String, _ title: String, _ detail: String, tint: Color = Palette.bad) -> some View {
        HStack(alignment: .top, spacing: 12) {
            IconTile(systemName: icon, tint: tint)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.bold())
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}
