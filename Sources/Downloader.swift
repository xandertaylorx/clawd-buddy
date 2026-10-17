import Cocoa

// MARK: - Links dropped on Clawd: YouTube / Spotify → MP3 / MP4 (uses yt-dlp + ffmpeg if installed)

struct DropItems {
    var files: [URL] = []
    var link: URL?
    var text: String?
}

func readDrop(_ pb: NSPasteboard) -> DropItems {
    var d = DropItems()
    d.files = (pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
    if d.files.isEmpty {
        let urls = (pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL]) ?? []
        d.link = urls.first { !$0.isFileURL && ($0.scheme == "http" || $0.scheme == "https") }
        d.text = pb.string(forType: .string)
        if d.link == nil, let t = d.text?.trimmingCharacters(in: .whitespacesAndNewlines),
           let u = URL(string: t), u.scheme == "http" || u.scheme == "https", u.host != nil {
            d.link = u
        }
    }
    return d
}

enum LinkKind { case youtube, spotifyTrack, other }
enum DLResult { case success(URL), failure(String) }

enum Downloader {
    static func classify(_ u: URL) -> LinkKind {
        let h = (u.host ?? "").lowercased()
        if h == "youtu.be" || h == "youtube.com" || h.hasSuffix(".youtube.com") { return .youtube }
        if h == "open.spotify.com" && u.path.contains("/track/") { return .spotifyTrack }
        return .other
    }

    static let searchDirs = ["/opt/homebrew/bin", "/usr/local/bin", NSHomeDirectory() + "/.local/bin", "/usr/bin"]

    static func tool(_ name: String) -> String? {
        let dirs = searchDirs + (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map(String.init)
        return dirs.map { $0 + "/" + name }.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    static var outputDir: URL {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0].appendingPathComponent("Clawd", isDirectory: true)
    }

    /// Spotify's own audio is DRM-locked, so we read the track's title and artist from its public page
    /// and look for the matching audio on YouTube instead.
    static func spotifyQuery(_ url: URL, completion: @escaping (String?) -> Void) {
        var req = URLRequest(url: url)
        req.setValue("Mozilla/5.0 (Macintosh) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 15
        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data, let html = String(data: data, encoding: .utf8) else { return completion(nil) }
            func meta(_ prop: String) -> String? {
                guard let r = html.range(of: "<meta property=\"\(prop)\" content=\"") else { return nil }
                let rest = html[r.upperBound...]
                guard let end = rest.firstIndex(of: "\"") else { return nil }
                return String(rest[..<end]).replacingOccurrences(of: "&amp;", with: "&")
                    .replacingOccurrences(of: "&#x27;", with: "'").replacingOccurrences(of: "&quot;", with: "\"")
            }
            guard let title = meta("og:title") else { return completion(nil) }
            let artist = meta("og:description")?.components(separatedBy: " · ").first ?? ""
            completion(artist.isEmpty ? title : "\(artist) - \(title)")
        }.resume()
    }

    static func args(source: String, mp4: Bool, fileName: String?) -> [String] {
        let base = outputDir.path + "/" + (fileName.map { sanitize($0) } ?? "%(title).150B") + ".%(ext)s"
        var a = ["--no-playlist", "--newline", "--progress", "--progress-template", "download:CLAWDPCT%(progress._percent_str)s",
                 "--print", "after_move:CLAWDFILE%(filepath)s", "--no-simulate", "-o", base]
        if mp4 {
            a += ["-f", "bv*[ext=mp4]+ba[ext=m4a]/b[ext=mp4]/bv*+ba/b", "--merge-output-format", "mp4"]
        } else {
            a += ["-x", "--audio-format", "mp3", "--audio-quality", "0", "--embed-metadata"]
        }
        a.append(source)
        return a
    }

    static func sanitize(_ s: String) -> String {
        let bad = CharacterSet(charactersIn: "/\\:*?\"<>|%").union(.controlCharacters)
        return String(s.unicodeScalars.filter { !bad.contains($0) }).trimmingCharacters(in: .whitespaces)
    }

    /// Runs yt-dlp. `progress` gets 0...100 on the main queue; `done` gets the saved file or an error message.
    static func run(source: String, mp4: Bool, fileName: String?, progress: @escaping (Int) -> Void,
                    done: @escaping (DLResult) -> Void) {
        guard let ytdlp = tool("yt-dlp") else { return done(.failure("missing yt-dlp")) }
        guard tool("ffmpeg") != nil else { return done(.failure("missing ffmpeg")) }
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        let p = Process()
        p.executableURL = URL(fileURLWithPath: ytdlp)
        p.arguments = args(source: source, mp4: mp4, fileName: fileName)
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = searchDirs.joined(separator: ":") + ":" + (env["PATH"] ?? "")
        p.environment = env
        let out = Pipe(), err = Pipe()
        p.standardOutput = out
        p.standardError = err
        var buffer = ""
        var saved: String?
        out.fileHandleForReading.readabilityHandler = { h in
            let chunk = String(decoding: h.availableData, as: UTF8.self)
            guard !chunk.isEmpty else { return }
            buffer += chunk
            while let nl = buffer.firstIndex(of: "\n") {
                let line = String(buffer[..<nl])
                buffer = String(buffer[buffer.index(after: nl)...])
                if let r = line.range(of: "CLAWDPCT") {
                    let pct = Double(line[r.upperBound...].trimmingCharacters(in: CharacterSet(charactersIn: "% "))) ?? 0
                    DispatchQueue.main.async { progress(Int(pct)) }
                } else if let r = line.range(of: "CLAWDFILE") {
                    saved = String(line[r.upperBound...]).trimmingCharacters(in: .whitespaces)
                }
            }
        }
        p.terminationHandler = { proc in
            out.fileHandleForReading.readabilityHandler = nil
            let errText = String(decoding: err.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            DispatchQueue.main.async {
                if proc.terminationStatus == 0, let s = saved, FileManager.default.fileExists(atPath: s) {
                    done(.success(URL(fileURLWithPath: s)))
                } else {
                    let line = errText.split(separator: "\n").last(where: { $0.contains("ERROR") }).map(String.init) ?? "download failed"
                    done(.failure(line.replacingOccurrences(of: "ERROR: ", with: "")))
                }
            }
        }
        do { try p.run() } catch { done(.failure("couldn't start yt-dlp")) }
    }
}
