import SwiftUI

struct CoinPackage: Identifiable {
    let id: Int
    let coins: Int
    let bonus: Int
    var total: Int { coins + bonus }
    static let grid = Array(repeating: 99, count: 9).enumerated().map { CoinPackage(id: $0.offset, coins: $0.element, bonus: 0) }
    static let room = [CoinPackage(id: 0, coins: 2405, bonus: 0), CoinPackage(id: 1, coins: 4955, bonus: 1650), CoinPackage(id: 2, coins: 9600, bonus: 4200)]
}
struct RechargeOptions: View {
    var compact = false
    var showsActions = true
    @EnvironmentObject private var store: VisitorStore
    @EnvironmentObject private var purchases: TatiPurchases
    @State private var selected: Int?
    private var packages: [CoinPackage] { compact ? CoinPackage.room : CoinPackage.grid }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if compact { Art(name: "recharge-banner") }
            Note(text: "Design samples · Purchases unavailable")
            if compact {
                ForEach(packages) { package in
                    Button { selected = package.id } label: {
                        HStack(spacing: 14) {
                            Art(name: package.bonus > 0 ? "coin-pile" : "coin", width: 42, height: 42)
                            VStack(alignment: .leading, spacing: 6) { Text(package.total.formatted()).font(.title3.bold()); if package.bonus > 0 { Text("Includes \(package.bonus.formatted()) bonus").font(.caption) } }
                            Spacer(); Text("Price pending").font(.caption)
                            if selected == package.id { Art(name: "check-pink", width: 20) }
                        }.padding(16).background { Image("coin-pack-card").resizable() }
                    }.buttonStyle(.plain)
                }
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                    ForEach(packages) { package in
                        Button { selected = package.id } label: {
                            VStack(spacing: 5) {
                                Text(package.total.formatted()).font(.headline).minimumScaleFactor(0.7).lineLimit(1)
                                Art(name: "coin", width: 34, height: 34)
                                Text("Price pending").font(.system(size: 10)).padding(6).foregroundStyle(.white).background(Color.tatiOlive).clipShape(Capsule())

                            }.padding(10).frame(maxWidth: .infinity).background { Image("coin-pack-card").resizable() }
                                .overlay(alignment: .topTrailing) { if selected == package.id { Art(name: "check-pink", width: 17, height: 17).padding(3) } }
                        }.buttonStyle(.plain).accessibilityAddTraits(selected == package.id ? .isSelected : [])
                    }
                }
            }
            if showsActions {
            TatiButton(title: "Continue", enabled: selected != nil) { store.tell("Purchases aren't configured", purchases.availability) }
            Button("Restore purchases") { store.tell("Purchases aren't configured", purchases.availability) }.font(.caption).buttonStyle(.plain).frame(minHeight: 32)
            }
        }
    }
}
struct RechargePanel: View {
    @EnvironmentObject private var store: VisitorStore
    var body: some View {
        TatiPanel(title: "Recharge") {
            HStack { Art(name: "coin", width: 30); Text("Purchased balance \(store.account.purchasedCoins)").font(.headline) }
            RechargeOptions(compact: true)
            Note(text: "Local gifts use free reward coins. No purchase is made.")
        }
    }
}
