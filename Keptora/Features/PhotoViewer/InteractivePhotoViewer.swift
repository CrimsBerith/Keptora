import SwiftUI
import KeptoraCore
import ImageIO
import AppKit

/// Model representing a photo currently displayed in the Interactive Photo Viewer.
public struct ViewerPhotoItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let fileURL: URL
    public let displayName: String
    public let byteCount: Int64?
    
    public init(id: String, fileURL: URL, displayName: String, byteCount: Int64? = nil) {
        self.id = id
        self.fileURL = fileURL
        self.displayName = displayName
        self.byteCount = byteCount
    }
}

/// State controller for the interactive photo viewer.
@MainActor
public final class PhotoViewerState: ObservableObject {
    @Published public var items: [ViewerPhotoItem]
    @Published public var selectedIndex: Int
    @Published public var zoomScale: CGFloat = 1.0
    @Published public var panOffset: CGSize = .zero
    @Published public var showInspector: Bool = false
    @Published public var isSideBySideComparing: Bool = false
    @Published public var compareTargetIndex: Int? = nil
    @Published public var isSlideshowPlaying: Bool = false
    @Published public var rotationAngle: Double = 0.0
    /// Photos already sent to the cleanup plan from this viewer session.
    @Published public private(set) var cleanedIDs: Set<String> = []
    
    public init(items: [ViewerPhotoItem], initialIndex: Int = 0) {
        self.items = items
        self.selectedIndex = max(0, min(initialIndex, items.count - 1))
    }
    
    public var currentItem: ViewerPhotoItem? {
        guard items.indices.contains(selectedIndex) else { return nil }
        return items[selectedIndex]
    }
    
    public var compareItem: ViewerPhotoItem? {
        guard let idx = compareTargetIndex, items.indices.contains(idx) else { return nil }
        return items[idx]
    }
    
    public func next() {
        guard !items.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % items.count
        resetTransform()
    }
    
    public func previous() {
        guard !items.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + items.count) % items.count
        resetTransform()
    }
    
    /// Records a photo as cleaned and moves to the next one without wrapping back to the start.
    public func markCleaned(_ item: ViewerPhotoItem) {
        cleanedIDs.insert(item.id)
        if selectedIndex < items.count - 1 {
            selectedIndex += 1
            resetTransform()
        }
    }
    
    public func resetTransform() {
        zoomScale = 1.0
        panOffset = .zero
        rotationAngle = 0.0
    }
    
    public func toggle100PercentZoom() {
        if zoomScale > 1.05 {
            zoomScale = 1.0
            panOffset = .zero
        } else {
            zoomScale = 2.5 // ~100% pixel detail for standard displays
        }
    }
    
    public func rotateClockwise() {
        rotationAngle = (rotationAngle + 90.0).truncatingRemainder(dividingBy: 360.0)
    }
}

/// Full-screen cinematic photo viewer with gestures, EXIF inspector, and comparison mode.
public struct InteractivePhotoViewerView: View {
    @ObservedObject public var state: PhotoViewerState
    public var onCleanOrDelete: ((ViewerPhotoItem) -> Void)?
    public var onClose: () -> Void
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var loadedImage: NSImage?
    @State private var compareImage: NSImage?
    @State private var metadata: DetailedPhotoMetadata?
    @State private var isShowingSwipeStudio: Bool = false
    
    @State private var baseZoomScale: CGFloat = 1.0
    @State private var basePanOffset: CGSize = .zero
    @State private var pinchStartScale: CGFloat?
    
    public init(
        state: PhotoViewerState,
        onCleanOrDelete: ((ViewerPhotoItem) -> Void)? = nil,
        onClose: @escaping () -> Void
    ) {
        self.state = state
        self.onCleanOrDelete = onCleanOrDelete
        self.onClose = onClose
    }
    
