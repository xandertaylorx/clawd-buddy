import Cocoa
import ImageIO

// MARK: - Shrink: compress any image (PNG, JPEG, HEIC, TIFF, BMP, GIF, WebP…) without a single dependency

enum ShrinkOutcome {
    case saved(url: URL, before: Int, after: Int, how: String)
    case alreadySmall
    case unsupported(String)
}

enum Shrinker {
    static let maxSide = 2560
    /// Mean squared error (per channel, 0...255 scale) of the last palette quantisation: tells us if a clean palette is visually lossless.
    static var lastMSE = 0.0

    static func shrink(_ src: URL) -> ShrinkOutcome {
        guard let source = CGImageSourceCreateWithURL(src as CFURL, nil), CGImageSourceGetCount(source) > 0 else {
            return .unsupported("not an image")
        }
        let type = (CGImageSourceGetType(source) as String?) ?? ""
        if CGImageSourceGetCount(source) > 1 && (type == "com.compuserve.gif" || type == "public.png") {
            return .unsupported("animated images aren't supported")
        }
        let before = Files.size(src)
        let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let longSide = max(props?[kCGImagePropertyPixelWidth] as? Int ?? 0, props?[kCGImagePropertyPixelHeight] as? Int ?? 0)
        let target = min(maxSide, longSide > 0 ? longSide : maxSide)
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: target] as CFDictionary) else { return .unsupported("couldn't read it") }
        let resized = longSide > maxSide
        let w = cg.width, h = cg.height

        // pixels as sRGB RGBA, and whether anything is actually transparent
        var rgba = [UInt8](repeating: 0, count: w * h * 4)
        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        rgba.withUnsafeMutableBytes { buf in
            if let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                   space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
                ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            }
        }
        var hasAlpha = false
        var i = 3
        while i < rgba.count { if rgba[i] < 250 { hasAlpha = true; break }; i += 4 }

        var best: (data: Data, ext: String, how: String)?
        func consider(_ data: Data?, _ ext: String, _ how: String) {
            guard let data, data.count < before else { return }
            if best == nil || data.count < best!.data.count { best = (data, ext, how) }
        }
        let supportsHEIC = (CGImageDestinationCopyTypeIdentifiers() as? [String])?.contains("public.heic") ?? false

        switch type {
        case "public.jpeg":
            let flat = flattened(cg) ?? cg
            for q in [0.78, 0.62, 0.5] {
                let d = encode(flat, "public.jpeg", q)
                consider(d, "jpg", "JPEG quality \(Int(q * 100))")
                if let d, Double(d.count) <= Double(before) * 0.8 { break }
            }
        case "public.heic", "public.heif":
            if supportsHEIC {
                for q in [0.6, 0.45] {
                    let d = encode(cg, "public.heic", q)
                    consider(d, "heic", "HEIC quality \(Int(q * 100))")
                    if let d, Double(d.count) <= Double(before) * 0.8 { break }
                }
            } else if let flat = flattened(cg) {
                consider(encode(flat, "public.jpeg", 0.7), "jpg", "JPEG quality 70")
            }
        default:   // PNG and every lossless-ish format
            if hasAlpha {
                // keep the transparency: a palette PNG with an alpha table, or at least a re-encode at smaller dimensions
                if let clean = paletteWithAlpha(rgba, w, h, dither: 0), lastMSE <= 9 {
                    consider(clean, "png", "PNG with a clean 256-colour palette, transparency kept")
                } else {
                    consider(paletteWithAlpha(rgba, w, h, dither: 0.85), "png", "PNG with a smart 256-colour palette, transparency kept")
                }
                consider(encode(cg, "public.png", nil), "png", resized ? "PNG, scaled down" : "PNG, re-encoded")
            } else {
                var pngData: Data?
                if type == "public.png" {
                    // a clean (undithered) palette is only used when it's visually lossless; anything smoother gets dithered or it bands
                    let clean = paletteImage(rgba, w, h, dither: 0).flatMap { encode($0, "public.png", nil) }
                    if lastMSE <= 9 {
                        consider(clean, "png", "PNG with a clean 256-colour palette")
                    } else {
                        pngData = paletteImage(rgba, w, h).flatMap { encode($0, "public.png", nil) }
                        consider(pngData, "png", "PNG with a smart 256-colour palette")
                    }
                    consider(encode(cg, "public.png", nil), "png", resized ? "PNG, scaled down" : "PNG, re-encoded")
                }
                let jpeg = flattened(cg).flatMap { encode($0, "public.jpeg", 0.82) }
                // a PNG stays a PNG unless JPEG is dramatically smaller
                if type != "public.png" {
                    consider(jpeg, "jpg", "JPEG quality 82")
                } else if let j = jpeg, let b = best, Double(j.count) < Double(b.data.count) * 0.5 {
                    consider(j, "jpg", "JPEG quality 82 (much smaller than PNG)")
                } else if best == nil {
                    consider(jpeg, "jpg", "JPEG quality 82")
                }
            }
        }

        guard let result = best else { return .alreadySmall }
        let out = Files.unique(src.deletingLastPathComponent(), src.deletingPathExtension().lastPathComponent + "-small", result.ext)
        do { try result.data.write(to: out) } catch { return .unsupported("couldn't write the file") }
        return .saved(url: out, before: before, after: result.data.count, how: result.how + (resized ? ", scaled to \(maxSide)px" : ""))
    }

    static func encode(_ image: CGImage, _ type: String, _ quality: Double?) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, type as CFString, 1, nil) else { return nil }
        var opts: [CFString: Any] = [:]
        if let quality { opts[kCGImageDestinationLossyCompressionQuality] = quality }
        CGImageDestinationAddImage(dest, image, opts as CFDictionary)
        return CGImageDestinationFinalize(dest) ? data as Data : nil
    }

    /// Drops the alpha channel onto white (JPEG can't store it).
    static func flattened(_ cg: CGImage) -> CGImage? {
        let w = cg.width, h = cg.height
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage()
    }

    // MARK: palette quantisation (median cut + Floyd–Steinberg dithering), like TinyPNG

    struct QColor { var r: Int; var g: Int; var b: Int; var n: Int; var mr: Float; var mg: Float; var mb: Float }

    static func distinctColors(_ rgba: [UInt8]) -> Int {
        var seen = [Bool](repeating: false, count: 32768)
        var p = 0, n = 0
        while p < rgba.count {
            let k = (Int(rgba[p]) >> 3) << 10 | (Int(rgba[p + 1]) >> 3) << 5 | (Int(rgba[p + 2]) >> 3)
            if !seen[k] { seen[k] = true; n += 1 }
            p += 4
        }
        return n
    }

    static func paletteImage(_ rgba: [UInt8], _ w: Int, _ h: Int, dither strength: Float = 0.85) -> CGImage? {
        var hist = [UInt32](repeating: 0, count: 32768)
        var sumR = [Float](repeating: 0, count: 32768), sumG = sumR, sumB = sumR
        var p = 0
        while p < rgba.count {
            let k = (Int(rgba[p]) >> 3) << 10 | (Int(rgba[p + 1]) >> 3) << 5 | (Int(rgba[p + 2]) >> 3)
            hist[k] += 1
            sumR[k] += Float(rgba[p]); sumG[k] += Float(rgba[p + 1]); sumB[k] += Float(rgba[p + 2])
            p += 4
        }
        var colors: [QColor] = []
        for key in 0..<32768 where hist[key] > 0 {
            let c = Float(hist[key])
            colors.append(QColor(r: key >> 10, g: (key >> 5) & 31, b: key & 31, n: Int(hist[key]), mr: sumR[key] / c, mg: sumG[key] / c, mb: sumB[key] / c))
        }
        guard !colors.isEmpty else { return nil }

        var boxes: [[QColor]] = [colors]
        while boxes.count < 256 {
            var pick = -1, score = 0
            for (i, box) in boxes.enumerated() where box.count > 1 {
                var lo = (31, 31, 31), hi = (0, 0, 0), total = 0
                for c in box {
                    lo = (min(lo.0, c.r), min(lo.1, c.g), min(lo.2, c.b)); hi = (max(hi.0, c.r), max(hi.1, c.g), max(hi.2, c.b)); total += c.n
                }
                let s = max(hi.0 - lo.0, hi.1 - lo.1, hi.2 - lo.2) * 1000 + 1
                let weighted = s * max(1, Int(Double(total).squareRoot()))
                if weighted > score { score = weighted; pick = i }
            }
            if pick < 0 { break }
            var box = boxes[pick]
            let rr = box.map { $0.r }, gg = box.map { $0.g }, bb = box.map { $0.b }
            let rRange = rr.max()! - rr.min()!, gRange = gg.max()! - gg.min()!, bRange = bb.max()! - bb.min()!
            if rRange >= gRange && rRange >= bRange { box.sort { $0.r < $1.r } }
            else if gRange >= bRange { box.sort { $0.g < $1.g } }
            else { box.sort { $0.b < $1.b } }
            let total = box.reduce(0) { $0 + $1.n }
            var acc = 0, cut = 1
            for (idx, c) in box.enumerated() { acc += c.n; if acc * 2 >= total { cut = max(1, min(box.count - 1, idx + 1)); break } }
            boxes[pick] = Array(box[..<cut])
            boxes.append(Array(box[cut...]))
        }
        func expand(_ v: Int) -> Int { (v << 3) | (v >> 2) }
        var palette: [(Int, Int, Int)] = boxes.map { box in
            let total = Float(max(1, box.reduce(0) { $0 + $1.n }))
            func avg(_ f: (QColor) -> Float) -> Int { max(0, min(255, Int((box.reduce(Float(0)) { $0 + f($1) * Float($1.n) } / total).rounded()))) }
            return (avg { $0.mr }, avg { $0.mg }, avg { $0.mb })
        }
        if palette.count < 2 { palette.append((0, 0, 0)) }

        // nearest palette entry for every 15-bit colour
        var lut = [UInt8](repeating: 0, count: 32768)
        for key in 0..<32768 {
            let populated = hist[key] > 0
            let c = Float(max(1, hist[key]))
            let r = populated ? Int((sumR[key] / c).rounded()) : expand(key >> 10)
            let g = populated ? Int((sumG[key] / c).rounded()) : expand((key >> 5) & 31)
            let b = populated ? Int((sumB[key] / c).rounded()) : expand(key & 31)
            var bestD = Int.max, bestI = 0
            for (i, c) in palette.enumerated() {
                let d = (r - c.0) * (r - c.0) + (g - c.1) * (g - c.1) + (b - c.2) * (b - c.2)
                if d < bestD { bestD = d; bestI = i }
            }
            lut[key] = UInt8(bestI)
        }

        // dither
        var indices = [UInt8](repeating: 0, count: w * h)
        var errSum = 0.0
        var cur = [Float](repeating: 0, count: (w + 2) * 3), next = [Float](repeating: 0, count: (w + 2) * 3)
        for y in 0..<h {
            for x in 0..<w {
                let q = (y * w + x) * 4
                let e = (x + 1) * 3
                let r = min(255, max(0, Float(rgba[q]) + cur[e])), g = min(255, max(0, Float(rgba[q + 1]) + cur[e + 1])),
                    b = min(255, max(0, Float(rgba[q + 2]) + cur[e + 2]))
                let key = (Int(r) >> 3) << 10 | (Int(g) >> 3) << 5 | (Int(b) >> 3)
                let idx = lut[key]
                indices[y * w + x] = idx
                let pc = palette[Int(idx)]
                let dr = Float(rgba[q]) - Float(pc.0), dg = Float(rgba[q + 1]) - Float(pc.1), db = Float(rgba[q + 2]) - Float(pc.2)
                errSum += Double(dr * dr + dg * dg + db * db)
                let er = (r - Float(pc.0)) * strength, eg = (g - Float(pc.1)) * strength, eb = (b - Float(pc.2)) * strength
                cur[e + 3] += er * 7 / 16; cur[e + 4] += eg * 7 / 16; cur[e + 5] += eb * 7 / 16
                next[e - 3] += er * 3 / 16; next[e - 2] += eg * 3 / 16; next[e - 1] += eb * 3 / 16
                next[e] += er * 5 / 16; next[e + 1] += eg * 5 / 16; next[e + 2] += eb * 5 / 16
                next[e + 3] += er / 16; next[e + 4] += eg / 16; next[e + 5] += eb / 16
            }
            swap(&cur, &next)
            for k in 0..<next.count { next[k] = 0 }
        }

        lastMSE = errSum / Double(max(1, w * h * 3))
        var table: [UInt8] = []
        for c in palette { table += [UInt8(c.0), UInt8(c.1), UInt8(c.2)] }
        guard let indexed = table.withUnsafeBufferPointer({ ptr in
            CGColorSpace(indexedBaseSpace: CGColorSpace(name: CGColorSpace.sRGB)!, last: palette.count - 1, colorTable: ptr.baseAddress!)
        }), let provider = CGDataProvider(data: Data(indices) as CFData) else { return nil }
        return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: w, space: indexed,
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue), provider: provider,
                       decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }

    /// One friendly sentence for a batch of dropped files.
    static func summary(_ urls: [URL]) -> String {
        var saved = 0, small = 0, bad = 0, before = 0, after = 0
        var lastHow = "", lastName = "", lastBad = ""
        for u in urls {
            switch shrink(u) {
            case .saved(let out, let b, let a, let how): saved += 1; before += b; after += a; lastHow = how; lastName = out.lastPathComponent
            case .alreadySmall: small += 1
            case .unsupported(let why): bad += 1; lastBad = why
            }
        }
        if saved == 0 {
            if small > 0 { return "\(small == 1 ? "That one's" : "Those are") already as small as I can get \(small == 1 ? "it" : "them")." }
            return bad == 1 ? "I can't shrink that: \(lastBad)." : "I can't shrink those. They aren't images I can read."
        }
        let pct = before > 0 ? Int((1 - Double(after) / Double(before)) * 100) : 0
        var msg = saved == 1
            ? "Shrunk \(lastName): \(Files.human(before)) → \(Files.human(after)) (−\(pct)%, \(lastHow))."
            : "Shrunk \(saved) images: \(Files.human(before)) → \(Files.human(after)) (−\(pct)%)."
        if small > 0 { msg += " \(small) already small." }
        if bad > 0 { msg += " Skipped \(bad)." }
        return msg
    }
}

