import SwiftUI
import KeptoraCore
import AppKit

/// Direction of card swipe action.
public enum SwipeCullingDirection: String, Sendable {
    case keep = "keep"          // Swiped Right -> Keep photo
    case cleanup = "cleanup"    // Swiped Left -> Add to safety plan
    case skip = "skip"          // Swiped Up -> Skip for now
}

/// Recorded action for undo support.
public struct SwipeCullingHistoryAction: Sendable {
    public let item: SwipeCardItem
    public let direction: SwipeCullingDirection
}

/// Visual style for card badge overlay.
public enum SwipeCardBadgeStyle: String, Sendable, CaseIterable {
    case orange, blue, purple, green, red, gray
    
    public var color: Color {
        switch self {
        case .orange: return .orange
        case .blue: return .blue
        case .purple: return .purple
        case .green: return .green
        case .red: return .red
        case .gray: return .gray
        }
    }
}

/// Item representing a photo card in the swipe stack.
public struct SwipeCardItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let fileURL: URL
    public let displayName: String
    public let byteCount: Int64
    public let badgeLabel: String?
    public let badgeStyle: SwipeCardBadgeStyle?
    
    public init(
        id: String,
        fileURL: URL,
        displayName: String,
        byteCount: Int64 = 0,
        badgeLabel: String? = nil,
        badgeStyle: SwipeCardBadgeStyle? = nil
    ) {
        self.id = id
        self.fileURL = fileURL
        self.displayName = displayName
        self.byteCount = byteCount
        self.badgeLabel = badgeLabel
        self.badgeStyle = badgeStyle
    }

    public init(
        id: String,
        fileURL: URL,
        displayName: String,
        byteCount: Int64 = 0,
        badgeLabel: String? = nil,
        badgeColor: Color?
    ) {
        self.id = id
        self.fileURL = fileURL
        self.displayName = displayName
        self.byteCount = byteCount
        self.badgeLabel = badgeLabel
        if let badgeColor {
            if badgeColor == .orange { self.badgeStyle = .orange }
            else if badgeColor == .blue { self.badgeStyle = .blue }
            else if badgeColor == .purple { self.badgeStyle = .purple }
            else if badgeColor == .green { self.badgeStyle = .green }
            else if badgeColor == .red { self.badgeStyle = .red }
            else { self.badgeStyle = .gray }
        } else {
            self.badgeStyle = nil
        }
    }

    public var badgeColor: Color? {
        badgeStyle?.color
    }
}

/// State controller managing card stack, swipe gestures, and undo history.
@MainActor
public final class SwipeCullingState: ObservableObject {
    @Published public var remainingCards: [SwipeCardItem] = []
    @Published public var keptCards: [SwipeCardItem] = []
    @Published public var cleanupCards: [SwipeCardItem] = []
    @Published public var skippedCards: [SwipeCardItem] = []
    @Published public var history: [SwipeCullingHistoryAction] = []
    @Published public var isCompleted: Bool = false
    
    public init(items: [SwipeCardItem]) {
        self.remainingCards = items
        self.isCompleted = items.isEmpty
    }
    
    public var currentCard: SwipeCardItem? {
        remainingCards.first
    }
    
    public var totalInitialCount: Int {
        remainingCards.count + keptCards.count + cleanupCards.count + skippedCards.count
    }
    
    public var totalReclaimableBytes: Int64 {
        cleanupCards.reduce(0) { $0 + $1.byteCount }
    }
    
    public func performSwipe(_ direction: SwipeCullingDirection) {
        guard !remainingCards.isEmpty else { return }
        let item = remainingCards.removeFirst()
        
        switch direction {
        case .keep:
            keptCards.append(item)
            triggerHapticFeedback(.alignment)
        case .cleanup:
            cleanupCards.append(item)
            triggerHapticFeedback(.levelChange)
        case .skip:
            skippedCards.append(item)
            triggerHapticFeedback(.alignment)
        }
        
        history.append(SwipeCullingHistoryAction(item: item, direction: direction))
        
        if remainingCards.isEmpty {
            isCompleted = true
        }
    }
    
    public func undo() {
        guard let last = history.popLast() else { return }
        
        switch last.direction {
        case .keep:
            keptCards.removeAll { $0.id == last.item.id }
        case .cleanup:
            cleanupCards.removeAll { $0.id == last.item.id }
        case .skip:
            skippedCards.removeAll { $0.id == last.item.id }
        }
        
        remainingCards.insert(last.item, at: 0)
        isCompleted = false
        triggerHapticFeedback(.alignment)
    }

    public func recycleSkipped() {
        guard !skippedCards.isEmpty else { return }
        remainingCards.append(contentsOf: skippedCards)
        skippedCards.removeAll()
        isCompleted = false
        triggerHapticFeedback(.alignment)
    }
    
