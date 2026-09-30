import SwiftUI
import KeptoraCore

/// Visual theme for smart bucket category.
public enum SmartBucketTheme: String, Sendable, CaseIterable {
    case orange, blue, purple, indigo, green
    
    public var color: Color {
        switch self {
        case .orange: return .orange
        case .blue: return .blue
        case .purple: return .purple
        case .indigo: return .indigo
        case .green: return .green
        }
    }
}

/// Item representing a smart cluster card on the dashboard.
public struct SmartBucketCardItem: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let count: Int
    public let reclaimableBytes: Int64
    public let iconName: String
    public let theme: SmartBucketTheme
    public let isDeclutter: Bool
    
    public var iconColor: Color {
        theme.color
    }

    public init(
        id: String,
        title: String,
        subtitle: String,
        count: Int,
        reclaimableBytes: Int64,
        iconName: String,
        theme: SmartBucketTheme = .orange,
        iconColor: Color? = nil,
        isDeclutter: Bool
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.count = count
        self.reclaimableBytes = reclaimableBytes
        self.iconName = iconName
        if let iconColor {
            if iconColor == .blue { self.theme = .blue }
            else if iconColor == .purple { self.theme = .purple }
            else if iconColor == .indigo { self.theme = .indigo }
            else if iconColor == .green { self.theme = .green }
            else { self.theme = .orange }
        } else {
            self.theme = theme
        }
        self.isDeclutter = isDeclutter
    }
}

private struct SwipeSessionPayload: Identifiable {
    let id: String
    let cards: [SwipeCardItem]
}

/// Single source of truth for which extra copies belong in which smart bucket, shared by the
/// bucket counts and the swipe deck so the two can never disagree.
private enum SmartBucketRule {
    static func matches(_ bucketID: String, asset: ReviewAsset, group: ReviewGroup) -> Bool {
        let name = asset.displayName.lowercased()
        let ext = asset.fileURL.pathExtension.lowercased()
        switch bucketID {
        case "screenshots":
            let screenshotKeywords = [
                "screenshot", "screen shot", "screen_shot", "ekran resmi", "ekran goruntusu",
                "ekran görüntüsü", "bildschirmfoto", "capture d’écran", "capture d'ecran",
                "captura de pantalla", "schermafbeelding"
            ]
            let hasScreenshotName = screenshotKeywords.contains { name.contains($0) }
            let hasScreenshotPrefix = name.hasPrefix("screen") || name.hasPrefix("ekran") || name.hasPrefix("capture")
            return hasScreenshotName || hasScreenshotPrefix
        case "receipts":
            let receiptKeywords = [
                "receipt", "fatura", "kdv", "slip", "invoice", "bill",
                "rechnung", "quittung", "facture", "recibo", "beleg"
            ]
            return receiptKeywords.contains { name.contains($0) }
        case "heavy_media":
            return asset.byteCount > 40_000_000 || ["mov", "mp4", "m4v"].contains(ext)
        case "bursts":
            return group.assets.count >= 3
        default:
            return true
        }
    }
}

