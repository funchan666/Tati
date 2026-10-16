import Foundation
import Combine

/// Local-guest availability boundary. No StoreKit transaction is started or finished here.
/// Connect verified product IDs, ownership and durable delivery before enabling payments.
@MainActor
final class TatiPurchases: ObservableObject {
    let availability = "Real purchases are not connected in this local guest edition. App Store products and gift delivery must be configured before top-ups can be enabled. No charge will be made."
}
