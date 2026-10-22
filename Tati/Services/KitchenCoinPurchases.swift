import Foundation
import Combine
import StoreKit

struct KitchenCoinPack: Identifiable, Decodable, Sendable {
    let id: String
    let coins: Int
    let usdPrice: String
    var referencePrice: String { "US$" + usdPrice }

    static var all: [KitchenCoinPack] { KitchenContentSnapshot.current?.offers.coinPacks ?? [] }

}

@MainActor
final class KitchenCoinPurchases: ObservableObject {
    enum Source: Equatable { case hostLocal, realtimeServer }
    struct Checkout {
        let token: UUID
        let ownerID: String
        let productID: String
        let coins: Int
        let source: Source
        let reference: String?
        let session: UUID?
    }
    @Published private(set) var busyProductID: String?
    @Published private(set) var recovering = false
    @Published private(set) var prices: [String: String] = [:]
    @Published private(set) var loadingOffers = false
    @Published private(set) var offerIssue: String?
    @Published private(set) var recoveryIssue: String?
    private weak var store: MemberKitchenStore?
    private var updates: Task<Void, Never>?
    private var cleanup: Task<Void, Never>?
    private var catalogTask: Task<Void, Never>?
    private var cleanupDone = false
    private var cleanupWaiters: [CheckedContinuation<Void, Never>] = []
    private var frozenOldIDs: Set<UInt64> = []
    private var handled: Set<UInt64> = []
    private var processing: Set<UInt64> = []
    private var knownConsumables: Set<String> = []
    private var contexts: [UUID: Checkout] = [:]
    private var appleToken: UUID?
    private let receipt = KitchenReceiptSnapshot()
    var isSessionCurrent: ((UUID) -> Bool)?
    var didConfirmRemote: (() -> Void)?
    var busy: Bool { busyProductID != nil || recovering }
    func start(store: MemberKitchenStore) {
        self.store = store
        guard updates == nil else { return }
        recovering = true
        cleanup = Task {
            let deadline = Date().addingTimeInterval(10)
            for await result in Transaction.unfinished {
                guard !Task.isCancelled, !cleanupDone, Date() < deadline else { break }
                if case .verified(let transaction) = result, transaction.productType == .consumable {
                    frozenOldIDs.insert(transaction.id)
                    await releaseOld(transaction)
                }
            }
            finishCleanup()
        }
        Task {
            do { try await Task.sleep(for: .seconds(10)) } catch { return }
            cleanup?.cancel(); finishCleanup()
        }
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                await self?.process(result)
            }
        }
    }
    deinit { updates?.cancel(); cleanup?.cancel(); catalogTask?.cancel() }
    func loadOffers() async {
        if let catalogTask { await catalogTask.value; return }
        guard !Task.isCancelled else { return }
        let identifiers = Set(KitchenCoinPack.all.map(\.id))
        loadingOffers = true; offerIssue = nil; prices = [:]
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.loadingOffers = false }
            guard !identifiers.isEmpty else {
                self.offerIssue = "Coin packs are unavailable. Please try again."; return
            }
            do {
                let products = try await Product.products(for: Array(identifiers))
                guard !Task.isCancelled else { return }
                let consumables = products.filter { identifiers.contains($0.id) && $0.type == .consumable }
                self.prices = Dictionary(uniqueKeysWithValues: consumables.map { ($0.id, $0.displayPrice) })
                self.knownConsumables.formUnion(consumables.map(\.id))
                if Set(self.prices.keys) != identifiers {
                    self.offerIssue = "Some coin packs are unavailable. Please try again."
                }
            } catch {
                self.offerIssue = "Apple prices could not be loaded. Please try again."
            }
        }
        catalogTask = task
        await task.value
        catalogTask = nil
        if identifiers != Set(KitchenCoinPack.all.map(\.id)) { await loadOffers() }
    }
    private func finishCleanup() {
        guard !cleanupDone else { return }; cleanupDone = true; recovering = false
        let waiters = cleanupWaiters; cleanupWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }
    func waitForStartupRelease() async {
        if cleanupDone { return }
        await withCheckedContinuation { cleanupWaiters.append($0) }
    }
    private func releaseOld(_ transaction: Transaction) async {
        guard !handled.contains(transaction.id), processing.insert(transaction.id).inserted else { return }
        await transaction.finish()
        handled.insert(transaction.id); processing.remove(transaction.id)
    }
    func buy(_ package: KitchenCoinPack) async { await checkout(productID: package.id, source: .hostLocal, reference: nil, session: nil) }
    func buyFromTable(productID: String, reference: String?, session: UUID) async {
        await checkout(productID: productID, source: .realtimeServer, reference: reference, session: session)
    }
    private func checkout(productID: String, source: Source, reference: String?, session: UUID?) async {
        await waitForStartupRelease()
        guard !Task.isCancelled, let store, !busy, store.account.signedIn, store.storageFailure == nil else { return }
        if let session, isSessionCurrent?(session) != true { return }
        guard SKPaymentQueue.canMakePayments() else { store.tell("Purchases restricted", "In-app purchases are not allowed on this device."); return }
        let owner = store.account.profile.id
        let token = UUID()
        let package = KitchenCoinPack.all.first { $0.id == productID }
        guard source == .realtimeServer || package != nil else { return }
        appleToken = token; busyProductID = productID; store.paymentInProgress = true; recoveryIssue = nil
        defer { releaseApple(token) }
        do {
            guard let product = try await Product.products(for: [productID]).first(where: { $0.id == productID }), product.type == .consumable else { throw KitchenServiceFailure.configuration }
            knownConsumables.insert(product.id)
            prices[productID] = product.displayPrice
            if source == .hostLocal, let package, product.priceFormatStyle.currencyCode == "USD", let expected = Decimal(string: package.usdPrice, locale: Locale(identifier: "en_US_POSIX")), product.price != expected { throw KitchenServiceFailure.configuration }
            guard owner == store.account.profile.id, store.account.signedIn else { return }
            if let session, isSessionCurrent?(session) != true { return }
            contexts[token] = Checkout(token: token, ownerID: owner, productID: productID, coins: package?.coins ?? 0, source: source, reference: reference, session: session)
            switch try await product.purchase(options: [.appAccountToken(token)]) {
            case .success(let result): await process(result)
            case .pending:
                store.tell("Awaiting Apple approval", "Apple is still reviewing this purchase. No coins have been added.")
            case .userCancelled: contexts.removeValue(forKey: token)
            @unknown default:
                contexts.removeValue(forKey: token)
                store.tell("Purchase not completed", "No coins have been added. Check your Apple purchase history if a payment appears.")
            }
        } catch {
            contexts.removeValue(forKey: token)
            store.tell("Purchase interrupted", "The purchase could not be completed. Check your Apple purchase history before buying again.")
        }
    }
    private func releaseApple(_ token: UUID) {
        guard appleToken == token else { return }
        appleToken = nil; busyProductID = nil; store?.paymentInProgress = false
    }
    func recover(showResult: Bool = true) async {
        await waitForStartupRelease()
        if showResult { store?.tell("Consumable purchases", "Used coins cannot be restored. If a payment is missing, contact support with your Apple order details. Tati does not automatically resubmit old coin orders.") }
    }
    private func process(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else {
            if case .unverified(let transaction, _) = result, transaction.productType == .consumable, knownConsumables.contains(transaction.productID) {
                await releaseOld(transaction)
                if let token = transaction.appAccountToken { contexts.removeValue(forKey: token); releaseApple(token) }
            }
            recoveryIssue = "Apple could not verify this purchase. No coins were added."; return
        }
        guard transaction.productType == .consumable else { return }
        if transaction.revocationDate != nil {
            if let store, let credit = store.account.purchaseCredits?[String(transaction.id)], !credit.revoked {
                _ = store.change { value in
                    var adjusted = credit; adjusted.revoked = true
                    value.purchaseCredits?[String(transaction.id)] = adjusted
                    if value.profile.id == credit.ownerID {
                        let removed = min(value.purchasedCoins, credit.coins); value.purchasedCoins -= removed
                        value.purchaseDebt = (value.purchaseDebt ?? 0) + credit.coins - removed
                    }
                }
            }
            if !processing.contains(transaction.id) { await transaction.finish(); handled.insert(transaction.id) }
            return
        }
        if frozenOldIDs.contains(transaction.id) { await releaseOld(transaction); return }
        guard let token = transaction.appAccountToken, let context = contexts[token], context.productID == transaction.productID else {
            await releaseOld(transaction); return
        }
        guard !handled.contains(transaction.id), processing.insert(transaction.id).inserted else { return }
        defer { processing.remove(transaction.id); contexts.removeValue(forKey: token) }
        guard let store else { await transaction.finish(); handled.insert(transaction.id); releaseApple(token); return }
        guard transaction.revocationDate == nil else { await transaction.finish(); handled.insert(transaction.id); releaseApple(token); return }
        let receiptData = await receipt.read()
        let transactionID = String(transaction.id)
        await transaction.finish()
        handled.insert(transaction.id); releaseApple(token)
        guard let receiptData, !receiptData.isEmpty else { failure("Apple's receipt was unavailable. No coins were added. Contact support with your Apple order details.", context); return }
        do {
            try await KitchenAuthentication().confirm(transactionID: transactionID, receipt: receiptData.base64EncodedString(), reference: context.reference)
            guard store.account.signedIn, store.account.profile.id == context.ownerID else { return }
            if let session = context.session, isSessionCurrent?(session) != true { return }
            if context.source == .realtimeServer { didConfirmRemote?(); return }
            guard context.coins > 0, !store.account.processedTransactions.contains(transactionID) else { return }
            let debt = min(store.account.purchaseDebt ?? 0, context.coins)
            let (balance, overflow) = store.account.purchasedCoins.addingReportingOverflow(context.coins - debt)
            guard !overflow else { throw KitchenServiceFailure.storage }
            let credit = CoinPurchaseCredit(transactionID: transactionID, token: token, ownerID: context.ownerID, productID: context.productID, coins: context.coins, creditedAt: Date())
            guard store.change({ value in
                value.purchasedCoins = balance; value.purchaseDebt = (value.purchaseDebt ?? 0) - debt
                value.processedTransactions.insert(transactionID)
                var credits = value.purchaseCredits ?? [:]; credits[transactionID] = credit; value.purchaseCredits = credits
            }) else { throw KitchenServiceFailure.storage }
            store.tell("Coins at your table", "\(context.coins - debt) coins added to your balance.")
        } catch { failure("Payment confirmation could not finish. No coins were added. Contact support with your Apple order details before purchasing again.", context) }
    }
    private func failure(_ text: String, _ context: Checkout) {
        recoveryIssue = text
        if store?.account.profile.id == context.ownerID, store?.account.signedIn == true { store?.tell("Purchase needs attention", text) }
    }
}