// MARK: - Palette PNGs *with* transparency (ImageIO can't write per-colour alpha, so this writes the PNG itself)

import Compression

extension Shrinker {
    static func zlibCompress(_ input: [UInt8]) -> [UInt8]? {
        var out = [UInt8](repeating: 0, count: input.count + input.count / 8 + 1024)
        let n = compression_encode_buffer(&out, out.count, input, input.count, nil, COMPRESSION_ZLIB)
        guard n > 0 else { return nil }
        var a: UInt32 = 1, b: UInt32 = 0
        var i = 0
        while i < input.count {
            let end = min(i + 5552, input.count)
            while i < end { a += UInt32(input[i]); b += a; i += 1 }
            a %= 65521; b %= 65521
        }
        let adler = (b << 16) | a
        return [0x78, 0x9C] + out[0..<n] + [UInt8(adler >> 24), UInt8((adler >> 16) & 255), UInt8((adler >> 8) & 255), UInt8(adler & 255)]
    }

    static let crcTable: [UInt32] = (0..<256).map { n -> UInt32 in
        var c = UInt32(n)
        for _ in 0..<8 { c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1 }
        return c
    }

    static func chunk(_ type: String, _ body: [UInt8]) -> [UInt8] {
        let t = Array(type.utf8)
        var crc: UInt32 = 0xFFFFFFFF
        for byte in t + body { crc = crcTable[Int((crc ^ UInt32(byte)) & 255)] ^ (crc >> 8) }
        crc ^= 0xFFFFFFFF
        func be(_ v: UInt32) -> [UInt8] { [UInt8(v >> 24), UInt8((v >> 16) & 255), UInt8((v >> 8) & 255), UInt8(v & 255)] }
        return be(UInt32(body.count)) + t + body + be(crc)
    }

