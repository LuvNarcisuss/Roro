import SwiftUI

struct PhotographyMember: View {
    @EnvironmentObject private var app: JournalStore
    let id: String
    private enum SafetyAction: String, Identifiable {
        case block = "Block", unblock = "Unblock", report = "Report"
        var id: String { rawValue }
    }
    @State private var pending: SafetyAction?

    var body: some View {
        let member = app.photographyMember(id)
        let photos = app.photos.filter { $0.str("authorID") == id }
        let clips = app.shorts.filter { $0.str("authorID") == id }
        let works = clips + photos
        let name = member.str("name")
        let blocked = app.state.strings("blocked").contains(id)
        let following = app.state.strings("following").contains(id)
        VStack(spacing: 0) {
            JournalHeader("Profile")
            ScrollView {
                VStack(spacing: 10) {
                    PhotographyPortrait(profile: member, size: 84)
                    PhotographyTitle(title: name, size: 28)
                    if !member.str("handle").isEmpty { Text("@" + member.str("handle")).foregroundStyle(.secondary) }
                    Text(member.str("bio")).multilineTextAlignment(.center)
                    HStack(spacing: 18) {
                        stat("Works", works.count)
                        stat("Likes", works.reduce(0) { $0 + app.photoCount("likes", $1) })
                        stat("Saves", works.reduce(0) { $0 + app.photoCount("saves", $1) })
                    }
                    HStack(spacing: 8) {
                        PhotographyLabeledAction(icon: following ? "check" : "plus", label: following ? "Following" : app.state.strings("followers").contains(id) ? "Follow back" : "Follow", selected: following) {
                            _ = app.change("toggleFollow", ["id": id])
                        }.disabled(blocked)
                        PhotographyLabeledAction(icon: "chat", label: "Message") {
                            if app.state.strings("unreadChats").contains(id) { _ = app.change("setChatUnread", ["peerID": id, "enabled": false]) }
                            app.open(.chat(id))
                        }.disabled(blocked)
                        JournalIcon("block", blocked ? "Unblock \(name)" : "Block \(name)", selected: blocked) {
                            pending = blocked ? .unblock : .block
                        }
                        if !blocked {
                            JournalIcon("info", "Report author " + name) { pending = .report }
                        }
                    }
                    if blocked { Text("You’ve blocked \(name).") }
                }.padding(14).frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 10) {
                    if !clips.isEmpty {
                        PhotographyTitle(title: "Shorts · \(clips.count)")
                        PhotographyGrid(works: clips)
                    }
                    if !photos.isEmpty {
                        PhotographyTitle(title: "Moments · \(photos.count)")
                        PhotographyGrid(works: photos)
                    }
                    if works.isEmpty { Text("No visible works. You can restore hidden works in Settings.") }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(14)
            }.refreshable { _ = await app.photographyRefresh() }
        }.buttonStyle(.plain)
            .alert(item: $pending) { action in
                Alert(title: Text(action.rawValue + " " + name + "?"),
                      message: action == .block ? Text("If you block \(name), you’ll no longer see their posts or comments.") : nil,
                      primaryButton: .destructive(Text(action.rawValue)) {
                    if action == .report {
                        if app.change("setReport", ["id": id, "kind": "author", "enabled": true]) {
                            app.confirmation = "Report saved for this account."
                        }
                    } else {
                        _ = app.change("setBlock", ["id": id, "enabled": action == .block])
                    }
                }, secondaryButton: .cancel())
            }
    }

    private func stat(_ label: String, _ value: Int) -> some View {
        VStack(spacing: 1) {
            Text("\(value)").fontWeight(.bold)
            Text(label).font(.footnote)
        }
    }
}