    public var body: some View {
        ZStack {
            // Immersive dark backdrop
            Color.black.ignoresSafeArea()
            
            // Main canvas
            if state.isSideBySideComparing, let compareItem = state.compareItem {
                HStack(spacing: 8) {
                    singleViewport(image: loadedImage, title: state.currentItem?.displayName ?? "Original")
                    singleViewport(image: compareImage, title: compareItem.displayName)
                }
                .padding(.horizontal, 16)
                .padding(.top, 50)
                .padding(.bottom, 80)
            } else {
                singleViewport(image: loadedImage, title: nil)
                    .padding(.top, 40)
                    .padding(.bottom, 70)
            }
            
            // Top Toolbar Overlay
            VStack {
                topBar
                Spacer()
                // Bottom Filmstrip
                bottomFilmstrip
            }
            
            // EXIF & Metadata Inspector Drawer
            if state.showInspector {
                HStack {
                    Spacer()
                    PhotoInspectorDrawer(metadata: metadata, item: state.currentItem) {
                        state.showInspector = false
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
        .background {
            // High-efficiency keyboard shortcuts
            HStack {
                Button("") { state.previous() }
                    .keyboardShortcut(.leftArrow, modifiers: [])
                Button("") { state.next() }
                    .keyboardShortcut(.rightArrow, modifiers: [])
                Button("") { onClose() }
                    .keyboardShortcut(.escape, modifiers: [])
                Button("") { state.showInspector.toggle() }
                    .keyboardShortcut("i", modifiers: [.command])
                Button("") { state.rotateClockwise() }
                    .keyboardShortcut("r", modifiers: [.command])
            }
            .opacity(0)
            .allowsHitTesting(false)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: state.showInspector)
        .animation(.easeInOut(duration: 0.2), value: state.isSideBySideComparing)
        .task(id: state.selectedIndex) { await loadCurrentAsset() }
        .task(id: state.compareTargetIndex) { await loadCompareAsset() }
        .onChange(of: state.selectedIndex) { _ in
            baseZoomScale = 1.0
            basePanOffset = .zero
            state.resetTransform()
        }
        .sheet(isPresented: $isShowingSwipeStudio) {
            let cards = state.items.map { item in
                SwipeCardItem(
                    id: item.id,
                    fileURL: item.fileURL,
                    displayName: item.displayName,
                    byteCount: item.byteCount ?? 0
                )
            }
            SwipeCullingStudioView(
                items: cards,
                onCommitPlan: { cleanupItems in
                    for c in cleanupItems {
                        if let match = state.items.first(where: { $0.id == c.id }) {
                            onCleanOrDelete?(match)
                        }
                    }
                    isShowingSwipeStudio = false
                },
                onClose: { isShowingSwipeStudio = false }
            )
        }
    }
    
    // MARK: - Viewports
    
    @ViewBuilder
    private func singleViewport(image: NSImage?, title: String?) -> some View {
        GeometryReader { proxy in
            ZStack {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .rotationEffect(.degrees(state.rotationAngle))
                        .scaleEffect(state.zoomScale)
                        .offset(state.panOffset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    // Anchor on the scale when the pinch began, so toolbar zoom
                                    // buttons and double-click zoom can never leave a stale base.
                                    let start = pinchStartScale ?? state.zoomScale
                                    pinchStartScale = start
                                    state.zoomScale = max(0.8, min(start * value, 8.0))
                                }
                                .onEnded { _ in
                                    pinchStartScale = nil
                                    baseZoomScale = state.zoomScale
                                }
                        )
                        .simultaneousGesture(
                            DragGesture()
                                .onChanged { value in
                                    if state.zoomScale > 1.05 {
                                        state.panOffset = CGSize(
                                            width: basePanOffset.width + value.translation.width,
                                            height: basePanOffset.height + value.translation.height
                                        )
                                    }
                                }
                                .onEnded { _ in
                                    if state.zoomScale <= 1.05 {
                                        state.panOffset = .zero
                                        basePanOffset = .zero
                                    } else {
                                        basePanOffset = state.panOffset
                                    }
                                }
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                state.toggle100PercentZoom()
                                baseZoomScale = state.zoomScale
                                if state.zoomScale <= 1.05 {
                                    state.panOffset = .zero
                                    basePanOffset = .zero
                                }
                            }
                        }
                } else {
                    ProgressView()
                        .tint(.white)
                }
                
                if let title {
                    VStack {
                        HStack {
                            Text(title)
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.ultraThinMaterial)
                                .cornerRadius(6)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(12)
                        Spacer()
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
    }
    
    // MARK: - Navigation & Bars
    
    private var topBar: some View {
        HStack(spacing: 12) {
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
            .help("Close viewer (Esc)")
            .accessibilityLabel("Close viewer (Esc)")
            
            if let item = state.currentItem {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.displayName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text("\(state.selectedIndex + 1) / \(state.items.count)")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundColor(.white.opacity(0.65))
                    }

                    if state.items.count > 1 {
                        HStack(spacing: 4) {
                            Button(action: { state.previous() }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white.opacity(0.85))
                                    .padding(5)
                                    .background(.ultraThinMaterial, in: Circle())
                            }
                            .buttonStyle(.plain)
                            .help("Previous photo (←)")
                            .accessibilityLabel("Previous photo (←)")
                            
                            Button(action: { state.next() }) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white.opacity(0.85))
                                    .padding(5)
                                    .background(.ultraThinMaterial, in: Circle())
                            }
                            .buttonStyle(.plain)
                            .help("Next photo (→)")
                            .accessibilityLabel("Next photo (→)")
                        }
                    }
                }
            }
            
            Spacer()
            
            // Zoom controls
            HStack(spacing: 8) {
                Button(action: {
                    if reduceMotion { state.zoomScale = max(1.0, state.zoomScale - 0.5) }
                    else { withAnimation(.easeOut(duration: 0.2)) { state.zoomScale = max(1.0, state.zoomScale - 0.5) } }
                }) {
                    Image(systemName: "minus.magnifyingglass")
                }
                
                Button(action: {
                    if reduceMotion { state.toggle100PercentZoom() }
                    else { withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { state.toggle100PercentZoom() } }
                }) {
                    Text("\(Int(state.zoomScale * 100))%")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                }
                
                Button(action: {
                    if reduceMotion { state.zoomScale = min(6.0, state.zoomScale + 0.5) }
                    else { withAnimation(.easeOut(duration: 0.2)) { state.zoomScale = min(6.0, state.zoomScale + 0.5) } }
                }) {
                    Image(systemName: "plus.magnifyingglass")
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(.white.opacity(0.85))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial)
            .cornerRadius(8)
            
            // Rotate
            Button(action: state.rotateClockwise) {
                Image(systemName: "rotate.right")
                    .foregroundColor(.white.opacity(0.85))
            }
            .buttonStyle(.plain)
            .padding(6)
            .background(.ultraThinMaterial)
            .cornerRadius(8)
            
            // Compare Side-by-Side
            if state.items.count > 1 {
                Button(action: {
                    state.isSideBySideComparing.toggle()
                    if state.isSideBySideComparing {
                        if state.compareTargetIndex == nil {
                            state.compareTargetIndex = (state.selectedIndex + 1) % state.items.count
                        }
                        Task { await loadCompareAsset() }
                    }
                }) {
                    Image(systemName: state.isSideBySideComparing ? "rectangle.split.2x1.fill" : "rectangle.split.2x1")
                        .foregroundColor(state.isSideBySideComparing ? .accentColor : .white.opacity(0.85))
                }
                .buttonStyle(.plain)
                .padding(6)
                .background(.ultraThinMaterial)
                .cornerRadius(8)
            }
            
            // Reveal in Finder
            Button(action: revealCurrentInFinder) {
                Image(systemName: "folder")
                    .foregroundColor(.white.opacity(0.85))
            }
            .buttonStyle(.plain)
            .padding(6)
            .background(.ultraThinMaterial)
            .cornerRadius(8)
            
            // EXIF Inspector Toggle
            Button(action: { state.showInspector.toggle() }) {
                Image(systemName: "info.circle")
                    .foregroundColor(state.showInspector ? .accentColor : .white.opacity(0.85))
            }
            .buttonStyle(.plain)
            .padding(6)
            .background(.ultraThinMaterial)
            .cornerRadius(8)
            
            // Swipe Culling Studio Launcher
            Button(action: { isShowingSwipeStudio = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "hand.draw.fill")
                    Text("Swipe & Cull")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(.white.opacity(0.9))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial)
            .cornerRadius(8)
            .help("Launch fast Tinder-style swipe culling for these photos")
            .accessibilityLabel("Launch fast Tinder-style swipe culling for these photos")

            // Clean Current Photo Button
            if let current = state.currentItem, onCleanOrDelete != nil {
                let alreadyCleaned = state.cleanedIDs.contains(current.id)
                Button(action: {
                    onCleanOrDelete?(current)
                    withAnimation(reduceMotion ? nil : .default) { state.markCleaned(current) }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: alreadyCleaned ? "checkmark" : "trash.fill")
                        Text(alreadyCleaned ? "In plan" : "Clean (⌫)")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.red.opacity(0.85))
                .cornerRadius(8)
                .keyboardShortcut(.delete, modifiers: [])
                .disabled(alreadyCleaned)
                .help("Add current photo to cleanup plan and view next")
                .accessibilityLabel("Add current photo to cleanup plan and view next")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            LinearGradient(colors: [Color.black.opacity(0.7), Color.clear], startPoint: .top, endPoint: .bottom)
        )
    }
    
    private var bottomFilmstrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(Array(state.items.enumerated()), id: \.element.id) { idx, item in
                        FilmstripThumbnail(
                            url: item.fileURL,
                            isSelected: idx == state.selectedIndex,
                            isCleaned: state.cleanedIDs.contains(item.id)
                        ) {
                            state.selectedIndex = idx
                        }
                        .id(idx)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .frame(height: 70)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .onChange(of: state.selectedIndex) { newIdx in
                withAnimation { proxy.scrollTo(newIdx, anchor: .center) }
            }
        }
    }
    
    // MARK: - Actions
    
    private func loadCurrentAsset() async {
        guard let item = state.currentItem else { return }
        let url = item.fileURL
        // Drop the previous photo immediately so it is never shown under the new title.
        loadedImage = nil
        metadata = nil
        
        let (img, meta) = await Task.detached(priority: .userInitiated) { () -> (NSImage?, DetailedPhotoMetadata?) in
            (ViewerImageLoader.image(at: url), PhotoMetadataExtractor.extract(from: url))
        }.value
        
        // .task(id:) cancels this when the selection changes, so a slow load cannot overwrite a newer one.
        guard !Task.isCancelled else { return }
        loadedImage = img
        metadata = meta
    }
    
    private func loadCompareAsset() async {
        guard let item = state.compareItem else {
            compareImage = nil
            return
        }
        let url = item.fileURL
        compareImage = nil
        let img = await Task.detached(priority: .userInitiated) { ViewerImageLoader.image(at: url) }.value
        guard !Task.isCancelled else { return }
        compareImage = img
    }
    
    private func revealCurrentInFinder() {
        guard let item = state.currentItem else { return }
        NSWorkspace.shared.activateFileViewerSelecting([item.fileURL])
    }
}

/// Decodes viewer images with a bounded pixel size and EXIF orientation applied,
/// instead of inflating the full-resolution bitmap (RAW/HEIC can be hundreds of MB).
enum ViewerImageLoader {
    static let maximumPixelSize = 4096

