import SwiftUI

extension View {
    /// Foreground follows its navigation/sheet container's safe area and keyboard.
    /// Apply edge extension to backgrounds only, never to the screen's controls.
    func tatiScreen() -> some View {
        toolbar(.hidden, for: .navigationBar)
    }
}

extension Color {
    static let tatiInk = Color(red: 0.23, green: 0.29, blue: 0.03)
    static let tatiOlive = Color(red: 0.36, green: 0.45, blue: 0.02)
    // Flat fills sampled from the supplied Lanhu boards 44, 06 and 16.
    static let tatiPink = Color(red: 254 / 255, green: 104 / 255, blue: 185 / 255)
    static let tatiLime = Color(red: 211 / 255, green: 254 / 255, blue: 46 / 255)
    static let tatiCream = Color(red: 244 / 255, green: 1, blue: 199 / 255)
}
struct Art: View {
    var name: String
    var width: CGFloat? = nil
    var height: CGFloat? = nil
    var alignment: Alignment = .center
    var body: some View {
        Image(name).resizable().scaledToFit().frame(width: width, height: height, alignment: alignment).accessibilityHidden(true)
    }
}

/// Identifies the room category; motion does not represent a connected broadcast
/// or a participant speaking. Reuses the original Lanhu raster artwork.
struct RoomKindBadge: View {
    var isVoice: Bool
    var animates = true
    var compact = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false
    private var shouldAnimate: Bool {
        animates && isVisible && !reduceMotion && scenePhase == .active
    }
    var body: some View {
        Group {
            if isVoice {
                HStack(spacing: compact ? 3 : 4) {
                    Art(name: "mic-small", width: compact ? 8 : 10, height: compact ? 11 : 14)
                    Text("Voice").font(.system(size: compact ? 9 : 10, weight: .semibold))
                }
                .padding(.horizontal, compact ? 5 : 7).frame(height: compact ? 18 : 22)
                .foregroundStyle(.white).background(compact ? Color.tatiPink : Color.tatiOlive)
                .clipShape(RoundedRectangle(cornerRadius: compact ? 4 : 11))
            } else {
                Art(name: "live-pink", width: 48, height: 22)
            }
        }
        .phaseAnimator(shouldAnimate ? [false, true] : [false]) { content, phase in
            content.scaleEffect(shouldAnimate && phase ? 1.04 : 1)
                .opacity(shouldAnimate && phase ? 0.82 : 1)
        } animation: { _ in
            shouldAnimate ? .easeInOut(duration: 1.2) : nil
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isVoice ? "Voice room" : "Video room")
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
    }
}
enum MissingIcon: Int { case send, pause, comment, viewers, toggleOff, play }
struct SupplementIcon: View {
    var icon: MissingIcon
    var size: CGFloat = 26
    var tint: Color? = nil
    var body: some View {
        // Display a cell of the generated raster sheet; no vector artwork is drawn in code.
        let cell = size / 0.76
        Image("missing-icons").renderingMode(tint == nil ? .original : .template)
            .resizable().foregroundStyle(tint ?? .white).frame(width: cell * 3, height: cell * 2)
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
            Text(title).font(.system(size: 15, weight: .medium)).foregroundStyle(.white)
                .multilineTextAlignment(.center).lineLimit(2)
                .fixedSize(horizontal: false, vertical: true).padding(.horizontal, 8)
                .frame(maxWidth: .infinity, minHeight: 42)
                .background(secondary ? Color.tatiOlive.opacity(0.65) : Color.tatiPink)
                .clipShape(Capsule())
                .frame(minHeight: 44)
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
            Text(title).font(.system(size: 17, weight: .medium)).lineLimit(2)
                .multilineTextAlignment(.center).frame(maxWidth: .infinity)
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
                ScrollView { VStack(alignment: .leading, spacing: 12) { content() }.padding(.horizontal, 18).padding(.vertical, 14).frame(maxWidth: 600).frame(maxWidth: .infinity) }
            } else { content() }
        }.background { if let background { GeometryReader { geo in Image(background).resizable().scaledToFill().frame(width: geo.size.width, height: geo.size.height).clipped() }.ignoresSafeArea() } else { TatiBackground() } }.foregroundStyle(Color.tatiInk).tatiScreen()
    }
}
struct Chip: View {
    var text: String
    var selected = false
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(text).font(.system(size: 12, weight: .medium))
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .foregroundStyle(.white)
                .background(selected ? Color.tatiPink.opacity(0.65) : Color.tatiOlive.opacity(0.48))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .frame(minHeight: 32)
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }
}
/// Forms fill the screen and keep their primary action above the keyboard.
struct TatiForm<Content: View, Footer: View>: View {
    var title: String
    @ViewBuilder var content: () -> Content
    @ViewBuilder var footer: () -> Footer
    var body: some View {
        VStack(spacing: 0) {
            TatiHeader(title: title)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) { content() }
                    .padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 18)
                    .frame(maxWidth: 600).frame(maxWidth: .infinity)
            }
            VStack(spacing: 8) { footer() }.padding(.horizontal, 18).padding(.vertical, 12)
                .frame(maxWidth: 600).frame(maxWidth: .infinity)
        }.background { TatiBackground() }.foregroundStyle(Color.tatiInk).tatiScreen()
    }
}
struct TopicStrip: View {
    var items: [String]
    @Binding var selected: String
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 24) {
                ForEach(items, id: \.self) { item in
                    Button { selected = item } label: {
                        Text(item).font(.system(size: 15, weight: selected == item ? .bold : .regular))
                            .foregroundStyle(selected == item ? Color.tatiOlive : Color.tatiOlive.opacity(0.55))
                            .padding(.vertical, 10)
                            .background(alignment: .bottom) { if selected == item { Color.tatiLime.frame(height: 3) } }
                    }.buttonStyle(.plain).accessibilityAddTraits(selected == item ? .isSelected : [])
                }
            }
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
enum ProfileArtwork {
    static let defaultPortrait = "portrait-12"
}
struct Avatar: View {
    var file: String? = nil
    var asset: String? = nil
    var size: CGFloat = 46
    var isCurrent = false
    @EnvironmentObject private var store: VisitorStore
    var body: some View {
        Group {
            if let file, let ui = UIImage(contentsOfFile: store.mediaURL(file).path) {
                Image(uiImage: ui).resizable().scaledToFill()
            } else if let asset { Image(asset).resizable().scaledToFill() }
            else if isCurrent { Image(ProfileArtwork.defaultPortrait).resizable().scaledToFill() }
            else { Image("media-placeholder").resizable().scaledToFit().padding(size * 0.15).background(Color.tatiCream) }
        }.frame(width: size, height: size, alignment: asset == nil ? .center : .top).clipShape(Circle()).overlay { if isCurrent && store.account.equippedFrame { Art(name: "host-frame", width: size * 1.3, height: size * 1.3) } }.accessibilityHidden(true)
    }
}
struct InputField: View {
    var title: String
    @Binding var text: String
    var multiline = false
    var showsLabel = true
    var minimumHeight: CGFloat? = nil
    var characterLimit: Int? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showsLabel { Text(title).font(.system(size: 13, weight: .regular)) }
            TextField(title, text: $text, axis: multiline ? .vertical : .horizontal)
                .lineLimit(multiline ? 4...7 : 1...1).textFieldStyle(.plain)
                .frame(minHeight: minimumHeight, alignment: .topLeading)
                .font(.system(size: 14)).padding(.horizontal, 16).padding(.top, 16)
                .padding(.bottom, characterLimit == nil ? 16 : 28).background(Color.tatiLime.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 16)).tint(.tatiPink)
                .overlay(alignment: .bottomTrailing) {
                    if let characterLimit {
                        Text("\(text.count)/\(characterLimit)").font(.system(size: 11))
                            .foregroundStyle(Color.tatiOlive.opacity(0.65)).padding(.trailing, 12).padding(.bottom, 8)
                            .allowsHitTesting(false)
                    }
                }
                .accessibilityLabel(title)
        }
    }
}
struct SettingRow: View {
    var title: String
    var asset: String? = nil
    var detail: String? = nil
    var outlined = false
    var body: some View {
        HStack(spacing: 13) {
            if let asset { Art(name: asset, width: 22, height: 22) }
            Text(title).font(.system(size: 14, weight: .regular))
            Spacer(minLength: 6)
            if let detail { Text(detail).font(.caption).foregroundStyle(Color.tatiOlive) }
            Art(name: "chevron", width: 14, height: 14)
        }.foregroundStyle(Color.tatiInk).padding(.horizontal, 12).frame(minHeight: 50)
            .background {
                if outlined { Image("outlined-card").resizable() }
                else { Color.white.opacity(0.3) }
            }
            .overlay(alignment: .bottom) { if !outlined { Color.tatiOlive.opacity(0.12).frame(height: 0.5).padding(.horizontal, 12) } }
    }
}
struct NoticeLayer: View {
    @EnvironmentObject private var store: VisitorStore
    var body: some View {
        if let notice = store.notice {
            ZStack {
                Color.black.opacity(0.48).ignoresSafeArea()
                GeometryReader { geometry in
                    ViewThatFits(in: .vertical) {
                        noticeContent(title: notice.title, message: notice.message, actionTitle: notice.actionTitle, action: notice.action)
                            .fixedSize(horizontal: false, vertical: true)
                        ScrollView {
                            noticeContent(title: notice.title, message: notice.message, actionTitle: notice.actionTitle, action: notice.action)
                        }
                    }
                    .frame(width: min(366, max(0, geometry.size.width - 32)))
                    .background { Image("dialog-card").resizable() }
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }.foregroundStyle(Color.tatiInk)
            }.accessibilityAddTraits(.isModal).transition(.opacity).zIndex(100)
        }
    }
    private func noticeContent(title: String, message: String, actionTitle: String, action: (() -> Void)?) -> some View {
        VStack(spacing: 18) {
            Text(title).font(.system(size: 18, weight: .semibold)).multilineTextAlignment(.center)
            Text(message).font(.system(size: 13)).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            HStack {
                if action != nil {
                    Button { store.notice = nil } label: {
                        Text("Cancel").font(.system(size: 14, weight: .medium)).foregroundStyle(.gray)
                            .frame(maxWidth: .infinity, minHeight: 44).background(Color.gray.opacity(0.18)).clipShape(Capsule())
                    }.buttonStyle(.plain)
                }
                TatiButton(title: actionTitle) { store.notice = nil; action?() }
            }
        }.padding(.horizontal, 24).padding(.vertical, 28)
    }
}

/// Shared bright bottom panel used by the Lanhu room and filter artboards.
struct TatiPanel<Content: View>: View {
    var title: String
    var showsHeader = true
    @ViewBuilder var content: () -> Content
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 0) {
            if showsHeader { HStack {
                Text(title).font(.system(size: 19, weight: .bold, design: .serif))
                Spacer()
                ArtButton(asset: "close-light", label: "Close") { dismiss() }
            }.padding(.horizontal, 16).padding(.top, 4) }
            ScrollView { VStack(alignment: .leading, spacing: 12) { content() }.padding(.horizontal, 16).padding(.top, showsHeader ? 0 : 18).padding(.bottom, 16).frame(maxWidth: 600).frame(maxWidth: .infinity) }
        }.background(Color.tatiLime).foregroundStyle(Color.tatiInk)
            .presentationBackground(Color.tatiLime).presentationDragIndicator(.hidden)
            .presentationCornerRadius(20)
            .tatiScreen()
            .accessibilityAction(.escape) { dismiss() }
    }
}
