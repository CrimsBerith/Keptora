import SwiftUI
import KeptoraCore

struct SideBySideCompareView: View {
    @EnvironmentObject private var archive: MacArchiveModel
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let group: LibraryReviewGroup
    @Binding var isPresented: LibraryReviewGroup?

    @State private var leftIndex: Int = 0
    @State private var rightIndex: Int = 1
    @State private var focusedPane: Pane = .right

    enum Pane {
        case left, right
    }

    private var assets: [UniversalMediaAsset] {
        group.assets
    }

    private var leftAsset: UniversalMediaAsset? {
        guard assets.indices.contains(leftIndex) else { return assets.first }
        return assets[leftIndex]
    }

    private var rightAsset: UniversalMediaAsset? {
        guard assets.count > 1 else { return nil }
        if assets.indices.contains(rightIndex), rightIndex != leftIndex {
            return assets[rightIndex]
        }
        if let fallback = assets.indices.first(where: { $0 != leftIndex }) {
            return assets[fallback]
        }
        return nil
    }

    private var currentKeeperID: String {
        archive.decisions.keeper(in: group)
    }

    var body: some View {
        ZStack {
            KeptoraBackdrop()

            VStack(spacing: 0) {
                headerBar
                Divider()
                comparisonContent
                    .padding(16)
                if assets.count > 2 {
                    Divider()
                    assetThumbnailStrip
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background {
                            if reduceTransparency {
                                KeptoraDesign.canvas
                            } else {
                                Rectangle().fill(.ultraThinMaterial)
                            }
                        }
                }
            }
        }
        .frame(minWidth: 850, minHeight: 620)
    }

