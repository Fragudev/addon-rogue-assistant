import Foundation
import CoreGraphics
import ImageIO

// Usage: swift make_tga.swift <input.png> <output.tga> <size> <marginFraction>
// Centres the image, keeping its aspect ratio, on a transparent size x size canvas and writes a 32-bit
// uncompressed TGA (bottom-left origin, straight alpha), the format WoW loads for textures.
let args = CommandLine.arguments
guard args.count == 5, let size = Int(args[3]), let margin = Double(args[4]) else {
    FileHandle.standardError.write("usage: make_tga <in.png> <out.tga> <size> <margin>\n".data(using: .utf8)!)
    exit(2)
}

guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: args[1]) as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    FileHandle.standardError.write("cannot read \(args[1])\n".data(using: .utf8)!)
    exit(1)
}

let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
    space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { exit(1) }

context.clear(CGRect(x: 0, y: 0, width: size, height: size))
context.interpolationQuality = .high

let available = Double(size) * (1.0 - 2.0 * margin)
let scale = min(available / Double(image.width), available / Double(image.height))
let drawWidth = Double(image.width) * scale
let drawHeight = Double(image.height) * scale
let rect = CGRect(
    x: (Double(size) - drawWidth) / 2.0, y: (Double(size) - drawHeight) / 2.0,
    width: drawWidth, height: drawHeight
)
context.draw(image, in: rect)

guard let data = context.data else { exit(1) }
let pixels = data.bindMemory(to: UInt8.self, capacity: size * size * 4)

// TGA header: no id, no colour map, type 2 (uncompressed true colour), 32 bpp, 8 alpha bits.
var out = Data([0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0])
out.append(contentsOf: [UInt8(size & 0xFF), UInt8(size >> 8), UInt8(size & 0xFF), UInt8(size >> 8), 32, 8])

// CGContext memory is top row first; a bottom-left-origin TGA wants the bottom row first.
for row in stride(from: size - 1, through: 0, by: -1) {
    for column in 0..<size {
        let offset = (row * size + column) * 4
        let alpha = Int(pixels[offset + 3])
        var red = Int(pixels[offset]), green = Int(pixels[offset + 1]), blue = Int(pixels[offset + 2])
        if alpha > 0 && alpha < 255 {
            // Undo the premultiplication: TGA stores straight alpha.
            red = min(255, red * 255 / alpha)
            green = min(255, green * 255 / alpha)
            blue = min(255, blue * 255 / alpha)
        }
        out.append(contentsOf: [UInt8(blue), UInt8(green), UInt8(red), UInt8(alpha)])
    }
}

try out.write(to: URL(fileURLWithPath: args[2]))
print("wrote \(args[2]): \(size)x\(size), \(out.count) bytes; logo drawn at \(Int(drawWidth))x\(Int(drawHeight))")
