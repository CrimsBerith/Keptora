import SwiftUI
import KeptoraCore

struct MobilePhotoInspectorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let asset: UniversalMediaAsset
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var showInfo = false
    
    init(asset: UniversalMediaAsset) {
        self.asset = asset
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                // Interactive Zoomable Image
                GeometryReader { proxy in
                    MobileAssetThumbnail(asset: asset, pixelSize: 1600, contentMode: .fit)
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
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
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
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
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
                            .foregroundStyle(.white.opacity(0.85))
                    }
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
                            .foregroundStyle(MobileKeptoraDesign.cyan)
                    }
                }
            }
            .sheet(isPresented: $showInfo) {
                AssetMetadataSheet(asset: asset)
                    .presentationDetents([.medium, .fraction(0.65)])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

// MARK: – EXIF & Technical Metadata Sheet

private struct AssetMetadataSheet: View {
    let asset: UniversalMediaAsset
    
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
                
                if let date = asset.creationDate {
                    Section(header: Text("Capture Information")) {
                        LabeledContent("Date", value: date.formatted(date: .long, time: .shortened))
                    }
                }
                
                Section(header: Text("Safety & Protection")) {
                    LabeledContent("Favorite", value: asset.isFavorite ? String(localized: "Yes") : String(localized: "No"))
                    LabeledContent("Protected", value: asset.isProtectedFromGlobalSelection ? String(localized: "Protected") : String(localized: "Eligible for Cleanup"))
                }
            }
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
