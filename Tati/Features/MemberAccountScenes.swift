import SwiftUI
import WebKit

struct CheckInView: View {
    @EnvironmentObject private var store: MemberKitchenStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var earnedCount: Int {
        let completed = store.account.claimedDays.count % 8
        return store.checkedIn && !store.account.claimedDays.isEmpty && completed == 0 ? 8 : completed
    }
    var body: some View {
        GeometryReader { geometry in
            let width = min(600, geometry.size.width)
            let columns = width < 340 || dynamicTypeSize >= .xxxLarge ? 2 : 4
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        let topInset = geometry.safeAreaInsets.top

                        Color.clear.frame(height: max(120, width * 0.64 - topInset))
                            .background(alignment: .top) {
                                Image("checkin-copy").resizable().scaledToFill()
                                    .frame(width: width, height: max(120 + topInset, width * 0.64), alignment: .top)
                                    .clipped().offset(y: -topInset)
                                    .accessibilityHidden(true)
                            }
                            .overlay(alignment: .top) { TatiHeader(title: "") }
                        VStack(alignment: .leading, spacing: 16) {
                            ViewThatFits(in: .horizontal) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text("Daily rewards").font(.tati(.headline))
                                    Spacer(minLength: 8)
                                    Text("\(earnedCount)/8 collected").font(.tati(.caption)).foregroundStyle(Color.tatiOlive)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Daily rewards").font(.tati(.headline))
                                    Text("\(earnedCount)/8 collected").font(.tati(.caption)).foregroundStyle(Color.tatiOlive)
                                }
                            }
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: columns), spacing: 10) {
                                ForEach(0..<8) { day in
                                    CheckInRewardTile(day: day + 1, collected: day < earnedCount,
                                                      available: !store.checkedIn && day == store.account.claimedDays.count % 8)
                                }
                            }
                            HStack(spacing: 7) {
                                Art(name: "coin-small", width: 20, height: 20)
                                Text("Reward balance").font(.tati(.subheadline))
                                Spacer(minLength: 8)
                                Text(store.account.rewardCoins.formatted()).font(.tati(.headline)).monospacedDigit()
                            }.padding(.top, 4).padding(.horizontal, 2)
                        }.padding(16).background {
                            UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22).fill(Color.tatiCream)
                        }.padding(.top, -12)
                    }.frame(maxWidth: 600).frame(maxWidth: .infinity)
                }
                VStack(spacing: 8) {
                    Note(text: "Check-in resets at midnight UTC. Reward coins cannot be exchanged for money.")
                    TatiButton(title: store.checkedIn ? "Collected today" : "Collect \(store.nextCheckInReward) reward coins", enabled: !store.checkedIn) { store.checkIn() }
                }.padding(18).frame(maxWidth: 600)
            }
        }.background(Color.tatiCream).foregroundStyle(Color.tatiInk).tatiScreen()
    }
}