    static func image(at url: URL) -> NSImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize
        ]
        if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
           let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
            return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        }
        return NSImage(contentsOf: url)
    }
}

/// Thumbnail item in the filmstrip.
private struct FilmstripThumbnail: View {
    let url: URL
    let isSelected: Bool
    var isCleaned: Bool = false
    let onSelect: () -> Void
    
    @State private var thumb: NSImage?
    
    var body: some View {
        Button(action: onSelect) {
            ZStack {
                if let thumb {
                    Image(nsImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Color.gray.opacity(0.3)
                }
            }
            .frame(width: 52, height: 52)
            .overlay {
                if isCleaned {
                    Color.black.opacity(0.45)
                    Image(systemName: "trash.fill").foregroundStyle(.white)
                }
            }
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .task(id: url) {
            let targetURL = url
            let generatedThumb = await Task.detached(priority: .utility) { () -> NSImage? in
                guard let src = CGImageSourceCreateWithURL(targetURL as CFURL, nil) else { return nil }
                let opts: [CFString: Any] = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceThumbnailMaxPixelSize: 120
                ]
                guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
                return NSImage(cgImage: cg, size: NSSize(width: 52, height: 52))
            }.value
            
            if let generatedThumb {
                self.thumb = generatedThumb
            }
        }
    }
}

/// Rich EXIF and Camera Inspector Drawer.
public struct PhotoInspectorDrawer: View {
    public let metadata: DetailedPhotoMetadata?
    public let item: ViewerPhotoItem?
    public let onClose: () -> Void
    @State private var pendingAction: MetadataAction?
    @State private var isWorking = false
    @State private var resultMessage: String?

