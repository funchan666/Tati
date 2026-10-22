import Foundation
import Combine
import StoreKit

struct KitchenCoinPack: Identifiable {
    let id: String
    let coins: Int
    let usdPrice: String
    var referencePrice: String { "US$" + usdPrice }
    // These identifiers and the seven supplied USD price points must remain stable.
    static let all: [KitchenCoinPack] = [
        .init(id: "eokulidmyylccexu", coins: 450, usdPrice: "0.99"),
        .init(id: "odaldmdjpwzbtkiz", coins: 950, usdPrice: "1.99"),
        .init(id: "nvqpshrkctazlme", coins: 1500, usdPrice: "2.99"),
        .init(id: "ozeeyhaxgaggmtoi", coins: 2700, usdPrice: "4.99"),
        .init(id: "kqlydmhtgbargefh", coins: 5800, usdPrice: "9.99"),
        .init(id: "hoakgbrbmsuzzbyt", coins: 12400, usdPrice: "19.99"),
        .init(id: "bzrktwqmnvslhya", coins: 19200, usdPrice: "29.99"),
        .init(id: "wdhsgsoedizvlozy", coins: 32500, usdPrice: "49.99"),
        .init(id: "enaomwjnhhidlyby", coins: 70000, usdPrice: "99.99")
    ]
}

/// StoreKit verifies signed transactions. Delivery and deduplication are committed
/// together in MemberKitchenStore before finish(); unknown ownership is never inferred.
@MainActor
final class KitchenCoinPurchases: ObservableObject {
    @Published private(set) var busyProductID: String?
    @Published private(set) var recovering = false
    @Published private(set) var prices: [String: String] = [:]
    @Published private(set) var recoveryIssue: String?
    private var updates: Task<Void, Never>?
    private weak var store: MemberKitchenStore?
    var busy: Bool { busyProductID != nil || recovering }

