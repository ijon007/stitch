import Photos
import SwiftUI

struct BoardExport {
    var image: Image
    var png: URL

    /// Renders the board at a fixed 360pt width (3x) so exports look the same on every device.
    @MainActor
    static func render(title: String, items: [BoardItem], aspect: CGFloat) -> BoardExport? {
        let width: CGFloat = 360
        let renderer = ImageRenderer(content: BoardStage(items: items).frame(width: width, height: width / aspect))
        renderer.scale = 3
        guard let image = renderer.uiImage, let data = image.pngData() else { return nil }

        let png = URL.temporaryDirectory.appending(path: "\(fileName(title)).png")
        do {
            try data.write(to: png)
        } catch {
            return nil
        }
        return BoardExport(image: Image(uiImage: image), png: png)
    }

    static func fileName(_ title: String) -> String {
        let cleaned = title
            .components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>").union(.newlines))
            .joined()
            .trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? "Board" : cleaned
    }
}

enum BoardExportCheck {
    static func run() {
        assert(BoardExport.fileName("Silk / season") == "Silk  season")
        assert(BoardExport.fileName(" :/ ") == "Board")
    }
}

struct SaveBoardView: View {
    var title: String
    var items: [BoardItem]
    var aspect: CGFloat
    var export: BoardExport
    var onBack: () -> Void
    var onDone: () -> Void

    @State private var finished = false
    @State private var savedPhotos = false
    @State private var saveFailed = false

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Text(title)
                    .font(StitchFont.display(22))
                    .foregroundStyle(StitchColor.ink)
                    .lineLimit(1)
                    .padding(.horizontal, 72)
                    .accessibilityAddTraits(.isHeader)

                HStack {
                    Button(action: onBack) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(StitchColor.ink)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Keep editing")

                    Spacer()

                    Button {
                        finished = true
                        onDone()
                    } label: {
                        Text("Done")
                            .font(StitchFont.sans(16, weight: .semibold))
                            .foregroundStyle(StitchColor.accent)
                            .frame(height: 44)
                            .padding(.horizontal, 6)
                            .contentShape(Rectangle())
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .frame(height: 52)

            BoardStage(items: items)
                .aspectRatio(aspect, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 16)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Board preview")

            VStack(spacing: 10) {
                ShareLink(item: export.image, preview: SharePreview(title, image: export.image)) {
                    Text("Share")
                        .font(StitchFont.sans(16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .tint(StitchColor.accent)

                ShareLink(item: inviteURL, message: Text("Add to “\(title)” with me on Stitch")) {
                    Text("Collaborate")
                        .font(StitchFont.sans(16, weight: .semibold))
                        .foregroundStyle(StitchColor.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)

                Button(action: saveToPhotos) {
                    Text(savedPhotos ? "Saved to Photos" : "Save to Photos")
                        .font(StitchFont.sans(16, weight: .semibold))
                        .foregroundStyle(StitchColor.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .contentTransition(.opacity)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .disabled(savedPhotos)
                .accessibilityHint("Saves the board into your photo library")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .background(StitchColor.cream)
        .sensoryFeedback(.success, trigger: finished)
        .sensoryFeedback(.success, trigger: savedPhotos)
        .alert("Couldn’t save to Photos", isPresented: $saveFailed) {
            Button("OK", role: .cancel) {}
        }
        .onAppear(perform: BoardExportCheck.run)
    }

    private var inviteURL: URL {
        let slug = BoardExport.fileName(title).lowercased().split(separator: " ").joined(separator: "-")
        return URL(string: "https://stitch.app/b/\(slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "board")")!
    }

    private func saveToPhotos() {
        Task {
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard status == .authorized || status == .limited else {
                saveFailed = true
                return
            }
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: export.png)
                }
                savedPhotos = true
            } catch {
                saveFailed = true
            }
        }
    }
}
