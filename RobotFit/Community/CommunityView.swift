import SwiftUI

struct CommunityView: View {
    @Environment(CommunityStore.self) private var store
    @Environment(AuthStore.self) private var auth
    @State private var isComposing = false

    var body: some View {
        NavigationStack {
            List {
                if let message = store.message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(Color.accentColor)
                }

                let summaries = Catalog.robots.compactMap { robot in
                    store.averagePayback(for: robot.displayName).map { (robot.displayName, $0) }
                }
                if !summaries.isEmpty {
                    Section("도입한 사장님들의 실제 회수 기간") {
                        ForEach(summaries, id: \.0) { name, summary in
                            HStack {
                                Text(name)
                                Spacer()
                                Text(String(format: "평균 %.0f개월", summary.months))
                                    .bold()
                                Text("· \(summary.count)곳")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("도입 후기") {
                    if store.reviews.isEmpty {
                        Text(store.isLoading ? "후기를 불러오는 중이에요" : "아직 후기가 없어요. 첫 후기를 남겨 주세요.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(store.reviews) { review in
                        ReviewRow(review: review)
                            .swipeActions {
                                if review.authorID == auth.userID {
                                    Button("삭제", role: .destructive) {
                                        Task { await store.delete(review) }
                                    }
                                }
                            }
                    }
                }
            }
            .navigationTitle("커뮤니티")
            .toolbar {
                Button {
                    isComposing = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
            }
            .refreshable { await store.refresh() }
            .task { await store.refresh() }
            .sheet(isPresented: $isComposing) {
                ComposeReviewView()
            }
        }
    }
}

struct ReviewRow: View {
    let review: Review

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(review.robotName)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.15), in: Capsule())
                Spacer()
                Text(String(repeating: "★", count: review.rating) + String(repeating: "☆", count: 5 - review.rating))
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
            }
            Text("\(review.storeType) · 실제 회수 \(review.paybackMonths)개월")
                .font(.subheadline.bold())
            Text(review.body)
                .font(.body)
            Text("\(review.authorName) · \(review.createdAt.formatted(.relative(presentation: .named)))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
