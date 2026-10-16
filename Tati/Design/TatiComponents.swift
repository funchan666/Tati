import SwiftUI

extension Color {
    static let tatiInk = Color(red: 0.23, green: 0.29, blue: 0.03)
    static let tatiOlive = Color(red: 0.36, green: 0.45, blue: 0.02)
    static let tatiPink = Color(red: 1, green: 0.30, blue: 0.69)
    static let tatiLime = Color(red: 0.83, green: 1, blue: 0.13)
    static let tatiCream = Color(red: 0.96, green: 1, blue: 0.78)
}
struct Art: View {
    var name: String
    var width: CGFloat? = nil
    var height: CGFloat? = nil
    var body: some View {
        Image(name).resizable().scaledToFit().frame(width: width, height: height).accessibilityHidden(true)
    }
}
enum MissingIcon: Int { case send, pause, comment, viewers, toggleOff, play }
struct SupplementIcon: View {
    var icon: MissingIcon
    var size: CGFloat = 26
    var body: some View {
        // Display a cell of the generated raster sheet; no vector artwork is drawn in code.
        let cell = size / 0.76
        Image("missing-icons").resizable().frame(width: cell * 3, height: cell * 2)
            .offset(x: -CGFloat(icon.rawValue % 3) * cell, y: -CGFloat(icon.rawValue / 3) * cell)
            .frame(width: cell, height: cell, alignment: .topLeading).clipped()
            .frame(width: size, height: size).accessibilityHidden(true)
    }
}
struct TatiBackground: View {
    var bright = false
    var body: some View {
        GeometryReader { geo in
            Image(bright ? "bright-background" : "page-background").resizable()
                .frame(width: geo.size.width, height: geo.size.height)
        }.ignoresSafeArea().accessibilityHidden(true)
    }
}
struct TatiButton: View {
    var title: String
    var secondary = false
    var enabled = true
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(secondary ? Color.tatiInk : .white)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(secondary ? Color.tatiLime : Color.tatiPink)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .opacity(enabled ? 1 : 0.48)
        }.buttonStyle(.plain).disabled(!enabled)
    }
}
struct ArtButton: View {
    var asset: String
    var label: String
    var size: CGFloat = 26
    var action: () -> Void
    var body: some View {
        Button(action: action) { Art(name: asset, width: size, height: size).frame(minWidth: 44, minHeight: 44) }
            .buttonStyle(.plain).accessibilityLabel(label)
    }
}
struct ImageAction: View {
    var asset: String
    var label: String
    var height: CGFloat = 48
    var action: () -> Void
    var body: some View {
        Button(action: action) { Art(name: asset, height: height).frame(maxWidth: .infinity) }
            .buttonStyle(.plain).accessibilityLabel(label)
    }
}
struct TatiHeader: View {
    var title: String
    var trailing: String? = nil
    var trailingLabel = "More"
    var action: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        HStack {
            ArtButton(asset: "back", label: "Back") { dismiss() }
            Text(title).font(.system(size: 19, weight: .bold)).frame(maxWidth: .infinity)
            if let trailing { ArtButton(asset: trailing, label: trailingLabel) { action?() } }
            else { Color.clear.frame(width: 44, height: 44) }
        }.foregroundStyle(Color.tatiInk).padding(.horizontal, 8)
    }
}
struct TatiPage<Content: View>: View {
    var title: String
    var scrolling = true
    var background: String? = nil
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(spacing: 0) {
            TatiHeader(title: title)
            if scrolling {
                ScrollView { VStack(alignment: .leading, spacing: 20) { content() }.padding(20).frame(maxWidth: 600) }
            } else { content() }
        }.background { if let background { GeometryReader { geo in Image(background).resizable().scaledToFill().frame(width: geo.size.width, height: geo.size.height).clipped() }.ignoresSafeArea() } else { TatiBackground() } }.foregroundStyle(Color.tatiInk).toolbar(.hidden, for: .navigationBar)
    }
}
struct Chip: View {
    var text: String
    var selected = false
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(text).font(.system(size: 13, weight: selected ? .bold : .medium))
                .padding(.horizontal, 15).padding(.vertical, 10)
                .foregroundStyle(selected ? Color.tatiInk : Color.tatiOlive)
                .background(selected ? Color.tatiLime : Color.white.opacity(0.58))
                .clipShape(Capsule())
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }
}
struct TopicStrip: View {
    var items: [String]
    @Binding var selected: String
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) { ForEach(items, id: \.self) { item in Chip(text: item, selected: selected == item) { selected = item } } }
        }
    }
}
struct Note: View {
    var text: String
    var body: some View { Text(text).font(.system(size: 12)).foregroundStyle(Color.tatiOlive).fixedSize(horizontal: false, vertical: true) }
}
struct EmptyContent: View {
    var title: String
    var detail: String
    var artwork = "support-mascot"
    var body: some View {
        VStack(spacing: 14) {
            Art(name: artwork, width: 72, height: 72)
            Text(title).font(.headline)
            Text(detail).font(.subheadline).multilineTextAlignment(.center).foregroundStyle(Color.tatiOlive)
        }.frame(maxWidth: .infinity).padding(.vertical, 32).padding(.horizontal, 18)
    }
}
struct MediaPlaceholder: View {
    var title = "Photo to come"
    var height: CGFloat = 200
    var body: some View {
        VStack(spacing: 10) {
            Art(name: "media-placeholder", width: 52, height: 52)
            Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(Color.tatiOlive)
        }.frame(maxWidth: .infinity).frame(height: height).background(Color.tatiLime.opacity(0.26))
            .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}
struct Avatar: View {
    var file: String? = nil
    var size: CGFloat = 46
    var isCurrent = false
    @EnvironmentObject private var store: VisitorStore
    var body: some View {
        Group {
            if let file, let ui = UIImage(contentsOfFile: store.mediaURL(file).path) {
                Image(uiImage: ui).resizable().scaledToFill()
            } else { Image("media-placeholder").resizable().scaledToFit().padding(size * 0.15).background(Color.tatiCream) }
        }.frame(width: size, height: size).clipShape(Circle()).overlay { if isCurrent && store.account.equippedFrame { Art(name: "host-frame", width: size * 1.3, height: size * 1.3) } }.accessibilityHidden(true)
    }
}
struct InputField: View {
    var title: String
    @Binding var text: String
    var multiline = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 13, weight: .semibold))
            TextField(title, text: $text, axis: multiline ? .vertical : .horizontal)
                .lineLimit(multiline ? 4...7 : 1...1).textFieldStyle(.plain)
                .padding(16).background(Color.tatiLime.opacity(0.40))
                .clipShape(RoundedRectangle(cornerRadius: 16)).tint(.tatiPink)
                .accessibilityLabel(title)
        }
    }
}
struct SettingRow: View {
    var title: String
    var asset: String? = nil
    var detail: String? = nil
    var body: some View {
        HStack(spacing: 13) {
            if let asset { Art(name: asset, width: 24, height: 24) }
            Text(title).font(.system(size: 15, weight: .medium))
            Spacer(minLength: 6)
            if let detail { Text(detail).font(.caption).foregroundStyle(Color.tatiOlive) }
            Art(name: "chevron", width: 14, height: 14)
        }.foregroundStyle(Color.tatiInk).padding(16).frame(minHeight: 54)
            .background(Color.white.opacity(0.45)).clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
struct NoticeLayer: View {
    @EnvironmentObject private var store: VisitorStore
    var body: some View {
        if let notice = store.notice {
            ZStack {
                Color.black.opacity(0.48).ignoresSafeArea()
                VStack(spacing: 18) {
                    Text(notice.title).font(.system(size: 23, weight: .heavy, design: .rounded))
                    Text(notice.message).font(.system(size: 15)).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                    HStack {
                        if notice.action != nil { TatiButton(title: "Cancel", secondary: true) { store.notice = nil } }
                        TatiButton(title: notice.actionTitle) {
                            store.notice = nil
                            notice.action?()
                        }
                    }
                }.padding(.horizontal, 32).padding(.vertical, 42).background { Image("dialog-card").resizable() }
                    .padding(26).frame(maxWidth: 440).foregroundStyle(Color.tatiInk)
            }.accessibilityAddTraits(.isModal).transition(.opacity).zIndex(100)
        }
    }
}

/// Shared bright bottom panel used by the Lanhu room and filter artboards.
struct TatiPanel<Content: View>: View {
    var title: String
    @ViewBuilder var content: () -> Content
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.system(size: 22, weight: .bold, design: .serif))
                Spacer()
                ArtButton(asset: "close-light", label: "Close") { dismiss() }
            }.padding(.horizontal, 18).padding(.top, 12)
            ScrollView { VStack(alignment: .leading, spacing: 18) { content() }.padding(18).frame(maxWidth: 600) }
        }.background(Color.tatiLime).foregroundStyle(Color.tatiInk)
            .presentationBackground(Color.tatiLime).presentationDragIndicator(.hidden)
            .toolbar(.hidden, for: .navigationBar)
    }
}
