//
//  ImageProcessor.swift
//  Poptart
//
//  Created by Aidan Cornelius-Bell on 10/9/2025.
//

import Foundation
import AppKit
import CoreGraphics

struct IconSize {
    let pixelSize: Int
    let filename: String
}

class ImageProcessor {
    
    private let macOSIconSizes = [
        IconSize(pixelSize: 16, filename: "icon_16x16"),
        IconSize(pixelSize: 32, filename: "icon_16x16@2x"),  // 16@2x = 32px
        IconSize(pixelSize: 32, filename: "icon_32x32"),
        IconSize(pixelSize: 64, filename: "icon_32x32@2x"),  // 32@2x = 64px
        IconSize(pixelSize: 64, filename: "icon_64x64"),
        IconSize(pixelSize: 128, filename: "icon_128x128"),
        IconSize(pixelSize: 256, filename: "icon_128x128@2x"), // 128@2x = 256px
        IconSize(pixelSize: 256, filename: "icon_256x256"),
        IconSize(pixelSize: 512, filename: "icon_256x256@2x"), // 256@2x = 512px
        IconSize(pixelSize: 512, filename: "icon_512x512"),
        IconSize(pixelSize: 1024, filename: "icon_512x512@2x"), // 512@2x = 1024px
        IconSize(pixelSize: 1024, filename: "icon_1024x1024")
    ]
    
    private let faviconSizes = [
        (size: 16, filename: "favicon-16x16.png"),
        (size: 32, filename: "favicon-32x32.png"),
        (size: 180, filename: "apple-touch-icon.png")
    ]
    
    func generateModernPNGs(from image: NSImage, to outputURL: URL, addRoundedRect: Bool = false) async throws {
        let folderURL = outputURL.appendingPathComponent("AppIcon")
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        
        let processedImage = addRoundedRect ? applyRoundedRectBackground(to: image) : image
        
        for iconSize in macOSIconSizes {
            let resized = resizeImage(processedImage, to: CGSize(width: iconSize.pixelSize, height: iconSize.pixelSize))
            let fileURL = folderURL.appendingPathComponent("\(iconSize.filename).png")
            try savePNG(resized, to: fileURL)
        }
    }
    
    func generateAppIconSet(from image: NSImage, to outputURL: URL, addRoundedRect: Bool = false) async throws {
        let iconsetURL = outputURL.appendingPathComponent("AppIcon.appiconset")
        try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
        
        let processedImage = addRoundedRect ? applyRoundedRectBackground(to: image) : image
        var contents = ContentsJson()
        
        for iconSize in macOSIconSizes {
            let resized = resizeImage(processedImage, to: CGSize(width: iconSize.pixelSize, height: iconSize.pixelSize))
            let filename = "\(iconSize.filename).png"
            let fileURL = iconsetURL.appendingPathComponent(filename)
            try savePNG(resized, to: fileURL)
            
            // Extract base size and scale from filename
            let (baseSize, scale) = extractSizeAndScale(from: iconSize.filename)
            contents.images.append(ContentsImage(
                size: "\(baseSize)x\(baseSize)",
                idiom: "mac",
                filename: filename,
                scale: scale
            ))
        }
        
        let contentsData = try JSONEncoder().encode(contents)
        let contentsURL = iconsetURL.appendingPathComponent("Contents.json")
        try contentsData.write(to: contentsURL)
    }
    
    func generateFavicons(from image: NSImage, to outputURL: URL) async throws {
        let faviconFolder = outputURL.appendingPathComponent("Favicons")
        try FileManager.default.createDirectory(at: faviconFolder, withIntermediateDirectories: true)
        
        for favicon in faviconSizes {
            let resized = resizeImage(image, to: CGSize(width: favicon.size, height: favicon.size))
            let fileURL = faviconFolder.appendingPathComponent(favicon.filename)
            try savePNG(resized, to: fileURL)
        }
        
        try generateICO(from: image, to: faviconFolder.appendingPathComponent("favicon.ico"))
    }
    
    func createProcessedPreview(from image: NSImage) -> NSImage {
        return applyRoundedRectBackground(to: image)
    }
    
    func generateICNS(from image: NSImage, to outputURL: URL, addRoundedRect: Bool = false) async throws {
        let processedImage = addRoundedRect ? applyRoundedRectBackground(to: image) : image
        
        // Create iconset first
        let iconsetURL = outputURL.appendingPathComponent("AppIcon.iconset")
        try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
        
        // Generate all required sizes for iconset (for iconutil to create ICNS)
        let iconsetSizes = [
            (16, 1), (16, 2),
            (32, 1), (32, 2),
            (128, 1), (128, 2),
            (256, 1), (256, 2),
            (512, 1), (512, 2)
        ]
        
        for (size, scale) in iconsetSizes {
            let pixelSize = size * scale
            // iconutil expects specific naming: icon_16x16.png, icon_16x16@2x.png, etc.
            let filename = scale == 1 ? "icon_\(size)x\(size).png" : "icon_\(size)x\(size)@2x.png"
            let resized = resizeImage(processedImage, to: CGSize(width: pixelSize, height: pixelSize))
            let fileURL = iconsetURL.appendingPathComponent(filename)
            try savePNG(resized, to: fileURL)
        }
        
        // Convert iconset to ICNS using iconutil
        let icnsURL = outputURL.appendingPathComponent("AppIcon.icns")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
        process.arguments = ["-c", "icns", iconsetURL.path, "-o", icnsURL.path]
        try process.run()
        process.waitUntilExit()
        
        // Clean up iconset folder
        try? FileManager.default.removeItem(at: iconsetURL)
    }
    
