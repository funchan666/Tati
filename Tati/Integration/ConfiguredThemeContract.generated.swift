import Foundation

enum ConfiguredThemeContract {
    enum Signal: String, CaseIterable {
        case `tableFollow` = "TableFollowerChanged"
        case `filmSafety` = "FoodFilmSafetyChanged"
        case `tableReceipt` = "TableChangeReceipt"
        case `tableReceiptAccepted` = "TableReceiptAccepted"
        case `tableSync` = "TableChangesRequested"
    }
    enum Direction { case inbound, outbound }
    enum ValueType { case string, integer, number, boolean, object, array }
    struct Field { let path: [String]; let type: ValueType; let required: Bool }
    struct Rule { let discriminator: [String]; let direction: Direction; let fields: [String: Field] }
    static func rule(for signal: Signal) -> Rule {
        switch signal {
        case .`tableFollow`: return Rule(discriminator: ["course"], direction: .inbound, fields: ["changeID": Field(path: ["serving", "changeID"], type: .string, required: true), "memberID": Field(path: ["serving", "memberID"], type: .string, required: true), "followsYou": Field(path: ["serving", "followsYou"], type: .boolean, required: true), "revision": Field(path: ["serving", "revision"], type: .integer, required: true)])
        case .`filmSafety`: return Rule(discriminator: ["course"], direction: .inbound, fields: ["changeID": Field(path: ["serving", "changeID"], type: .string, required: true), "filmID": Field(path: ["serving", "filmID"], type: .string, required: true), "hidden": Field(path: ["serving", "hidden"], type: .boolean, required: true), "revision": Field(path: ["serving", "revision"], type: .integer, required: true)])
        case .`tableReceipt`: return Rule(discriminator: ["course"], direction: .outbound, fields: ["receiptID": Field(path: ["serving", "receiptID"], type: .string, required: true), "changeID": Field(path: ["serving", "changeID"], type: .string, required: true), "stage": Field(path: ["serving", "stage"], type: .string, required: true)])
        case .`tableReceiptAccepted`: return Rule(discriminator: ["course"], direction: .inbound, fields: ["receiptID": Field(path: ["serving", "receiptID"], type: .string, required: true)])
        case .`tableSync`: return Rule(discriminator: ["course"], direction: .outbound, fields: ["profileID": Field(path: ["serving", "profileID"], type: .string, required: true), "revisions": Field(path: ["serving", "revisions"], type: .object, required: true)])
        }
    }
}
