import SwiftUI

/// Photos follow the current container, without imposing a device-sized width.
struct ContentPhoto: View {
    var asset: String?
    var height: CGFloat
    var alignment: Alignment = .top
    var body: some View {
        GeometryReader { geometry in
            if let asset {
                Image(asset).resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: alignment)
                    .clipped()
            } else {
                MediaPlaceholder(title: "Photo unavailable", height: geometry.size.height)
            }
        }.frame(height: height).accessibilityHidden(true)
    }
}

struct ClipPoster: View {
    var clip: FoodClip
    var height: CGFloat = 210
    @EnvironmentObject private var store: VisitorStore
    var body: some View {
        if let artwork = clip.posterArtwork {
            ContentPhoto(asset: artwork, height: height, alignment: .center)
        } else if let url = store.videoURL(for: clip) {
            LocalVideoPoster(url: url, height: height)
        } else {
            MediaPlaceholder(title: "Video unavailable", height: height)
        }
    }
}

struct PortraitPhotoView: View {
    var person: FoodPerson
    var body: some View {
        TatiPage(title: person.name, scrolling: false) {
            MediaViewport {
                if let asset = person.portraitArtwork {
                    Image(asset).resizable().scaledToFit()
                        .accessibilityLabel("Photo for the " + person.name + " sample profile")
                } else {
                    EmptyContent(title: "Photo unavailable", detail: "This photo could not be loaded.")
                }
            }
        }
    }
}

/// Independent media and player controls avoid active folds and camera occlusions.
/// Full-screen backdrops are rendered separately and may extend to every edge.
struct MediaViewport<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        GeometryReader { geometry in
            let area = availableFrame(in: geometry)
            content()
                .frame(width: area.width, height: area.height)
                .clipped()
                .position(x: area.midX, y: area.midY)
        }
    }

    private func availableFrame(in geometry: GeometryProxy) -> CGRect {
        let bounds = CGRect(origin: .zero, size: geometry.size)
        if #available(iOS 27.1, *) {
            let obstacles = (
                geometry.reservedRegions(kind: .division, layoutDirectionBehavior: .fixed)
                + geometry.reservedRegions(kind: .occlusion, layoutDirectionBehavior: .fixed)
            ).filter(\.isActive).map(\.frame)
            var candidates = [bounds]
            for obstacle in obstacles {
                candidates = candidates.flatMap { rectangle -> [CGRect] in
                    let intersection = rectangle.intersection(obstacle)
                    guard !intersection.isNull, !intersection.isEmpty else { return [rectangle] }
                    return [
                        CGRect(x: rectangle.minX, y: rectangle.minY, width: rectangle.width, height: intersection.minY - rectangle.minY),
                        CGRect(x: rectangle.minX, y: intersection.maxY, width: rectangle.width, height: rectangle.maxY - intersection.maxY),
                        CGRect(x: rectangle.minX, y: rectangle.minY, width: intersection.minX - rectangle.minX, height: rectangle.height),
                        CGRect(x: intersection.maxX, y: rectangle.minY, width: rectangle.maxX - intersection.maxX, height: rectangle.height)
                    ].filter { $0.width > 0 && $0.height > 0 }
                }
            }
            return candidates.max(by: { $0.width * $0.height < $1.width * $1.height }) ?? .zero
        }
        return bounds
    }
}
