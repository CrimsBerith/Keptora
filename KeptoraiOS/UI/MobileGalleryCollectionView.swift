import KeptoraCore
@preconcurrency import AVFoundation
import ImageIO
import Photos
import SwiftUI
import TipKit
import UIKit

// UIKit photo grid for the library screen.
//
// `LazyVGrid` rebuilt and diffed every visible cell on each store change and had no cell
// reuse or prefetching. This grid uses `UICollectionView` the way Photos does: reusable
// UIKit cells, diffable data source applied only when the gallery projection changes,
// in-place refresh of visible cells for selection/progress changes, and PhotoKit
// prefetching ahead of the scroll position. Rows that are not photos (the header, block
// titles, group actions) stay SwiftUI through `UIHostingConfiguration`.

// MARK: - Content

struct MobileGalleryEntry {
    let asset: UniversalMediaAsset
    var groups: [LibraryReviewGroup] = []
    var keeperBadge: String? = nil
}

/// A titled run of grid cells, optionally followed by full-width rows (group actions).
struct MobileGalleryBlock {
    let id: String
    let hasHeader: Bool
    let entries: [MobileGalleryEntry]
    let footerIDs: [String]

    static func dateSections(_ sections: [MobileGallerySection]) -> [MobileGalleryBlock] {
        sections.map { section in
            MobileGalleryBlock(
                id: "date:\(section.id)",
                hasHeader: true,
                entries: section.assets.map { MobileGalleryEntry(asset: $0) },
                footerIDs: []
            )
        }
    }
}

/// Everything a cell reads. Sets and dictionaries are copy-on-write, so building this per
/// update does not copy them.
struct MobileGalleryCellContext {
    var selectedIDs: Set<String> = []
    var protectedIDs: Set<String> = []
    var quality: [String: QualityAssessment] = [:]
    /// A scan or analysis is running; "Keep This" waits for it.
    var isBusy = false
    var isCleaningUp = false
    var sourceLabel: (UniversalMediaAsset) -> String = { _ in "" }
}

struct MobileGalleryActions {
    var toggleSelection: (UniversalMediaAsset) -> Void
    var selectFromMenu: (UniversalMediaAsset) -> Void
    var keep: (UniversalMediaAsset, [LibraryReviewGroup]) -> Void
    var showLarge: (UniversalMediaAsset) -> Void
    var swipeCleanFrom: (UniversalMediaAsset) -> Void
    var unprotectAndSelect: (UniversalMediaAsset) -> Void
    var toggleProtection: (UniversalMediaAsset) -> Void
    var protectGroup: (LibraryReviewGroup) -> Void
    var refresh: () async -> Void
}

struct MobileGalleryCellState: Equatable {
    var selected = false
    var protected = false
    /// Localization key of the keeper badge, when this item is the suggested keeper.
    var keeperLabel: String?
    var showsKeep = false
    var keepEnabled = true
    var accessibilityLabel = ""
}

// MARK: - Representable

struct MobileGalleryCollectionView: UIViewControllerRepresentable {
    /// Full-width SwiftUI content above the grid (status, filters, batch actions).
    let top: () -> AnyView
    /// Built only when `structureVersion` changes.
    let blocks: () -> [MobileGalleryBlock]
    /// Change this whenever the set or order of blocks, items or rows changes.
    let structureVersion: Int
    let blockHeader: (_ blockID: String) -> AnyView
    let footer: (_ blockID: String, _ footerID: String) -> AnyView
    let minimumCellWidth: CGFloat
    let cellContext: MobileGalleryCellContext
    let actions: MobileGalleryActions

    func makeCoordinator() -> MobileGalleryCoordinator { MobileGalleryCoordinator() }

    func makeUIViewController(context: Context) -> MobileGalleryViewController {
        let controller = MobileGalleryViewController()
        context.coordinator.attach(to: controller.collectionView)
        context.coordinator.update(with: self)
        return controller
    }

    func updateUIViewController(_ controller: MobileGalleryViewController, context: Context) {
        context.coordinator.update(with: self)
    }
}

final class MobileGalleryViewController: UIViewController {
    let collectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())

    override func loadView() {
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.keyboardDismissMode = .onDrag
        collectionView.accessibilityIdentifier = "ios.archive.gallery"
        view = collectionView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
    }
}

// MARK: - Coordinator

@MainActor
final class MobileGalleryCoordinator: NSObject, UICollectionViewDelegate, UICollectionViewDataSourcePrefetching {
    enum Section: Hashable {
        case top
        case title(String)
        case grid(String)
        case footers(String)
    }

