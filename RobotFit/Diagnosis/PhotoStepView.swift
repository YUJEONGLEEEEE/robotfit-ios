import PhotosUI
import SwiftUI

struct PhotoStepView: View {
    enum Step {
        case kitchen
        case menu
    }

    @Environment(DiagnosisModel.self) private var model
    let step: Step

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isShowingCamera = false

    private var photos: [DiagnosisPhoto] {
        step == .kitchen ? model.kitchenPhotos : model.menuPhotos
    }

    private func setPhotos(_ photos: [DiagnosisPhoto]) {
        let limited = Array(photos.prefix(DiagnosisModel.maxPhotos))
        if step == .kitchen { model.kitchenPhotos = limited } else { model.menuPhotos = limited }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Steps(current: step == .kitchen ? 1 : 2)
                Headline(
                    title: step == .kitchen ? "주방 사진을 올려주세요" : "메뉴판 사진을 올려주세요",
                    sub: "1장은 꼭 필요하고, 최대 \(DiagnosisModel.maxPhotos)장까지 올릴 수 있어요."
                )
                picker
                tips
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("우리 가게 진단")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            FooterButtons {
                PrimaryButton(title: "다음") {
                    model.path.append(step == .kitchen ? .menuPhotos : .storeInfo)
                }
                .disabled(photos.isEmpty)
                .opacity(photos.isEmpty ? 0.4 : 1)
            }
        }
        .onChange(of: pickerItems) { _, items in
            Task { await load(items) }
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraPicker { image in
                setPhotos(photos + [DiagnosisPhoto(image: image, sampleName: nil)])
            }
            .ignoresSafeArea()
        }
    }

    private var picker: some View {
        Card {
            HStack {
                Text("대표 사진")
                    .font(.headline)
                Spacer()
                Text("필수")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 12)

            if photos.isEmpty {
                Button {
                    setPhotos([step == .kitchen ? .kitchenExample : .menuExample])
                } label: {
                    ZStack(alignment: .topLeading) {
                        Image(step == .kitchen ? "SampleKitchen" : "SampleMenu")
                            .resizable()
                            .scaledToFill()
                            .frame(height: 220)
                            .clipped()
                            .opacity(0.6)
                        exampleTag.padding(12)
                        Text("민수네 치킨 예시 사진 쓰기")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.black, in: Capsule())
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                            .padding(.bottom, 12)
                    }
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(photos) { photo in
                        thumbnail(photo)
                    }
                }
            }

            HStack(spacing: 8) {
                PhotosPicker(
                    selection: $pickerItems,
                    maxSelectionCount: max(1, DiagnosisModel.maxPhotos - photos.count),
                    matching: .images
                ) {
                    Label("앨범에서 선택", systemImage: "photo")
                        .smallButtonStyle()
                }
                Button {
                    isShowingCamera = true
                } label: {
                    Label("바로 촬영", systemImage: "camera")
                        .smallButtonStyle()
                }
                .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
            }
            .padding(.top, 12)
        }
    }

    private func thumbnail(_ photo: DiagnosisPhoto) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image = photo.image {
                    Image(uiImage: image).resizable()
                } else if let name = photo.sampleName {
                    Image(name).resizable()
                }
            }
            .scaledToFill()
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(alignment: .topLeading) {
                if photo.isExample { exampleTag.padding(8) }
            }
            Button {
                setPhotos(photos.filter { $0.id != photo.id })
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(.black.opacity(0.6), in: Circle())
            }
            .padding(8)
            .accessibilityLabel("사진 빼기")
        }
    }

    private var exampleTag: some View {
        Text("예시")
            .font(.caption2.bold())
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
    }

    private var tips: some View {
        Card {
            Text("이렇게 찍어 주세요")
                .font(.headline)
                .padding(.bottom, 12)
            VStack(alignment: .leading, spacing: 12) {
                ForEach(tipItems, id: \.text) { tip in
                    HStack(spacing: 12) {
                        IconTile(systemName: tip.icon, tint: tip.tint)
                        Text(tip.text)
                            .font(.subheadline)
                    }
                }
            }
        }
    }

    private var tipItems: [(icon: String, tint: Color, text: String)] {
        switch step {
        case .kitchen:
            [
                ("photo", .accentColor, "입구에서 주방 전체가 보이게 찍어주세요"),
                ("flame", Palette.warn, "튀김기·후드가 화면에 들어오게 해주세요"),
                ("sun.max", Palette.good, "너무 가깝거나 어두운 사진은 피해주세요"),
            ]
        case .menu:
            [
                ("doc.text", Palette.good, "메뉴 이름이 다 보이게 찍어주세요"),
                ("iphone", .accentColor, "배달앱 메뉴 화면 캡처도 괜찮아요"),
                ("sun.max", Palette.warn, "글자가 흐리거나 반사되지 않게 해주세요"),
            ]
        }
    }

    private func load(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        var added: [DiagnosisPhoto] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                added.append(DiagnosisPhoto(image: image, sampleName: nil))
            }
        }
        setPhotos(photos.filter { !$0.isExample } + added)
        pickerItems = []
    }
}

private extension View {
    func smallButtonStyle() -> some View {
        font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    let onPick: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onPick(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
