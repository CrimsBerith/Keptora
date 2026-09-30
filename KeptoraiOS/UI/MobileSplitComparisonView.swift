import KeptoraCore
import SwiftUI

/// Interactive Split-Slider Loupe that allows side-by-side / overlapping pixel comparison
/// between two visually similar images with synchronized pinch-to-zoom.
struct MobileSplitComparisonView: View {
    let assetA: UniversalMediaAsset
    let assetB: UniversalMediaAsset
    
    @Environment(\.dismiss) private var dismiss
    @State private var splitRatio: CGFloat = 0.5
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    init(assetA: UniversalMediaAsset, assetB: UniversalMediaAsset) {
        self.assetA = assetA
        self.assetB = assetB
    }
    
    public var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let width = proxy.size.width
                let height = proxy.size.height
                
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    // Background: Image B (Right side)
                    MobileAssetThumbnail(asset: assetB, pixelSize: 1600, contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .frame(width: width, height: height)
                    
                    // Foreground: Image A (Left side clipped by slider)
                    MobileAssetThumbnail(asset: assetA, pixelSize: 1600, contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .frame(width: width, height: height)
                        .mask(
                            HStack(spacing: 0) {
                                Rectangle().frame(width: max(0, width * splitRatio))
                                Spacer(minLength: 0)
                            }
                        )
                    
                    // Interactive Divider: a 44 pt wide hit area around the visible 2.5 pt bar
                    ZStack {
                        Rectangle()
                            .fill(Color.white.opacity(0.85))
                            .frame(width: 2.5)
                            .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 0)
                        Circle()
                            .fill(Color.white)
                            .frame(width: 32, height: 32)
                            .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
                            .overlay(
                                Image(systemName: "arrow.left.and.right")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.black)
                            )
                    }
                    .frame(width: 44, height: height)
                    .contentShape(Rectangle())
                    .position(x: width * splitRatio, y: height / 2)
                    // High priority so dragging the divider never also pans the images.
                    .highPriorityGesture(
                        DragGesture(coordinateSpace: .named("splitCanvas"))
                            .onChanged { value in
                                splitRatio = min(max(value.location.x / max(width, 1), 0.05), 0.95)
                            }
                    )
                    .accessibilityElement()
                    .accessibilityLabel(Text("Comparison divider"))
                    .accessibilityValue(Text("\(Int(splitRatio * 100)) percent"))
                    .accessibilityAdjustableAction { direction in
                        switch direction {
                        case .increment: splitRatio = min(splitRatio + 0.05, 0.95)
                        case .decrement: splitRatio = max(splitRatio - 0.05, 0.05)
                        @unknown default: break
                        }
                    }
                    
                    // Top floating labels
                    VStack {
                        HStack {
                            Text(verbatim: assetA.displayName)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(.black.opacity(0.65), in: Capsule())
                                .foregroundStyle(.white)
                            
                            Spacer()
                            
                            Text(verbatim: assetB.displayName)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(.black.opacity(0.65), in: Capsule())
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        
                        Spacer()
                    }
                }
                .coordinateSpace(name: "splitCanvas")
                .clipped()
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { val in
                            scale = min(max(lastScale * val, 1.0), 6.0)
                            offset = clamped(offset, in: proxy.size)
                        }
                        .onEnded { _ in
                            lastScale = scale
                            lastOffset = offset
                        }
                )
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { val in
                            // Panning only makes sense once zoomed in.
                            guard scale > 1.0 else { return }
                            offset = clamped(
                                CGSize(
                                    width: lastOffset.width + val.translation.width,
                                    height: lastOffset.height + val.translation.height
                                ),
                                in: proxy.size
                            )
                        }
                        .onEnded { _ in lastOffset = offset }
                )
            }
            .navigationTitle("Split Loupe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("ios.splitComparison.close")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Reset") {
                        withAnimation {
                            scale = 1.0
                            lastScale = 1.0
                            offset = .zero
                            lastOffset = .zero
                            splitRatio = 0.5
                        }
                    }
                    .disabled(scale == 1.0 && offset == .zero && splitRatio == 0.5)
                    .accessibilityIdentifier("ios.splitComparison.reset")
                }
            }
        }
    }

    /// Keeps the zoomed image from being dragged out of view.
    private func clamped(_ value: CGSize, in size: CGSize) -> CGSize {
        let maxX = size.width * (scale - 1) / 2
        let maxY = size.height * (scale - 1) / 2
        return CGSize(
            width: min(max(value.width, -maxX), maxX),
            height: min(max(value.height, -maxY), maxY)
        )
    }
}
