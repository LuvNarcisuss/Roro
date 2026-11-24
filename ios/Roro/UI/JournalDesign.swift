import SwiftUI
import ImageIO

enum JournalColor {
    static let ink = Color(red: 0.263, green: 0.173, blue: 0.129)
    static let paper = Color(red: 1, green: 0.941, blue: 0.855)
    static let petrol = Color(red: 0.09, green: 0.298, blue: 0.271)
    static let accent = Color(red: 0.576, green: 0.263, blue: 0.141)
    static let gold = Color(red: 1, green: 0.808, blue: 0.463)
}

private enum JournalPictures {
    static let cache: NSCache<NSURL, UIImage> = {
        let cache = NSCache<NSURL, UIImage>()
        cache.totalCostLimit = 64 * 1024 * 1024
        return cache
    }()

    static func image(_ url: URL) -> UIImage? {
        if let hit = cache.object(forKey: url as NSURL) { return hit }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let pixels = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 1600
              ] as CFDictionary) else { return nil }
        let image = UIImage(cgImage: pixels)
        cache.setObject(image, forKey: url as NSURL, cost: pixels.bytesPerRow * pixels.height)
        return image
    }
}

struct JournalImage: View {
    @EnvironmentObject private var app: JournalStore
    let path: String
    let mode: ContentMode
    let tiled: Bool
    @State private var resolvedPath = ""
    @State private var resolvedURL: URL?

    init(_ path: String, mode: ContentMode = .fit, tiled: Bool = false) {
        self.path = path
        self.mode = mode
        self.tiled = tiled
    }

    var body: some View {
        Group {
            if let url = (resolvedPath == path ? resolvedURL : nil) ?? app.imageURL(path),
               let image = JournalPictures.image(url) {
                if tiled {
                    Rectangle().fill(ImagePaint(image: Image(uiImage: image), scale: 290 / image.size.width))
                } else {
                    Image(uiImage: image).resizable().aspectRatio(contentMode: mode)
                }
            } else {
                Color.clear
            }
        }
        .task(id: path) {
            let file = try? await app.assetFile(path)
            guard !Task.isCancelled else { return }
            resolvedURL = file
            resolvedPath = path
        }
    }
}

struct JournalIcon: View {
    let name: String
    let label: String
    let selected: Bool
    let action: () -> Void

    init(_ name: String, _ label: String, selected: Bool = false, action: @escaping () -> Void) {
        self.name = name
        self.label = label
        self.selected = selected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            JournalImage("assets/icons/\(name).png")
                .frame(width: 30, height: 30)
                .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct JournalHeader<Actions: View>: View {
    @EnvironmentObject private var app: JournalStore
    let title: String
    let root: Bool
    let actions: Actions

    init(_ title: String, root: Bool = false, @ViewBuilder actions: () -> Actions) {
        self.title = title
        self.root = root
        self.actions = actions()
    }

    var body: some View {
        HStack(spacing: 2) {
            if root {
                JournalImage("assets/icons/roro-logo.png")
                    .frame(width: 64, height: 50).accessibilityLabel("Roro")
            } else {
                JournalIcon("back", "Back") { app.back() }
            }
            Spacer(minLength: 2)
            HStack(spacing: 0) { actions }
        }
        .overlay {
            if !title.isEmpty {
                Text(title).font(.custom("Courgette-Regular", size: root ? 31 : 24, relativeTo: .title2))
                    .foregroundColor(JournalColor.petrol).lineLimit(2).minimumScaleFactor(0.65)
                    .multilineTextAlignment(.center).padding(.horizontal, root ? 105 : 78)
                    .accessibilityAddTraits(.isHeader).allowsHitTesting(false)
            }
        }
        .padding(.horizontal, 12).frame(minHeight: 64)
    }
}

extension JournalHeader where Actions == EmptyView {
    init(_ title: String, root: Bool = false) { self.init(title, root: root) { EmptyView() } }
}

struct JournalPaper: View {
    var body: some View {
        ZStack {
            JournalColor.paper
            JournalImage("assets/backgrounds/journal-paper.png", tiled: true)
            Color(red: 1, green: 0.85, blue: 0.83).opacity(0.30)
        }.ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)
    }
}
