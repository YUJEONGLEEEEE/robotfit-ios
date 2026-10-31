import SwiftUI

struct ComposeReviewView: View {
    @Environment(CommunityStore.self) private var store
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var draft = ReviewDraft()
    @State private var isPosting = false

    var body: some View {
        NavigationStack {
            Form {
                Section("도입한 로봇") {
                    Picker("로봇", selection: $draft.robotName) {
                        ForEach(Catalog.robots) { robot in
                            Text(robot.displayName).tag(robot.displayName)
                        }
                    }
                    TextField("업종 (예: 치킨집)", text: $draft.storeType)
                }

                Section("도입 결과") {
                    Stepper("실제 회수 기간 \(draft.paybackMonths)개월", value: $draft.paybackMonths, in: 1...60)
                    Picker("만족도", selection: $draft.rating) {
                        ForEach(1...5, id: \.self) { score in
                            Text(String(repeating: "★", count: score)).tag(score)
                        }
                    }
                }

                Section("한 줄 후기") {
                    TextField("좋았던 점, 아쉬운 점을 적어 주세요", text: $draft.body, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let message = store.message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
            .navigationTitle("후기 쓰기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isPosting ? "올리는 중…" : "올리기") {
                        Task { await submit() }
                    }
                    .disabled(!draft.isValid || isPosting)
                }
            }
        }
    }

    private func submit() async {
        guard let userID = auth.userID else { return }
        isPosting = true
        let posted = await store.post(draft, authorName: auth.displayName, authorID: userID)
        isPosting = false
        if posted {
            dismiss()
        }
    }
}