    enum Item: Hashable {
        case top
        case title(String)
        case asset(block: String, id: String)
        case footer(block: String, id: String)
    }

    private weak var collectionView: UICollectionView?
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>?
    private var configuration: MobileGalleryCollectionView?
    private var appliedStructureVersion: Int?
    private var entries: [Item: MobileGalleryEntry] = [:]
    private var entryByAssetID: [String: MobileGalleryEntry] = [:]
    private var minimumCellWidth: CGFloat = 106
    private let loader = MobileGalleryThumbnailLoader.shared
    private let refreshControl = UIRefreshControl()

    func attach(to collectionView: UICollectionView) {
        self.collectionView = collectionView
        collectionView.collectionViewLayout = makeLayout()
        collectionView.delegate = self
        collectionView.prefetchDataSource = self
        collectionView.isPrefetchingEnabled = true
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        collectionView.refreshControl = refreshControl

        let assetRegistration = UICollectionView.CellRegistration<MobileGalleryAssetCell, Item> { [weak self] cell, _, item in
            self?.configureAsset(cell, item: item, reloadImage: true)
        }
        let rowRegistration = UICollectionView.CellRegistration<UICollectionViewCell, Item> { [weak self] cell, _, item in
            self?.configureRow(cell, item: item)
        }
        dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView) { collectionView, indexPath, item in
            if case .asset = item {
                return collectionView.dequeueConfiguredReusableCell(using: assetRegistration, for: indexPath, item: item)
            }
            return collectionView.dequeueConfiguredReusableCell(using: rowRegistration, for: indexPath, item: item)
        }
    }

    func update(with configuration: MobileGalleryCollectionView) {
        self.configuration = configuration
        if minimumCellWidth != configuration.minimumCellWidth {
            minimumCellWidth = configuration.minimumCellWidth
            collectionView?.collectionViewLayout.invalidateLayout()
        }
        if appliedStructureVersion != configuration.structureVersion {
            appliedStructureVersion = configuration.structureVersion
            applyStructure(configuration.blocks())
        }
        refreshVisibleCells()
    }

    private func applyStructure(_ blocks: [MobileGalleryBlock]) {
        guard let dataSource else { return }
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        var newEntries: [Item: MobileGalleryEntry] = [:]
        var byAsset: [String: MobileGalleryEntry] = [:]
        snapshot.appendSections([.top])
        snapshot.appendItems([.top], toSection: .top)
        // Diffable data sources crash on duplicate identifiers; projections should not
        // produce them, but a repeated block or item is skipped rather than trusted.
        var seenBlocks = Set<String>()
        for block in blocks where seenBlocks.insert(block.id).inserted {
            if block.hasHeader {
                snapshot.appendSections([.title(block.id)])
                snapshot.appendItems([.title(block.id)], toSection: .title(block.id))
            }
            var seenAssets = Set<String>()
            var items: [Item] = []
            items.reserveCapacity(block.entries.count)
            for entry in block.entries where seenAssets.insert(entry.asset.id).inserted {
                let item = Item.asset(block: block.id, id: entry.asset.id)
                items.append(item)
                newEntries[item] = entry
                if byAsset[entry.asset.id] == nil { byAsset[entry.asset.id] = entry }
            }
            if !items.isEmpty {
                snapshot.appendSections([.grid(block.id)])
                snapshot.appendItems(items, toSection: .grid(block.id))
            }
            var seenFooters = Set<String>()
            let footers = block.footerIDs.filter { seenFooters.insert($0).inserted }.map { Item.footer(block: block.id, id: $0) }
            if !footers.isEmpty {
                snapshot.appendSections([.footers(block.id)])
                snapshot.appendItems(footers, toSection: .footers(block.id))
            }
        }
        entries = newEntries
        entryByAssetID = byAsset
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    /// Selection, protection, scan state and the SwiftUI rows change far more often than the
    /// grid structure. Only on-screen cells are touched, and asset cells skip work when
    /// their state is unchanged.
    private func refreshVisibleCells() {
        guard let collectionView, let dataSource else { return }
        for indexPath in collectionView.indexPathsForVisibleItems {
            guard let item = dataSource.itemIdentifier(for: indexPath),
                  let cell = collectionView.cellForItem(at: indexPath) else { continue }
            if case .asset = item {
                if let cell = cell as? MobileGalleryAssetCell { configureAsset(cell, item: item, reloadImage: false) }
            } else {
                configureRow(cell, item: item)
            }
        }
    }

    private func cellState(for entry: MobileGalleryEntry, context: MobileGalleryCellContext) -> MobileGalleryCellState {
        let asset = entry.asset
        let selected = context.selectedIDs.contains(asset.id)
        let kept = !selected && entry.keeperBadge != nil
        let keeperKey = entry.keeperBadge ?? "Suggested Keep"
        let protected = context.protectedIDs.contains(asset.id)
        var spoken = [asset.displayName, context.sourceLabel(asset)]
        if asset.mediaKind == .video { spoken.append(asset.formattedDuration) }
        if let finding = context.quality[asset.id]?.findings.first { spoken.append(L10n.tr(String.LocalizationValue(finding.titleKey))) }
        if kept { spoken.append(L10n.tr(String.LocalizationValue(keeperKey))) }
        if protected { spoken.append(L10n.tr("Protected")) }
        return MobileGalleryCellState(
            selected: selected,
            protected: protected,
            keeperLabel: kept ? keeperKey : nil,
            showsKeep: !entry.groups.isEmpty && !kept,
            keepEnabled: !context.isBusy && !context.isCleaningUp,
            accessibilityLabel: spoken.joined(separator: ", ")
        )
    }

    private func configureAsset(_ cell: MobileGalleryAssetCell, item: Item, reloadImage: Bool) {
        guard let configuration, let entry = entries[item] else { return }
        let state = cellState(for: entry, context: configuration.cellContext)
        cell.apply(asset: entry.asset, state: state, loader: loader)
        cell.onKeep = { [weak self] in
            guard let self, let current = self.configuration, !current.cellContext.isBusy else { return }
            current.actions.keep(entry.asset, entry.groups)
        }
    }

    private func configureRow(_ cell: UICollectionViewCell, item: Item) {
        guard let configuration else { return }
        let view: AnyView
        switch item {
        case .top: view = configuration.top()
        case .title(let id): view = configuration.blockHeader(id)
        case .footer(let block, let id): view = configuration.footer(block, id)
        case .asset: return
        }
        cell.contentConfiguration = UIHostingConfiguration { view }.margins(.all, 0)
        cell.backgroundConfiguration = .clear()
    }

    @objc private func handleRefresh() {
        guard let refresh = configuration?.actions.refresh else { refreshControl.endRefreshing(); return }
        Task { @MainActor [weak self] in
            await refresh()
            self?.refreshControl.endRefreshing()
        }
    }

    // MARK: Layout

    private func makeLayout() -> UICollectionViewCompositionalLayout {
        // The provider closure is formed here, on the main actor, and UIKit calls it there.
        UICollectionViewCompositionalLayout { [weak self] index, environment in
            guard let self, let section = self.dataSource?.sectionIdentifier(for: index) else {
                return Self.rowSection(top: 0, bottom: 0, spacing: 0)
            }
            switch section {
            case .top: return Self.rowSection(top: 16, bottom: 18, spacing: 0)
            case .title: return Self.rowSection(top: 4, bottom: 10, spacing: 0)
            case .grid: return self.gridSection(environment)
            case .footers: return Self.rowSection(top: 10, bottom: 18, spacing: 10)
            }
        }
    }

    private static func rowSection(top: CGFloat, bottom: CGFloat, spacing: CGFloat) -> NSCollectionLayoutSection {
        let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(120))
        let item = NSCollectionLayoutItem(layoutSize: size)
        let group = NSCollectionLayoutGroup.vertical(layoutSize: size, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = spacing
        section.contentInsets = NSDirectionalEdgeInsets(top: top, leading: 12, bottom: bottom, trailing: 12)
        return section
    }

    /// Same column rule as `GridItem(.adaptive(minimum:), spacing: 4)`: as many columns of at
    /// least `minimumCellWidth` as fit, square cells.
    private func gridSection(_ environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let spacing: CGFloat = 4
        let width = max(environment.container.effectiveContentSize.width - 24, 1)
        let columns = max(1, Int((width + spacing) / (minimumCellWidth + spacing)))
        let side = floor((width - spacing * CGFloat(columns - 1)) / CGFloat(columns))
        let itemSize = NSCollectionLayoutSize(widthDimension: .absolute(side), heightDimension: .absolute(side))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(side))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, repeatingSubitem: item, count: columns)
        group.interItemSpacing = .fixed(spacing)
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = spacing
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12)
        return section
    }

    // MARK: Delegate

    private func entry(at indexPath: IndexPath) -> MobileGalleryEntry? {
        guard let item = dataSource?.itemIdentifier(for: indexPath), case .asset = item else { return nil }
        return entries[item]
    }

    func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        entry(at: indexPath) != nil && configuration?.cellContext.isCleaningUp == false
    }

    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        entry(at: indexPath) != nil && configuration?.cellContext.isCleaningUp == false
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: false)
        guard let entry = entry(at: indexPath), let configuration, !configuration.cellContext.isCleaningUp else { return }
        configuration.actions.toggleSelection(entry.asset)
    }

    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemsAt indexPaths: [IndexPath], point: CGPoint) -> UIContextMenuConfiguration? {
        guard indexPaths.count == 1, let indexPath = indexPaths.first, let entry = entry(at: indexPath),
              let configuration, !configuration.cellContext.isCleaningUp else { return nil }
        let asset = entry.asset
        let actions = configuration.actions
        let state = cellState(for: entry, context: configuration.cellContext)
        let sourceLabel = configuration.cellContext.sourceLabel(asset)
        // Built here on the main actor; the providers only hand them over.
        let menu = Self.menu(asset: asset, groups: entry.groups, state: state, actions: actions)
        let preview = UIHostingController(rootView: MobileAssetPreview(asset: asset, sourceLabel: sourceLabel))
        preview.view.backgroundColor = .clear
        preview.preferredContentSize = preview.sizeThatFits(in: CGSize(width: 340, height: 800))
        return UIContextMenuConfiguration(identifier: asset.id as NSString,
                                          previewProvider: { preview },
                                          actionProvider: { _ in menu })
    }

    private static func menu(asset: UniversalMediaAsset, groups: [LibraryReviewGroup], state: MobileGalleryCellState,
                             actions: MobileGalleryActions) -> UIMenu {
        var items: [UIMenuElement] = []
        items.append(UIAction(title: L10n.tr("View Large"), image: UIImage(systemName: "arrow.up.left.and.arrow.down.right")) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { actions.showLarge(asset) }
        })
        items.append(UIAction(title: L10n.tr("Swipe Clean from Here"), image: UIImage(systemName: "hand.draw")) { _ in
            actions.swipeCleanFrom(asset)
        })
        if state.showsKeep {
            items.append(UIAction(title: L10n.tr("Keep This"), image: UIImage(systemName: "star.fill")) { _ in
                actions.keep(asset, groups)
            })
        }
        if state.protected {
            items.append(UIAction(title: L10n.tr("Unprotect and Select"), image: UIImage(systemName: "lock.open")) { _ in
                actions.unprotectAndSelect(asset)
            })
        } else {
            items.append(UIAction(title: (state.selected ? L10n.tr("Deselect") : L10n.tr("Select")),
                                  image: UIImage(systemName: state.selected ? "circle" : "checkmark.circle")) { _ in
                actions.selectFromMenu(asset)
            })
        }
        items.append(UIAction(title: (state.protected ? L10n.tr("Unprotect Photo") : L10n.tr("Protect Photo")),
                              image: UIImage(systemName: state.protected ? "lock.open" : "lock")) { _ in
            actions.toggleProtection(asset)
        })
        for group in groups {
            items.append(UIAction(title: L10n.tr("Protect Group"), image: UIImage(systemName: "lock.rectangle.stack")) { _ in
                actions.protectGroup(group)
            })
        }
        return UIMenu(children: items)
    }

    func collectionView(_ collectionView: UICollectionView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration,
                        animator: UIContextMenuInteractionCommitAnimating) {
        guard let id = configuration.identifier as? NSString, let entry = entryByAssetID[id as String],
              let actions = self.configuration?.actions else { return }
        let asset = entry.asset
        animator.addCompletion { actions.showLarge(asset) }
    }

    // MARK: Prefetching

    private func assets(at indexPaths: [IndexPath]) -> [UniversalMediaAsset] {
        indexPaths.compactMap { entry(at: $0)?.asset }
    }

    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        loader.startCaching(assets(at: indexPaths))
    }

    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        loader.stopCaching(assets(at: indexPaths))
    }
}

