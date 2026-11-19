import Foundation
import AVFoundation

func roroError(_ message: String) -> NSError {
    NSError(domain: "Roro", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
}

// The same immutable catalog is bundled for the H5 pages and native ID validation.
enum CommunityCatalog {
    static func load() throws -> [String: Any] {
        guard let url = Bundle.main.url(forResource: "community", withExtension: "json", subdirectory: "AppResources"),
              let data = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any],
              data["authors"] is [[String: Any]], data["photos"] is [[String: Any]], data["shorts"] is [[String: Any]] else {
            throw roroError("The inspiration library could not be opened.")
        }
        return data
    }
    static func records(_ key: String) throws -> [[String: Any]] {
        try load()[key] as? [[String: Any]] ?? []
    }
    static func comments() throws -> [[String: String]] {
        let works = try records("photos") + records("shorts")
        return works.flatMap { work -> [[String: String]] in
            guard let postID = work["id"] as? String else { return [] }
            return (work["comments"] as? [[String: String]] ?? []).map { comment in
                var record = comment
                record["postID"] = postID
                return record
            }
        }
    }

    static func workIDs() throws -> Set<String> {
        Set(try (records("photos") + records("shorts")).compactMap { $0["id"] as? String })
    }
    static func authorIDs() throws -> Set<String> {
        Set(try records("authors").compactMap { $0["id"] as? String }).union(["roro"])
    }
    static func video(_ id: String) throws -> String? {
        guard let record = try records("shorts").first(where: { $0["id"] as? String == id }),
              let path = record["video"] as? String,
              path.range(of: "^assets/videos/[a-z0-9-]+\\.mp4$", options: .regularExpression) != nil else { return nil }
        return path
    }
}

final class PhotoLibrary {
    let directory: URL
    let media: URL
    private var cached: [String: Any]?
    private let fileManager = FileManager.default

    init() {
        directory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Roro", isDirectory: true)
        media = directory.appendingPathComponent("Media", isDirectory: true)
    }

    private func empty(revision: Int = 0) -> [String: Any] {
        ["revision": revision, "consent": false, "profile": ["name": "", "bio": ""],
         "moments": [[String: Any]](), "shorts": [[String: Any]](), "likes": [String](), "saves": [String](),
         "following": [String](), "blocked": [String](), "hidden": [String](), "notes": [[String: Any]](), "comments": [[String: Any]]()]
    }

