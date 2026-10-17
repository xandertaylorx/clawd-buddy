import Cocoa
import Vision

enum OCR {
    /// Reads text out of an image file using the built-in Vision framework (on-device).
    static func recognize(_ url: URL) -> String? {
        guard let img = NSImage(contentsOf: url), let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        var lines: [(CGFloat, CGFloat, String)] = []
        let req = VNRecognizeTextRequest { r, _ in
            for o in (r.results as? [VNRecognizedTextObservation]) ?? [] {
                if let c = o.topCandidates(1).first { lines.append((o.boundingBox.midY, o.boundingBox.minX, c.string)) }
            }
        }
        req.recognitionLevel = .accurate
        req.usesLanguageCorrection = true
        guard (try? VNImageRequestHandler(cgImage: cg, options: [:]).perform([req])) != nil else { return nil }
        // top to bottom (Vision's y axis points up)
        let sorted = lines.sorted { abs($0.0 - $1.0) > 0.012 ? $0.0 > $1.0 : $0.1 < $1.1 }
        return sorted.map { $0.2 }.joined(separator: "\n")
    }
}

extension Pet {
    /// Drag a box around anything on screen; the text in it lands on your clipboard.
    @objc func screenshotToText() {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("clawd-ocr-\(UUID().uuidString).png")
        brain.start(.think)
        DispatchQueue.global(qos: .userInitiated).async {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            p.arguments = ["-i", "-x", tmp.path]
            guard (try? p.run()) != nil else { return }
            p.waitUntilExit()
            guard FileManager.default.fileExists(atPath: tmp.path) else { return }   // you pressed Esc
            let text = OCR.recognize(tmp)
            try? FileManager.default.removeItem(at: tmp)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    self.say("I couldn't read any text. (Check Screen Recording is allowed for Clawd.)", hold: 5)
                    return
                }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                let words = text.split { $0 == " " || $0 == "\n" }.count
                Sfx.play(.fanfare)
                self.brain.start(.wave)
                self.say("Copied \(words) word\(words == 1 ? "" : "s") from the screenshot.", hold: 4)
            }
        }
    }
}
