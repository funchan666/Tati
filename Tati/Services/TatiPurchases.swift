import Foundation
import Combine

/// Local-guest availability boundary. No StoreKit transaction is started or finished here.
/// Connect verified product IDs, ownership and durable delivery before enabling payments.
@MainActor
final class TatiPurchases: ObservableObject {
    let availability = "Purchases are currently unavailable. No charge will be made."
}