// MARK: - Asset cell

final class MobileGalleryAssetCell: UICollectionViewCell {
    var onKeep: (() -> Void)?

    private let container = UIView()
    private let imageView = UIImageView()
    private let placeholderView = UIImageView(image: UIImage(systemName: "photo.badge.exclamationmark"))
    private let dimView = UIView()
    private let checkView = UIImageView()
    private let lockBadge = MobileGalleryAssetCell.badge(symbol: "lock.fill", color: UIColor.black.withAlphaComponent(0.70))
    private let keeperBadge = MobileGalleryAssetCell.badge(symbol: "bookmark.fill", color: UIColor(MobileKeptoraDesign.mintFill).withAlphaComponent(0.90))
    private let mediaLabel = UILabel()
    private let mediaBackground = UIView()
    private let keepButton = MobileGalleryKeepButton(type: .system)
    /// Carries the selection button's accessibility; touches still reach the collection view.
    private let selectionTarget = UIView()

    private var representedID: String?
    private var representedFavorite = false
    private var representedAsset: UniversalMediaAsset?
    private var state: MobileGalleryCellState?
    private var loadToken: MobileGalleryThumbnailLoader.Token?

    private static let checkConfiguration = UIImage.SymbolConfiguration(textStyle: .title2)

    override init(frame: CGRect) {
        super.init(frame: frame)
        build()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (cell: MobileGalleryAssetCell, _) in
            if let asset = cell.representedAsset { cell.applyMedia(asset) }
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private static func badge(symbol: String, color: UIColor) -> UIView {
        let view = UIView()
        view.backgroundColor = color
        view.layer.cornerRadius = 10
        view.translatesAutoresizingMaskIntoConstraints = false
        let image = UIImageView(image: UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .semibold)))
        image.tintColor = .white
        image.contentMode = .center
        image.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(image)
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: 20), view.heightAnchor.constraint(equalToConstant: 20),
            image.centerXAnchor.constraint(equalTo: view.centerXAnchor), image.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        view.isHidden = true
        return view
    }

    private func build() {
        contentView.layer.cornerRadius = 10
        contentView.clipsToBounds = true
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = .secondarySystemFill
        container.clipsToBounds = true
        contentView.addSubview(container)

        for view in [imageView, placeholderView, dimView, selectionTarget] {
            view.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(view)
        }
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        placeholderView.contentMode = .center
        placeholderView.tintColor = UIColor(MobileKeptoraDesign.secondaryInk)
        placeholderView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 20)
        placeholderView.isHidden = true
        dimView.backgroundColor = UIColor.black.withAlphaComponent(0.28)
        dimView.isHidden = true
        dimView.isUserInteractionEnabled = false

        let badges = UIStackView(arrangedSubviews: [lockBadge, keeperBadge])
        badges.axis = .horizontal
        badges.spacing = 4
        badges.translatesAutoresizingMaskIntoConstraints = false
        badges.isUserInteractionEnabled = false
        container.addSubview(badges)

        mediaBackground.backgroundColor = UIColor.black.withAlphaComponent(0.65)
        mediaBackground.layer.cornerRadius = 4
        mediaBackground.translatesAutoresizingMaskIntoConstraints = false
        mediaBackground.isUserInteractionEnabled = false
        mediaBackground.isAccessibilityElement = false
        mediaBackground.accessibilityElementsHidden = true
        mediaLabel.translatesAutoresizingMaskIntoConstraints = false
        mediaLabel.textColor = .white
        mediaLabel.font = UIFont.preferredFont(forTextStyle: .caption2, compatibleWith: traitCollection)
        mediaLabel.adjustsFontForContentSizeCategory = true
        mediaLabel.isAccessibilityElement = false
        mediaBackground.addSubview(mediaLabel)
        container.addSubview(mediaBackground)

        checkView.translatesAutoresizingMaskIntoConstraints = false
        checkView.preferredSymbolConfiguration = Self.checkConfiguration
        checkView.backgroundColor = UIColor.black.withAlphaComponent(0.62)
        checkView.layer.cornerRadius = 16
        checkView.clipsToBounds = true
        checkView.contentMode = .center
        checkView.isUserInteractionEnabled = false
        container.addSubview(checkView)

        keepButton.translatesAutoresizingMaskIntoConstraints = false
        keepButton.configure()
        keepButton.addAction(UIAction { [weak self] _ in self?.onKeep?() }, for: .touchUpInside)
        keepButton.isHidden = true
        container.addSubview(keepButton)

        NSLayoutConstraint.activate([
            // Matches the SwiftUI cell's 4 pt inner padding.
            container.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            container.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            container.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            container.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: container.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            placeholderView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            placeholderView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            dimView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            dimView.topAnchor.constraint(equalTo: container.topAnchor),
            dimView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            selectionTarget.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            selectionTarget.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            selectionTarget.topAnchor.constraint(equalTo: container.topAnchor),
            selectionTarget.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            badges.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 3),
            badges.topAnchor.constraint(equalTo: container.topAnchor, constant: 3),
            mediaBackground.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -3),
            mediaBackground.topAnchor.constraint(equalTo: container.topAnchor, constant: 3),
            mediaLabel.leadingAnchor.constraint(equalTo: mediaBackground.leadingAnchor, constant: 5),
            mediaLabel.trailingAnchor.constraint(equalTo: mediaBackground.trailingAnchor, constant: -5),
            mediaLabel.topAnchor.constraint(equalTo: mediaBackground.topAnchor, constant: 2.5),
            mediaLabel.bottomAnchor.constraint(equalTo: mediaBackground.bottomAnchor, constant: -2.5),
            checkView.widthAnchor.constraint(equalToConstant: 32),
            checkView.heightAnchor.constraint(equalToConstant: 32),
            checkView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -3),
            checkView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -3),
            keepButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 3),
            keepButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -3),
            keepButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
            keepButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            keepButton.trailingAnchor.constraint(lessThanOrEqualTo: checkView.leadingAnchor, constant: -2)
        ])

        selectionTarget.isAccessibilityElement = true
        selectionTarget.accessibilityHint = L10n.tr("Tap to change selection")
        isAccessibilityElement = false
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        loadToken?.cancel()
        loadToken = nil
        imageView.image = nil
        placeholderView.isHidden = true
        representedID = nil
        representedAsset = nil
        state = nil
        onKeep = nil
    }

    func apply(asset: UniversalMediaAsset, state: MobileGalleryCellState, loader: MobileGalleryThumbnailLoader) {
        representedAsset = asset
        if representedID != asset.id || representedFavorite != asset.isFavorite {
            if representedID != asset.id { loadImage(asset, loader: loader) }
            representedID = asset.id
            representedFavorite = asset.isFavorite
            applyMedia(asset)
            selectionTarget.accessibilityIdentifier = "archive.asset.\(asset.id)"
            keepButton.accessibilityIdentifier = "archive.keep.\(asset.id)"
        }
        guard state != self.state else { return }
        self.state = state
        dimView.isHidden = !state.selected
        checkView.image = UIImage(systemName: state.selected ? "checkmark.circle.fill" : "circle")
        checkView.backgroundColor = state.selected ? UIColor(MobileKeptoraDesign.accentFill) : UIColor.black.withAlphaComponent(0.62)
        checkView.tintColor = .white
        lockBadge.isHidden = !state.protected
        keeperBadge.isHidden = state.keeperLabel == nil
        keepButton.isHidden = !state.showsKeep
        keepButton.isEnabled = state.keepEnabled
        selectionTarget.accessibilityLabel = state.accessibilityLabel
        selectionTarget.accessibilityValue = (state.selected ? L10n.tr("Selected") : L10n.tr("Not selected"))
        selectionTarget.accessibilityTraits = state.selected ? [.button, .selected] : [.button]
        accessibilityElements = state.showsKeep ? [selectionTarget, keepButton] : [selectionTarget]
    }

    private func applyMedia(_ asset: UniversalMediaAsset) {
        let isVideo = asset.mediaKind == .video
        guard asset.isFavorite || isVideo else {
            mediaBackground.isHidden = true
            return
        }
        let font = UIFontMetrics(forTextStyle: .caption2)
            .scaledFont(for: UIFont.systemFont(ofSize: 11, weight: .semibold), compatibleWith: traitCollection)
        mediaLabel.font = font
        let text = NSMutableAttributedString()
        let symbolConfiguration = UIImage.SymbolConfiguration(font: font)
        if asset.isFavorite, let heart = UIImage(systemName: "heart.fill", withConfiguration: symbolConfiguration)?
            .withTintColor(.systemPink, renderingMode: .alwaysOriginal) {
            text.append(NSAttributedString(attachment: NSTextAttachment(image: heart)))
        }
        if isVideo {
            if text.length > 0 { text.append(NSAttributedString(string: " ")) }
            if let play = UIImage(systemName: "play.fill", withConfiguration: symbolConfiguration)?
                .withTintColor(.white, renderingMode: .alwaysOriginal) {
                text.append(NSAttributedString(attachment: NSTextAttachment(image: play)))
            }
            text.append(NSAttributedString(string: " " + asset.formattedDuration))
        }
        text.addAttributes([.font: font, .foregroundColor: UIColor.white], range: NSRange(location: 0, length: text.length))
        mediaLabel.attributedText = text
        mediaBackground.isHidden = false
    }

    private func loadImage(_ asset: UniversalMediaAsset, loader: MobileGalleryThumbnailLoader) {
        loadToken?.cancel()
        placeholderView.isHidden = true
        if let cached = loader.cachedImage(for: asset) {
            imageView.image = cached
            loadToken = nil
            return
        }
        imageView.image = nil
        let id = asset.id
        loadToken = loader.requestImage(for: asset) { [weak self] image, isFinal in
            guard let self, self.representedID == id else { return }
            if let image {
                self.imageView.image = image
            } else if isFinal, self.imageView.image == nil {
                self.placeholderView.isHidden = false
            }
        }
    }
}

