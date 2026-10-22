import SwiftUI
import ImageIO

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
    private let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(memoryCapacity: 8 * 1_024 * 1_024, diskCapacity: 64 * 1_024 * 1_024, diskPath: "tati.editorial.photos")
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        configuration.httpMaximumConnectionsPerHost = 4
        configuration.httpShouldSetCookies = false
        return URLSession(configuration: configuration)
    }()
    private var downloads: [URL: Task<Data?, Never>] = [:]
    private let images: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 96
        cache.totalCostLimit = 48 * 1_024 * 1_024
        return cache
    }()

    func image(for request: PhotoRequest) async -> UIImage? {
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
        case .asset(let name): image = await artworkImage(name, request: request)
        case .file(let url):
            if let local = fileImage(url, request: request) { image = local }
            else if let fallback = request.fallback { image = await artworkImage(fallback, request: request) }
            else { image = nil }
        }
        guard let image, !Task.isCancelled else { return nil }
        let cost = (image.cgImage?.bytesPerRow ?? request.width * 4) * (image.cgImage?.height ?? request.height)
        images.setObject(image, forKey: key, cost: cost)
        return image
    }

    private func artworkImage(_ name: String, request: PhotoRequest) async -> UIImage? {
        if let url = KitchenEditorialLibrary.photographURL(for: name) {
            guard let data = await photographData(at: url), !Task.isCancelled,
                  let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
            return thumbnail(source, request: request)
        }
        if let poster = KitchenEditorialLibrary.posterMovie(for: name) {
            return await VideoPosterCache.shared.image(at: poster.url, seconds: poster.seconds)
        }
        return assetImage(name, request: request)
    }

    private func photographData(at url: URL) async -> Data? {
        if let transfer = downloads[url] { return await transfer.value }

        let transfer = Task { [session] () -> Data? in
            do {
                let (data, response) = try await session.data(from: url)
                guard let response = response as? HTTPURLResponse, response.statusCode == 200,
                      response.mimeType?.hasPrefix("image/") == true,
                      !data.isEmpty, data.count <= 25 * 1_024 * 1_024 else { return nil }
                return data
            } catch { return nil }
        }
        downloads[url] = transfer
        let data = await transfer.value
        downloads[url] = nil
        return data
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

        let bounded = min(scale, 2_560 / max(width, height))
        return CGSize(width: max(1, width * bounded), height: max(1, height * bounded))
    }

    private func assetImage(_ name: String, request: PhotoRequest) -> UIImage? {
        guard let original = UIImage(named: name), original.size.width > 0, original.size.height > 0 else { return nil }
        return original.preparingThumbnail(of: targetSize(width: original.size.width, height: original.size.height, request: request))
    }

    private func fileImage(_ url: URL, request: PhotoRequest) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
        return thumbnail(source, request: request)
    }

    private func thumbnail(_ source: CGImageSource, request: PhotoRequest) -> UIImage? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
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
    @Environment(\.scenePhase) private var scenePhase
    private struct LoadKey: Hashable { let request: PhotoRequest; let active: Bool }
    var body: some View {
        GeometryReader { geometry in
            Group {

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
        .task(id: LoadKey(request: request, active: scenePhase == .active)) {
            guard scenePhase == .active, loaded != request || image == nil else { return }
            let prepared = await PhotoPixelCache.shared.image(for: request)
            guard !Task.isCancelled else { return }
            image = prepared
            loaded = request
        }
    }
}

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
                    PreparedPhoto(source: .asset(asset), fills: false)
                        .accessibilityLabel("Photo of " + person.name)
                } else {
                    EmptyContent(title: "Photo unavailable", detail: "This photo could not be loaded.")
                }
            }
        }
    }
}

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