    func start(store: MemberKitchenStore) {
        self.store = store
        guard updates == nil else { return }
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                await self?.process(result)
            }
        }
        Task { [weak self] in await self?.recover(showResult: false) }
    }
    deinit { updates?.cancel() }

    func buy(_ package: KitchenCoinPack) async {
        guard let store, !busy, store.account.signedIn, store.storageFailure == nil else { return }
        guard SKPaymentQueue.canMakePayments() else {
            store.tell("Purchases restricted", "In-app purchases are not allowed on this device."); return
        }
        let owner = store.account.profile.id
        busyProductID = package.id; recoveryIssue = nil; store.paymentInProgress = true
        defer { busyProductID = nil; store.paymentInProgress = false }
        do {
            // The only product request in the app: executed by the Buy action.
            guard let product = try await Product.products(for: [package.id]).first(where: { $0.id == package.id }),
                  product.type == .consumable else {
                store.tell("Pack unavailable", "Apple could not load this coin pack. No payment was started. Please try again later."); return
            }
            prices[package.id] = product.displayPrice
            if product.priceFormatStyle.currencyCode == "USD", let expected = Decimal(string: package.usdPrice, locale: Locale(identifier: "en_US_POSIX")), product.price != expected {
                store.tell("Price needs updating", "This pack's Apple price does not match its offer. No payment was started."); return
            }
            guard store.account.profile.id == owner, store.account.signedIn else { return }
            // A unique durable token maps this checkout to its original account and
            // exact coin offer. It is never guessed from SKU or the foreground user.
            let intent = CoinPurchaseIntent(token: UUID(), ownerID: owner, productID: package.id, coins: package.coins, createdAt: Date())
            guard store.change({ value in
                var intents = value.purchaseIntents ?? [:]
                intents[intent.token.uuidString] = intent; value.purchaseIntents = intents
            }) else { return }
            let result = try await product.purchase(options: [.appAccountToken(intent.token)])
            switch result {
            case .success(let verified):
                await process(verified)
                if let recoveryIssue { store.tell("Purchase needs attention", recoveryIssue) }
            case .pending:
                store.tell("Awaiting Apple approval", "Your purchase is pending. Coins will be added after Apple confirms payment.")
            case .userCancelled:
                // Keep the intent as recovery evidence. Cancellation grants nothing.
                break
            @unknown default:
                store.tell("Purchase not completed", "No coins have been added. Use Recover purchases to check its status.")
            }
        } catch {
            store.tell("Purchase interrupted", "This screen could not confirm the purchase. Check your balance or use Recover purchases to check unfinished orders.")
        }
    }

    func recover(showResult: Bool = true) async {
        guard let store, !busy else { return }
        recovering = true; recoveryIssue = nil
        defer { recovering = false }
        let before = (store.account.purchaseCredits ?? [:]).count
        for await result in Transaction.unfinished { await process(result, announces: false) }
        if showResult {
            if let recoveryIssue { store.tell("Purchase needs attention", recoveryIssue) }
            else if (store.account.purchaseCredits ?? [:]).count > before {
                store.celebrate("Balance updated", "Your confirmed purchase has been recovered.", artwork: "coin-pile")
            } else {
                store.tell("Purchases checked", "There are no additional coins to recover for this profile. Previously used consumable coins cannot be restored.")
            }
        }
    }

    private func process(_ result: VerificationResult<Transaction>, announces: Bool = true) async {
        guard let store else { return }
        guard case .verified(let transaction) = result else {
            recoveryIssue = "Apple's transaction signature could not be verified. No coins were added and the order remains unfinished."
            if announces { store.tell("Verification incomplete", recoveryIssue!) }
            return
        }
        guard transaction.productType == .consumable, let token = transaction.appAccountToken else {
            recoveryIssue = "This order has no matching account information. It remains unfinished for review."; return
        }
        let id = String(transaction.id)
        if var credit = store.account.purchaseCredits?[id] {
            guard credit.token == token, credit.productID == transaction.productID else {
                recoveryIssue = "The saved order does not match Apple's transaction. It remains unfinished."; return
            }
            if transaction.revocationDate != nil, !credit.revoked {
                credit.revoked = true
                guard store.change({ value in
                    value.purchaseCredits?[id] = credit
                    if value.profile.id == credit.ownerID {
                        let removed = min(value.purchasedCoins, credit.coins)
                        value.purchasedCoins -= removed
                        value.purchaseDebt = (value.purchaseDebt ?? 0) + credit.coins - removed
                    }
                }) else { recoveryIssue = "The refund adjustment could not be saved."; return }
            }
            // The durable receipt, even for a deleted profile, proves prior delivery.
            await transaction.finish(); return
        }
        guard transaction.revocationDate == nil,
              !store.account.processedTransactions.contains(id),
              let intent = store.account.purchaseIntents?[token.uuidString],
              intent.productID == transaction.productID, intent.ownerID == store.account.profile.id,
              !(store.account.purchaseCredits ?? [:]).values.contains(where: { $0.token == token }),
              intent.coins > 0 else {
            recoveryIssue = "This order cannot be safely matched to this profile and coin offer. It remains unfinished; contact support with your Apple order details."; return
        }
        let debt = min(store.account.purchaseDebt ?? 0, intent.coins)
        let added = intent.coins - debt
        let (balance, overflow) = store.account.purchasedCoins.addingReportingOverflow(added)
        guard !overflow else { recoveryIssue = "The balance could not be updated safely."; return }
        let credit = CoinPurchaseCredit(transactionID: id, token: token, ownerID: intent.ownerID, productID: intent.productID, coins: intent.coins, creditedAt: Date())
        guard store.change({ value in
            var credits = value.purchaseCredits ?? [:]; credits[id] = credit; value.purchaseCredits = credits
            value.processedTransactions.insert(id)
            value.purchasedCoins = balance
            value.purchaseDebt = (value.purchaseDebt ?? 0) - debt
        }) else { recoveryIssue = "Payment was confirmed, but its coin delivery could not be saved. Reopen Tati and recover the purchase."; return }
        await transaction.finish()
        if announces, store.account.profile.id == intent.ownerID, store.account.signedIn {
            store.celebrate("Coins at your table", debt == 0 ? "\(intent.coins.formatted()) coins added to your balance." : "\(added.formatted()) coins added; \(debt.formatted()) settled a previous refund adjustment.", artwork: "coin-pile")
        }
    }
}
