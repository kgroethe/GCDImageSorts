//
//  CanvasImage.swift
//  SortVisualizer
//
//  Turns the canvas into something drawable.
//
//  The buffer being sorted holds indices, not colours, so a frame is built by
//  looking each index up in the source image. That is what makes the picture
//  reassemble as the sort runs, rather than dissolving into a gradient.
//

import CoreGraphics
import CoreText
import Foundation

enum CanvasImage {
    /// Snapshot the canvas as an image.
    ///
    /// This deliberately reads the order buffer while the sort is still writing
    /// to it, exactly as the Objective-C++ DrawThread did. A half-updated frame
    /// is the point: it is what the sort looks like mid-flight.
    static func make(colors: [UInt32],
                     order: UnsafeMutableBufferPointer<UInt32>,
                     width: Int, height: Int,
                     label: String? = nil) -> CGImage? {
        let count = width * height
        guard order.count >= count, colors.count >= count else { return nil }

        var out = [UInt32](repeating: 0, count: count)
        let limit = UInt32(colors.count)
        for i in 0 ..< count {
            let idx = order[i]
            out[i] = idx < limit ? colors[Int(idx)] : 0xFF00_0000
        }

        return out.withUnsafeMutableBytes { raw -> CGImage? in
            guard let ctx = CGContext(
                data: raw.baseAddress,
                width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                    | CGBitmapInfo.byteOrder32Little.rawValue
            ) else { return nil }
            if let label { drawLabel(label, in: ctx, width: width, height: height) }
            return ctx.makeImage()
        }
    }

    /// Draw the algorithm name into the strip the test pattern reserves for it.
    ///
    /// SortablePicture::CreateGradientPattern leaves rows of black at the top
    /// specifically so the name can sit there, and the Objective-C++ app drew
    /// into it. Ours left it empty, which made the reserve look like a bug
    /// rather than a design.
    private static func drawLabel(_ text: String, in ctx: CGContext,
                                  width: Int, height: Int) {
        let reserved = max(height * 50 / 480, 0)
        guard reserved >= 10 else { return }        // too small to read

        // The reserved rows are only black once the image is sorted. While a
        // sort is running they hold whatever pixels happen to have landed
        // there, so the text needs its own backing to stay readable. The
        // Objective-C++ overlay did the same thing.
        ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.68))
        ctx.fill(CGRect(x: 0, y: CGFloat(height - reserved),
                        width: CGFloat(width), height: CGFloat(reserved)))

        let size = min(CGFloat(reserved) * 0.55, CGFloat(width) * 0.05)
        let font = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, size, nil)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: CGColor(red: 1, green: 1, blue: 1, alpha: 0.92),
        ]
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(string: text, attributes: attrs))

        // The bitmap context has its origin bottom left, so the reserved strip
        // at the top of the image is at high y.
        let inset = size * 0.6
        ctx.textMatrix = .identity
        ctx.textPosition = CGPoint(x: inset,
                                   y: CGFloat(height) - CGFloat(reserved) + (CGFloat(reserved) - size) / 2 + size * 0.22)
        CTLineDraw(line, ctx)
    }

    /// Decode any CGImage into the packed layout PixelCanvas uses, scaled to fit.
    static func canvasColors(from image: CGImage, maxWidth: Int, maxHeight: Int)
        -> (colors: [UInt32], width: Int, height: Int)? {
        // Scale to fit while preserving aspect: sorting a 12 megapixel photo
        // with a quadratic algorithm would never finish.
        let scale = min(Double(maxWidth) / Double(image.width),
                        Double(maxHeight) / Double(image.height), 1.0)
        let w = max(1, Int((Double(image.width) * scale).rounded()))
        let h = max(1, Int((Double(image.height) * scale).rounded()))

        var buf = [UInt32](repeating: 0, count: w * h)
        let ok = buf.withUnsafeMutableBytes { raw -> Bool in
            guard let ctx = CGContext(
                data: raw.baseAddress,
                width: w, height: h,
                bitsPerComponent: 8, bytesPerRow: w * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                    | CGBitmapInfo.byteOrder32Little.rawValue
            ) else { return false }
            ctx.interpolationQuality = .high
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        return ok ? (buf, w, h) : nil
    }
}