/// Icon-only keeper action preserves a 44 pt target without covering the photo.
final class MobileGalleryKeepButton: UIButton {
    private var registeredForTypographyChanges = false

    func configure() {
        if !registeredForTypographyChanges {
            registeredForTypographyChanges = true
            registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (button: MobileGalleryKeepButton, _) in
                button.configure()
            }
        }

        var configuration = UIButton.Configuration.plain()
        let iconConfiguration = UIImage.SymbolConfiguration(textStyle: .caption1)
            .applying(UIImage.SymbolConfiguration(weight: .bold))
        configuration.image = UIImage(systemName: "star.fill", withConfiguration: iconConfiguration)
        configuration.contentInsets = .zero
        configuration.baseForegroundColor = .white
        configuration.titleLineBreakMode = .byTruncatingTail
        configuration.background.backgroundColor = UIColor.black.withAlphaComponent(0.68)
        configuration.background.strokeColor = UIColor(MobileKeptoraDesign.mint).withAlphaComponent(0.60)
        configuration.background.strokeWidth = 0.8
        configuration.cornerStyle = .capsule
        self.configuration = configuration
        accessibilityLabel = L10n.tr("Keep This")
    }
}

// MARK: - Thumbnail loading

/// Grid thumbnails through one `PHCachingImageManager`, so prefetch (`startCachingImages`)
/// and display requests share PhotoKit's cache. Final images go to `MobileThumbnailCache`
/// under the same key `MobileAssetThumbnail` uses at 384 px, so other screens reuse them.
@MainActor
final class MobileGalleryThumbnailLoader {
    static let shared = MobileGalleryThumbnailLoader()
    static let pixelSize: CGFloat = 384