/// Dashboard view for intelligent categorization and smart actionable cleanup buckets.
public struct SmartBucketsDashboardView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var store: StoreEntitlementController
    
    @State private var selectedBucketID: String? = nil
    @State private var activeSwipeSession: SwipeSessionPayload? = nil
    @State private var showingNoItemsAlert: Bool = false
    @State private var isShowingExportSheet: Bool = false
    @State private var cachedCards: [SmartBucketCardItem] = []
    
    private var dynamicCards: [SmartBucketCardItem] {
        var screenshotsCount = 0
        var screenshotsBytes: Int64 = 0
        var receiptsCount = 0
        var receiptsBytes: Int64 = 0
        var heavyCount = 0
        var heavyBytes: Int64 = 0
        var burstCount = 0
        var burstBytes: Int64 = 0
        var exactCopiesCount = 0
        var exactCopiesBytes: Int64 = 0

        for group in model.duplicateGroups {
            for asset in group.assets where asset.id != group.canonicalAssetID {
                exactCopiesCount += 1
                exactCopiesBytes += asset.byteCount

                if SmartBucketRule.matches("screenshots", asset: asset, group: group) {
                    screenshotsCount += 1
                    screenshotsBytes += asset.byteCount
                }
                if SmartBucketRule.matches("receipts", asset: asset, group: group) {
                    receiptsCount += 1
                    receiptsBytes += asset.byteCount
                }
                if SmartBucketRule.matches("heavy_media", asset: asset, group: group) {
                    heavyCount += 1
                    heavyBytes += asset.byteCount
                }
                if SmartBucketRule.matches("bursts", asset: asset, group: group) {
                    burstCount += 1
                    burstBytes += asset.byteCount
                }
            }
        }

        var result: [SmartBucketCardItem] = []

        result.append(SmartBucketCardItem(
            id: "exact_duplicates",
            title: "Exact Duplicate Copies",
            subtitle: "Identical files with cryptographic byte-level match",
            count: exactCopiesCount,
            reclaimableBytes: exactCopiesBytes,
            iconName: "square.on.square.fill",
            iconColor: .orange,
            isDeclutter: true
        ))

        result.append(SmartBucketCardItem(
            id: "screenshots",
            title: "Screenshots & Grabs",
            subtitle: "Temporary captures and screen clips",
            count: screenshotsCount,
            reclaimableBytes: screenshotsBytes,
            iconName: "iphone",
            iconColor: .blue,
            isDeclutter: true
        ))

        result.append(SmartBucketCardItem(
            id: "receipts",
            title: "Receipts & Documents",
            subtitle: "Invoices, payment slips, and expense records",
            count: receiptsCount,
            reclaimableBytes: receiptsBytes,
            iconName: "receipt",
            iconColor: .orange,
            isDeclutter: true
        ))

        result.append(SmartBucketCardItem(
            id: "heavy_media",
            title: "Heavy Media & Videos",
            subtitle: "Large video files consuming high disk space",
            count: heavyCount,
            reclaimableBytes: heavyBytes,
            iconName: "film.fill",
            iconColor: .purple,
            isDeclutter: true
        ))

        result.append(SmartBucketCardItem(
            id: "bursts",
            title: "Burst Sequences",
            subtitle: "Repeated shots with multiple duplicate extras",
            count: burstCount,
            reclaimableBytes: burstBytes,
            iconName: "square.stack.3d.forward.dottedline.fill",
            iconColor: .indigo,
            isDeclutter: true
        ))

        return result
    }
    
    public init() {}
    
    public var body: some View {
        // Computed once per render or cached across duplicateGroups changes.
        let cards = cachedCards.isEmpty ? dynamicCards : cachedCards
        return ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.accentColor)
                            .font(.title2)
                        Text("Smart Categories & Clutter Clusters")
                            .font(.title2.bold())
                    }
                    
                    Text("100% on-device AI clusters your photos into actionable cleanups and beautiful highlights without sharing any data.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if model.duplicateGroups.isEmpty {
                    emptyStateCard
                } else {
                    // Storage impact summary banner
                    totalSavingsBanner(cards: cards)
                    
                    // Grid of Smart Buckets
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 16)], spacing: 16) {
                        ForEach(cards) { card in
                            SmartBucketCard(card: card, isSelected: selectedBucketID == card.id) {
                                selectedBucketID = card.id
                                startSwipeCulling(for: card.id)
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .alert("No Scanned Photos Found", isPresented: $showingNoItemsAlert) {
            Button("OK", role: .cancel) { selectedBucketID = nil }
        } message: {
            Text("Nothing in this category needs review yet. Scan a folder or your Apple Photos library from Home first, or pick another category.")
        }
        .sheet(item: $activeSwipeSession, onDismiss: { selectedBucketID = nil }) { session in
            SwipeCullingStudioView(
                items: session.cards,
                onCommitPlan: { cleanupItems in
                    let cleanupAssetIDs = cleanupItems.map { AssetID(rawValue: $0.id) }
                    model.applySwipeDecisions(cleanupAssetIDs: cleanupAssetIDs, access: store)
                    activeSwipeSession = nil
                    selectedBucketID = nil
                    model.isShowingSafetyPlan = true
                },
                onClose: {
                    activeSwipeSession = nil
                    selectedBucketID = nil
                }
            )
        }
        .onAppear { cachedCards = dynamicCards }
        .onChange(of: model.duplicateGroups.count) { _ in cachedCards = dynamicCards }
        .onChange(of: model.decisions.count) { _ in cachedCards = dynamicCards }
        .sheet(isPresented: $isShowingExportSheet) {
            let universalAssets: [UniversalMediaAsset] = model.duplicateGroups.flatMap { group in
                group.assets.map { asset in
                    UniversalMediaAsset(
                        id: asset.id.rawValue,
                        sourceID: "local",
                        reference: .file(asset.fileURL),
                        displayName: asset.displayName,
                        mediaKind: .image,
                        byteCount: asset.byteCount,
                        pixelWidth: 0,
                        pixelHeight: 0,
                        duration: nil,
                        creationDate: asset.modificationDate,
                        modificationDate: asset.modificationDate
                    )
                }
            }
            PhysicalArchiveExportSheet(
                assets: universalAssets,
                sourceURL: model.sourceURL
            ) {
                isShowingExportSheet = false
            }
        }
    }
    
    private var emptyStateCard: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(KeptoraDesign.accent.opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: 32))
                    .foregroundColor(KeptoraDesign.accent)
            }
            
            VStack(spacing: 6) {
                Text("Ready to Analyze & Group Your Library")
                    .font(.title3.bold())
                Text("Scan Apple Photos or any folder from Home. Keptora will instantly classify exact duplicates, screenshots, receipts, large videos, and bursts into fast, actionable swipe buckets.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
            }
            
            HStack(spacing: 12) {
                Button {
                    model.selectedRoute = .home
                } label: {
                    Label("Go to Home & Start Scan", systemImage: "sparkle.magnifyingglass")
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .padding(.horizontal, 24)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.03), radius: 8, y: 3)
        )
    }

    private func totalSavingsBanner(cards: [SmartBucketCardItem]) -> some View {
        // Buckets overlap (a screenshot copy is also an exact copy), so summing them would count
        // the same file several times. The exact-copy bucket contains every candidate exactly once.
        let union = cards.first { $0.id == "exact_duplicates" }
        let totalBytes = union?.reclaimableBytes ?? 0
        let totalCount = union?.count ?? 0
        
        return HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Potential Reclaimable Storage")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                Text(ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("\(totalCount) clutter items identified across \(cards.count) categories")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: { isShowingExportSheet = true }) {
                    Label("Organize in Finder", systemImage: "folder.badge.gearshape")
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button(action: { startSwipeCulling() }) {
                    Label("Start Smart Review", systemImage: "arrow.right.circle.fill")
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
        )
    }
    
    private func startSwipeCulling(for bucketID: String? = nil) {
        var items: [SwipeCardItem] = []
        
        for group in model.duplicateGroups {
            for asset in group.assets {
                let isKeeper = asset.id == group.canonicalAssetID
                // Keepers are sacred and protected; never present them as items to delete
                if isKeeper { continue }
                
                var label = "Exact Duplicate"
                var color: Color = .orange
                
                if let bucketID {
                    guard SmartBucketRule.matches(bucketID, asset: asset, group: group) else { continue }
                    switch bucketID {
                    case "screenshots": label = "Screenshot"; color = .blue
                    case "receipts": label = "Document"; color = .orange
                    case "heavy_media": label = "Heavy Video"; color = .purple
                    case "bursts": label = "Burst"; color = .indigo
                    default: break
                    }
                }
                
                items.append(SwipeCardItem(
                    id: asset.id.rawValue,
                    fileURL: asset.fileURL,
                    displayName: asset.displayName,
                    byteCount: asset.byteCount,
                    badgeLabel: label,
                    badgeColor: color
                ))
            }
        }
        
        if items.isEmpty {
            showingNoItemsAlert = true
            selectedBucketID = nil
        } else {
            activeSwipeSession = SwipeSessionPayload(id: bucketID ?? "all", cards: items)
        }
    }
}

/// A single card representing a Smart Bucket.
public struct SmartBucketCard: View {
    public let card: SmartBucketCardItem
    public let isSelected: Bool
    public let onSelect: () -> Void
    
    public init(card: SmartBucketCardItem, isSelected: Bool, onSelect: @escaping () -> Void) {
        self.card = card
        self.isSelected = isSelected
        self.onSelect = onSelect
    }
    
    public var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(card.iconColor.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: card.iconName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(card.iconColor)
                    }
                    
                    Spacer()
                    
                    Text("\(card.count) items")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.12))
                        .cornerRadius(6)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(card.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer(minLength: 0)
                
                HStack {
                    if card.reclaimableBytes > 0 {
                        Text(ByteCountFormatter.string(fromByteCount: card.reclaimableBytes, countStyle: .file))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(card.isDeclutter ? .orange : .secondary)
                    } else {
                        Text("Curated Collection")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundColor(.secondary.opacity(0.6))
                }
            }
            .padding(16)
            .frame(minHeight: 155)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.15), lineWidth: isSelected ? 2 : 1)
                    )
                    .shadow(color: .black.opacity(0.03), radius: 6, y: 2)
            )
        }
        .buttonStyle(KeptoraCardButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
