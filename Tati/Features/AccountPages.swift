import SwiftUI
import WebKit

struct CheckInView: View {
    @EnvironmentObject private var store: VisitorStore
    var body: some View {
        GeometryReader { geometry in
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    let width = min(600, geometry.size.width)
                    let topInset = geometry.safeAreaInsets.top
                    // The design crops the decorative bottom of this banner.
                    // Only its background reaches behind the status area.
                    Color.clear.frame(height: max(120, width * 0.64 - topInset))
                        .background(alignment: .top) {
                            Image("checkin-copy").resizable().scaledToFill()
                                .frame(width: width, height: max(120 + topInset, width * 0.64), alignment: .top)
                                .clipped().offset(y: -topInset)
                                .accessibilityHidden(true)
                        }
                        .overlay(alignment: .top) { TatiHeader(title: "") }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(0..<8) { day in
                            let completed = store.account.claimedDays.count % 8
                            let earnedCount = store.checkedIn && !store.account.claimedDays.isEmpty && completed == 0 ? 8 : completed
                            let earned = day < earnedCount
                            let next = !store.checkedIn && day == store.account.claimedDays.count % 8
                            VStack(spacing: 6) {
                                VStack(spacing: 8) {
                                    Art(name: "coin", width: 40, height: 40)
                                    if earned { Art(name: "paw", width: 16, height: 16) } else { Color.clear.frame(height: 16) }
                                }.padding(.top, 22).padding(.bottom, 8).frame(maxWidth: .infinity)
                                    .background { Image(earned || next ? "day-selected" : "day-default").resizable() }
                                    .overlay(alignment: .topTrailing) {
                                        Text("Day \(day + 1)").font(.system(size: 9)).foregroundStyle(.white)
                                            .frame(width: 43, height: 20)
                                            .background { Image(earned || next ? "label-olive" : "label-gray").resizable() }
                                    }
                                Text("\((day + 1) * 10)").font(.system(size: 13))
                            }.accessibilityLabel("Day \(day + 1), \((day + 1) * 10) reward coins, \(earned ? "collected" : "not collected")")
                        }
                    }.padding(16).background(Color.tatiCream).clipShape(UnevenRoundedRectangle(topLeadingRadius: 18, topTrailingRadius: 18))
                    Text("Reward balance: \(store.account.demoCoins)").font(.system(size: 12)).padding(10)
                }.frame(maxWidth: 600).frame(maxWidth: .infinity)
            }
            VStack(spacing: 8) {
                Note(text: "One reward per UTC day · Reward coins have no cash value.")
                TatiButton(title: store.checkedIn ? "Collected today" : "Collect \(store.nextCheckInReward) reward coins", enabled: !store.checkedIn) { store.checkIn() }
            }.padding(18).frame(maxWidth: 600)
        }
        }.background(Color.tatiCream).foregroundStyle(Color.tatiInk).tatiScreen()
    }
}
struct WalletView: View {
    @EnvironmentObject private var store: VisitorStore
    @EnvironmentObject private var purchases: TatiPurchases
    var body: some View {
        TatiForm(title: "Recharge") {
            ZStack(alignment: .trailing) {
                Image("wallet-card").resizable().frame(height: 104)
                Art(name: "coin-pile", width: 125, height: 105).padding(.trailing, 4)
                VStack(alignment: .leading, spacing: 7) {
                    Text("My coins:").font(.system(size: 15))
                    Text("\(store.account.purchasedCoins)").font(.system(size: 28, weight: .heavy)).lineLimit(1).minimumScaleFactor(0.6)
                }.foregroundStyle(.white).padding(20).padding(.trailing, 112).frame(maxWidth: .infinity, alignment: .leading)
            }
            RechargeOptions(showsActions: false).padding(14).background(.white).clipShape(RoundedRectangle(cornerRadius: 18))
            NavigationLink(destination: CheckInView()) { SettingRow(title: "Reward coins", asset: "coin-small", detail: "\(store.account.demoCoins) · Check-in") }.buttonStyle(.plain)
            if !store.account.gifts.isEmpty {
                Text("Gift history").font(.system(size: 14, weight: .semibold))
                ForEach(store.account.gifts.reversed()) { receipt in
                    HStack {
                        Art(name: FoodCatalog.gift(receipt.giftID)?.artwork ?? "gift-box", width: 38, height: 38)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(FoodCatalog.gift(receipt.giftID)?.name ?? "Gift") × \(receipt.quantity)").font(.system(size: 13))
                            Text("For \(FoodCatalog.person(receipt.recipientID)?.name ?? "recipient")").font(.system(size: 10))
                        }
                        Spacer(); Text("−\(receipt.spent)").font(.system(size: 13))
                    }
                }
            }
        } footer: {
            TatiButton(title: "Continue") { store.tell("Purchases unavailable", purchases.availability) }
            Button("Restore purchases") { store.tell("Purchases unavailable", purchases.availability) }.font(.system(size: 12)).buttonStyle(.plain).frame(minHeight: 32)
        }
    }
}
struct LevelView: View {
    @EnvironmentObject private var store: VisitorStore
    private var level: Int { 1 + store.account.claimedDays.count / 7 }
    var body: some View {
        TatiPage(title: "My level") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Avatar(file: store.account.profile.avatarFile, size: 44, isCurrent: true)
                    Text(store.account.profile.name).font(.system(size: 17, weight: .medium)).lineLimit(2)
                    Spacer(minLength: 0)
                }.padding(.trailing, 72)
                Text("Lv. \(level)").font(.system(size: 26, weight: .heavy))
                Color.white.opacity(0.8).frame(height: 2)
                Text("\(store.account.claimedDays.count % 7) / 7 check-ins").font(.system(size: 11)).frame(maxWidth: .infinity)
            }.padding(.horizontal, 22).padding(.top, 36).padding(.bottom, 18).frame(maxWidth: .infinity, alignment: .leading).background { Image("level-card").resizable() }.padding(.top, 20)
            Note(text: "Every seven check-in days adds one level. Gifts do not affect your level.")
            NavigationLink(destination: CheckInView()) { SettingRow(title: "Daily check-in", asset: "level") }.buttonStyle(.plain)
        }
    }
}
struct BackpackView: View {
    @EnvironmentObject private var store: VisitorStore
    @State private var category = "Stickers"
    var body: some View {
        TatiPage(title: "My backpack") {
            TopicStrip(items: ["Stickers", "Frames", "Badges"], selected: $category)
            if category == "Frames" {
                Art(name: "host-frame", width: 150, height: 150).frame(maxWidth: .infinity)
                Text("Kitchen spotlight").font(.title3.bold())
                Note(text: "A profile frame unlocked by your first daily check-in.")
                TatiButton(title: store.account.equippedFrame ? "Remove frame" : "Wear frame", enabled: !store.account.claimedDays.isEmpty) {
                    _ = store.change { $0.equippedFrame.toggle() }
                }
                if store.account.claimedDays.isEmpty { NavigationLink(destination: CheckInView()) { SettingRow(title: "Check in to unlock", asset: "coin") } }
            } else if category == "Stickers" {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(FoodCatalog.gifts) { gift in
                        VStack(spacing: 8) { Art(name: gift.artwork, width: 48, height: 48); Text(gift.name).font(.system(size: 14)); Text("×0").font(.system(size: 11)) }
                            .padding(10).frame(maxWidth: .infinity).background { Image("outlined-card").resizable() }
                    }
                }
                NavigationLink(destination: WalletView()) { SettingRow(title: "Gift history", asset: "gift-chat") }
            } else {
                Art(name: "level", width: 80, height: 80).frame(maxWidth: .infinity)
                Text("Level \(1 + store.account.claimedDays.count / 7)").font(.headline)
                NavigationLink(destination: LevelView()) { SettingRow(title: "View level progress", asset: "level") }
            }
        }
    }
}
struct BlacklistView: View {
    @EnvironmentObject private var store: VisitorStore
    var body: some View {
        TatiPage(title: "Blacklist") {
            let blocked = FoodCatalog.people.filter { store.account.blocked.contains($0.id) }
            if blocked.isEmpty { EmptyContent(title: "No blocked profiles", detail: "Profiles you block will appear here. Their rooms and videos will be hidden.", artwork: "blacklist") }
            ForEach(blocked) { person in
                HStack {
                    Avatar(asset: person.portraitArtwork, size: 38); Text(person.name).font(.system(size: 14)); Spacer()
                    ArtButton(asset: "remove", label: "Unblock \(person.name)", size: 24) { _ = store.change { $0.blocked.remove(person.id) } }
                }.padding(.horizontal, 12).padding(.vertical, 4).background { Image("outlined-card").resizable() }
            }
        }
    }
}
struct SettingsView: View {
    @EnvironmentObject private var store: VisitorStore
    var body: some View {
        TatiPage(title: "Settings") {
            NavigationLink(destination: BlacklistView()) { SettingRow(title: "Blacklist", outlined: true) }
            NavigationLink(destination: PolicyView(kind: .privacy)) { SettingRow(title: "Privacy agreement", outlined: true) }
            NavigationLink(destination: PolicyView(kind: .terms)) { SettingRow(title: "User agreement", outlined: true) }
            Button { store.deleteVisitor() } label: { SettingRow(title: "Delete profile", outlined: true) }
            Button { store.logout() } label: { SettingRow(title: "Log Out", outlined: true) }
            NavigationLink(destination: LanguagePreferenceView()) { SettingRow(title: "Language", detail: store.account.preferredLanguage ?? "English", outlined: true) }
            Button { _ = store.change { $0.notifications.toggle() } } label: {
                HStack {
                    Text("Notifications").font(.system(size: 14)); Spacer()
                    if store.account.notifications { Art(name: "toggle-on", width: 32, height: 23) } else { SupplementIcon(icon: .toggleOff, size: 32) }
                }.padding(.horizontal, 18).frame(height: 50).background { Image("outlined-card").resizable() }
            }.buttonStyle(.plain).accessibilityValue(store.account.notifications ? "Preference on" : "Preference off")
        }.buttonStyle(.plain)
    }
}
struct ReportView: View {
    var subjectID: String
    var feedback = false
    @EnvironmentObject private var store: VisitorStore
    @Environment(\.dismiss) private var dismiss
    @State private var reason = "Other"
    @State private var details = ""
    @State private var photoData: Data?
    @State private var photoLoading = false
    var body: some View {
        TatiForm(title: feedback ? "Feedback" : "Report") {
            Text("Type").font(.system(size: 14))
            ChoiceGrid(items: feedback ? ["Bug", "Suggestion", "Payment", "Other"] : ["Harassment", "Inappropriate content", "Spam", "Safety concern", "Other"], selected: $reason)
            InputField(title: "Description", text: $details, multiline: true, minimumHeight: 160).onChange(of: details) { _, value in details = String(value.prefix(1000)) }
            Text("Upload photo").font(.system(size: 14))
            PhotoAttachmentPicker(data: $photoData, loading: $photoLoading)

            let saved = store.account.reports.filter { $0.subjectID == subjectID }
            if !saved.isEmpty {
                Text("Saved drafts").font(.headline)
                ForEach(saved.reversed()) { draft in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(draft.reason).font(.subheadline.bold()); Text(draft.details).font(.subheadline)
                        if let file = draft.imageFile, let image = UIImage(contentsOfFile: store.mediaURL(file).path) { Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 150) }
                        Text(draft.date, style: .date).font(.caption)
                        Button("Delete draft") { store.removeReport(draft) }.font(.caption.bold()).foregroundStyle(Color.tatiOlive).buttonStyle(.plain).padding(.vertical, 10)
                    }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(Color.white.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        } footer: {
            TatiButton(title: "Save draft", enabled: !photoLoading && !details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                var file: String?
                do {
                    if let photoData { file = try store.importImage(photoData) }
                    if store.saveReport(subject: subjectID, reason: reason, details: details, imageFile: file) {
                        dismiss()
                        store.tell("Draft saved", "Your \(feedback ? "feedback" : "report") and attachment have been saved as a draft. They have not been submitted.")
                    } else if let file { store.removeUnusedMedia(file) }
                } catch { store.tell("Couldn't save attachment", "Your text and photo selection are still here. Free device storage and try again.") }
            }
        }
    }
}
struct InviteView: View {
    var body: some View {
        TatiPage(title: "Invitation code") {
            VStack(spacing: 10) {
                Art(name: "gift-hero", height: 84)
                Text("Invite friends to your table").font(.system(size: 14))
                Text("Code unavailable").font(.system(size: 14)).padding(.horizontal, 20).padding(.vertical, 10).background(Color.tatiOlive).foregroundStyle(.white).clipShape(Capsule())
            }.padding(18).frame(maxWidth: .infinity).background { Image("outlined-card").resizable() }
            TatiButton(title: "Share invite link", enabled: false) {}
            VStack(alignment: .leading, spacing: 8) {
                Text("How it works").font(.system(size: 15, weight: .semibold))
                ForEach(["Your invitation code will appear here when available.", "Friends enter that code when signing up.", "Invitation rewards depend on the active offer."], id: \.self) { text in
                    HStack(alignment: .top, spacing: 6) { Art(name: "check-pink", width: 16, height: 16); Text(text).font(.system(size: 12)) }
                }
            }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background { Image("outlined-card").resizable() }
        }
    }
}
enum PolicyKind {
    case terms, privacy