    final class Token {
        private var onCancel: (() -> Void)?
        private(set) var isCancelled = false
        func setCancel(_ handler: @escaping () -> Void) {
            if isCancelled { handler() } else { onCancel = handler }
        }
        func cancel() {
            isCancelled = true
            onCancel?()
            onCancel = nil
        }
    }

    private let manager: PHCachingImageManager = {
        let manager = PHCachingImageManager()
        manager.allowsCachingHighQualityImages = false
        return manager
    }()

    private let options: PHImageRequestOptions = {
        let options = PHImageRequestOptions()
        // A fast degraded image first, then the 384 px one, as Photos does while scrolling.
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = false
        return options
    }()

    private var targetSize: CGSize { CGSize(width: Self.pixelSize, height: Self.pixelSize) }

    static func cacheKey(for asset: UniversalMediaAsset) -> String {
        let stamp = asset.modificationDate?.timeIntervalSince1970 ?? asset.creationDate?.timeIntervalSince1970 ?? 0
        return "\(asset.id)_\(stamp)_\(asset.fileRevision?.physicalIdentity ?? "")_\(asset.fileRevision?.changeToken ?? "")_\(Int(pixelSize))_fill"
    }

    func cachedImage(for asset: UniversalMediaAsset) -> UIImage? {
        MobileThumbnailCache.shared.image(forKey: Self.cacheKey(for: asset))
    }