    private func triggerHapticFeedback(_ pattern: NSHapticFeedbackManager.FeedbackPattern) {
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .default)
    }
}

/// Tinder-style swipe culling studio for lightning-fast photo decluttering.
public struct SwipeCullingStudioView: View {
    // Owned here so progress survives parent re-renders (the sheet content closure is re-evaluated
    // whenever the model publishes).
    @StateObject private var state: SwipeCullingState
    public var onCommitPlan: (_ cleanupItems: [SwipeCardItem]) -> Void
    public var onClose: () -> Void
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragOffset: CGSize = .zero
    @State private var cardImages: [String: NSImage] = [:]
    @State private var isAnimating = false
    @State private var showDiscardAlert = false
    
    public init(
        items: [SwipeCardItem],
        onCommitPlan: @escaping (_ cleanupItems: [SwipeCardItem]) -> Void,
        onClose: @escaping () -> Void
    ) {
        _state = StateObject(wrappedValue: SwipeCullingState(items: items))
        self.onCommitPlan = onCommitPlan
        self.onClose = onClose
    }
    
    public var body: some View {
        ZStack {
            // Elegant background
            Color(nsColor: .windowBackgroundColor).ignoresSafeArea()
            
            // Interactive Drop Zone Halos (Left = Clean, Right = Keep)
            if !state.isCompleted {
                HStack {
                    // Left Zone Glow (Clean / Delete)
                    ZStack {
                        LinearGradient(
                            colors: [KeptoraDesign.danger.opacity(min(0.25, max(0.0, Double(-dragOffset.width) / 350.0))), Color.clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: 140)
                        
                        VStack(spacing: 8) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 30, weight: .bold))
                            Text("THROW TO CLEAN")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                        }
                        .foregroundStyle(KeptoraDesign.danger)
                        .opacity(min(1.0, max(0.0, (Double(-dragOffset.width) - 40.0) / 100.0)))
                        .padding(.leading, 24)
                    }
                    
                    Spacer()
                    
                    // Right Zone Glow (Keep)
                    ZStack {
                        LinearGradient(
                            colors: [Color.clear, KeptoraDesign.success.opacity(min(0.25, max(0.0, Double(dragOffset.width) / 350.0)))],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: 140)
                        
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 30, weight: .bold))
                            Text("THROW TO KEEP")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                        }
                        .foregroundStyle(KeptoraDesign.success)
                        .opacity(min(1.0, max(0.0, (Double(dragOffset.width) - 40.0) / 100.0)))
                        .padding(.trailing, 24)
                    }
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
            
            VStack(spacing: 16) {
                // Header Bar
                headerBar
                
                if state.isCompleted {
                    // Summary celebration screen
                    completionSummaryView
                        .transition(.scale.combined(with: .opacity))
                } else {
                    // Interactive Card Stack
                    ZStack {
                        // Background stack cards (depth effect)
                        ForEach(Array(state.remainingCards.prefix(3).enumerated().reversed()), id: \.element.id) { index, card in
                            cardView(for: card, stackIndex: index)
                        }
                    }
                    .frame(maxWidth: 580, maxHeight: 600)
                    .padding(.horizontal, 24)
                    
                    // Bottom Swipe Action Controls
                    bottomActionBar
                }
            }
            .padding(.vertical, 16)
        }
        .frame(minWidth: 750, minHeight: 680)
        .animation(reduceMotion ? .none : .spring(response: 0.35, dampingFraction: 0.75), value: state.remainingCards.count)
        .animation(reduceMotion ? .none : .spring(response: 0.35, dampingFraction: 0.75), value: state.isCompleted)
        .alert("Discard Pending Selections?", isPresented: $showDiscardAlert) {
            Button("Add to Safety Plan") {
                onCommitPlan(state.cleanupCards)
            }
            Button("Discard and Close", role: .destructive) {
                onClose()
            }
            Button("Keep Reviewing", role: .cancel) {}
        } message: {
            Text("You have \(state.cleanupCards.count) photos selected for cleanup. Closing without adding them to your Safety Plan will discard these selections.")
        }
    }
    
    // MARK: - Subviews
    
    private var headerBar: some View {
        HStack {
            Button(action: handleClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
            .keyboardShortcut(.cancelAction)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "hand.draw.fill")
                        .foregroundStyle(KeptoraDesign.accent)
                    Text("Swipe Culling Studio")
                        .font(.headline)
                }
                
                Text("Swipe Right to Keep · Swipe Left to Clean · Swipe Up to Skip")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Progress Indicator
            if !state.isCompleted {
                let reviewed = state.keptCards.count + state.cleanupCards.count + state.skippedCards.count
                let total = state.totalInitialCount
                Text("\(reviewed) of \(total) reviewed")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(.horizontal, 24)
    }
    
    private func handleClose() {
        if !state.cleanupCards.isEmpty && !state.isCompleted {
            showDiscardAlert = true
        } else {
            onClose()
        }
    }
    
    @ViewBuilder
    private func cardView(for card: SwipeCardItem, stackIndex: Int) -> some View {
        let isTop = stackIndex == 0
        let offset = isTop ? dragOffset : .zero
        let rotation = (reduceMotion || !isTop) ? 0.0 : Double(dragOffset.width / 20.0)
        let scale = isTop ? 1.0 : (stackIndex == 1 ? 0.95 : 0.90)
        let yOffset = isTop ? offset.height : CGFloat(stackIndex * 12)
        
        ZStack(alignment: .topTrailing) {
            // Card background and image
            VStack(spacing: 0) {
                ZStack {
                    Color.black.opacity(0.85)
                    
                    if let img = cardImages[card.id] {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        ProgressView()
                            .tint(.white)
                    }
                    
                    // Live Swipe Feedback Badges
                    if isTop {
                        if dragOffset.width > 40 {
                            keepBadgeOverlay
                                .opacity(min(1.0, Double(dragOffset.width / 100.0)))
                        } else if dragOffset.width < -40 {
                            cleanupBadgeOverlay
                                .opacity(min(1.0, Double(-dragOffset.width / 100.0)))
                        } else if dragOffset.height < -40 {
                            skipBadgeOverlay
                                .opacity(min(1.0, Double(-dragOffset.height / 80.0)))
                        }
                    }
                }
                .frame(maxHeight: .infinity)
                
                // Card Footer
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(card.displayName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        
                        Text(ByteCountFormatter.string(fromByteCount: card.byteCount, countStyle: .file))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    if let badge = card.badgeLabel {
                        Text(badge)
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background((card.badgeColor ?? KeptoraDesign.accent).opacity(0.15))
                            .foregroundStyle(card.badgeColor ?? KeptoraDesign.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }
                .padding(14)
                .background(Color(nsColor: .controlBackgroundColor))
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
        }
        .scaleEffect(scale)
        .rotationEffect(.degrees(rotation))
        .offset(x: offset.width, y: yOffset)
        .gesture(
            isTop ?
            DragGesture()
                .onChanged { value in
                    guard !isAnimating else { return }
                    dragOffset = value.translation
                }
                .onEnded { value in
                    let threshold: CGFloat = 110
                    let predictedX = value.predictedEndTranslation.width
                    let predictedY = value.predictedEndTranslation.height

                    let isThrowRight = value.translation.width > threshold || (value.translation.width > 40 && predictedX > 180)
                    let isThrowLeft = value.translation.width < -threshold || (value.translation.width < -40 && predictedX < -180)
                    let isThrowUp = value.translation.height < -threshold || (value.translation.height < -40 && predictedY < -180)

                    if isThrowRight {
                        commit(.keep, offset: CGSize(width: 850, height: value.translation.height))
                    } else if isThrowLeft {
                        commit(.cleanup, offset: CGSize(width: -850, height: value.translation.height))
                    } else if isThrowUp {
                        commit(.skip, offset: CGSize(width: value.translation.width, height: -850))
                    } else {
                        // Snap back to center
                        withAnimation(reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.7)) {
                            dragOffset = .zero
                        }
                    }
                } : nil
        )
        // Dragging is not available to VoiceOver / Switch Control users; expose the same actions.
        .accessibilityLabel(Text(card.displayName))
        .accessibilityAction(named: Text("Keep")) { if isTop { commit(.keep, offset: CGSize(width: 850, height: 0)) } }
        .accessibilityAction(named: Text("Add to cleanup plan")) { if isTop { commit(.cleanup, offset: CGSize(width: -850, height: 0)) } }
        .accessibilityAction(named: Text("Skip")) { if isTop { commit(.skip, offset: CGSize(width: 0, height: -850)) } }
        .task(id: card.id) {
            if cardImages[card.id] == nil {
                let url = card.fileURL
                let cardID = card.id
                let loadedImg = await Task.detached(priority: .userInitiated) { () -> NSImage? in
                    return ViewerImageLoader.image(at: url)
                }.value
                
                if let loadedImg {
                    cardImages[cardID] = loadedImg
                }
                
                // Keep image memory bounded by pruning cards beyond active window and recent undo history
                var keepIDs = Set(state.remainingCards.prefix(6).map(\.id))
                for recent in state.history.suffix(2) {
                    keepIDs.insert(recent.item.id)
                }
                for key in cardImages.keys where !keepIDs.contains(key) {
                    cardImages.removeValue(forKey: key)
                }
            }
        }
    }
    
    /// Single entry point for every swipe (drag, buttons, keys). Ignores re-entrant calls while
    /// the previous card is still flying off, so a key repeat cannot dismiss two cards.
    private func commit(_ direction: SwipeCullingDirection, offset: CGSize) {
        guard !isAnimating, state.currentCard != nil else { return }
        isAnimating = true
        withAnimation(reduceMotion ? .none : .spring(response: 0.35, dampingFraction: 0.7)) {
            dragOffset = offset
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: reduceMotion ? 0 : 220_000_000)
            state.performSwipe(direction)
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) { dragOffset = .zero }
            isAnimating = false
        }
    }

    // MARK: - Badges
    
    private var keepBadgeOverlay: some View {
        VStack {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("KEEP")
                }
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(KeptoraDesign.success)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.62))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(KeptoraDesign.success, lineWidth: 2))
                .padding(20)
                Spacer()
            }
            Spacer()
        }
    }
    
    private var cleanupBadgeOverlay: some View {
        VStack {
            HStack {
                Spacer()
                HStack(spacing: 6) {
                    Text("CLEAN")
                    Image(systemName: "trash.fill")
                }
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(KeptoraDesign.danger)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.62))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(KeptoraDesign.danger, lineWidth: 2))
                .padding(20)
            }
            Spacer()
        }
    }
    
    private var skipBadgeOverlay: some View {
        VStack {
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.circle.fill")
                Text("SKIP")
            }
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundStyle(KeptoraDesign.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.62))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(KeptoraDesign.accent, lineWidth: 2))
            .padding(.bottom, 24)
        }
    }
    
    // MARK: - Bottom Controls
    
    private var bottomActionBar: some View {
        HStack(spacing: 24) {
            // Swipe Left / Clean Button
            Button(action: {
                commit(.cleanup, offset: CGSize(width: -800, height: 0))
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "trash.fill")
                        .font(.title2)
                        .foregroundStyle(KeptoraDesign.danger)
                        .frame(width: 56, height: 56)
                        .background(KeptoraDesign.danger.opacity(0.12))
                        .clipShape(Circle())
                    Text("Clean (←)")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.leftArrow, modifiers: [])
            .keyboardShortcut(.delete, modifiers: [.command])
            
            // Undo Button
            Button(action: state.undo) {
                VStack(spacing: 4) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(Circle())
                    Text("Undo")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .disabled(state.history.isEmpty || isAnimating)
            .keyboardShortcut("z", modifiers: [.command])
            
            // Skip Button
            Button(action: {
                commit(.skip, offset: CGSize(width: 0, height: -800))
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                        .font(.headline)
                        .foregroundStyle(KeptoraDesign.accent)
                        .frame(width: 44, height: 44)
                        .background(KeptoraDesign.accent.opacity(0.12))
                        .clipShape(Circle())
                    Text("Skip (↑)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.upArrow, modifiers: [])
            
            // Swipe Right / Keep Button
            Button(action: {
                commit(.keep, offset: CGSize(width: 800, height: 0))
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.title2.bold())
                        .foregroundStyle(KeptoraDesign.success)
                        .frame(width: 56, height: 56)
                        .background(KeptoraDesign.success.opacity(0.12))
                        .clipShape(Circle())
                    Text("Keep (→)")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.rightArrow, modifiers: [])
        }
        .padding(.top, 8)
    }
    
    // MARK: - Completion Summary
    
    private var completionSummaryView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(KeptoraDesign.success.opacity(0.15))
                    .frame(width: 80, height: 80)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(KeptoraDesign.success)
            }
            
            Text("Review Batch Completed!")
                .font(.title.bold())
            
            Text("All \(state.totalInitialCount) photos have been categorized.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            // Metrics Box
            HStack(spacing: 24) {
                metricCell(title: "Kept", value: "\(state.keptCards.count)", color: KeptoraDesign.success)
                metricCell(title: "Planned to Clean", value: "\(state.cleanupCards.count)", color: KeptoraDesign.danger)
                metricCell(title: "Reclaimable Space", value: ByteCountFormatter.string(fromByteCount: state.totalReclaimableBytes, countStyle: .file), color: KeptoraDesign.warning)
            }
            .padding(18)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            
            HStack(spacing: 14) {
                if !state.skippedCards.isEmpty {
                    Button(action: state.recycleSkipped) {
                        Label("Review Skipped (\(state.skippedCards.count))", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                Button("Close", action: onClose)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                
                if !state.cleanupCards.isEmpty {
                    Button(action: { onCommitPlan(state.cleanupCards) }) {
                        Label("Add \(state.cleanupCards.count) Items to Safety Plan", systemImage: "shield.lefthalf.filled")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding(.top, 8)
        }
        .padding(32)
        .frame(maxWidth: 500)
    }
    
    private func metricCell(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
