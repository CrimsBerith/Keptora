import SwiftUI
import AVKit
import Photos
import KeptoraCore

struct MobilePhotoInspectorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: MobileKeptoraStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var allowNetwork = false
    @State private var player: AVPlayer?
    @State private var videoLoading = false
    @State private var previewError: String?
    @State private var asset: UniversalMediaAsset
    private let items: [UniversalMediaAsset]
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var showInfo = false
    
    init(asset: UniversalMediaAsset, items: [UniversalMediaAsset] = []) {
        _asset = State(initialValue: asset); self.items = items
    }
    private var currentIndex: Int? { items.firstIndex { $0.id == asset.id } }
    private func move(_ delta: Int) {
        guard let index = currentIndex, items.indices.contains(index + delta) else { return }
        player?.pause(); player = nil; scale = 1; lastScale = 1; offset = .zero; lastOffset = .zero; previewError = nil
        asset = items[index + delta]
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let player { VideoPlayer(player: player) }
                else {
                // Interactive Zoomable Image
                GeometryReader { proxy in
                    MobileAssetThumbnail(asset: asset, pixelSize: 1600, contentMode: .fit, allowNetwork: allowNetwork)
                        .scaleEffect(scale)
                        .offset(offset)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = min(max(lastScale * value, 1.0), 4.5)
                                }
                                .onEnded { _ in
                                    if scale <= 1.0 {
                                        withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8)) {
                                            scale = 1.0
                                            offset = .zero
                                        }
                                        lastScale = 1.0
                                        lastOffset = .zero
                                    } else {
                                        lastScale = scale
                                    }
                                }
                        )
                        .simultaneousGesture(
                            DragGesture()
                                .onChanged { value in
                                    if scale > 1.0 {
                                        let maxX = max(0, (proxy.size.width * (scale - 1)) / 2)
                                        let maxY = max(0, (proxy.size.height * (scale - 1)) / 2)
                                        let targetX = lastOffset.width + value.translation.width
                                        let targetY = lastOffset.height + value.translation.height
                                        offset = CGSize(
                                            width: min(max(targetX, -maxX), maxX),
                                            height: min(max(targetY, -maxY), maxY)
                                        )
                                    }
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )
                        .onTapGesture(count: 2) {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.prepare()
                            generator.impactOccurred()
                            withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8)) {
                                if scale > 1.0 {
                                    scale = 1.0
                                    offset = .zero
                                    lastScale = 1.0
                                    lastOffset = .zero
                                } else {
                                    scale = 2.5
                                    lastScale = 2.5
                                }
                            }
                        }
                }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    if let previewError { Text(previewError).font(.caption).foregroundStyle(.white) }
                    if videoLoading { ProgressView("Loading video…").tint(.white) }
                    if case .photoLibrary = asset.reference, !allowNetwork {
                        Button("Download Preview from iCloud") { allowNetwork = true }.frame(minHeight: 44)
                    }
                    HStack {
                        if !items.isEmpty {
                            Button { move(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }.accessibilityLabel("Previous Item").disabled((currentIndex ?? 0) <= 0)
                            Button { move(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }.accessibilityLabel("Next Item").disabled((currentIndex ?? 0) >= items.count - 1)
                        }
                        if asset.mediaKind == .video && player == nil { Button("Play Video") { Task { await loadVideo() } }.disabled(videoLoading) }
                        Spacer()
                        Button(store.selectedLibraryIDs.contains(asset.id) ? "Deselect" : "Select") { store.toggleLibrarySelection(asset) }
                    }.buttonStyle(.borderedProminent).frame(minHeight: 44)
                }.padding(12).background(.black.opacity(0.85))
            }
            .onDisappear { player?.pause() }
            .navigationTitle(asset.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.prepare()
                        generator.impactOccurred()
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white.opacity(0.85)).frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("Close Preview")
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.prepare()
                        generator.impactOccurred()
                        showInfo.toggle()
                    }) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(MobileKeptoraDesign.cyan).frame(minWidth: 44, minHeight: 44)
                    }
                }
            }
            .sheet(isPresented: $showInfo) {
                AssetMetadataSheet(asset: asset, allowNetwork: allowNetwork)
                    .presentationDetents([.medium, .fraction(0.65)])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private func loadVideo() async {
        videoLoading = true; previewError = nil
        defer { videoLoading = false }
        switch asset.reference {
        case .file(let url): player = AVPlayer(url: url)
        case .photoLibrary(let id):
            guard let photo = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else {
                previewError = String(localized: "Preview unavailable"); return
            }
            let options = PHVideoRequestOptions(); options.isNetworkAccessAllowed = allowNetwork
            let avAsset = await withCheckedContinuation { (continuation: CheckedContinuation<AVAsset?, Never>) in
                PHImageManager.default().requestAVAsset(forVideo: photo, options: options) { value, _, _ in continuation.resume(returning: value) }
            }
            if let avAsset { player = AVPlayer(playerItem: AVPlayerItem(asset: avAsset)) }
            else { previewError = String(localized: "Video is unavailable locally. Allow an iCloud download and try again.") }
        }
        player?.play()
    }
}