    private func applyRoundedRectBackground(to image: NSImage) -> NSImage {
        let size = CGSize(width: 1024, height: 1024)
        let newImage = NSImage(size: size)
        
        newImage.lockFocus()
        
        // macOS app icons use 824x824 inside 1024x1024 (about 80.5%)
        let iconSize: CGFloat = 824
        let insetSize = CGSize(width: iconSize, height: iconSize)
        let insetOrigin = CGPoint(
            x: (size.width - iconSize) / 2,
            y: (size.height - iconSize) / 2
        )
        
        // Create clipping path with macOS standard corner radius (about 18% of icon size)
        let cornerRadius = iconSize * 0.18
        let clipPath = NSBezierPath(roundedRect: NSRect(origin: insetOrigin, size: insetSize), 
                                    xRadius: cornerRadius, 
                                    yRadius: cornerRadius)
        clipPath.addClip()
        
        // Draw the original image scaled to fit the clipped area
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: insetOrigin, size: insetSize),
                  from: NSRect(origin: .zero, size: image.size),
                  operation: .copy,
                  fraction: 1.0)
        
        newImage.unlockFocus()
        return newImage
    }
    
    private func resizeImage(_ image: NSImage, to size: CGSize) -> NSImage {
        // Create a bitmap representation with exact pixel dimensions
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                         pixelsWide: Int(size.width),
                                         pixelsHigh: Int(size.height),
                                         bitsPerSample: 8,
                                         samplesPerPixel: 4,
                                         hasAlpha: true,
                                         isPlanar: false,
                                         colorSpaceName: .deviceRGB,
                                         bytesPerRow: 0,
                                         bitsPerPixel: 0) else {
            return image
        }
        
        rep.size = size
        
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.imageInterpolation = .high
        
        image.draw(in: NSRect(origin: .zero, size: size),
                  from: NSRect(origin: .zero, size: image.size),
                  operation: .copy,
                  fraction: 1.0)
        
        NSGraphicsContext.restoreGraphicsState()
        
        let newImage = NSImage(size: size)
        newImage.addRepresentation(rep)
        return newImage
    }
    
    private func savePNG(_ image: NSImage, to url: URL) throws {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw ImageProcessorError.conversionFailed
        }
        
        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw ImageProcessorError.conversionFailed
        }
        
        try data.write(to: url)
    }
    
    private func generateICO(from image: NSImage, to url: URL) throws {
        let sizes = [16, 32, 48]
        var icoData = Data()
        
        icoData.append(contentsOf: [0, 0])
        icoData.append(contentsOf: [1, 0])
        let imageCount = UInt16(sizes.count)
        icoData.append(contentsOf: withUnsafeBytes(of: imageCount.littleEndian) { Array($0) })
        
        var imageDataArray: [Data] = []
        var currentOffset = 6 + (16 * sizes.count)
        
        for size in sizes {
            let resized = resizeImage(image, to: CGSize(width: size, height: size))
            guard let cgImage = resized.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                throw ImageProcessorError.conversionFailed
            }
            
            let rep = NSBitmapImageRep(cgImage: cgImage)
            guard let pngData = rep.representation(using: .png, properties: [:]) else {
                throw ImageProcessorError.conversionFailed
            }
            
            imageDataArray.append(pngData)
            
            icoData.append(UInt8(size))
            icoData.append(UInt8(size))
            icoData.append(0)
            icoData.append(0)
            icoData.append(contentsOf: [1, 0])
            icoData.append(contentsOf: [32, 0])
            
            let dataSize = UInt32(pngData.count)
            icoData.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Array($0) })
            
            let offset = UInt32(currentOffset)
            icoData.append(contentsOf: withUnsafeBytes(of: offset.littleEndian) { Array($0) })
            
            currentOffset += pngData.count
        }
        
        for data in imageDataArray {
            icoData.append(data)
        }
        
        try icoData.write(to: url)
    }
}

enum ImageProcessorError: LocalizedError {
    case conversionFailed
    
    var errorDescription: String? {
        switch self {
        case .conversionFailed:
            return "Failed to convert image"
        }
    }
}

extension ImageProcessor {
    private func extractSizeAndScale(from filename: String) -> (Int, String) {
        // Parse filenames like "icon_16x16" or "icon_16x16@2x"
        if filename.contains("@2x") {
            // Extract base size from pattern like "icon_32x32@2x"
            if let match = filename.range(of: #"\d+"#, options: .regularExpression) {
                let sizeStr = String(filename[match])
                if let size = Int(sizeStr) {
                    return (size, "2x")
                }
            }
        } else {
            // Extract size from pattern like "icon_16x16"
            if let match = filename.range(of: #"\d+"#, options: .regularExpression) {
                let sizeStr = String(filename[match])
                if let size = Int(sizeStr) {
                    return (size, "1x")
                }
            }
        }
        // Fallback
        return (512, "1x")
    }
}

struct ContentsJson: Codable {
    var images: [ContentsImage] = []
    let info = ContentsInfo()
}

struct ContentsImage: Codable {
    let size: String
    let idiom: String
    let filename: String
    let scale: String
}

struct ContentsInfo: Codable {
    let version: Int
    let author: String
    
    init() {
        self.version = 1
        self.author = "IconMaker"
    }
}