    private var headerBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.tr(String.LocalizationValue(group.titleKey)))
                    .font(.headline)
                Text(L10n.plural("%lld items in this group", assets.count))
                    .font(.caption)
                    .foregroundStyle(KeptoraDesign.secondaryInk)
            }
            Spacer()

            if assets.count > 1 {
                Button {
                    let temp = leftIndex
                    leftIndex = rightIndex
                    rightIndex = temp
                } label: {
                    Label("Swap Sides", systemImage: "arrow.left.arrow.right")
                }
                .controlSize(.regular)
            }

            Button("Done") {
                isPresented = nil
            }
            .keyboardShortcut(.cancelAction)
            .controlSize(.regular)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background {
            if reduceTransparency {
                KeptoraDesign.canvas
            } else {
                Rectangle().fill(.ultraThinMaterial)
            }
        }
    }

    private var comparisonContent: some View {
        HStack(spacing: 16) {
            if let leftAsset {
                assetComparisonPane(asset: leftAsset, isLeft: true)
                    .padding(12)
                    .keptoraGlass(cornerRadius: 16, tint: KeptoraDesign.accent, isSelected: focusedPane == .left)
                    .onTapGesture { focusedPane = .left }
            }
            Divider()
            if let rightAsset {
                assetComparisonPane(asset: rightAsset, isLeft: false)
                    .padding(12)
                    .keptoraGlass(cornerRadius: 16, tint: KeptoraDesign.violet, isSelected: focusedPane == .right)
                    .onTapGesture { focusedPane = .right }
            } else {
                Text("No second item to compare")
                    .font(.callout)
                    .foregroundStyle(KeptoraDesign.secondaryInk)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(12)
                    .keptoraGlass(cornerRadius: 16)
            }
        }
    }

    private func assetComparisonPane(asset: UniversalMediaAsset, isLeft: Bool) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text(isLeft ? "Left Pane" : "Right Pane")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(isLeft ? Color.blue : Color.purple)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background((isLeft ? Color.blue : Color.purple).opacity(0.12), in: Capsule())

                if asset.id == currentKeeperID {
                    Label("Keeper", systemImage: "star.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(KeptoraDesign.warning)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(KeptoraDesign.warning.opacity(0.15), in: Capsule())
                }
                Spacer()
                if archive.selection.contains(asset.id) {
                    Label("Marked for Removal", systemImage: "trash")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(KeptoraDesign.danger)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(KeptoraDesign.danger.opacity(0.15), in: Capsule())
                } else {
                    Label("Kept", systemImage: "checkmark.shield")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(KeptoraDesign.success)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(KeptoraDesign.success.opacity(0.15), in: Capsule())
                }
            }

            MacPhotosThumbnail(asset: asset, pixelSize: 1600, fit: true, allowNetwork: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2), lineWidth: 1))

            metadataCard(for: asset, other: isLeft ? rightAsset : leftAsset, isLeft: isLeft)

            HStack(spacing: 10) {
                Button {
                    archive.keep(asset, in: group)
                } label: {
                    Label("Keep This", systemImage: "star")
                }
                .buttonStyle(.borderedProminent)
                .tint(KeptoraDesign.accentFill)

                Button {
                    archive.toggleSelection(asset)
                } label: {
                    Text(archive.selection.contains(asset.id) ? LocalizedStringKey("Deselect") : LocalizedStringKey("Select for Removal"))
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func metadataCard(for asset: UniversalMediaAsset, other: UniversalMediaAsset?, isLeft: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(asset.displayName)
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Text(archive.sourceLabel(asset))
                    .font(.caption2)
                    .foregroundStyle(KeptoraDesign.secondaryInk)
            }

            HStack {
                Text("Dimensions:")
                    .font(.caption2)
                    .foregroundStyle(KeptoraDesign.secondaryInk)
                Text(verbatim: "\(asset.pixelWidth) × \(asset.pixelHeight)")
                    .font(.caption.weight(.medium))
                if let other, (asset.pixelWidth * asset.pixelHeight) > (other.pixelWidth * other.pixelHeight) {
                    Text("Higher Res")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(KeptoraDesign.success)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(KeptoraDesign.success.opacity(0.12), in: Capsule())
                }
                Spacer()
            }

            HStack {
                Text("File Size:")
                    .font(.caption2)
                    .foregroundStyle(KeptoraDesign.secondaryInk)
                if let bytes = asset.byteCount {
                    Text(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
                        .font(.caption.weight(.medium))
                    if let otherBytes = other?.byteCount, bytes > otherBytes {
                        Text("Larger")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color.blue)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.12), in: Capsule())
                    }
                } else {
                    Text("Unknown")
                        .font(.caption)
                }
                Spacer()
            }

            if let date = asset.context?.captureDate ?? asset.creationDate {
                HStack {
                    Text("Captured:")
                        .font(.caption2)
                        .foregroundStyle(KeptoraDesign.secondaryInk)
                    Text(date.formatted(date: .abbreviated, time: .standard))
                        .font(.caption)
                    Spacer()
                }
            }

            if let camera = asset.context?.camera {
                HStack {
                    Text("Camera:")
                        .font(.caption2)
                        .foregroundStyle(KeptoraDesign.secondaryInk)
                    Text(camera)
                        .font(.caption)
                        .lineLimit(1)
                    Spacer()
                }
            }
        }
        .padding(10)
        .keptoraGlass(cornerRadius: 10, tint: isLeft ? KeptoraDesign.accent : KeptoraDesign.violet)
    }

    private var assetThumbnailStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Click a photo to place in:")
                    .font(.caption2)
                    .foregroundStyle(KeptoraDesign.secondaryInk)
                Button("Left Pane") { focusedPane = .left }
                    .font(.caption2.weight(focusedPane == .left ? .bold : .regular))
                    .foregroundStyle(focusedPane == .left ? Color.blue : KeptoraDesign.secondaryInk)
                Text(verbatim: "·")
                    .font(.caption2)
                    .foregroundStyle(KeptoraDesign.secondaryInk)
                Button("Right Pane") { focusedPane = .right }
                    .font(.caption2.weight(focusedPane == .right ? .bold : .regular))
                    .foregroundStyle(focusedPane == .right ? Color.purple : KeptoraDesign.secondaryInk)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(assets.enumerated()), id: \.element.id) { index, asset in
                        Button {
                            if focusedPane == .left {
                                if index == rightIndex {
                                    rightIndex = leftIndex
                                }
                                leftIndex = index
                                focusedPane = .right
                            } else {
                                if index == leftIndex {
                                    leftIndex = rightIndex
                                }
                                rightIndex = index
                                focusedPane = .left
                            }
                        } label: {
                            VStack(spacing: 4) {
                                MacPhotosThumbnail(asset: asset, pixelSize: 120, fit: false, allowNetwork: false)
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(
                                                index == leftIndex ? Color.blue :
                                                (index == rightIndex ? Color.purple : Color.clear),
                                                lineWidth: 2
                                            )
                                    )
                                if index == leftIndex {
                                    Text("Left")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(Color.blue)
                                } else if index == rightIndex {
                                    Text("Right")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(Color.purple)
                                } else {
                                    Text(verbatim: "#\(index + 1)")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(KeptoraDesign.secondaryInk)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
}