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

    init(_ path: String, mode: ContentMode = .fit) {
        self.path = path
        self.mode = mode
    }

    var body: some View {
        if let url = app.imageURL(path), let image = JournalPictures.image(url) {
            Image(uiImage: image).resizable().aspectRatio(contentMode: mode)
        } else {
            Color.clear
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
            Group {
                if name == "block" { Text("🚫") }
                else { JournalImage("assets/icons/\(name).png").frame(width: 30, height: 30) }
            }
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
            if let url = JournalAssets.url("assets/backgrounds/journal-paper.png"),
               let tile = JournalPictures.image(url) {
                Rectangle().fill(ImagePaint(image: Image(uiImage: tile), scale: 290 / tile.size.width))
            }
            Color(red: 1, green: 0.85, blue: 0.83).opacity(0.30)
        }.ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)
    }
}
