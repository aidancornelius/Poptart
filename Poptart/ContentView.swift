//
//  ContentView.swift
//  Poptart
//
//  Created by Aidan Cornelius-Bell on 10/9/2025.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var originalImage: NSImage?
    @State private var processedImage: NSImage?
    @State private var isProcessing = false
    @State private var addRoundedRect = true
    @State private var outputFormat: OutputFormat = .appiconset
    @State private var generatedIconsURL: URL?
    @State private var processingProgress: Double = 0
    
    enum OutputFormat: String, CaseIterable {
        case icns = "ICNS"
        case appiconset = "AppIconSet"
        case web = "Web"
    }
    
    private var hasContent: Bool {
        originalImage != nil || processedImage != nil
    }
    
    private var imageSize: CGFloat {
        hasContent ? 256 : 140
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main drag/drop and display area
            ZStack {
                if let processed = processedImage {
                    // Show processed image that can be dragged out
                    Image(nsImage: processed)
                        .resizable()
                        .scaledToFit()
                        .frame(width: imageSize, height: imageSize)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 1)
                        )
                        .onDrag {
                            return createDragProvider()
                        }
                } else if isProcessing {
                    // Show processing animation
                    VStack {
                        ProgressView()
                            .scaleEffect(hasContent ? 1.5 : 1.0)
                            .padding()
                        if hasContent {
                            Text("Processing...")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(width: imageSize, height: imageSize)
                } else {
                    // Drop zone
                    DropZoneView(droppedImage: $originalImage)
                        .frame(width: imageSize, height: imageSize)
                }
            }
            .padding(.top, hasContent ? 20 : 16)
            .padding(.horizontal, hasContent ? 20 : 16)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: hasContent)
            
            // Settings below
            if originalImage != nil || processedImage != nil {
                VStack(spacing: 10) {
                    // Output format picker
                    Picker("", selection: $outputFormat) {
                        ForEach(OutputFormat.allCases, id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .controlSize(.small)
                    .onChange(of: outputFormat) { _ in
                        if originalImage != nil {
                            processImage()
                        }
                    }
                    
                    Toggle(isOn: $addRoundedRect) {
                        Label("macOS roundrect style (824 on 1024)", systemImage: "app.badge")
                            .font(.system(size: 11))
                    }
                    .toggleStyle(.checkbox)
                    .controlSize(.small)
                    .disabled(outputFormat == .web)
                    .onChange(of: addRoundedRect) { _ in
                        if originalImage != nil {
                            processImage()
                        }
                    }
                    
                    if processedImage != nil {
                        Button("Reset") {
                            withAnimation(.easeOut(duration: 0.2)) {
                                originalImage = nil
                                processedImage = nil
                                generatedIconsURL = nil
                            }
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 10))
                        .foregroundColor(.accentColor)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .transition(.opacity)
            }
        }
        .frame(width: hasContent ? 296 : 172, height: hasContent ? 360 : 172)
        .background(Color(NSColor.windowBackgroundColor))
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: hasContent)
        .onChange(of: originalImage) { newImage in
            if newImage != nil {
                processImage()
            }
        }
    }
    
    private func createDragProvider() -> NSItemProvider {
        guard let url = generatedIconsURL else {
            // Fallback to image if no URL
            if let image = processedImage {
                return NSItemProvider(object: image)
            }
            return NSItemProvider()
        }
        
        // Based on format, provide the appropriate file
        let provider = NSItemProvider()
        
        switch outputFormat {
        case .icns:
            let icnsURL = url.appendingPathComponent("AppIcon.icns")
            if FileManager.default.fileExists(atPath: icnsURL.path) {
                provider.registerFileRepresentation(forTypeIdentifier: "com.apple.icns", 
                                                   fileOptions: .openInPlace,
                                                   visibility: .all) { completion in
                    completion(icnsURL, false, nil)
                    return nil
                }
                provider.suggestedName = "AppIcon.icns"
            }
        case .appiconset:
            let iconsetURL = url.appendingPathComponent("AppIcon.appiconset")
            if FileManager.default.fileExists(atPath: iconsetURL.path) {
                // For folder, we'll create a zip
                let zipURL = url.appendingPathComponent("AppIcon.appiconset.zip")
                if !FileManager.default.fileExists(atPath: zipURL.path) {
                    // Create zip of the appiconset
                    let task = Process()
                    task.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
                    task.currentDirectoryURL = url
                    task.arguments = ["-r", zipURL.lastPathComponent, iconsetURL.lastPathComponent]
                    try? task.run()
                    task.waitUntilExit()
                }
                
                provider.registerFileRepresentation(forTypeIdentifier: "public.zip-archive",
                                                   fileOptions: .openInPlace,
                                                   visibility: .all) { completion in
                    completion(zipURL, false, nil)
                    return nil
                }
                provider.suggestedName = "AppIcon.appiconset.zip"
            }
        case .web:
            let faviconFolder = url.appendingPathComponent("Favicons")
            if FileManager.default.fileExists(atPath: faviconFolder.path) {
                // Create zip of the favicons
                let zipURL = url.appendingPathComponent("Favicons.zip")
                if !FileManager.default.fileExists(atPath: zipURL.path) {
                    let task = Process()
                    task.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
                    task.currentDirectoryURL = url
                    task.arguments = ["-r", zipURL.lastPathComponent, faviconFolder.lastPathComponent]
                    try? task.run()
                    task.waitUntilExit()
                }
                
                provider.registerFileRepresentation(forTypeIdentifier: "public.zip-archive",
                                                   fileOptions: .openInPlace,
                                                   visibility: .all) { completion in
                    completion(zipURL, false, nil)
                    return nil
                }
                provider.suggestedName = "Favicons.zip"
            }
        }
        
        return provider
    }
    
    private func processImage() {
        guard let image = originalImage else { return }
        
        withAnimation(.easeIn(duration: 0.2)) {
            isProcessing = true
            processedImage = nil
        }
        
        Task {
            // Create a temporary directory for processing
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            
            do {
                let processor = ImageProcessor()
                
                // Generate based on selected format
                switch outputFormat {
                case .icns:
                    try await processor.generateICNS(from: image, to: tempDir, addRoundedRect: addRoundedRect)
                case .appiconset:
                    try await processor.generateAppIconSet(from: image, to: tempDir, addRoundedRect: addRoundedRect)
                case .web:
                    try await processor.generateFavicons(from: image, to: tempDir)
                }
                
                // For display, create the processed preview
                let displayImage = (addRoundedRect && outputFormat != .web) ? processor.createProcessedPreview(from: image) : image
                
                await MainActor.run {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        self.processedImage = displayImage
                        self.generatedIconsURL = tempDir
                        self.isProcessing = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    // Silently fail for now, just use original
                    self.processedImage = image
                }
            }
        }
    }
}

