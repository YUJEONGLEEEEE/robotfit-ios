import AVFoundation
import PhotosUI
import SwiftUI

struct PhotoStepView: View {
    enum Step {
        case kitchen
        case menu
    }

    @Environment(DiagnosisModel.self) private var model
    @Environment(\.openURL) private var openURL
    let step: Step

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isShowingPicker = false
    @State private var isShowingCamera = false
    @State private var isCameraDenied = false

    private var photos: [DiagnosisPhoto] {
        step == .kitchen ? model.kitchenPhotos : model.menuPhotos
    }

    private func setPhotos(_ photos: [DiagnosisPhoto]) {
        let limited = Array(photos.prefix(DiagnosisModel.maxPhotos))
        if step == .kitchen { model.kitchenPhotos = limited } else { model.menuPhotos = limited }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Steps(current: step == .kitchen ? 1 : 2)
                    .padding(.top, 4)
                Headline(
                    title: step == .kitchen ? "주방 사진을 올려주세요" : "메뉴판 사진을 올려주세요",
                    sub: step == .kitchen
                        ? "1장은 꼭 필요하고, 최대 \(DiagnosisModel.maxPhotos)장까지 올릴 수 있어요."
                        : "어떤 메뉴에 가장 손이 많이 가는지 알아봐요."
                )
                .padding(.top, 28)
                photoCard
                    .padding(.top, 20)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .screenChrome("우리 가게 진단")
        .safeAreaInset(edge: .bottom) {
            FooterButtons {
                PrimaryButton(title: "다음", enabled: !photos.isEmpty) {
                    model.path.append(step == .kitchen ? .menuPhotos : .storeInfo)
                }
            }
        }
        .photosPicker(
            isPresented: $isShowingPicker,
            selection: $pickerItems,
            maxSelectionCount: max(1, DiagnosisModel.maxPhotos - photos.filter { !$0.isExample }.count),
            matching: .images
        )
        .onChange(of: pickerItems) { _, items in
            Task { await load(items) }
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraPicker { image in
                setPhotos(photos.filter { !$0.isExample } + [DiagnosisPhoto(image: image, sampleName: nil)])
            }
            .ignoresSafeArea()
        }
        .alert("카메라 접근이 꺼져 있어요", isPresented: $isCameraDenied) {
            Button("취소", role: .cancel) {}
            Button("설정 열기") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
        } message: {
            Text("사진을 바로 찍으려면 설정에서 로봇핏의 카메라 접근을 허용해 주세요.")
        }
    }

    private var photoCard: some View {
        Card {
            HStack {
                Text(step == .kitchen ? "대표 사진" : "메뉴판 사진")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text("필수")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.sub)
            }

            Group {
                if photos.isEmpty {
                    exampleImage
                } else {
                    selectedGrid
                }
            }
            .padding(.top, 16)

            HStack(spacing: 8) {
                Button {
                    isShowingPicker = true
                } label: {
                    Text("앨범에서 선택")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Color.white, in: Capsule())
                        .overlay(Capsule().stroke(Palette.disabled, lineWidth: 1))
                }
                Button {
                    openCamera()
                } label: {
                    Text("바로 촬영")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Palette.action, in: Capsule())
                }
            }
            .padding(.top, 16)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(tipItems, id: \.text) { tip in
                    HStack(spacing: 14) {
                        Image(systemName: tip.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(tip.tint)
                            .frame(width: 36, height: 36)
                            .background(tip.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                        Text(tip.text)
                            .font(.system(size: 15))
                            .foregroundStyle(Palette.ink)
                    }
                }
            }
            .padding(.top, 20)
        }
    }

    private var exampleImage: some View {
        Button {
            setPhotos([step == .kitchen ? .kitchenExample : .menuExample])
        } label: {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 204)
                .overlay {
                    Image(step == .kitchen ? "SampleKitchen" : "SampleMenu")
                        .resizable()
                        .scaledToFill()
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(alignment: .topLeading) {
                    exampleTag.padding(12)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("민수네 치킨 예시 사진 쓰기")
    }

    private var selectedGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(photos) { photo in
                thumbnail(photo)
            }
        }
    }

    private func thumbnail(_ photo: DiagnosisPhoto) -> some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .overlay {
                Group {
                    if let image = photo.image {
                        Image(uiImage: image).resizable()
                    } else if let name = photo.sampleName {
                        Image(name).resizable()
                    }
                }
                .scaledToFill()
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(alignment: .topLeading) {
            if photo.isExample { exampleTag.padding(8) }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                setPhotos(photos.filter { $0.id != photo.id })
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(.black.opacity(0.6), in: Circle())
            }
            .padding(8)
            .accessibilityLabel("사진 빼기")
        }
    }

    private var exampleTag: some View {
        Text("예시")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Palette.action)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color(red: 1, green: 0.945, blue: 0.902), in: RoundedRectangle(cornerRadius: 6))
    }

    private var tipItems: [(icon: String, tint: Color, text: String)] {
        switch step {
        case .kitchen:
            [
                ("photo.fill", Palette.action, "입구에서 주방 전체가 보이게 찍어주세요"),
                ("flame.fill", Palette.warn, "튀김기·후드가 화면에 들어오게 해주세요"),
                ("lightbulb.fill", Color(red: 0.0, green: 0.62, blue: 0.82), "너무 가깝거나 어두운 사진은 피해주세요"),
            ]
        case .menu:
            [
                ("list.bullet", Palette.good, "메뉴 이름이 다 보이게 찍어주세요"),
                ("iphone", Palette.action, "배달앱 메뉴 화면 캡처도 괜찮아요"),
                ("viewfinder", Color(red: 0.0, green: 0.62, blue: 0.82), "글자가 흐리지 않게 초점을 맞춰주세요"),
            ]
        }
    }

    private func openCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { return }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isShowingCamera = true
        case .notDetermined:
            Task {
                if await AVCaptureDevice.requestAccess(for: .video) {
                    isShowingCamera = true
                } else {
                    isCameraDenied = true
                }
            }
        default:
            isCameraDenied = true
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