    private func cachedPHAsset(_ identifier: String) -> PHAsset? {
        if let asset = MobilePHAssetCache.shared.asset(for: identifier) { return asset }
        if let asset = PhotoLibraryAssetCache.shared.asset(for: identifier) {
            MobilePHAssetCache.shared.setAsset(asset, for: identifier)
            return asset
        }
        return nil
    }

    func startCaching(_ assets: [UniversalMediaAsset]) {
        var photos: [PHAsset] = []
        var missing: [String] = []
        for asset in assets {
            guard case .photoLibrary(let identifier) = asset.reference, cachedImage(for: asset) == nil else { continue }
            if let photo = cachedPHAsset(identifier) { photos.append(photo) } else { missing.append(identifier) }
        }
        if !photos.isEmpty {
            manager.startCachingImages(for: photos, targetSize: targetSize, contentMode: .aspectFill, options: options)
        }
        guard !missing.isEmpty else { return }
        // An immutable copy: the detached fetch must not capture the main-actor `var`.
        let identifiers = missing
        // One batched fetch for everything about to scroll in, off the main thread.
        Task { [weak self] in
            let fetched = await Task.detached(priority: .utility) { () -> [PHAsset] in
                var result: [PHAsset] = []
                PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil).enumerateObjects { asset, _, _ in result.append(asset) }
                return result
            }.value
            guard let self, !fetched.isEmpty else { return }
            for photo in fetched { MobilePHAssetCache.shared.setAsset(photo, for: photo.localIdentifier) }
            self.manager.startCachingImages(for: fetched, targetSize: self.targetSize, contentMode: .aspectFill, options: self.options)
        }
    }

    func stopCaching(_ assets: [UniversalMediaAsset]) {
        let photos = assets.compactMap { asset -> PHAsset? in
            guard case .photoLibrary(let identifier) = asset.reference else { return nil }
            return MobilePHAssetCache.shared.asset(for: identifier)
        }
        guard !photos.isEmpty else { return }
        manager.stopCachingImages(for: photos, targetSize: targetSize, contentMode: .aspectFill, options: options)
    }

    /// `completion` runs on the main thread, possibly twice for Photos items (degraded, then final).
    func requestImage(for asset: UniversalMediaAsset, completion: @escaping (UIImage?, _ isFinal: Bool) -> Void) -> Token {
        let token = Token()
        switch asset.reference {
        case .photoLibrary(let identifier):
            if let photo = cachedPHAsset(identifier) {
                requestPhoto(photo, asset: asset, token: token, completion: completion)
            } else {
                let task = Task { [weak self] in
                    let fetched = await Task.detached(priority: .userInitiated) {
                        PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject
                    }.value
                    guard let self, !token.isCancelled else { return }
                    guard let fetched else { completion(nil, true); return }
                    MobilePHAssetCache.shared.setAsset(fetched, for: identifier)
                    self.requestPhoto(fetched, asset: asset, token: token, completion: completion)
                }
                token.setCancel { task.cancel() }
            }
        case .file(let url):
            let key = Self.cacheKey(for: asset)
            let isVideo = asset.mediaKind == .video
            let pixel = max(Int(Self.pixelSize), 64)
            let task = Task {
                do {
                    try await FolderSourceAdapter(rootURL: url.deletingLastPathComponent(), cleanupAvailable: false).prepareForAccess(url, allowNetwork: false)
                } catch {
                    if !token.isCancelled { completion(nil, true) }
                    return
                }
                var image: UIImage?
                if isVideo {
                    let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
                    generator.appliesPreferredTrackTransform = true
                    generator.maximumSize = CGSize(width: pixel, height: pixel)
                    image = await withTaskCancellationHandler {
                        if let frame = try? await generator.image(at: CMTime(seconds: 0.2, preferredTimescale: 600)).image {
                            return UIImage(cgImage: frame)
                        }
                        return nil
                    } onCancel: {
                        generator.cancelAllCGImageGeneration()
                    }
                } else {
                    let work = Task.detached(priority: .utility) { () -> UIImage? in
                        try? await MediaWorkGate.thumbnails.withPermit {
                            guard !Task.isCancelled else { return nil as UIImage? }
                            return autoreleasepool {
                                guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                                      let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                                        kCGImageSourceThumbnailMaxPixelSize: pixel,
                                        kCGImageSourceCreateThumbnailWithTransform: true
                                      ] as CFDictionary) else { return nil }
                                return UIImage(cgImage: cgImage)
                            }
                        }
                    }
                    image = await withTaskCancellationHandler { await work.value } onCancel: { work.cancel() }
                }
                guard !token.isCancelled else { return }
                if let image { MobileThumbnailCache.shared.setImage(image, forKey: key) }
                completion(image, true)
            }
            token.setCancel { task.cancel() }
        }
        return token
    }

    private func requestPhoto(_ photo: PHAsset, asset: UniversalMediaAsset, token: Token,
                              completion: @escaping (UIImage?, Bool) -> Void) {
        let key = Self.cacheKey(for: asset)
        let deliver: (UIImage?, [AnyHashable: Any]?) -> Void = { image, info in
            guard !token.isCancelled else { return }
            if (info?[PHImageCancelledKey] as? Bool) == true { return }
            let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            if !degraded, let image { MobileThumbnailCache.shared.setImage(image, forKey: key) }
            completion(image, !degraded)
        }
        let requestID = manager.requestImage(for: photo, targetSize: targetSize, contentMode: .aspectFill, options: options) { image, info in
            // Asynchronous requests normally answer on the main thread; hop if one does not.
            if Thread.isMainThread {
                MainActor.assumeIsolated { deliver(image, info) }
            } else {
                DispatchQueue.main.async { deliver(image, info) }
            }
        }
        let manager = self.manager
        token.setCancel { manager.cancelImageRequest(requestID) }
    }
}