private struct CheckInRewardTile: View {
    let day: Int
    let collected: Bool
    let available: Bool
    private var status: String { collected ? "Collected" : available ? "Today" : "Upcoming" }
    var body: some View {
        VStack(spacing: 4) {
            Text("Day \(day)").font(.tati(.caption).weight(available ? .bold : .medium))
                .foregroundStyle(available ? Color.tatiInk : Color.tatiOlive)
            Art(name: "coin", width: 32, height: 32).opacity(collected || available ? 1 : 0.65)
                .padding(.vertical, 1)
            Text("+\(day * 10)").font(.tati(.headline, design: .rounded).weight(.bold)).monospacedDigit()
            HStack(spacing: 3) {
                if collected { Art(name: "paw", width: 11, height: 11) }
                Text(LocalizedStringKey(status)).font(.tati(.caption2).weight(available ? .semibold : .regular))
            }.foregroundStyle(available ? Color.tatiInk : Color.tatiOlive)
                .fixedSize(horizontal: false, vertical: true)
        }.padding(.vertical, 10).padding(.horizontal, 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                Image(available ? "day-selected" : "day-default")
                    .resizable(capInsets: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                    .opacity(available ? 1 : collected ? 0.45 : 0.7)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Day \(day), \(day * 10) reward coins, \(status)")
    }
}
struct WalletView: View {
    @EnvironmentObject private var store: MemberKitchenStore
    @EnvironmentObject private var purchases: KitchenCoinPurchases
    @State private var selected = KitchenCoinPack.all.first?.id ?? ""
    private var package: KitchenCoinPack? { KitchenCoinPack.all.first { $0.id == selected } ?? KitchenCoinPack.all.first }
    var body: some View {
        TatiForm(title: "Recharge") {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your balance").font(.tati(.subheadline))
                    Text(store.coinBalance.formatted()).font(.tati(size: 34, weight: .heavy, design: .rounded)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
                    Text("coins").font(.tati(.caption))
                }.frame(maxWidth: .infinity, alignment: .leading)
                Art(name: "coin-pile", width: 116, height: 100)
            }.padding(20).foregroundStyle(.white)
                .background { Image("wallet-card").resizable(capInsets: EdgeInsets(top: 24, leading: 24, bottom: 24, trailing: 24)) }
            ViewThatFits(in: .horizontal) {
                HStack { Text("Purchased \(store.account.purchasedCoins.formatted())"); Spacer(minLength: 8); Text("Bonus \(store.account.rewardCoins.formatted())") }
                VStack(alignment: .leading, spacing: 4) { Text("Purchased \(store.account.purchasedCoins.formatted())"); Text("Bonus \(store.account.rewardCoins.formatted())") }
            }.font(.tati(.caption)).foregroundStyle(Color.tatiOlive).padding(.horizontal, 4)
            Text("Choose your treat").font(.tati(.headline)).padding(.top, 4)
            RechargeOptions(selected: $selected)
            Text("Reference prices in USD. Apple's purchase sheet shows your currency and final price.")
                .font(.tati(.caption2)).foregroundStyle(Color.tatiOlive)
            if let issue = purchases.recoveryIssue { Note(text: issue) }
            if let debt = store.account.purchaseDebt, debt > 0 {
                Note(text: "A previous refund adjustment of \(debt.formatted()) coins will be settled from your next purchase.")
            }
            CoinUsesView()
            NavigationLink(destination: BackpackView()) { SettingRow(title: "My frames", asset: "host-frame") }.buttonStyle(.plain)
            NavigationLink(destination: CheckInView()) { SettingRow(title: "Daily rewards", asset: "coin-small", detail: "Check-in") }.buttonStyle(.plain)
            if !(store.account.coinExpenses ?? []).isEmpty {
                Text("Recent coin activity").font(.tati(.headline))
                ForEach(Array((store.account.coinExpenses ?? []).suffix(10).reversed())) { expense in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) { Text(expense.title).font(.tati(.subheadline)); Text(expense.date, style: .date).font(.tati(.caption)).foregroundStyle(Color.tatiOlive) }
                        Spacer(minLength: 8)
                        Text("−\(expense.coins.formatted())").font(.tati(.subheadline).weight(.semibold)).monospacedDigit()
                    }.padding(.vertical, 6)
                }
            }
        } footer: {
            TatiButton(title: purchases.busyProductID != nil ? "Waiting for Apple…" : "Buy \((package?.coins ?? 0).formatted()) coins", enabled: package != nil && !purchases.busy && store.storageFailure == nil) {
                guard let offer = package else { return }
                Task { await purchases.buy(offer) }
            }
            Button(purchases.recovering ? "Checking purchases…" : "Purchase help") {
                Task { await purchases.recover() }
            }.font(.tati(.caption)).buttonStyle(.plain).frame(minHeight: 44).disabled(purchases.busy)
        }
    }
}
struct LevelView: View {
    @EnvironmentObject private var store: MemberKitchenStore
    private var level: Int { 1 + store.account.claimedDays.count / 7 }
    var body: some View {
        TatiPage(title: "My level") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Avatar(file: store.account.profile.avatarFile, size: 44, isCurrent: true)
                    Text(store.account.profile.name).font(.tati(size: 17, weight: .medium)).lineLimit(2)
                    Spacer(minLength: 0)
                }.padding(.trailing, 72)
                Text("Lv. \(level)").font(.tati(size: 26, weight: .heavy))
                Color.white.opacity(0.8).frame(height: 2)
                Text("\(store.account.claimedDays.count % 7) / 7 check-ins").font(.tati(size: 11)).frame(maxWidth: .infinity)
            }.padding(.horizontal, 22).padding(.top, 36).padding(.bottom, 18).frame(maxWidth: .infinity, alignment: .leading).background { Image("level-card").resizable() }.padding(.top, 20)
            Note(text: "Every seven check-in days adds one level. Gifts do not affect your level.")
            NavigationLink(destination: CheckInView()) { SettingRow(title: "Daily check-in", asset: "level") }.buttonStyle(.plain)
        }
    }
}
struct BackpackView: View {
    @EnvironmentObject private var store: MemberKitchenStore
    @State private var category = "Stickers"
    @State private var showRecharge = false
    var body: some View {
        TatiPage(title: "My backpack") {
            TopicStrip(items: ["Stickers", "Frames", "Badges"], selected: $category)
            if category == "Frames" {
                Art(name: "host-frame", width: 150, height: 150).frame(maxWidth: .infinity)
                Text("Kitchen spotlight").font(.tati(.title3).bold())
                Note(text: store.ownsFrame ? "Yours to wear whenever you like." : "300 coins · A permanent frame for your profile.")
                TatiButton(title: store.ownsFrame ? (store.account.equippedFrame ? "Remove frame" : "Wear frame") : "Unlock · 300 coins") {
                    store.requestFrame { showRecharge = true }
                }
            } else if category == "Stickers" {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(TableCommunity.gifts) { gift in
                        VStack(spacing: 8) { Art(name: gift.artwork, width: 48, height: 48); Text(LocalizedStringKey(gift.name)).font(.tati(size: 14)); Text("\(gift.cost) coins / effect").font(.tati(size: 11)) }
                            .padding(10).frame(maxWidth: .infinity).background { Image("outlined-card").resizable() }
                    }
                }
                NavigationLink(destination: WalletView()) { SettingRow(title: "Gift history", asset: "gift-chat") }
            } else {
                Art(name: "level", width: 80, height: 80).frame(maxWidth: .infinity)
                Text("Level \(1 + store.account.claimedDays.count / 7)").font(.tati(.headline))
                NavigationLink(destination: LevelView()) { SettingRow(title: "View level progress", asset: "level") }
            }
        }.sheet(isPresented: $showRecharge) { NavigationStack { WalletView() }.overlay { NoticeLayer() } }
    }
}
struct BlacklistView: View {
    @EnvironmentObject private var store: MemberKitchenStore
    var body: some View {
        TatiPage(title: "Blacklist", lazyContent: true) {
            let blocked = store.account.blocked.sorted()
            if blocked.isEmpty { EmptyContent(title: "No blocked profiles", detail: "Profiles you block will appear here. Their rooms and videos will be hidden.", artwork: "blacklist") }
            ForEach(blocked, id: \.self) { id in
                let person = TableCommunity.person(id)
                HStack(spacing: 12) {
                    if let person {
                        NavigationLink(destination: PersonProfileView(person: person)) {
                            HStack(spacing: 10) {
                                Avatar(asset: person.portraitArtwork, size: 40)
                                Text(person.name).font(.tati(.body)).fixedSize(horizontal: false, vertical: true)
                            }
                        }.buttonStyle(.plain)
                    } else {
                        Art(name: "blacklist", width: 32, height: 32)
                        Text("Unavailable profile").font(.tati(.body))
                    }
                    Spacer(minLength: 0)
                    Button { store.unblock(id) } label: {
                        Text("Unblock").font(.tati(.subheadline).weight(.semibold))
                            .padding(.horizontal, 12).frame(minHeight: 44)
                            .background(Color.tatiCream, in: RoundedRectangle(cornerRadius: 12))
                    }.buttonStyle(.plain)
                }.padding(12).background(.white, in: RoundedRectangle(cornerRadius: 18))
            }
        }
    }
}
struct SettingsView: View {
    @EnvironmentObject private var store: MemberKitchenStore
    @EnvironmentObject private var notifications: NotificationPreferences
    private var reminderEnabled: Bool { store.account.notifications && notifications.authorized }
    var body: some View {
        TatiPage(title: "Settings") {
            NavigationLink(destination: BlacklistView()) { SettingRow(title: "Blacklist", outlined: true) }
            NavigationLink(destination: PolicyView(kind: .privacy)) { SettingRow(title: "Privacy agreement", outlined: true) }
            NavigationLink(destination: PolicyView(kind: .terms)) { SettingRow(title: "User agreement", outlined: true) }
            NavigationLink(destination: TableGuidelinesView()) { SettingRow(title: "Our table rules", outlined: true) }
            Button { store.deleteVisitor() } label: { SettingRow(title: "Delete profile", outlined: true) }
            Button { store.logout() } label: { SettingRow(title: "Log Out", outlined: true) }
            NavigationLink(destination: LanguagePreferenceView()) {
                SettingRow(title: "Language", detail: AppLanguage.preference(store.account.preferredLanguage).nativeName, outlined: true)
            }
            Button {
                if reminderEnabled { Task { await notifications.toggle(store: store) } }
                else {
                    store.confirm("Daily reminders?", "Get a daily check-in reminder at 19:00, using your device's local time. You can turn it off here at any time.", button: "Enable") {
                        Task { await notifications.toggle(store: store) }
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Notifications").font(.tati(.body))
                        Text("Daily check-in · 19:00").font(.tati(.caption)).foregroundStyle(Color.tatiOlive)
                    }.fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    if reminderEnabled { Art(name: "toggle-on", width: 32, height: 23) }
                    else { SupplementIcon(icon: .toggleOff, size: 32) }
                }.padding(.horizontal, 18).padding(.vertical, 12)
                    .frame(minHeight: 64).background { Image("outlined-card").resizable() }
            }.buttonStyle(.plain).disabled(notifications.busy)
                .accessibilityLabel("Notifications")
                .accessibilityValue(LocalizedStringKey(reminderEnabled ? "On" : "Off"))
        }.buttonStyle(.plain)
            .task { notifications.refresh(store: store) }
    }
}