// MARK: – EXIF & Technical Metadata Sheet

private struct AssetMetadataSheet: View {
    let asset: UniversalMediaAsset
    var allowNetwork = false
    @State private var detailed: DetailedPhotoMetadata?
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Photo Specifications")) {
                    LabeledContent("Dimensions", value: "\(asset.pixelWidth) × \(asset.pixelHeight)")
                    let mp = Double(Int64(asset.pixelWidth) * Int64(asset.pixelHeight)) / 1_000_000.0
                    LabeledContent("Resolution", value: String(format: "%.1f MP", mp))
                    if let bytes = asset.byteCount {
                        LabeledContent("File Size", value: ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
                    }
                    LabeledContent("Kind", value: asset.mediaKind == .image ? String(localized: "Photo") : String(localized: "Video"))
                    if let duration = asset.duration {
                        LabeledContent("Duration", value: String(format: "%.1f s", duration))
                    }
                }
                
                Section("Capture Information") {
                    if let description = asset.captureDateDescription {
                        LabeledContent("Capture Date", value: description)
                        if asset.context?.captureTimeIsReliable != true { Text("Time zone is unavailable. Time is shown as recorded.").font(.footnote).foregroundStyle(.secondary) }
                    } else {
                        Text("Capture date unavailable")
                        if let date = asset.creationDate { LabeledContent("File Created", value: date.formatted()) }
                    }
                    if let camera = detailed?.cameraModel ?? asset.context?.camera { LabeledContent("Camera", value: camera) }
                    if let lens = detailed?.lensModel { LabeledContent("Lens", value: lens) }
                    if let focal = detailed?.formattedFocalLength { LabeledContent("Focal Length", value: focal) }
                    if let aperture = detailed?.formattedAperture { LabeledContent("Aperture", value: aperture) }
                    if let exposure = detailed?.formattedShutterSpeed { LabeledContent("Shutter Speed", value: exposure) }
                    if let iso = detailed?.iso { LabeledContent("ISO", value: iso.formatted()) }
                    if let location = asset.context?.location {
                        LabeledContent("Location", value: String(format: "%.5f, %.5f", location.latitude, location.longitude))
                    } else { Text("Location unavailable") }
                    ForEach(asset.context?.albums ?? []) { album in LabeledContent("Album", value: album.title) }
                }
                Section("Selection Details") {
                    LabeledContent("Favorite", value: asset.isFavorite ? String(localized: "Yes") : String(localized: "No"))
                    if asset.hasAdjustments { Text("This item has edits.") }
                    Text("You can select any accessible item manually. Suggested batch selections preserve favorites and edited items.").font(.footnote).foregroundStyle(.secondary)
                }
            }
            .task(id: asset.id) {
                if case .file(let url) = asset.reference, asset.mediaKind == .image {
                    detailed = await Task.detached { PhotoMetadataExtractor.extract(from: url) }.value
                } else if asset.mediaKind == .image {
                    detailed = try? await PhotoLibrarySourceAdapter().metadata(for: asset, allowNetwork: allowNetwork)
                }
            }
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