    public init(metadata: DetailedPhotoMetadata?, item: ViewerPhotoItem?, onClose: @escaping () -> Void) {
        self.metadata = metadata
        self.item = item
        self.onClose = onClose
    }

    private enum MetadataAction: Identifiable {
        case fixDate(Date)
        case stripLocationCopy

        var id: String {
            switch self {
            case .fixDate: return "fixDate"
            case .stripLocationCopy: return "stripLocationCopy"
            }
        }
    }

    /// Runs the confirmed metadata action off the main thread and reports the outcome.
    /// GPS removal writes a new copy next to the original; the original is never rewritten.
    @MainActor
    private func perform(_ action: MetadataAction) {
        guard let url = item?.fileURL, !isWorking else { return }
        isWorking = true
        Task {
            let message: String
            do {
                message = try await Task.detached(priority: .userInitiated) { () -> String in
                    switch action {
                    case .fixDate(let date):
                        try FileManager.default.setAttributes([.creationDate: date], ofItemAtPath: url.path)
                        return String(localized: "Creation date updated from the filename.")
                    case .stripLocationCopy:
                        let copyURL = Self.uniqueCopyURL(for: url)
                        try MetadataDoctorEngine.stripLocationData(from: url, destinationURL: copyURL)
                        return String(localized: "Saved a copy without location data: \(copyURL.lastPathComponent)")
                    }
                }.value
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
            } catch {
                message = String(localized: "Could not complete the change: \(error.localizedDescription)")
            }
            resultMessage = message
            isWorking = false
        }
    }

