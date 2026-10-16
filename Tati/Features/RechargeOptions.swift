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
    @EnvironmentObject private var store: VisitorStore
    @EnvironmentObject private var purchases: TatiPurchases
    @State private var selected: Int?
    private var packages: [CoinPackage] { compact ? CoinPackage.room : CoinPackage.grid }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Art(name: "recharge-banner")
            Note(text: "Package layout preview · Products and prices are not configured. Amounts below are design samples, not purchasable offers.")
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
                            VStack(spacing: 10) {
                                Text(package.total.formatted()).font(.headline).minimumScaleFactor(0.7).lineLimit(1)
                                Art(name: "coin", width: 34, height: 34)
                                Text("Price pending").font(.system(size: 10)).padding(6).foregroundStyle(.white).background(Color.tatiOlive).clipShape(Capsule())
                                if selected == package.id { Art(name: "check-pink", width: 18, height: 18) } else { Color.clear.frame(height: 18) }
                            }.padding(12).frame(maxWidth: .infinity).background { Image("coin-pack-card").resizable() }
                        }.buttonStyle(.plain).accessibilityAddTraits(selected == package.id ? .isSelected : [])
                    }
                }
            }
            TatiButton(title: "Continue", enabled: selected != nil) { store.tell("Purchases aren't configured", purchases.availability) }
            TatiButton(title: "Restore purchases", secondary: true) { store.tell("Purchases aren't configured", purchases.availability) }
        }
    }
}
struct RechargePanel: View {
    @EnvironmentObject private var store: VisitorStore
    var body: some View {
        TatiPanel(title: "Recharge") {
            HStack { Art(name: "coin", width: 30); Text("Purchased balance \(store.account.purchasedCoins)").font(.headline) }
            RechargeOptions(compact: true)
            Note(text: "Demo gift previews do not use purchased coins. No charge is made in this local edition.")
        }
    }
}