    var title: String { self == .terms ? "User Agreement" : "Privacy Policy" }
    var url: URL {
        switch self {
        case .terms: return URL(string: "https://sites.google.com/view/tutu-terms-of-service/foodd")!
        case .privacy: return URL(string: "https://sites.google.com/view/tati-privacypolicy/foodd")!
        }
    }
}
struct PolicyView: View {
    var kind: PolicyKind
    @State private var loading = true
    @State private var loadFailed = false
    @State private var retryID = 0

    var body: some View {
        TatiPage(title: kind.title, scrolling: false) {
            ZStack {
                PolicyWebView(url: kind.url, retryID: retryID, loading: $loading, loadFailed: $loadFailed)
                    .opacity(loadFailed ? 0 : 1)
                    .allowsHitTesting(!loadFailed)
                    .accessibilityHidden(loadFailed)
                if loadFailed {
                    VStack(spacing: 18) {
                        EmptyContent(title: "Couldn't load this page", detail: "Check your connection and try again.")
                        TatiButton(title: "Retry") {
                            loadFailed = false
                            loading = true
                            retryID += 1
                        }
                    }.padding(24).frame(maxWidth: 440)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .top) {
                if loading {
                    Text("Loading…").font(.subheadline).padding(12)
                        .frame(maxWidth: .infinity).background(Color.tatiCream)
                        .accessibilityLabel("Loading \(kind.title)")
                        .allowsHitTesting(false)
                }
            }
        }
    }
}

private struct PolicyWebView: UIViewRepresentable {
    var url: URL
    var retryID: Int
    @Binding var loading: Bool
    @Binding var loadFailed: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        context.coordinator.loadIfNeeded(webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        // Layout and state updates must preserve the document and its reading position.
        context.coordinator.loadIfNeeded(webView)
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        webView.stopLoading()
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: PolicyWebView
        private var loadedURL: URL?
        private var loadedRetryID: Int?
        private var activeNavigation: WKNavigation?

        init(_ parent: PolicyWebView) { self.parent = parent }

        func loadIfNeeded(_ webView: WKWebView) {
            guard loadedURL != parent.url || loadedRetryID != parent.retryID else { return }
            loadedURL = parent.url
            loadedRetryID = parent.retryID
            activeNavigation = webView.load(URLRequest(url: parent.url))
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            activeNavigation = navigation
            parent.loading = true
            parent.loadFailed = false
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard navigation === activeNavigation else { return }
            parent.loading = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            failed(navigation, error: error)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            failed(navigation, error: error)
        }

        private func failed(_ navigation: WKNavigation?, error: Error) {
            guard navigation === activeNavigation else { return }
            let error = error as NSError
            guard !(error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled) else { return }
            parent.loading = false
            parent.loadFailed = true
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            if navigationResponse.isForMainFrame,
               let response = navigationResponse.response as? HTTPURLResponse,
               response.statusCode >= 400 {
                parent.loading = false
                parent.loadFailed = true
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            parent.loading = false
            parent.loadFailed = true
        }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                activeNavigation = webView.load(navigationAction.request)
            }
            return nil
        }
    }
}
