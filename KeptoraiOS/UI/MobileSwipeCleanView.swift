//
//  MobileSwipeCleanView.swift
//  KeptoraiOS
//
//  Card-swipe triage for rapid decluttering.
//  Swipe Left = Select for deletion | Swipe Right = Keep | Swipe Up = Skip
//

import SwiftUI
import KeptoraCore

public struct MobileSwipeCleanView: View {
    @EnvironmentObject private var store: MobileKeptoraStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize

    let assets: [UniversalMediaAsset]
    var onFinish: (() -> Void)? = nil

    @State private var currentIndex: Int = 0
    @State private var dragOffset: CGSize = .zero
    @State private var dragRotation: Double = 0
    @State private var history: [SwipeHistoryEntry] = []
    @State private var showReviewSheet: Bool = false

    private struct SwipeHistoryEntry {
        let index: Int
        let asset: UniversalMediaAsset
        let wasSelected: Bool
        let action: SwipeAction
    }

    private enum SwipeAction {
        case delete
        case keep
        case skip
    }

    private let deckIDs: Set<String>

    public init(assets: [UniversalMediaAsset], onFinish: (() -> Void)? = nil) {
        self.assets = assets
        self.deckIDs = Set(assets.map(\.id))
        self.onFinish = onFinish
    }

    private var currentAsset: UniversalMediaAsset? {
        guard currentIndex >= 0 && currentIndex < assets.count else { return nil }
        return assets[currentIndex]
    }

    private var nextAsset: UniversalMediaAsset? {
        let nextIndex = currentIndex + 1
        guard nextIndex >= 0 && nextIndex < assets.count else { return nil }
        return assets[nextIndex]
    }

    private var selectedInDeckCount: Int {
        store.selectedLibraryIDs.intersection(deckIDs).count
    }

