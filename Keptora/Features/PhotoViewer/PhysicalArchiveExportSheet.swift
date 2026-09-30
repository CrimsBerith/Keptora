import SwiftUI
import KeptoraCore
import UniformTypeIdentifiers
import AppKit

/// Sheet allowing users to export and organize their photo library into structured Finder folders.
public struct PhysicalArchiveExportSheet: View {
    public let assets: [UniversalMediaAsset]
    public let sourceURL: URL?
    public var onClose: () -> Void
    
    @State private var destinationURL: URL?
    @State private var selectedStructure: PhysicalExportConfiguration.OrganizationStructure = .yearAndMonth
    @State private var selectedTransferMode: PhysicalExportConfiguration.TransferMode = .copy
    @State private var isExporting: Bool = false
    @State private var progressFraction: Double = 0.0
    @State private var progressText: String = ""
    @State private var isCompleted: Bool = false
    @State private var errorMessage: String?
    
    public init(assets: [UniversalMediaAsset], sourceURL: URL? = nil, onClose: @escaping () -> Void) {
        self.assets = assets
        self.sourceURL = sourceURL
        self.onClose = onClose
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "folder.badge.gearshape")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Export & Organize Photo Archive")
                        .font(.headline)
                    Text("Organize \(assets.count) photos into clean, sorted Finder folders")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            if isCompleted {
                // Success screen
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    
                    Text("Archive Successfully Exported!")
                        .font(.title3.bold())
                    
                    Text("All photos were sorted into structured folders at your selected destination.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    if let dest = destinationURL {
                        Button("Reveal in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([dest])
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .padding(.top, 8)
                    }
                    
                    Button("Close", action: onClose)
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .padding(.vertical, 32)
            } else {
                // Configuration Form
                VStack(alignment: .leading, spacing: 18) {
                    // Destination Folder
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Destination Folder")
                            .font(.subheadline.bold())
                        
                        HStack {
                            if let dest = destinationURL {
                                Label(dest.lastPathComponent, systemImage: "folder.fill")
                                    .lineLimit(1)
                                    .font(.callout)
                            } else {
                                Text("No destination selected")
                                    .foregroundColor(.secondary)
                                    .font(.callout)
                            }
                            Spacer()
                            Button("Choose Folder…") {
                                pickDestinationFolder()
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(10)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(8)
                    }
                    
                    // Folder Hierarchy Strategy
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Folder Hierarchy Structure")
                            .font(.subheadline.bold())
                        
                        Picker("Structure", selection: $selectedStructure) {
                            Text("By Year & Month (e.g. 2026/08 - August/)").tag(PhysicalExportConfiguration.OrganizationStructure.yearAndMonth)
                            Text("By Year & AI Category (e.g. 2026/Nature/)").tag(PhysicalExportConfiguration.OrganizationStructure.yearAndCategory)
                            Text("By Category Only (e.g. Documents/Receipts/)").tag(PhysicalExportConfiguration.OrganizationStructure.categoryOnly)
                        }
                        .pickerStyle(.radioGroup)
                    }
                    
                    // Transfer Mode
                    VStack(alignment: .leading, spacing: 6) {
                        Text("File Placement Mode")
                            .font(.subheadline.bold())
                        
                        Picker("Mode", selection: $selectedTransferMode) {
                            Text("Copy Files (Safe duplicate copies)").tag(PhysicalExportConfiguration.TransferMode.copy)
                            Text("Hardlinks (Zero extra disk space, instant)").tag(PhysicalExportConfiguration.TransferMode.hardlink)
                            Text("Symlinks (Finder Aliases)").tag(PhysicalExportConfiguration.TransferMode.symlink)
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    if let err = errorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    // Progress Bar
                    if isExporting {
                        VStack(alignment: .leading, spacing: 6) {
                            ProgressView(value: progressFraction, total: 1.0)
                            Text(progressText)
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 4)
                    }
                    
                    Spacer(minLength: 0)
                    
                    // Action Buttons
                    HStack {
                        Button("Cancel", action: onClose)
                            .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        Button(action: startExport) {
                            Label("Export & Organize Archive", systemImage: "arrow.right.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(destinationURL == nil || isExporting || assets.isEmpty)
                    }
                }
            }
        }
        .padding(24)
        .frame(minWidth: 540, minHeight: 460)
    }
    
    private func pickDestinationFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Destination"
        if panel.runModal() == .OK {
            self.destinationURL = panel.url
        }
    }
    
    private func startExport() {
        guard let dest = destinationURL else { return }
        isExporting = true
        errorMessage = nil
        
        let config = PhysicalExportConfiguration(
            destinationURL: dest,
            structure: selectedStructure,
            transferMode: selectedTransferMode,
            skipDuplicates: true
        )
        
        let sourceScoped = sourceURL
        Task {
            let hasDestAccess = dest.startAccessingSecurityScopedResource()
            let hasSourceAccess = sourceScoped?.startAccessingSecurityScopedResource() ?? false
            defer {
                if hasDestAccess { dest.stopAccessingSecurityScopedResource() }
                if hasSourceAccess { sourceScoped?.stopAccessingSecurityScopedResource() }
            }
            do {
                try await PhysicalArchiveExporter.export(
                    assets: assets,
                    reports: [:],
                    config: config
                ) { progress in
                    Task { @MainActor in
                        self.progressFraction = Double(progress.processedCount) / Double(max(1, progress.totalCount))
                        self.progressText = "Sorting \(progress.processedCount) of \(progress.totalCount): \(progress.currentFilename)"
                    }
                }
                await MainActor.run {
                    self.isExporting = false
                    self.isCompleted = true
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                }
            } catch {
                await MainActor.run {
                    self.isExporting = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