    /// 8-bit indexed PNG with a PLTE and tRNS chunk.
    static func indexedPNG(_ w: Int, _ h: Int, _ indices: [UInt8], _ palette: [(r: UInt8, g: UInt8, b: UInt8, a: UInt8)]) -> Data? {
        var raw = [UInt8]()
        raw.reserveCapacity((w + 1) * h)
        for y in 0..<h { raw.append(0); raw.append(contentsOf: indices[(y * w)..<((y + 1) * w)]) }
        guard let z = zlibCompress(raw) else { return nil }
        func be(_ v: Int) -> [UInt8] { [UInt8((v >> 24) & 255), UInt8((v >> 16) & 255), UInt8((v >> 8) & 255), UInt8(v & 255)] }
        var png: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        png += chunk("IHDR", be(w) + be(h) + [8, 3, 0, 0, 0])
        png += chunk("PLTE", palette.flatMap { [$0.r, $0.g, $0.b] })
        var trns = palette.map { $0.a }
        while trns.last == 255 { trns.removeLast() }
        if !trns.isEmpty { png += chunk("tRNS", trns) }
        png += chunk("IDAT", z)
        png += chunk("IEND", [])
        return Data(png)
    }

    /// Median-cut RGBA quantiser (alpha is one of the four axes) with optional Floyd–Steinberg dithering.
    static func paletteWithAlpha(_ premult: [UInt8], _ w: Int, _ h: Int, dither strength: Float) -> Data? {
        let count = w * h
        func aq(_ a: Int) -> Int { a == 0 ? 0 : min(8, 1 + a / 32) }
        func keyOf(_ r: Int, _ g: Int, _ b: Int, _ a: Int) -> Int { (r >> 3) << 14 | (g >> 3) << 9 | (b >> 3) << 4 | aq(a) }

        // straight (un-premultiplied) pixels
        var px = [UInt8](repeating: 0, count: count * 4)
        for i in 0..<count {
            let a = Int(premult[i * 4 + 3])
            px[i * 4 + 3] = UInt8(a)
            if a > 0 {
                px[i * 4] = UInt8(min(255, Int(premult[i * 4]) * 255 / a))
                px[i * 4 + 1] = UInt8(min(255, Int(premult[i * 4 + 1]) * 255 / a))
                px[i * 4 + 2] = UInt8(min(255, Int(premult[i * 4 + 2]) * 255 / a))
            }
        }
        var n = [UInt32](repeating: 0, count: 1 << 19)
        var sr = [Float](repeating: 0, count: 1 << 19), sg = sr, sb = sr, sa = sr
        for i in 0..<count {
            let r = Int(px[i * 4]), g = Int(px[i * 4 + 1]), b = Int(px[i * 4 + 2]), a = Int(px[i * 4 + 3])
            let k = keyOf(r, g, b, a)
            n[k] += 1; sr[k] += Float(r); sg[k] += Float(g); sb[k] += Float(b); sa[k] += Float(a)
        }
        struct C { var r: Float; var g: Float; var b: Float; var a: Float; var n: Int }
        var colors: [C] = []
        for k in 0..<(1 << 19) where n[k] > 0 {
            let c = Float(n[k]); colors.append(C(r: sr[k] / c, g: sg[k] / c, b: sb[k] / c, a: sa[k] / c, n: Int(n[k])))
        }
        guard !colors.isEmpty else { return nil }

        var boxes: [[C]] = [colors]
        while boxes.count < 256 {
            var pick = -1
            var best: Float = 0
            for (i, box) in boxes.enumerated() where box.count > 1 {
                var lo = (Float(255), Float(255), Float(255), Float(255)), hi = (Float(0), Float(0), Float(0), Float(0)), total = 0
                for c in box {
                    lo = (min(lo.0, c.r), min(lo.1, c.g), min(lo.2, c.b), min(lo.3, c.a))
                    hi = (max(hi.0, c.r), max(hi.1, c.g), max(hi.2, c.b), max(hi.3, c.a))
                    total += c.n
                }
                let range = max(hi.0 - lo.0, hi.1 - lo.1, hi.2 - lo.2, hi.3 - lo.3)
                let score = (range + 1) * Float(total).squareRoot()
                if score > best { best = score; pick = i }
            }
            if pick < 0 { break }
            var box = boxes[pick]
            let ranges = [box.map { $0.r }, box.map { $0.g }, box.map { $0.b }, box.map { $0.a }].map { $0.max()! - $0.min()! }
            let axis = ranges.firstIndex(of: ranges.max()!)!
            box.sort { axis == 0 ? $0.r < $1.r : axis == 1 ? $0.g < $1.g : axis == 2 ? $0.b < $1.b : $0.a < $1.a }
            let total = box.reduce(0) { $0 + $1.n }
            var acc = 0, cut = 1
            for (idx, c) in box.enumerated() { acc += c.n; if acc * 2 >= total { cut = max(1, min(box.count - 1, idx + 1)); break } }
            boxes[pick] = Array(box[..<cut])
            boxes.append(Array(box[cut...]))
        }
        var palette: [(r: UInt8, g: UInt8, b: UInt8, a: UInt8)] = boxes.map { box in
            let t = Float(max(1, box.reduce(0) { $0 + $1.n }))
            func avg(_ f: (C) -> Float) -> UInt8 { UInt8(max(0, min(255, (box.reduce(Float(0)) { $0 + f($1) * Float($1.n) } / t).rounded()))) }
            return (avg { $0.r }, avg { $0.g }, avg { $0.b }, avg { $0.a })
        }
        palette.sort { $0.a < $1.a }   // transparent entries first keeps the tRNS chunk short
        if palette.count < 2 { palette.append((0, 0, 0, 255)) }

        var cache = [Int16](repeating: -1, count: 1 << 19)
        func nearest(_ r: Float, _ g: Float, _ b: Float, _ a: Int) -> Int {
            let key = keyOf(Int(r), Int(g), Int(b), a)
            if cache[key] >= 0 { return Int(cache[key]) }
            var bd = Float.greatestFiniteMagnitude, bi = 0
            for (i, p) in palette.enumerated() {
                let da = Float(a) - Float(p.a)
                let weight: Float = (a == 0 || p.a == 0) ? 0 : 1   // transparent pixels: colour is irrelevant
                let d = weight * ((r - Float(p.r)) * (r - Float(p.r)) + (g - Float(p.g)) * (g - Float(p.g)) + (b - Float(p.b)) * (b - Float(p.b))) + da * da * 3
                if d < bd { bd = d; bi = i }
            }
            cache[key] = Int16(bi)
            return bi
        }

        var indices = [UInt8](repeating: 0, count: count)
        var errSum = 0.0
        var cur = [Float](repeating: 0, count: (w + 2) * 3), next = cur
        for y in 0..<h {
            for x in 0..<w {
                let q = (y * w + x) * 4, e = (x + 1) * 3, a = Int(px[q + 3])
                let r = min(255, max(0, Float(px[q]) + cur[e])), g = min(255, max(0, Float(px[q + 1]) + cur[e + 1])), b = min(255, max(0, Float(px[q + 2]) + cur[e + 2]))
                let idx = nearest(r, g, b, a)
                indices[y * w + x] = UInt8(idx)
                guard a > 0 else { continue }
                let pc = palette[idx]
                let dr = Float(px[q]) - Float(pc.r), dg = Float(px[q + 1]) - Float(pc.g), db = Float(px[q + 2]) - Float(pc.b), da = Float(a) - Float(pc.a)
                errSum += Double(dr * dr + dg * dg + db * db + da * da)
                guard strength > 0 else { continue }
                let er = (r - Float(pc.r)) * strength, eg = (g - Float(pc.g)) * strength, eb = (b - Float(pc.b)) * strength
                cur[e + 3] += er * 7 / 16; cur[e + 4] += eg * 7 / 16; cur[e + 5] += eb * 7 / 16
                next[e - 3] += er * 3 / 16; next[e - 2] += eg * 3 / 16; next[e - 1] += eb * 3 / 16
                next[e] += er * 5 / 16; next[e + 1] += eg * 5 / 16; next[e + 2] += eb * 5 / 16
                next[e + 3] += er / 16; next[e + 4] += eg / 16; next[e + 5] += eb / 16
            }
            swap(&cur, &next)
            for k in 0..<next.count { next[k] = 0 }
        }
        lastMSE = errSum / Double(max(1, count * 4))
        guard let data = indexedPNG(w, h, indices, palette) else { return nil }
        // never ship a PNG we can't read back
        guard let src = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceCreateImageAtIndex(src, 0, nil) != nil else { return nil }
        return data
    }
}
