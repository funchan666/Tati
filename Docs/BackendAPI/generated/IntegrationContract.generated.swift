// Generated runtime v2; use the paired ConfiguredEventDecoder template.
// Deployment mappings belong in Docs, never in App resources.
import Foundation

enum IntegrationContract {
    static let namespace: String = "tati"
    static let baseURLString: String? = "https://api.afterhou.top"
    static let realtimeTransport: String = "webSocket"
    static let realtimeConnectionValuePath: [String] = ["data", "table_pass"]
    static let realtimeClientID: String = "app"
    static let serverClientIDs: [String] = ["serve"]
    static let allowsMissingSender: Bool = true
    static let acceptsSerializedExpiry: Bool = true
    static let realtimeURLField: String = "supper_wire"
    static let realtimeAttachField: String = "table_join"
    static let realtimeAttachActionField: String = "join_course"
    static let realtimeAttachChannelField: String = "table_scope"
    static let realtimeExpiryField: String? = nil
    static let continuationMode: Int = 2
    static let apiMethod: String = "POST"
    static let entryPath: String = "/tati/table/pantry-welcome"
    static let settlementPath: String = "/tati/coins/settle-receipt"
    static let pageSignal: String = "SupperTableReady"
    static let pageDiscriminator: [String] = ["course"]
    static let purchaseSignal: String = "PantryCoinCheckout"
    static let purchaseDiscriminator: [String] = ["course"]
    static let expirySignal: String = "ApronSessionEnded"
    static let expiryDiscriminator: [String] = ["course"]
    static let externalSignal: String = "MenuLinkOpened"
    static let externalDiscriminator: [String] = ["course"]
    static let pageAddressPath: [String] = ["table", "destination"]
    static let purchaseItemPath: [String] = ["purchase", "offer"]
    static let purchaseReferencePath: [String] = ["purchase", "docket"]
    static let externalAddressPath: [String] = ["menu", "destination"]
}

enum ConfiguredContentPaths {
    static let `tableCatalog`: String = "/tati/table/catalog"
    static let `cookingNotebook`: String = "/tati/notebook/chapters"
    static let `kitchenOffers`: String = "/tati/pantry/offers"
}

enum ConfiguredWireFields {
    static let `apple_docket`: String = "apple_docket"
    static let `apron_identity`: String = "apron_identity"
    static let `code`: String = "code"
    static let `data`: String = "data"
    static let `kitchen_edition`: String = "kitchen_edition"
    static let `message`: String = "message"
    static let `pantry_order`: String = "pantry_order"
    static let `receipt_fold`: String = "receipt_fold"
    static let `table_chime`: String = "table_chime"
    static let `table_delivery`: String = "table_delivery"
    static let `table_pass`: String = "table_pass"
}
