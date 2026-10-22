import SwiftUI
import ImageIO

/// Photos follow the current container, without imposing a device-sized width.
struct ContentPhoto: View {
    var asset: String?
    var height: CGFloat
    var alignment: Alignment = .top
    var body: some View {
        GeometryReader { geometry in
            if let asset {
                PreparedPhoto(source: .asset(asset), alignment: alignment)
            } else {
                MediaPlaceholder(title: "Photo unavailable", height: geometry.size.height)
            }
        }.frame(height: height).accessibilityHidden(true)
    }
}

/// Imported files use unique names; bundled artwork is immutable for this app version.
/// Cache display-sized pixels, never mutate the original photo or attachment.
enum PhotoSource: Hashable {
    case asset(String)
    case file(URL)
}

private struct PhotoRequest: Hashable {
    let source: PhotoSource
    let fallback: String?
    let width: Int
    let height: Int
    let fills: Bool
}

private actor PhotoPixelCache {
    static let shared = PhotoPixelCache()
    private let images: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 96
        cache.totalCostLimit = 48 * 1_024 * 1_024
        return cache
    }()

    func image(for request: PhotoRequest) -> UIImage? {
        guard !Task.isCancelled else { return nil }
        let sourceKey: String
        switch request.source {
        case .asset(let name): sourceKey = "asset:" + name
        case .file(let url): sourceKey = "file:" + url.path
        }
        let key = "\(sourceKey)|\(request.fallback ?? "")|\(request.width)x\(request.height)|\(request.fills)" as NSString
        if let image = images.object(forKey: key) { return image }
        let image: UIImage?
        switch request.source {
        case .asset(let name): image = assetImage(name, request: request)
        case .file(let url):
            image = fileImage(url, request: request)
                ?? request.fallback.flatMap { assetImage($0, request: request) }
        }
        guard let image, !Task.isCancelled else { return nil }
        let cost = (image.cgImage?.bytesPerRow ?? request.width * 4) * (image.cgImage?.height ?? request.height)
        images.setObject(image, forKey: key, cost: cost)
        return image
    }

    func preview(data: Data, maxPixels: Int) -> UIImage? {
        guard !Task.isCancelled,
              let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixels
              ] as CFDictionary) else { return nil }
        return UIImage(cgImage: thumbnail)
    }

    private func targetSize(width: CGFloat, height: CGFloat, request: PhotoRequest) -> CGSize {
        let x = CGFloat(request.width) / width
        let y = CGFloat(request.height) / height
        let scale = request.fills ? max(x, y) : min(x, y)
        // Extremely panoramic photos must not produce an unbounded decode.
        let bounded = min(scale, 2_560 / max(width, height))
        return CGSize(width: max(1, width * bounded), height: max(1, height * bounded))
    }

    private func assetImage(_ name: String, request: PhotoRequest) -> UIImage? {
        guard let original = UIImage(named: name), original.size.width > 0, original.size.height > 0 else { return nil }
        return original.preparingThumbnail(of: targetSize(width: original.size.width, height: original.size.height, request: request))
    }

    private func fileImage(_ url: URL, request: PhotoRequest) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = properties[kCGImagePropertyPixelHeight] as? NSNumber,
              width.doubleValue > 0, height.doubleValue > 0 else { return nil }
        let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        let rotated = (5...8).contains(orientation)
        let target = targetSize(width: CGFloat(rotated ? height.doubleValue : width.doubleValue),
                                height: CGFloat(rotated ? width.doubleValue : height.doubleValue), request: request)
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(max(target.width, target.height).rounded(.up))
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: thumbnail)
    }
}

/// Shared by avatars, covers and attachments. Layout stays stable while pixels load.
struct PreparedPhoto: View {
    let source: PhotoSource
    var fallbackAsset: String? = nil
    var fills = true
    var alignment: Alignment = .center
    @Environment(\.displayScale) private var displayScale
    var body: some View {
        GeometryReader { geometry in
            let request = PhotoRequest(source: source, fallback: fallbackAsset,
                                       width: pixelBucket(geometry.size.width), height: pixelBucket(geometry.size.height), fills: fills)
            PreparedPhotoPixels(request: request, alignment: alignment)
                .frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }
    }
    private func pixelBucket(_ points: CGFloat) -> Int {
        guard points.isFinite else { return 640 }
        return Int(min(2_048, max(64, (points * displayScale / 64).rounded(.up) * 64)))
    }
}

private struct PreparedPhotoPixels: View {
    let request: PhotoRequest
    let alignment: Alignment
    @State private var image: UIImage?
    @State private var loaded: PhotoRequest?
    var body: some View {
        GeometryReader { geometry in
            Group {
                // Keep the old size during resizing, but never show a previous person's photo.
                if let image, loaded?.source == request.source, loaded?.fallback == request.fallback {
                    Image(uiImage: image).resizable()
                        .aspectRatio(contentMode: request.fills ? .fill : .fit)
                } else {
                    Color.tatiCream
                        .overlay {
                            if loaded == request {
                                Art(name: "media-placeholder", width: min(32, geometry.size.width), height: min(32, geometry.size.height))
                            }
                        }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: alignment).clipped()
        }
        .task(id: request) {
            guard loaded != request else { return }
            let prepared = await PhotoPixelCache.shared.image(for: request)
            guard !Task.isCancelled else { return }
            image = prepared
            loaded = request
        }
    }
}

/// A selected photo is decoded once per selection, not again while typing form fields.
struct PreparedDataPhoto: View {
    let data: Data
    var maxPixels = 1_200
    var fills = true
    @State private var image: UIImage?
    @State private var loaded: Request?
    private struct Request: Equatable { let data: Data; let maxPixels: Int }
    var body: some View {
        let request = Request(data: data, maxPixels: maxPixels)
        GeometryReader { geometry in
            Group {
                if let image, loaded == request {
                    Image(uiImage: image).resizable().aspectRatio(contentMode: fills ? .fill : .fit)
                } else { Color.tatiCream }
            }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }
        .task(id: request) {
            guard loaded != request else { return }
            let prepared = await PhotoPixelCache.shared.preview(data: data, maxPixels: maxPixels)
            guard !Task.isCancelled else { return }
            image = prepared; loaded = request
        }
    }
}

struct ClipPoster: View {
    var clip: FoodFilm
    var height: CGFloat = 210
    @EnvironmentObject private var store: MemberKitchenStore
    var body: some View {
        if let artwork = clip.posterAssetName {
            ContentPhoto(asset: artwork, height: height, alignment: .center)
        } else if let url = store.videoURL(for: clip) {
            LocalVideoPoster(url: url, height: height)
        } else {
            MediaPlaceholder(title: "Video unavailable", height: height)
        }
    }
}

struct PortraitPhotoView: View {
    var person: TableMember
    var body: some View {
        TatiPage(title: person.name, scrolling: false) {
            MediaViewport {
                if let asset = person.portraitArtwork {
                    Image(asset).resizable().scaledToFit()
                        .accessibilityLabel("Photo of " + person.name)
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
