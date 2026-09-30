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

/// Item representing a photo card in the swipe stack.
public struct SwipeCardItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let fileURL: URL
    public let displayName: String
    public let byteCount: Int64
    public let badgeLabel: String?
    public let badgeColor: Color?
    
    public init(
        id: String,
        fileURL: URL,
        displayName: String,
        byteCount: Int64 = 0,
        badgeLabel: String? = nil,
        badgeColor: Color? = nil
    ) {
        self.id = id
        self.fileURL = fileURL
        self.displayName = displayName
        self.byteCount = byteCount
        self.badgeLabel = badgeLabel
        self.badgeColor = badgeColor
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
    
    private func triggerHapticFeedback(_ pattern: NSHapticFeedbackManager.FeedbackPattern) {
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .default)
    }
}

/// Tinder-style swipe culling studio for lightning-fast photo decluttering.
public struct SwipeCullingStudioView: View {
    @ObservedObject public var state: SwipeCullingState
    public var onCommitPlan: (_ cleanupItems: [SwipeCardItem]) -> Void
    public var onClose: () -> Void
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragOffset: CGSize = .zero
    @State private var cardImages: [String: NSImage] = [:]
    
    public init(
        state: SwipeCullingState,
        onCommitPlan: @escaping (_ cleanupItems: [SwipeCardItem]) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.state = state
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
                            colors: [Color.red.opacity(min(0.25, max(0.0, Double(-dragOffset.width) / 350.0))), Color.clear],
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
                        .foregroundColor(.red)
                        .opacity(min(1.0, max(0.0, (Double(-dragOffset.width) - 40.0) / 100.0)))
                        .padding(.leading, 24)
                    }
                    
                    Spacer()
                    
                    // Right Zone Glow (Keep)
                    ZStack {
                        LinearGradient(
                            colors: [Color.clear, Color.green.opacity(min(0.25, max(0.0, Double(dragOffset.width) / 350.0)))],
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
                        .foregroundColor(.green)
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
    }
    
    // MARK: - Subviews
    
    private var headerBar: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "hand.draw.fill")
                        .foregroundColor(.accentColor)
                    Text("Swipe Culling Studio")
                        .font(.headline)
                }
                
                Text("Swipe Right to Keep · Swipe Left to Clean · Swipe Up to Skip")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal, 24)
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
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Text(ByteCountFormatter.string(fromByteCount: card.byteCount, countStyle: .file))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if let badge = card.badgeLabel {
                        Text(badge)
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background((card.badgeColor ?? .accentColor).opacity(0.15))
                            .foregroundColor(card.badgeColor ?? .accentColor)
                            .cornerRadius(6)
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
                        // Throw Right -> Keep
                        withAnimation(reduceMotion ? .none : .spring(response: 0.35, dampingFraction: 0.7)) {
                            dragOffset = CGSize(width: 850, height: value.translation.height)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            state.performSwipe(.keep)
                            dragOffset = .zero
                        }
                    } else if isThrowLeft {
                        // Throw Left -> Clean / Delete
                        withAnimation(reduceMotion ? .none : .spring(response: 0.35, dampingFraction: 0.7)) {
                            dragOffset = CGSize(width: -850, height: value.translation.height)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            state.performSwipe(.cleanup)
                            dragOffset = .zero
                        }
                    } else if isThrowUp {
                        // Throw Up -> Skip
                        withAnimation(reduceMotion ? .none : .spring(response: 0.35, dampingFraction: 0.7)) {
                            dragOffset = CGSize(width: value.translation.width, height: -850)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            state.performSwipe(.skip)
                            dragOffset = .zero
                        }
                    } else {
                        // Snap back to center
                        withAnimation(reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.7)) {
                            dragOffset = .zero
                        }
                    }
                } : nil
        )
        .task(id: card.id) {
            if cardImages[card.id] == nil {
                let url = card.fileURL
                let cardID = card.id
                let loadedImg = await Task.detached(priority: .userInitiated) { () -> NSImage? in
                    return NSImage(contentsOf: url)
                }.value
                
                if let loadedImg {
                    cardImages[cardID] = loadedImg
                }
                
                // Keep image memory bounded by pruning cards beyond active window
                let activeIDs = Set(state.remainingCards.prefix(6).map(\.id))
                for key in cardImages.keys where !activeIDs.contains(key) {
                    cardImages.removeValue(forKey: key)
                }
            }
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
                .foregroundColor(.green)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green, lineWidth: 2))
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
                .foregroundColor(.red)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.red, lineWidth: 2))
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
            .foregroundColor(.blue)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blue, lineWidth: 2))
            .padding(.bottom, 24)
        }
    }
    
    // MARK: - Bottom Controls
    
    private var bottomActionBar: some View {
        HStack(spacing: 24) {
            // Swipe Left / Clean Button
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    dragOffset = CGSize(width: -800, height: 0)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    state.performSwipe(.cleanup)
                    dragOffset = .zero
                }
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "trash.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                        .frame(width: 56, height: 56)
                        .background(Color.red.opacity(0.12))
                        .clipShape(Circle())
                    Text("Clean (←/⌫)")
                        .font(.caption2.bold())
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.leftArrow, modifiers: [])
            .keyboardShortcut(.delete, modifiers: [])
            
            // Undo Button
            Button(action: state.undo) {
                VStack(spacing: 4) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .frame(width: 44, height: 44)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(Circle())
                    Text("Undo")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            .disabled(state.history.isEmpty)
            .keyboardShortcut("z", modifiers: [.command])
            
            // Skip Button
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    dragOffset = CGSize(width: 0, height: -800)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    state.performSwipe(.skip)
                    dragOffset = .zero
                }
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                        .font(.headline)
                        .foregroundColor(.blue)
                        .frame(width: 44, height: 44)
                        .background(Color.blue.opacity(0.12))
                        .clipShape(Circle())
                    Text("Skip (↑)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.upArrow, modifiers: [])
            
            // Swipe Right / Keep Button
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    dragOffset = CGSize(width: 800, height: 0)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    state.performSwipe(.keep)
                    dragOffset = .zero
                }
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.title2.bold())
                        .foregroundColor(.green)
                        .frame(width: 56, height: 56)
                        .background(Color.green.opacity(0.12))
                        .clipShape(Circle())
                    Text("Keep (→)")
                        .font(.caption2.bold())
                        .foregroundColor(.secondary)
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
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 80, height: 80)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.green)
            }
            
            Text("Review Batch Completed!")
                .font(.title.bold())
            
            Text("You swiped through \(state.totalInitialCount) photos in record time.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Metrics Box
            HStack(spacing: 24) {
                metricCell(title: "Kept", value: "\(state.keptCards.count)", color: .green)
                metricCell(title: "Planned to Clean", value: "\(state.cleanupCards.count)", color: .red)
                metricCell(title: "Reclaimable Space", value: ByteCountFormatter.string(fromByteCount: state.totalReclaimableBytes, countStyle: .file), color: .orange)
            }
            .padding(18)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(14)
            
            HStack(spacing: 14) {
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
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
