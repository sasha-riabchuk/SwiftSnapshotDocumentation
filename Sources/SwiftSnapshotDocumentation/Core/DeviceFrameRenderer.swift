//
//  DeviceFrameRenderer.swift
//  SwiftSnapshotDocumentation
//
//  Created by Sasha Riabchuk on 09.12.2025.
//

import CoreGraphics
import Foundation
import ImageIO

/// Composites a captured screenshot into a procedurally-drawn device bezel.
///
/// Uses CoreGraphics/ImageIO only (no UIKit), so it runs on every platform the
/// package builds for and stays independent of the snapshot-capture pipeline:
/// the regression snapshots in `__Snapshots__` remain bare, and only the copies
/// placed into the DocC catalog are framed.
enum DeviceFrameRenderer {
    /// Reads the PNG at `sourcePath`, draws `frame` around it, and writes the
    /// framed PNG to `destinationPath`.
    ///
    /// - Throws: ``DocumentationError/imageProcessingFailed(path:)`` if the source
    ///   cannot be decoded or the framed image cannot be written.
    static func writeFramedPNG(from sourcePath: String, to destinationPath: String, frame: DeviceFrame) throws {
        guard
            let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: sourcePath) as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw DocumentationError.imageProcessingFailed(path: sourcePath)
        }

        guard let framed = renderFramedImage(image, frame: frame) else {
            throw DocumentationError.imageProcessingFailed(path: sourcePath)
        }

        guard
            let destination = CGImageDestinationCreateWithURL(
                URL(fileURLWithPath: destinationPath) as CFURL,
                "public.png" as CFString,
                1,
                nil
            )
        else {
            throw DocumentationError.imageProcessingFailed(path: destinationPath)
        }

        CGImageDestinationAddImage(destination, framed, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw DocumentationError.imageProcessingFailed(path: destinationPath)
        }
    }

    /// Draws `frame` around `image` and returns the composited result.
    ///
    /// The output is `image` size plus a bezel on every edge. Drawing happens in a
    /// top-left coordinate system so the screenshot stays upright and the notch sits
    /// at the top.
    static func renderFramedImage(_ image: CGImage, frame: DeviceFrame) -> CGImage? {
        let screenWidth = CGFloat(image.width)
        let screenHeight = CGFloat(image.height)
        let minSide = min(screenWidth, screenHeight)

        let bezel = (frame.bezelFraction * minSide).rounded()
        let screenCorner = frame.screenCornerFraction * minSide
        let bodyCorner = screenCorner + bezel

        let outputWidth = screenWidth + bezel * 2
        let outputHeight = screenHeight + bezel * 2

        guard let context = CGContext(
            data: nil,
            width: Int(outputWidth),
            height: Int(outputHeight),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        // Flip to a top-left origin so the screenshot renders upright.
        context.translateBy(x: 0, y: outputHeight)
        context.scaleBy(x: 1, y: -1)

        let black = CGColor(red: 0, green: 0, blue: 0, alpha: 1)

        // Device body.
        let bodyRect = CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight)
        context.addPath(CGPath(roundedRect: bodyRect, cornerWidth: bodyCorner, cornerHeight: bodyCorner, transform: nil))
        context.setFillColor(black)
        context.fillPath()

        // Screen, clipped to rounded corners. The context is flipped to a top-left
        // origin (so paths read naturally), but `CGContext.draw` would then render a
        // normally-oriented PNG upside down — so flip locally about the screen rect's
        // center to keep the screenshot upright.
        let screenRect = CGRect(x: bezel, y: bezel, width: screenWidth, height: screenHeight)
        context.saveGState()
        context.addPath(CGPath(roundedRect: screenRect, cornerWidth: screenCorner, cornerHeight: screenCorner, transform: nil))
        context.clip()
        context.translateBy(x: 0, y: 2 * bezel + screenHeight)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: screenRect)
        context.restoreGState()

        // Sensor housing. `context.draw(image:)` renders the screenshot upright
        // while path fills are vertically mirrored relative to it in this flipped
        // context, so the island is positioned from the high-y (visual top) edge to
        // land just below the top of the displayed screenshot.
        if frame.notch == .island {
            let islandWidth = screenWidth * 0.32
            let islandHeight = bezel * 1.1
            let islandRect = CGRect(
                x: bezel + (screenWidth - islandWidth) / 2,
                y: outputHeight - bezel - islandHeight * 1.5,
                width: islandWidth,
                height: islandHeight
            )
            context.addPath(CGPath(roundedRect: islandRect, cornerWidth: islandHeight / 2, cornerHeight: islandHeight / 2, transform: nil))
            context.setFillColor(black)
            context.fillPath()
        }

        return context.makeImage()
    }
}
