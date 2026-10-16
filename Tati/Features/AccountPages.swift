import SwiftUI

struct CheckInView: View {
    @EnvironmentObject private var store: VisitorStore
    var body: some View {
        TatiPage(title: "Check-in") {
            Art(name: "checkin").frame(maxWidth: .infinity)
            HStack { Text("Your little daily treat").font(.title3.bold()); Spacer(); Text("\(store.account.claimedDays.count) days").font(.caption.bold()) }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                ForEach(0..<8) { day in
                    let earned = day < store.account.claimedDays.count % 8
                    VStack(spacing: 9) {
                        Text("Day \(day + 1)").font(.caption.bold())
                        Art(name: "coin-pile", width: 45, height: 45)
                        Text("50").font(.headline)
                        Text(earned ? "Collected" : "Demo coins").font(.system(size: 9))
                    }.padding(.vertical, 14).frame(maxWidth: .infinity).background { Image(earned ? "day-selected" : "day-default").resizable() }
                }
            }
            TatiButton(title: store.checkedIn ? "Collected today" : "Collect 50 demo coins", enabled: !store.checkedIn) { store.checkIn() }
            Note(text: "One reward per UTC calendar day. Each check-in earns 50 demo coins; missed days do not remove earlier rewards. Demo coins are local, have no cash value and cannot be transferred.")
            Text("Demo balance: \(store.account.demoCoins)").font(.headline)
        }
    }
}
struct WalletView: View {
    @EnvironmentObject private var store: VisitorStore
    @EnvironmentObject private var purchases: TatiPurchases
    var body: some View {
        TatiPage(title: "My wallet") {
            VStack(alignment: .leading, spacing: 14) {
                Text("Tati wallet").font(.title2.bold())
                HStack { Art(name: "coin", width: 42); Text("\(store.account.purchasedCoins)").font(.system(size: 34, weight: .heavy)); Spacer() }
                Text("Purchased coins").font(.caption)
            }.padding(24).frame(maxWidth: .infinity, alignment: .leading).background { Image("wallet-card").resizable() }
            HStack { Text("Demo coins").font(.headline); Spacer(); Text("\(store.account.demoCoins)").font(.headline) }
            NavigationLink(destination: CheckInView()) { SettingRow(title: "Daily check-in", asset: "coin-pile", detail: "50 demo coins") }.buttonStyle(.plain)
            Text("Top up").font(.title3.bold())
            Art(name: "recharge-banner")
            Note(text: purchases.availability)
            TatiButton(title: "Purchases unavailable", enabled: false) {}
            TatiButton(title: "Restore purchases", secondary: true) { store.tell("Purchases aren't configured", purchases.availability) }
            Text("Gift preview history").font(.headline)
            if store.account.gifts.isEmpty { EmptyContent(title: "No gift previews yet", detail: "Preview a gift in a room or profile using local demo coins.", artwork: "gift-box") }
            ForEach(store.account.gifts.reversed()) { receipt in
                HStack {
                    Art(name: FoodCatalog.gift(receipt.giftID)?.artwork ?? "gift-box", width: 48, height: 48)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(FoodCatalog.gift(receipt.giftID)?.name ?? "Gift") × \(receipt.quantity)").font(.subheadline.bold())
                        Text("Preview for \(FoodCatalog.person(receipt.recipientID)?.name ?? "sample profile")").font(.caption)
                        Text(receipt.date, style: .date).font(.caption2)
                    }
                    Spacer(); Text("−\(receipt.spent)").font(.subheadline.bold())
                }.padding(12).background(Color.white.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: 15))
            }
            Note(text: "Gift previews use only demo coins. They are never delivered to a remote account. No prices or successful purchases are simulated.")
        }
    }
}
struct LevelView: View {
    @EnvironmentObject private var store: VisitorStore
    private var level: Int { 1 + store.account.claimedDays.count / 7 }
    var body: some View {
        TatiPage(title: "My level") {
            Art(name: "level-card")
            Text("Local level \(level)").font(.largeTitle.bold())
            Text("\(store.account.claimedDays.count % 7) / 7 check-ins toward your next level").font(.headline)
            Note(text: "In this local version, every seven check-in days adds one level. Buying or previewing gifts does not affect your level.")
            NavigationLink(destination: CheckInView()) { SettingRow(title: "Daily check-in", asset: "level") }.buttonStyle(.plain)
        }
    }
}
struct BackpackView: View {
    @EnvironmentObject private var store: VisitorStore
    @State private var category = "Frames"
    var body: some View {
        TatiPage(title: "My backpack") {
            TopicStrip(items: ["Frames", "Gifts", "Badges"], selected: $category)
            if category == "Frames" {
                Art(name: "host-frame", width: 150, height: 150).frame(maxWidth: .infinity)
                Text("Kitchen spotlight").font(.title3.bold())
                Note(text: "A local profile frame unlocked by your first daily check-in.")
                TatiButton(title: store.account.equippedFrame ? "Remove frame" : "Wear frame", enabled: !store.account.claimedDays.isEmpty) {
                    _ = store.change { $0.equippedFrame.toggle() }
                }
                if store.account.claimedDays.isEmpty { NavigationLink(destination: CheckInView()) { SettingRow(title: "Check in to unlock", asset: "coin") } }
            } else if category == "Gifts" {
                EmptyContent(title: "No stored gifts", detail: "Gift previews are consumed when you confirm them. Their history is in your wallet.", artwork: "gift-box")
                NavigationLink(destination: WalletView()) { SettingRow(title: "Gift preview history", asset: "gift-chat") }
            } else {
                Art(name: "level", width: 80, height: 80).frame(maxWidth: .infinity)
                Text("Local level \(1 + store.account.claimedDays.count / 7)").font(.headline)
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
            if blocked.isEmpty { EmptyContent(title: "No blocked profiles", detail: "Profiles you block will appear here. Their rooms and videos are hidden on this device.", artwork: "blacklist") }
            ForEach(blocked) { person in
                HStack {
                    Avatar(); Text(person.name).font(.headline); Spacer()
                    TatiButton(title: "Unblock", secondary: true) { _ = store.change { $0.blocked.remove(person.id) } }.frame(width: 115)
                }
            }
        }
    }
}
struct SettingsView: View {
    @EnvironmentObject private var store: VisitorStore
    var body: some View {
        TatiPage(title: "Settings") {
            NavigationLink(destination: EditProfileView()) { SettingRow(title: "Edit profile", asset: "profile-heading") }
            NavigationLink(destination: BlacklistView()) { SettingRow(title: "Blacklist", asset: "blacklist", detail: "\(store.account.blocked.count)") }
            HStack {
                Art(name: "email", width: 25); Text("Notifications").font(.subheadline); Spacer()
                SupplementIcon(icon: .toggleOff, size: 40)
            }.padding(16).background(Color.white.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: 14))
            Note(text: "Notifications will become available when a service is connected. Tati does not send notifications in local guest mode.")
            SettingRow(title: "Language", asset: "globe", detail: "English")
            Note(text: "This version follows the English design copy. Additional languages are not installed yet.")
            NavigationLink(destination: PolicyView(kind: .privacy)) { SettingRow(title: "Privacy Policy", asset: "bio") }
            NavigationLink(destination: PolicyView(kind: .terms)) { SettingRow(title: "Terms of Use", asset: "bio") }
            NavigationLink(destination: ReportView(subjectID: "feedback", feedback: true)) { SettingRow(title: "Feedback", asset: "feedback") }
            TatiButton(title: "Log out", secondary: true) { store.logout() }
            TatiButton(title: "Delete local profile") { store.deleteVisitor() }
            Note(text: "Tati 1.0 · Local guest edition. Logging out keeps your data on this device. Deleting your local profile removes its saved content.")
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
    var body: some View {
        TatiPage(title: feedback ? "Feedback" : "Report") {
            Text(feedback ? "Help Tati grow" : "Tell us what happened").font(.title2.bold())
            ChoiceGrid(items: feedback ? ["Suggestion", "Technical issue", "Other"] : ["Harassment", "Inappropriate content", "Spam", "Safety concern", "Other"], selected: $reason)
            InputField(title: "Details", text: $details, multiline: true).onChange(of: details) { _, value in details = String(value.prefix(1000)) }
            Note(text: "Support is not connected yet. This saves a private draft on this device; it is not submitted to a moderation team.")
            TatiButton(title: "Save local draft", enabled: !details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                if store.saveReport(subject: subjectID, reason: reason, details: details) {
                    dismiss()
                    store.tell("Draft saved", "Your \(feedback ? "feedback" : "report") is saved locally. It has not been sent to support.")
                }
            }
            let saved = store.account.reports.filter { $0.subjectID == subjectID }
            if !saved.isEmpty {
                Text("Saved drafts").font(.headline)
                ForEach(saved.reversed()) { draft in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(draft.reason).font(.subheadline.bold()); Text(draft.details).font(.subheadline)
                        Text(draft.date, style: .date).font(.caption)
                        Button("Delete draft") { _ = store.change { $0.reports.removeAll { $0.id == draft.id } } }.font(.caption.bold()).foregroundStyle(Color.tatiOlive).buttonStyle(.plain).padding(.vertical, 10)
                    }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(Color.white.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }
}
struct SupportView: View {
    var body: some View {
        TatiPage(title: "Customer support") {
            Art(name: "support-banner")
            Art(name: "support-mascot", height: 125).frame(maxWidth: .infinity)
            Text("We're building a better table").font(.title2.bold())
            Note(text: "No support service or contact address has been configured for this local version. Save feedback below to keep it on this device.")
            NavigationLink(destination: ReportView(subjectID: "support", feedback: true)) { SettingRow(title: "Write feedback", asset: "feedback") }.buttonStyle(.plain)
        }
    }
}
struct InviteView: View {
    var body: some View {
        TatiPage(title: "Invite friends") {
            Art(name: "invite", height: 90).frame(maxWidth: .infinity)
            EmptyContent(title: "Invite codes are coming later", detail: "A connected account service is needed to create or redeem a real invitation code. Local guests do not receive fabricated invite codes.", artwork: "tool-invite")
        }
    }
}
enum PolicyKind { case terms, privacy }
struct PolicyView: View {
    var kind: PolicyKind
    var body: some View {
        TatiPage(title: kind == .terms ? "Local guest terms" : "Local guest privacy") {
            Text("Tati · Local guest edition").font(.title2.bold())
            if kind == .privacy {
                policy("Stored on your device", "Your guest profile, imported media, follows, blocks, likes, drafts, check-ins and gift previews are stored in Tati's application storage. This version has no account or analytics server connection.")
                policy("Photos, camera and microphone", "Photo and video selection uses the iOS picker. Camera access is requested only for the camera preview. Microphone access is requested only when you choose to check it. No live broadcast, call or voice recording is started.")
                policy("Your controls", "You may delete imported videos and local drafts, edit your profile or delete all local profile data from Settings. Logging out retains the local profile. Device backups may retain app data according to your iOS backup settings.")
                policy("Before online services", "The publisher must provide its identity, contact details and final policy before connecting services or public release. No third-party data-processing policy is claimed by this local preview.")
            } else {
                policy("A local preview", "Tati currently provides on-device profiles, media and interface previews. Sample profiles are not connected people. Room previews are not live broadcasts. Chats, comments, AI prompts and reports are saved locally rather than sent.")
                policy("Media and community", "Import only content you have the right to use. Do not use Tati to create unlawful, abusive or exploitative content. Block controls hide sample content locally; saved reports are not reviewed by a remote team.")
                policy("Rewards and gifts", "Demo coins are free local rewards with no monetary value. Gift previews consume demo coins and are recorded locally. They do not deliver gifts to another person. Real purchases are unavailable in this edition.")
                policy("Availability", "Local data cannot be recovered from an online account. Deleting your local profile or removing the app can remove this data. Final publisher terms and contact information must be supplied before public release.")
            }
        }
    }
    private func policy(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 10) { Text(title).font(.headline); Text(body).font(.subheadline).fixedSize(horizontal: false, vertical: true) }
    }
}