    nonisolated private static func uniqueCopyURL(for url: URL) -> URL {
        let directory = url.deletingLastPathComponent()
        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        var index = 1
        while true {
            let suffix = index == 1 ? " (no location)" : " (no location \(index))"
            let name = ext.isEmpty ? base + suffix : base + suffix + "." + ext
            let candidate = directory.appendingPathComponent(name)
            if !FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            index += 1
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Photo Details", systemImage: "info.circle")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close photo details")
            }
            .padding(.bottom, 4)
            
            Divider().background(Color.white.opacity(0.2))
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let meta = metadata {
                        // Camera & Lens
                        if meta.cameraModel != nil || meta.lensModel != nil {
                            sectionHeader(title: "Camera & Optics", icon: "camera.fill")
                            infoRow(label: "Camera", value: meta.cameraModel ?? meta.cameraMake ?? "-")
                            if let lens = meta.lensModel {
                                infoRow(label: "Lens", value: lens)
                            }
                        }
                        
                        // Exposure Parameters
                        sectionHeader(title: "Exposure Settings", icon: "slider.horizontal.3")
                        HStack(spacing: 8) {
                            badge(label: "ISO", value: meta.iso.map(String.init) ?? "-")
                            badge(label: "Focal", value: meta.formattedFocalLength ?? "-")
                            badge(label: "Aperture", value: meta.formattedAperture ?? "-")
                            badge(label: "Shutter", value: meta.formattedShutterSpeed ?? "-")
                        }
                        
                        // Image Dimensions & File
                        sectionHeader(title: "File Specification", icon: "doc.fill")
                        infoRow(label: "Resolution", value: "\(meta.pixelWidth) × \(meta.pixelHeight) (\(String(format: "%.1f", meta.megapixelCount)) MP)")
                        if let item, let bytes = item.byteCount {
                            infoRow(label: "File Size", value: ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
                        }
                        if let color = meta.colorSpace {
                            infoRow(label: "Color Space", value: color)
                        }
                        if let date = meta.dateCaptured {
                            infoRow(label: "Captured At", value: date.formatted(date: .abbreviated, time: .shortened))
                        }
                        
                        // Infer Date from filename if missing or generic
                        if let item, MetadataDoctorEngine.inferDateFromFilename(item.fileURL.lastPathComponent) != nil {
                            Button(action: {
                                if let inferred = MetadataDoctorEngine.inferDateFromFilename(item.fileURL.lastPathComponent) {
                                    pendingAction = .fixDate(inferred)
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "calendar.badge.clock")
                                    Text("Fix Date from Filename")
                                }
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.85))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 2)
                            .help("Restore capture date using filename timestamp (WhatsApp, Camera)")
                        }
                        