    func snapshot(reload: Bool = false) throws -> [String: Any] {
        if !reload, let cached { return cached }
        try fileManager.createDirectory(at: media, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("library.json")
        guard fileManager.fileExists(atPath: file.path) else {
            guard cached == nil else { throw roroError("Your library could not be refreshed. Please try again.") }
            let initial = empty()
            try persist(initial)
            return initial
        }
        do {
            let data = try Data(contentsOf: file)
            guard let value = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  value["revision"] is Int, value["consent"] is Bool,
                  value["profile"] is [String: String], value["moments"] is [[String: Any]],
                  value["notes"] is [[String: Any]],
                  ["likes", "saves", "following", "hidden"].allSatisfy({ value[$0] is [String] }) else {
                throw roroError("Your library could not be read. Its original files have been kept.")
            }
            try validate(value)
            cached = value
            return value
        } catch {
            throw roroError("Your library could not be read. Its original files have been kept.")
        }
    }

    func visibleSnapshot(reload: Bool = false) throws -> [String: Any] {
        var result = try snapshot(reload: reload)
        result.removeValue(forKey: "safetyHistory")
        return result
    }

    private func validate(_ value: [String: Any]) throws {
        let invalid = roroError("Your library could not be read. Its original files have been kept.")
        guard let revision = value["revision"] as? Int, revision >= 0,
              let profile = value["profile"] as? [String: String], profile["name"] != nil, profile["bio"] != nil,
              let moments = value["moments"] as? [[String: Any]], let notes = value["notes"] as? [[String: Any]] else { throw invalid }
        var ids = Set<String>()
        for moment in moments {
            guard let id = moment["id"] as? String, UUID(uuidString: id) != nil, ids.insert(id).inserted,
                  let images = moment["images"] as? [String], (1...3).contains(images.count),
                  moment["caption"] is String, moment["topic"] is String, moment["draft"] is Bool,
                  let date = moment["createdAt"] as? String, ISO8601DateFormatter().date(from: date) != nil else { throw invalid }
            for image in images {
                guard image.hasPrefix("media/"), image.hasSuffix(".jpg"),
                      UUID(uuidString: String(image.dropFirst(6).dropLast(4))) != nil else { throw invalid }
            }
        }
        if let raw = value["shorts"], !(raw is [[String: Any]]) { throw invalid }
        for short in value["shorts"] as? [[String: Any]] ?? [] {
            guard let id = short["id"] as? String, UUID(uuidString: id) != nil, ids.insert(id).inserted,
                  let video = short["video"] as? String, validMediaPath(video, extension: "mp4"),
                  let poster = short["poster"] as? String, poster == String(video.dropLast(4)) + ".jpg",
                  let duration = short["duration"] as? Double, duration.isFinite, duration > 0, duration <= 60,
                  short["caption"] is String, short["topic"] is String,
                  let date = short["createdAt"] as? String, ISO8601DateFormatter().date(from: date) != nil else { throw invalid }
        }
        let known = try CommunityCatalog.workIDs().union(ids)
        for key in ["likes", "saves", "hidden"] {
            guard let entries = value[key] as? [String], Set(entries).count == entries.count,
                  entries.allSatisfy({ known.contains($0) }) else { throw invalid }
        }
        let authors = try CommunityCatalog.authorIDs()
        guard let follows = value["following"] as? [String], Set(follows).count == follows.count, follows.allSatisfy({ authors.contains($0) }) else { throw invalid }
        if let raw = value["blocked"], !(raw is [String]) { throw invalid }
        let blocked = value["blocked"] as? [String] ?? []
        guard Set(blocked).count == blocked.count, blocked.allSatisfy({ authors.contains($0) && $0 != "roro" }),
              Set(blocked).isDisjoint(with: follows) else { throw invalid }
        if let raw = value["reports"] {
            guard let reports = raw as? [String], Set(reports).count == reports.count,
                  Set(reports).isSubset(of: Set(try CommunityCatalog.records("shorts").compactMap { $0["id"] as? String })) else { throw invalid }
        }
        if let raw = value["reportedPosts"] {
            guard let reports = raw as? [String], Set(reports).count == reports.count,
                  Set(reports).isSubset(of: Set(try CommunityCatalog.records("photos").compactMap { $0["id"] as? String })) else { throw invalid }
        }
        if let raw = value["reportedComments"] {
            guard let reports = raw as? [String], Set(reports).count == reports.count,
                  Set(reports).isSubset(of: Set(try CommunityCatalog.comments().compactMap { $0["id"] })) else { throw invalid }
        }
        if let raw = value["safetyHistory"] {
            guard let history = raw as? [[String: String]], history.allSatisfy({
                $0["targetID"] != nil && $0["label"] != nil && $0["date"] != nil &&
                    ["block", "unblock", "report", "withdraw"].contains($0["action"] ?? "")
            }) else { throw invalid }
        }
        var noteIDs = Set<String>()
        for note in notes {
            guard let id = note["id"] as? String, UUID(uuidString: id) != nil, noteIDs.insert(id).inserted,
                  let postID = note["postID"] as? String, known.contains(postID), note["text"] is String,
                  let date = note["createdAt"] as? String, ISO8601DateFormatter().date(from: date) != nil else { throw invalid }
        }
        if let raw = value["comments"], !(raw is [[String: Any]]) { throw invalid }
        var commentIDs = Set<String>()
        for comment in value["comments"] as? [[String: Any]] ?? [] {
            guard let id = comment["id"] as? String, UUID(uuidString: id) != nil, commentIDs.insert(id).inserted,
                  let post = comment["postID"] as? String, known.contains(post),
                  let text = comment["text"] as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, text.count <= 500,
                  let date = comment["createdAt"] as? String, ISO8601DateFormatter().date(from: date) != nil else { throw invalid }
        }
        if let pending = value["cleanupPending"], !(pending is Bool) { throw invalid }
    }

    private func persist(_ value: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
        try data.write(to: directory.appendingPathComponent("library.json"), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        cached = value
    }

    func change(_ command: String, _ payload: [String: Any]) throws -> [String: Any] {
        var value = try snapshot()
        var moments = value["moments"] as! [[String: Any]]
        let id = payload["id"] as? String ?? ""
        var shorts = value["shorts"] as? [[String: Any]] ?? []
        let known = try CommunityCatalog.workIDs().union(moments.compactMap { $0["id"] as? String }).union(shorts.compactMap { $0["id"] as? String })
        if command != "consent" && command != "clearLibrary" && value["consent"] as? Bool != true {
            throw roroError("Please accept the agreements to continue.")
        }
        let blocked = Set(value["blocked"] as? [String] ?? [])
        let target = payload["postID"] as? String ?? id
        if ["toggleLike", "toggleSave", "addComment", "addNote"].contains(command),
           (value["reportedPosts"] as? [String] ?? []).contains(target) { throw roroError("This post is hidden.") }
        if ["toggleLike", "toggleSave", "addComment", "addNote"].contains(command),
           (value["reports"] as? [String] ?? []).contains(target) { throw roroError("This video is hidden.") }
        if ["toggleLike", "toggleSave", "addComment", "addNote"].contains(command),
           let work = try (CommunityCatalog.records("photos") + CommunityCatalog.records("shorts")).first(where: { $0["id"] as? String == target }),
           let author = work["authorID"] as? String, blocked.contains(author) {
            throw roroError("Unblock this person before interacting with their work.")
        }
        switch command {
        case "consent":
            value["consent"] = true
            value["acceptedAt"] = ISO8601DateFormatter().string(from: Date())
            value["consentRevision"] = "2026-11-17"
        case "setBlock", "toggleBlock", "setReport":
            let isReport = command == "setReport"
            let key: String
            let record: [String: Any]
            let label: String
            if isReport && payload["kind"] as? String == "comment" {
                guard let comment = try CommunityCatalog.comments().first(where: { $0["id"] == id }),
                      let text = comment["text"], let parent = comment["postID"],
                      payload["postID"] == nil || payload["postID"] as? String == parent else {
                    throw roroError("This comment is unavailable.")
                }
                key = "reportedComments"
                record = comment
                label = text
            } else if isReport && payload["kind"] as? String == "post" {
                guard let post = try CommunityCatalog.records("photos").first(where: { $0["id"] as? String == id }),
                      let caption = post["caption"] as? String else { throw roroError("This post is unavailable.") }
                key = "reportedPosts"
                record = post
                label = caption
            } else {
                let records = try CommunityCatalog.records(isReport ? "shorts" : "authors")
                guard let target = records.first(where: { $0["id"] as? String == id }), id != "roro" else {
                    throw roroError("This safety action is unavailable.")
                }
                key = isReport ? "reports" : "blocked"
                record = target
                label = target[isReport ? "caption" : "name"] as? String ?? (isReport ? "Community video" : "Community member")
            }
            var entries = value[key] as? [String] ?? []
            guard let enabled = command == "toggleBlock" ? !entries.contains(id) : payload["enabled"] as? Bool else {
                throw roroError("This safety action is unavailable.")
            }
            if entries.contains(id) == enabled { return value }
            if enabled { entries.append(id) } else { entries.removeAll { $0 == id } }
            value[key] = entries
            if !isReport && enabled {
                value["following"] = (value["following"] as! [String]).filter { $0 != id }
            }
            var event = ["targetID": id, "label": label, "date": ISO8601DateFormatter().string(from: Date()),
                         "action": isReport ? (enabled ? "report" : "withdraw") : (enabled ? "block" : "unblock")]
            event["authorID"] = isReport ? record["authorID"] as? String : id
            if key == "reportedPosts" {
                event["postID"] = id
            } else if key == "reportedComments" {
                event["postID"] = record["postID"] as? String
                event["commentID"] = id
            } else if let post = payload["postID"] as? String, known.contains(post) {
                event["postID"] = post
                event["commentID"] = payload["commentID"] as? String
            }
            var history = value["safetyHistory"] as? [[String: String]] ?? []
            history.append(event)
            value["safetyHistory"] = history
        case "toggleLike", "toggleSave", "toggleFollow", "hide":
            if command == "toggleFollow", blocked.contains(id) { throw roroError("Unblock this person before following.") }
            guard command == "toggleFollow" ? try CommunityCatalog.authorIDs().contains(id) : known.contains(id) else { throw roroError("This photo is unavailable.") }
            let key = ["toggleLike":"likes", "toggleSave":"saves", "toggleFollow":"following", "hide":"hidden"][command]!
            var items = value[key] as! [String]
            if items.contains(id) { items.removeAll { $0 == id } } else { items.append(id) }
            value[key] = items
        case "saveMoment":
            guard UUID(uuidString: id) != nil,
                  let images = payload["images"] as? [String], (1...3).contains(images.count), Set(images).count == images.count,
                  let caption = payload["caption"] as? String, caption.count <= 500,
                  let topic = payload["topic"] as? String, topic.count <= 60,
                  let draft = payload["draft"] as? Bool else { throw roroError("Please check your moment and try again.") }
            guard !shorts.contains(where: { $0["id"] as? String == id }) else { throw roroError("This identifier is already in use.") }
            for image in images {
                guard validMediaPath(image, extension: "jpg") else { throw roroError("Please choose a photo.") }
                _ = try mediaURL(image)
            }
            let old = moments.first { $0["id"] as? String == id }
            guard old != nil || moments.count < 300 else { throw roroError("Your library is full. Remove a moment before adding another.") }
            let surface = (old?["surface"] as? String ?? payload["surface"] as? String) == "topics" ? "topics" : "home"
            let moment: [String: Any] = ["surface": surface, "id": id, "images": images, "caption": caption.trimmingCharacters(in: .whitespacesAndNewlines), "topic": topic, "draft": draft,
                                         "createdAt": old?["createdAt"] ?? ISO8601DateFormatter().string(from: Date())]
            moments.removeAll { $0["id"] as? String == id }
            moments.insert(moment, at: 0)
            value["moments"] = moments
        case "saveShort":
            guard UUID(uuidString: id) != nil, !moments.contains(where: { $0["id"] as? String == id }),
                  let video = payload["video"] as? String, validMediaPath(video, extension: "mp4"),
                  let poster = payload["poster"] as? String, poster == String(video.dropLast(4)) + ".jpg",
                  let caption = payload["caption"] as? String, caption.count <= 500,
                  let topic = payload["topic"] as? String, topic.count <= 60 else { throw roroError("Please check your short and try again.") }
            let url = try mediaURL(video)
            _ = try mediaURL(poster)
            let asset = AVURLAsset(url: url)
            let duration = CMTimeGetSeconds(asset.duration)
            guard duration.isFinite, duration > 0, duration <= 60, !asset.tracks(withMediaType: .video).isEmpty else { throw roroError("Choose a video up to 60 seconds long.") }
            guard shorts.contains(where: { $0["id"] as? String == id }) || shorts.count < 100 else { throw roroError("Your video library is full. Remove a short before adding another.") }
            let old = shorts.first { $0["id"] as? String == id }
            shorts.removeAll { $0["id"] as? String == id }
            shorts.insert(["id": id, "video": video, "poster": poster, "duration": duration,
                           "caption": caption.trimmingCharacters(in: .whitespacesAndNewlines), "topic": topic,
                           "createdAt": old?["createdAt"] ?? ISO8601DateFormatter().string(from: Date())], at: 0)
            value["shorts"] = shorts
        case "deleteShort":
            guard shorts.contains(where: { $0["id"] as? String == id }) else { throw roroError("This short is unavailable.") }
            shorts.removeAll { $0["id"] as? String == id }
            value["shorts"] = shorts
            for key in ["likes", "saves", "hidden"] { value[key] = (value[key] as! [String]).filter { $0 != id } }
            value["notes"] = (value["notes"] as! [[String: Any]]).filter { $0["postID"] as? String != id }
            value["comments"] = (value["comments"] as? [[String: Any]] ?? []).filter { $0["postID"] as? String != id }
        case "deleteMoment":
            guard moments.contains(where: { $0["id"] as? String == id }) else { throw roroError("This moment is unavailable.") }
            moments.removeAll { $0["id"] as? String == id }
            value["moments"] = moments
            for key in ["likes", "saves", "hidden"] { value[key] = (value[key] as! [String]).filter { $0 != id } }
            value["notes"] = (value["notes"] as! [[String: Any]]).filter { $0["postID"] as? String != id }
            value["comments"] = (value["comments"] as? [[String: Any]] ?? []).filter { $0["postID"] as? String != id }
        case "addComment":
            guard let post = payload["postID"] as? String, known.contains(post),
                  let text = payload["text"] as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  text.count <= 500, UUID(uuidString: id) != nil else { throw roroError("Please enter a short comment.") }
            var comments = value["comments"] as? [[String: Any]] ?? []
            guard comments.count < 3000 else { throw roroError("Your comment library is full.") }
            if !comments.contains(where: { $0["id"] as? String == id }) {
                comments.append(["id": id, "postID": post, "text": text.trimmingCharacters(in: .whitespacesAndNewlines), "createdAt": ISO8601DateFormatter().string(from: Date())])
            }
            value["comments"] = comments
        case "deleteComment":
            value["comments"] = (value["comments"] as? [[String: Any]] ?? []).filter { $0["id"] as? String != id }
        case "addNote":
            guard let post = payload["postID"] as? String, known.contains(post),
                  let text = payload["text"] as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  text.count <= 500, UUID(uuidString: id) != nil else { throw roroError("Please enter a short note.") }
            var notes = value["notes"] as! [[String: Any]]
            guard notes.count < 3000 else { throw roroError("Your notebook is full.") }
            if !notes.contains(where: { $0["id"] as? String == id }) {
                notes.append(["id": id, "postID": post, "text": text, "createdAt": ISO8601DateFormatter().string(from: Date())])
            }
            value["notes"] = notes
        case "deleteNote":
            value["notes"] = (value["notes"] as! [[String: Any]]).filter { $0["id"] as? String != id }
        case "profile":
            guard let name = payload["name"] as? String, let bio = payload["bio"] as? String,
                  !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, name.count <= 40, bio.count <= 160 else { throw roroError("Please check your profile details.") }
            value["profile"] = ["name": name.trimmingCharacters(in: .whitespacesAndNewlines), "bio": bio]
        case "clearLibrary":
            value = empty(revision: value["revision"] as! Int)
            value["cleanupPending"] = true
        default:
            throw roroError("This action is unavailable.")
        }
        value["revision"] = (value["revision"] as! Int) + 1
        try persist(value)
        return value
    }

    func finishPendingCleanup(pages: URL) throws {
        var value = try snapshot()
        guard value["cleanupPending"] as? Bool == true else { return }
        try cleanRemovedMedia(pages: pages, clearAll: true)
        value["cleanupPending"] = false
        value["revision"] = (value["revision"] as! Int) + 1
        try persist(value)
    }

    private func validMediaPath(_ relative: String, extension ext: String) -> Bool {
        relative.hasPrefix("media/") && relative.hasSuffix("." + ext) &&
        UUID(uuidString: String(relative.dropFirst(6).dropLast(ext.count + 1))) != nil
    }

    func discardVideo(_ relative: String, pages: URL) throws {
        guard validMediaPath(relative, extension: "mp4") else { throw roroError("This video is unavailable.") }
        let state = try snapshot()
        let poster = String(relative.dropLast(4)) + ".jpg"
        let used = referencedMedia(state)
        guard !used.contains(relative), !used.contains(poster) else { return }
        for item in [relative, poster] {
            let source = media.appendingPathComponent(String(item.dropFirst(6)))
            let exported = pages.appendingPathComponent(item)
            for url in [source, exported] where fileManager.fileExists(atPath: url.path) { try fileManager.removeItem(at: url) }
        }
    }

    private func referencedMedia(_ state: [String: Any]) -> Set<String> {
        var used = Set((state["moments"] as! [[String: Any]]).flatMap { $0["images"] as? [String] ?? [] })
        for short in state["shorts"] as? [[String: Any]] ?? [] {
            if let video = short["video"] as? String { used.insert(video) }
            if let poster = short["poster"] as? String { used.insert(poster) }
        }
        return used
    }

    func mediaURL(_ relative: String) throws -> URL {
        let name = String(relative.dropFirst("media/".count))
        guard (validMediaPath(relative, extension: "jpg") || validMediaPath(relative, extension: "mp4")),
              fileManager.fileExists(atPath: media.appendingPathComponent(name).path) else {
            throw roroError("This media file could not be found.")
        }
        return media.appendingPathComponent(name)
    }

    func exportMedia(to pages: URL) throws {
        _ = try snapshot()
        let destination = pages.appendingPathComponent("media", isDirectory: true)
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        for source in try fileManager.contentsOfDirectory(at: media, includingPropertiesForKeys: nil) where source.pathExtension == "jpg" {
            let output = destination.appendingPathComponent(source.lastPathComponent)
            if !fileManager.fileExists(atPath: output.path) { try fileManager.copyItem(at: source, to: output) }
        }
    }

    func cleanRemovedMedia(pages: URL, clearAll: Bool = false) throws {
        let state = try snapshot()
        let used = referencedMedia(state)
        for source in try fileManager.contentsOfDirectory(at: media, includingPropertiesForKeys: [.creationDateKey]) {
            let relative = "media/" + source.lastPathComponent
            let date = try source.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date()
            if !used.contains(relative) && (clearAll || Date().timeIntervalSince(date) > 86400) {
                try fileManager.removeItem(at: source)
                let exported = pages.appendingPathComponent(relative)
                if fileManager.fileExists(atPath: exported.path) { try fileManager.removeItem(at: exported) }
            }
        }
    }
}
