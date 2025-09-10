//
//  DropZoneView.swift
//  Poptart
//
//  Created by Aidan Cornelius-Bell on 10/9/2025.
//

import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    @Binding var droppedImage: NSImage?
    @State private var isDragging = false
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                .foregroundColor(isDragging ? .accentColor : Color.gray.opacity(0.3))
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isDragging ? Color.accentColor.opacity(0.05) : Color.gray.opacity(0.02))
                )
            
            VStack(spacing: 4) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 28))
                    .foregroundColor(Color.gray.opacity(0.5))
                
                Text("Drop image to convert to icon")
                    .font(.system(size: 11, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color.gray.opacity(0.6))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isDragging)
        .onDrop(of: [.fileURL, .image], isTargeted: $isDragging) { providers in
            loadImage(from: providers)
            return true
        }
        .padding(.bottom, 24)
    }
    
    private func loadImage(from providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }
        
        // Try file URL first
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                if let url = item as? URL {
                    if let image = NSImage(contentsOf: url) {
                        DispatchQueue.main.async {
                            withAnimation(.easeIn(duration: 0.3)) {
                                self.droppedImage = image
                            }
                        }
                    }
                } else if let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil),
                          let image = NSImage(contentsOf: url) {
                    DispatchQueue.main.async {
                        withAnimation(.easeIn(duration: 0.3)) {
                            self.droppedImage = image
                        }
                    }
                }
            }
        } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            // Fallback to image data
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                if let data = data, let image = NSImage(data: data) {
                    DispatchQueue.main.async {
                        withAnimation(.easeIn(duration: 0.3)) {
                            self.droppedImage = image
                        }
                    }
                }
            }
        }
    }
}