@MainActor
private final class KitchenReceiptSnapshot: NSObject, SKRequestDelegate {
    private var request: SKReceiptRefreshRequest?
    private var waiters: [CheckedContinuation<Data?, Never>] = []
    private var deadline: Task<Void, Never>?
    private func existing() -> Data? {
        guard let url = Bundle.main.appStoreReceiptURL, let data = try? Data(contentsOf: url), !data.isEmpty else { return nil }
        return data
    }
    func read() async -> Data? {
        if let data = existing() { return data }
        return await withCheckedContinuation { continuation in
            waiters.append(continuation)
            guard request == nil else { return }
            let refresh = SKReceiptRefreshRequest(); refresh.delegate = self; request = refresh
            deadline = Task { do { try await Task.sleep(for: .seconds(8)) } catch { return }; complete(nil) }
            refresh.start()
        }
    }
    nonisolated func requestDidFinish(_ request: SKRequest) {
        let identity = ObjectIdentifier(request)
        Task { @MainActor in
            guard self.request.map(ObjectIdentifier.init) == identity else { return }
            self.complete(self.existing())
        }
    }
    nonisolated func request(_ request: SKRequest, didFailWithError error: Error) {
        let identity = ObjectIdentifier(request)
        Task { @MainActor in
            guard self.request.map(ObjectIdentifier.init) == identity else { return }
            self.complete(nil)
        }
    }
    private func complete(_ data: Data?) {
        request?.delegate = nil; request?.cancel(); request = nil; deadline?.cancel(); deadline = nil
        let pending = waiters; waiters.removeAll(); pending.forEach { $0.resume(returning: data) }
    }
}
