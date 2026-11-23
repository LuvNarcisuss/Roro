import SwiftUI

struct JournalRoot: View {
    @EnvironmentObject private var app: JournalStore

    var body: some View {
        ZStack {
            JournalPaper()
            if let error = app.loadingError {
                VStack(spacing: 16) {
                    JournalImage("assets/icons/roro-logo.png").frame(width: 96, height: 80)
                    Text(error).multilineTextAlignment(.center)
                    JournalIcon("home", "Reopen library") { app.prepare() }
                }.padding()
            } else if app.state.isEmpty {
                ProgressView("Opening your little moments…")
            } else if !app.entered {
                JournalWelcome()
            } else {
                NavigationStack(path: $app.path) {
                    page(app.tab.route, root: true)
                        .navigationDestination(for: JournalRoute.self) { route in
                            page(route, root: false)
                        }
                }
            }
        }
        .font(.custom("Kalam-Regular", size: 17, relativeTo: .body))
        .foregroundColor(JournalColor.ink)
        .tint(JournalColor.petrol)
        .preferredColorScheme(.light)
        .task { if app.state.isEmpty { app.prepare() } }
        .onReceive(NotificationCenter.default.publisher(for: PurchaseService.balanceDidChange)) { _ in app.refreshWallet() }
        .task(id: app.confirmation) {
            if let confirmation = app.confirmation { await app.presentConfirmation(confirmation) }
        }
        .task(id: app.message) {
            if let message = app.message { await app.presentNotice(message) }
        }
    }

    private func page(_ route: JournalRoute, root: Bool) -> some View {
        let tab = JournalTab.allCases.first { $0.route == route } ?? {
            if case .shorts = route { return .shorts }
            return nil
        }()
        return ZStack {
            JournalPaper()
            if tab == .shorts {
                content(route, root: root).overlay(alignment: .bottom) {
                    JournalDock(selected: .shorts, overVideo: true)
                }
            } else {
                VStack(spacing: 0) {
                    content(route, root: root).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    if let tab { JournalDock(selected: tab, overVideo: false) }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private func content(_ route: JournalRoute, root: Bool) -> some View {
        switch route {
        case .home: PhotographyHome()
        case .topics: PhotographyTopics()
        case let .topic(topic, access): PhotographyTopic(topic: topic, access: access)
        case let .photo(id, focus): PhotographyDetail(id: id, focusComments: focus)
        case let .compose(id, topic): PhotographyCompose(draftID: id, topic: topic)
        case let .member(id): PhotographyMember(id: id)
        case .collection: PhotographyCollection()
        case let .shorts(id, topic): JournalShorts(id: id, topic: topic, root: root)
        case .createShort: JournalShortComposer()
        case .chats: AccountChats()
        case .me: AccountMe()
        default: AccountPage(route: route)
        }
    }
}

private struct JournalWelcome: View {
    @EnvironmentObject private var app: JournalStore
    @State private var choice: Bool?
    private var checked: Bool { choice ?? (app.state["consent"] as? Bool ?? false) }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    JournalImage("assets/icons/roro-logo.png").frame(width: 80, height: 60).accessibilityLabel("Roro")
                    if let cover = (app.catalog["editorialCovers"] as? [String: String])?["welcome"] {
                        Color.clear.frame(height: min(geometry.size.height * 0.52, 460))
                            .overlay { JournalImage(cover, mode: .fill) }.clipped()
                            .accessibilityLabel("Two hands meeting over coffee")
                            .overlay(alignment: .bottomLeading) {
                                Text("A little moment, kept.").foregroundColor(.white).shadow(radius: 2).padding()
                            }
                            .padding(6).background(Color(red: 1, green: 0.96, blue: 0.88)).shadow(radius: 2)
                    }
                    Spacer(minLength: 6)
                    Text("Welcome to Roro").font(.custom("Courgette-Regular", size: 30, relativeTo: .title))
                        .foregroundColor(JournalColor.petrol).accessibilityAddTraits(.isHeader)
                    Text("Keep your photos. Find a little inspiration.")
                    HStack(spacing: 3) {
                        Button { choice = !checked } label: {
                            HStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 3).strokeBorder(JournalColor.petrol, lineWidth: 2)
                                    .frame(width: 20, height: 20).overlay {
                                        if checked { JournalImage("assets/icons/check.png").frame(width: 18, height: 18) }
                                    }
                                Text("I agree to the")
                            }.frame(minHeight: 44)
                        }.accessibilityValue(checked ? "Checked" : "Unchecked")
                        agreement("Terms of Service", "terms")
                        Text("and")
                        agreement("Privacy Policy", "privacy")
                    }.buttonStyle(.plain).font(.custom("Kalam-Regular", size: 14, relativeTo: .footnote))
                    Button { app.login() } label: {
                        Text("Log in").frame(maxWidth: .infinity, minHeight: 48)
                            .foregroundColor(.white).background(JournalColor.accent.opacity(checked ? 1 : 0.5))
                            .cornerRadius(10).contentShape(Rectangle())
                    }.buttonStyle(.plain).disabled(!checked)
                }
                .padding(.horizontal, 24).padding(.vertical, 12)
                .frame(minHeight: geometry.size.height)
            }
        }
    }

    private func agreement(_ title: String, _ kind: String) -> some View {
        Button {
            Task { do { try await app.perform("openAgreement", ["kind": kind]) } catch { app.showError(error) } }
        } label: {
            Text(title).underline().foregroundColor(JournalColor.petrol).frame(minHeight: 44)
        }.accessibilityAddTraits(.isLink)
    }
}

private struct JournalDock: View {
    @EnvironmentObject private var app: JournalStore
    let selected: JournalTab
    let overVideo: Bool

    var body: some View {
        HStack(spacing: 0) {
            ForEach(JournalTab.allCases, id: \.self) { tab in
                Button { app.root(tab) } label: {
                    VStack(spacing: 0) {
                        JournalImage("assets/icons/\(tab.icon).png")
                            .frame(width: 43, height: 40)
                        Text(tab.rawValue).font(.custom("Kalam-Bold", size: 14, relativeTo: .caption))
                        Capsule().fill(tab == selected ? JournalColor.gold : .clear).frame(width: 28, height: 3)
                    }
                    .frame(minWidth: 44, minHeight: 62)
                    .foregroundColor(tab == selected ? JournalColor.gold : JournalColor.paper)
                    .shadow(color: overVideo ? .black : .clear, radius: 2)
                }
                .buttonStyle(.plain).accessibilityLabel(Text(tab.rawValue))
                .accessibilityAddTraits(tab == selected ? .isSelected : [])
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 9).padding(.vertical, 3)
        .background {
            if !overVideo {
                JournalColor.petrol.ignoresSafeArea(edges: .bottom)
                    .overlay {
                        HStack {
                            sprockets
                            Spacer()
                            sprockets
                        }.padding(.horizontal, 2)
                    }
            }
        }
    }

    private var sprockets: some View {
        VStack(spacing: 8) {
            ForEach(0..<5) { _ in Rectangle().fill(JournalColor.paper).frame(width: 4, height: 5) }
        }.accessibilityHidden(true)
    }
}