struct ReportView: View {
    var subjectID: String
    var feedback = false
    var authorID: String? = nil
    var contextID: String? = nil
    @EnvironmentObject private var store: MemberKitchenStore
    @Environment(\.dismiss) private var dismiss
    @State private var reason = ""
    @State private var details = ""
    @State private var photoData: Data?
    @State private var photoLoading = false
    private var reasons: [String] {
        feedback ? ["Bug", "Suggestion", "Payment", "Other"]
            : ["Harassment", "Inappropriate content", "Spam", "Safety concern", "Other"]
    }

    var body: some View {
        TatiEditingForm(title: feedback ? "Feedback" : "Report") {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(LocalizedStringKey(feedback ? "A little better, together." : "Keep our table welcoming."))
                        .font(.tati(.title3).weight(.bold)).fixedSize(horizontal: false, vertical: true)
                    Text(LocalizedStringKey(feedback ? "Tell us what could work better." : "Choose the reason that best fits."))
                        .font(.tati(.subheadline)).foregroundStyle(Color.tatiOlive)
                        .fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Art(name: "support-mascot", width: 56, height: 62)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(LocalizedStringKey(feedback ? "Feedback type" : "Report reason")).font(.tati(.subheadline).weight(.semibold))
                VStack(spacing: 4) {
                    ForEach(reasons, id: \.self) { item in
                        Button { reason = item } label: {
                            HStack(spacing: 12) {
                                Text(LocalizedStringKey(item)).font(.tati(.body).weight(reason == item ? .semibold : .regular))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Art(name: "check-pink", width: 22, height: 22)
                                    .opacity(reason == item ? 1 : 0)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 12)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(reason == item ? Color.tatiLime.opacity(0.7) : .clear,
                                        in: RoundedRectangle(cornerRadius: 12))
                            .contentShape(Rectangle())
                        }.buttonStyle(.plain)
                            .accessibilityAddTraits(reason == item ? .isSelected : [])
                    }
                }.padding(6).background(.white, in: RoundedRectangle(cornerRadius: 18))
            }

            TatiEditingField(label: "More details · optional", placeholder: "Tell us what happened…", text: $details, limit: 1000, multiline: true)

            VStack(alignment: .leading, spacing: 10) {
                Text(LocalizedStringKey(feedback ? "Screenshot · optional" : "Photo evidence · optional")).font(.tati(.subheadline).weight(.semibold))
                PhotoAttachmentPicker(data: $photoData, loading: $photoLoading)
            }

            if !reason.isEmpty {
                    SupportMailboxButton(subject: feedback ? "Tati feedback" : "Tati content report",
                                         message: "Subject: \(subjectID)\nAuthor: \(authorID ?? "Not provided")\nContext: \(contextID ?? "Not provided")\nReason: \(reason)\n\n\(details)",
                                         evidence: photoData,
                                         title: feedback ? "Email feedback" : "Email report", enabled: !photoLoading)
                }

            let saved = store.account.reports.filter { $0.subjectID == subjectID }
            if !saved.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(LocalizedStringKey(feedback ? "Saved feedback" : "Report history")).font(.tati(.subheadline).weight(.semibold))
                    ForEach(saved.reversed()) { draft in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(draft.reason).font(.tati(.subheadline).bold())
                            if !draft.details.isEmpty { Text(draft.details).font(.tati(.subheadline)) }
                            if let file = draft.imageFile {
                                PreparedPhoto(source: .file(store.mediaURL(file)), fills: false)
                                    .frame(height: 150).clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            Text(draft.date, style: .date).font(.tati(.caption)).foregroundStyle(Color.tatiOlive)
                            Button("Remove record") { store.removeReport(draft) }
                                .font(.tati(.caption).bold()).foregroundStyle(Color.tatiOlive)
                                .buttonStyle(.plain).frame(minHeight: 44)
                        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                            .background(.white, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
        } footer: {
            VStack(spacing: 10) {
                Text(LocalizedStringKey(reason.isEmpty ? "Choose a reason to continue." : (feedback ? "Email opens Mail for you to review and send. Saving here does not contact support." : "Email opens Mail for you to review and send. Saving here hides the content but does not contact support.")))
                    .font(.tati(.caption)).foregroundStyle(Color.tatiOlive)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                TatiEditingButton(title: photoLoading ? "Loading photo…" : (feedback ? "Save feedback" : "Hide and save record"), enabled: !photoLoading && !reason.isEmpty, action: save)
            }
        }
        .presentationBackground(Color.tatiCream)
    }

    private func save() {
        var file: String?
        do {
            if let photoData { file = try store.importImage(photoData) }
            if store.saveReport(subject: subjectID, reason: reason, details: details, imageFile: file, authorID: authorID, contextID: contextID, feedback: feedback) {
                dismiss()
                store.celebrate(feedback ? "Feedback saved" : "Report saved", feedback ? "Thank you for helping improve Tati." : "This content is now hidden from your feed.", artwork: "support-mascot")
            } else if let file { store.removeUnusedMedia(file) }
        } catch { store.tell("Couldn't save attachment", "Your text and photo selection are still here. Free device storage and try again.") }
    }
}

struct InviteView: View {
    var body: some View {
        TatiPage(title: "Invitation code") {
            VStack(spacing: 10) {
                Art(name: "gift-hero", height: 84)
                Text("Invite friends to your table").font(.tati(size: 14))
                Text("Code unavailable").font(.tati(size: 14)).padding(.horizontal, 20).padding(.vertical, 10).background(Color.tatiOlive).foregroundStyle(.white).clipShape(Capsule())
            }.padding(18).frame(maxWidth: .infinity).background { Image("outlined-card").resizable() }
            TatiButton(title: "Share invite link", enabled: false) {}
            VStack(alignment: .leading, spacing: 8) {
                Text("How it works").font(.tati(size: 15, weight: .semibold))
                ForEach(["Invitation codes are unavailable.", "You can still find people by name in Search.", "Sharing Tati does not award coins."], id: \.self) { text in
                    HStack(alignment: .top, spacing: 6) { Art(name: "check-pink", width: 16, height: 16); Text(LocalizedStringKey(text)).font(.tati(size: 12)) }
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
    @Environment(\.openURL) private var openURL

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
                        TatiEditingButton(title: "Open in browser", enabled: true) { openURL(kind.url) }
                    }.padding(24).frame(maxWidth: 440)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .top) {
                if loading {
                    Text("Loading…").font(.tati(.subheadline)).padding(12)
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

        context.coordinator.loadIfNeeded(webView)
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        webView.stopLoading()
    }

    @MainActor final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
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

        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping @MainActor @Sendable (WKNavigationResponsePolicy) -> Void) {
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