                        // GPS Location
                        if let lat = meta.latitude, let lon = meta.longitude {
                            sectionHeader(title: "GPS Coordinates", icon: "location.fill")
                            infoRow(label: "Coordinates", value: String(format: "%.4f, %.4f", lat, lon))
                            if let alt = meta.altitude {
                                infoRow(label: "Altitude", value: String(format: "%.0f m", alt))
                            }
                            
                            Button(action: {
                                pendingAction = .stripLocationCopy
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "location.slash.fill")
                                    Text("Save Copy Without GPS Location")
                                }
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(Color.orange.opacity(0.85))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 4)
                            .help("Save a new copy without location coordinates. The original file is not changed.")
                        }
                    } else {
                        Text("Reading EXIF parameters...")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                }
            }
        }
        .padding(18)
        .frame(width: 320)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .padding(16)
        .disabled(isWorking)
        .confirmationDialog(
            pendingAction.map(Self.confirmationTitle) ?? "",
            isPresented: Binding(get: { pendingAction != nil }, set: { if !$0 { pendingAction = nil } }),
            titleVisibility: .visible,
            presenting: pendingAction
        ) { action in
            Button(Self.confirmButtonTitle(for: action)) { perform(action) }
            Button("Cancel", role: .cancel) {}
        } message: { action in
            Text(Self.confirmationMessage(for: action))
        }
        .alert(
            "Photo Details",
            isPresented: Binding(get: { resultMessage != nil }, set: { if !$0 { resultMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(resultMessage ?? "")
        }
    }

    private static func confirmationTitle(for action: MetadataAction) -> String {
        switch action {
        case .fixDate: return String(localized: "Change the file's creation date?")
        case .stripLocationCopy: return String(localized: "Save a copy without location?")
        }
    }

    private static func confirmButtonTitle(for action: MetadataAction) -> String {
        switch action {
        case .fixDate: return String(localized: "Change Date")
        case .stripLocationCopy: return String(localized: "Save Copy")
        }
    }

    private static func confirmationMessage(for action: MetadataAction) -> String {
        switch action {
        case .fixDate(let date):
            return String(localized: "This modifies the original file on disk and sets its creation date to \(date.formatted(date: .abbreviated, time: .shortened)).")
        case .stripLocationCopy:
            return String(localized: "A new file without GPS coordinates will be saved next to the original. The original is not changed.")
        }
    }
    
    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(.accentColor)
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(.top, 4)
    }
    
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
        }
    }
    
    private func badge(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.08))
        .cornerRadius(6)
    }
}