    private var selectedBytesInDeck: Int64 {
        let selectedIDs = store.selectedLibraryIDs.intersection(deckIDs)
        guard !selectedIDs.isEmpty else { return 0 }
        return assets.filter { selectedIDs.contains($0.id) }
            .reduce(Int64(0)) { $0 + ($1.byteCount ?? 0) }
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                MobileAuroraBackground().ignoresSafeArea()

                if currentIndex < assets.count {
                    activeDeckView
                } else {
                    completedView
                }
            }
            .navigationTitle("Swipe Clean")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Done")) {
                        onFinish?()
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                }
                ToolbarItem(placement: .primaryAction) {
                    if selectedInDeckCount > 0 {
                        Button {
                            showReviewSheet = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "trash.fill")
                                Text(selectedInDeckCount.formatted())
                            }
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .foregroundStyle(.white)
                            .background(MobileKeptoraDesign.dangerFill, in: Capsule())
                        }
                    }
                }
            }
            .sheet(isPresented: $showReviewSheet) {
                MobileSelectionReviewSheet()
            }
        }
    }

    @ViewBuilder
    private var activeDeckView: some View {
        VStack(spacing: 12) {
            // Header progress
            HStack {
                Text(L10n.format("%lld of %lld", currentIndex + 1, assets.count))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MobileKeptoraDesign.secondaryInk)

                Spacer()

                if selectedInDeckCount > 0 {
                    Text(L10n.format("%lld marked · %@", selectedInDeckCount, ByteCountFormatter.string(fromByteCount: selectedBytesInDeck, countStyle: .file)))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MobileKeptoraDesign.danger)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)

            // Card Stack
            GeometryReader { geo in
                let cardWidth = min(geo.size.width - 32, 420)
                let cardHeight = min(geo.size.height - 20, 560)

                ZStack {
                    // Background placeholder card (next card)
                    if let next = nextAsset {
                        cardView(for: next, isCurrent: false)
                            .frame(width: cardWidth, height: cardHeight)
                            .scaleEffect(0.94)
                            .offset(y: 10)
                            .opacity(0.85)
                            .allowsHitTesting(false)
                    }

                    // Foreground active card
                    if let current = currentAsset {
                        cardView(for: current, isCurrent: true)
                            .frame(width: cardWidth, height: cardHeight)
                            .offset(dragOffset)
                            .rotationEffect(.degrees(dragRotation))
                            .gesture(dragGesture(cardWidth: cardWidth))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }

            // Hint Text
            Text("Swipe left to delete, right to keep")
                .font(.caption)
                .foregroundStyle(MobileKeptoraDesign.secondaryInk)

            // Action Buttons
            actionButtons
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        }
    }

    private func cardView(for asset: UniversalMediaAsset, isCurrent: Bool) -> some View {
        ZStack(alignment: .bottom) {
            // Card background & photo
            Color(uiColor: .secondarySystemFill)

            MobileAssetThumbnail(
                asset: asset,
                pixelSize: 1200,
                contentMode: .fit,
                allowNetwork: true,
                showsRetryButton: false
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            // Dim gradient overlay at bottom for readable text
            LinearGradient(
                colors: [.clear, .black.opacity(0.75)],
                startPoint: .center,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            // Asset info overlay
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(asset.displayName)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        HStack(spacing: 8) {
                            Text(store.sourceLabel(asset))
                            if let date = asset.captureDateDescription {
                                Text("·")
                                Text(date)
                            }
                            if let bytes = asset.byteCount {
                                Text("·")
                                Text(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.85))
                    }

                    Spacer()

                    // Selection badge if previously selected
                    if store.selectedLibraryIDs.contains(asset.id) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(MobileKeptoraDesign.danger)
                    }
                }
            }
            .padding(16)

            // Swipe indicator badges
            if isCurrent {
                swipeIndicators
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 6)
    }

    @ViewBuilder
    private var swipeIndicators: some View {
        ZStack {
            // Delete badge (Dragging Left)
            if dragOffset.width < -30 {
                VStack {
                    HStack {
                        Spacer()
                        Label("DELETE", systemImage: "trash.fill")
                            .font(.headline.weight(.black))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .foregroundStyle(.white)
                            .background(MobileKeptoraDesign.dangerFill, in: RoundedRectangle(cornerRadius: 12))
                            .opacity(min(Double(-dragOffset.width - 30) / 60.0, 1.0))
                            .rotationEffect(.degrees(12))
                            .padding(20)
                    }
                    Spacer()
                }
            }

            // Keep badge (Dragging Right)
            if dragOffset.width > 30 {
                VStack {
                    HStack {
                        Label("KEEP", systemImage: "bookmark.fill")
                            .font(.headline.weight(.black))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .foregroundStyle(.white)
                            .background(MobileKeptoraDesign.mintFill, in: RoundedRectangle(cornerRadius: 12))
                            .opacity(min(Double(dragOffset.width - 30) / 60.0, 1.0))
                            .rotationEffect(.degrees(-12))
                            .padding(20)
                        Spacer()
                    }
                    Spacer()
                }
            }

            // Skip badge (Dragging Up)
            if dragOffset.height < -40 && abs(dragOffset.width) < 50 {
                VStack {
                    Label("SKIP", systemImage: "forward.fill")
                        .font(.headline.weight(.black))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .foregroundStyle(.white)
                        .background(Color.secondary.opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
                        .opacity(min(Double(-dragOffset.height - 40) / 60.0, 1.0))
                        .padding(.top, 24)
                    Spacer()
                }
            }
        }
    }

    private func dragGesture(cardWidth: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation
                dragRotation = Double(value.translation.width / cardWidth) * 16
            }
            .onEnded { value in
                let threshold: CGFloat = 85
                if value.translation.width < -threshold {
                    swipeAction(.delete)
                } else if value.translation.width > threshold {
                    swipeAction(.keep)
                } else if value.translation.height < -100 && abs(value.translation.width) < 60 {
                    swipeAction(.skip)
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        dragOffset = .zero
                        dragRotation = 0
                    }
                }
            }
    }

    private func swipeAction(_ action: SwipeAction) {
        guard let current = currentAsset else { return }
        let wasSelected = store.selectedLibraryIDs.contains(current.id)

        history.append(SwipeHistoryEntry(index: currentIndex, asset: current, wasSelected: wasSelected, action: action))

        switch action {
        case .delete:
            let impact = UINotificationFeedbackGenerator()
            impact.notificationOccurred(.warning)
            store.selectLibraryItems([current])
            animateOut(to: -500)

        case .keep:
            let impact = UINotificationFeedbackGenerator()
            impact.notificationOccurred(.success)
            if wasSelected {
                store.replaceLibrarySelection(store.selectedLibraryIDs.subtracting([current.id]))
            }
            animateOut(to: 500)

        case .skip:
            animateOut(to: 0, y: -600)
        }
    }

    private func animateOut(to x: CGFloat, y: CGFloat = 0) {
        withAnimation(.easeOut(duration: 0.22)) {
            dragOffset = CGSize(width: x, height: y)
            dragRotation = x == 0 ? 0 : (x > 0 ? 15 : -15)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            dragOffset = .zero
            dragRotation = 0
            currentIndex += 1
        }
    }

    private func undoLast() {
        guard let last = history.popLast() else { return }
        currentIndex = last.index
        if last.action == .delete && !last.wasSelected {
            store.replaceLibrarySelection(store.selectedLibraryIDs.subtracting([last.asset.id]))
        } else if last.action == .keep && last.wasSelected {
            store.selectLibraryItems([last.asset])
        }
        withAnimation(.spring()) {
            dragOffset = .zero
            dragRotation = 0
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 20) {
            // Undo button
            Button {
                undoLast()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.title3.weight(.semibold))
                    .frame(width: 48, height: 48)
                    .foregroundStyle(history.isEmpty ? Color.secondary.opacity(0.4) : Color.primary)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(history.isEmpty)
            .accessibilityLabel("Undo last swipe")

            // Keep button
            Button {
                swipeAction(.keep)
            } label: {
                Image(systemName: "bookmark.fill")
                    .font(.title2.weight(.bold))
                    .frame(width: 58, height: 58)
                    .foregroundStyle(.white)
                    .background(MobileKeptoraDesign.mintFill, in: Circle())
                    .shadow(color: MobileKeptoraDesign.mint.opacity(0.35), radius: 8, y: 3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Keep photo")

            // Skip button
            Button {
                swipeAction(.skip)
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title3.weight(.semibold))
                    .frame(width: 48, height: 48)
                    .foregroundStyle(Color.secondary)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Skip photo")

            // Delete button
            Button {
                swipeAction(.delete)
            } label: {
                Image(systemName: "trash.fill")
                    .font(.title2.weight(.bold))
                    .frame(width: 58, height: 58)
                    .foregroundStyle(.white)
                    .background(MobileKeptoraDesign.dangerFill, in: Circle())
                    .shadow(color: MobileKeptoraDesign.danger.opacity(0.35), radius: 8, y: 3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Select for deletion")
        }
    }

    @ViewBuilder
    private var completedView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(MobileKeptoraDesign.accent)

            Text("Deck Reviewed!")
                .font(.title2.bold())

            if selectedInDeckCount > 0 {
                VStack(spacing: 6) {
                    Text(L10n.format("You marked %lld items for deletion.", selectedInDeckCount))
                        .font(.headline)
                        .foregroundStyle(MobileKeptoraDesign.danger)

                    Text(ByteCountFormatter.string(fromByteCount: selectedBytesInDeck, countStyle: .file) + " " + L10n.tr("selected"))
                        .font(.subheadline)
                        .foregroundStyle(MobileKeptoraDesign.secondaryInk)
                }
                .padding(16)
                .keptoraMobileGlass(cornerRadius: 16, tint: MobileKeptoraDesign.danger)
                .padding(.horizontal, 24)

                Button {
                    showReviewSheet = true
                } label: {
                    Text(L10n.format("Review & Clean (%lld)", selectedInDeckCount))
                }
                .buttonStyle(MobilePrimaryButtonStyle(fillsWidth: true, tint: MobileKeptoraDesign.dangerFill))
                .padding(.horizontal, 24)
            } else {
                Text("All items in this set kept safe in your library.")
                    .font(.subheadline)
                    .foregroundStyle(MobileKeptoraDesign.secondaryInk)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Button(LocalizedStringKey("Back to Gallery")) {
                onFinish?()
                dismiss()
            }
            .buttonStyle(MobileSleekActionButtonStyle(fillsWidth: true, tint: MobileKeptoraDesign.accent))
            .padding(.horizontal, 24)

            Spacer()
        }
    }
}
