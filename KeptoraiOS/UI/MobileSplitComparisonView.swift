import KeptoraCore
import SwiftUI

/// Interactive Split-Slider Loupe that allows side-by-side / overlapping pixel comparison
/// between two visually similar images with synchronized pinch-to-zoom.
public struct MobileSplitComparisonView: View {
    public let assetA: UniversalMediaAsset
    public let assetB: UniversalMediaAsset
    
    @Environment(\.dismiss) private var dismiss
    @State private var splitRatio: CGFloat = 0.5
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    public init(assetA: UniversalMediaAsset, assetB: UniversalMediaAsset) {
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
                    MobileAssetThumbnail(asset: assetB)
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(offset)
                        .frame(width: width, height: height)
                    
                    // Foreground: Image A (Left side clipped by slider)
                    MobileAssetThumbnail(asset: assetA)
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(offset)
                        .frame(width: width, height: height)
                        .mask(
                            HStack(spacing: 0) {
                                Rectangle().frame(width: max(0, width * splitRatio))
                                Spacer(minLength: 0)
                            }
                        )
                    
                    // Interactive Divider Bar
                    Rectangle()
                        .fill(Color.white.opacity(0.85))
                        .frame(width: 2.5)
                        .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 0)
                        .position(x: width * splitRatio, y: height / 2)
                        .overlay(
                            Circle()
                                .fill(Color.white)
                                .frame(width: 32, height: 32)
                                .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
                                .overlay(
                                    Image(systemName: "arrow.left.and.right")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Color.black)
                                )
                                .position(x: width * splitRatio, y: height / 2)
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let newRatio = value.location.x / width
                                    splitRatio = min(max(newRatio, 0.05), 0.95)
                                }
                        )
                    
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
                .clipped()
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { val in scale = min(max(lastScale * val, 1.0), 6.0) }
                        .onEnded { _ in lastScale = scale }
                )
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { val in
                            offset = CGSize(
                                width: lastOffset.width + val.translation.width,
                                height: lastOffset.height + val.translation.height
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
                    .accessibilityIdentifier("ios.splitComparison.reset")
                }
            }
        }
    }
}
