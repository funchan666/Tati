import SwiftUI

struct RechargeOptions: View {
    @Binding var selected: String
    @EnvironmentObject private var purchases: KitchenCoinPurchases
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        ViewThatFits(in: .horizontal) {
            packGrid(columns: dynamicTypeSize >= .xxxLarge ? 2 : 3)
                .frame(minWidth: dynamicTypeSize >= .xxxLarge ? 220 : 310)
            packGrid(columns: 2)
        }
    }
    private func packGrid(columns: Int) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: columns), spacing: 10) {
            ForEach(KitchenCoinPack.all) { package in
                let isSelected = selected == package.id
                Button { selected = package.id } label: {
                    VStack(spacing: 7) {
                        Art(name: package.coins >= 12400 ? "coin-pile" : "coin", width: 36, height: 36)
                        Text(package.coins.formatted()).font(.tati(.headline, design: .rounded).weight(.bold)).monospacedDigit()
                            .lineLimit(1).minimumScaleFactor(0.75)
                        Text(purchases.prices[package.id] ?? package.referencePrice)
                            .font(.tati(.subheadline).weight(.semibold)).lineLimit(1).minimumScaleFactor(0.75)
                            .foregroundStyle(isSelected ? Color.white : Color.tatiInk)
                            .padding(.horizontal, 8).padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                            .background(isSelected ? Color.tatiOlive : Color.white.opacity(0.65))
                            .clipShape(Capsule())
                    }.padding(.horizontal, 9).padding(.vertical, 14).frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background {
                            Image(isSelected ? "day-selected" : "coin-pack-card")
                                .resizable(capInsets: EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14))
                        }
                        .overlay(alignment: .topTrailing) {
                            if isSelected { Art(name: "check-pink", width: 18, height: 18).padding(5) }
                        }
                }.buttonStyle(.plain).disabled(purchases.busy)
                    .accessibilityLabel("\(package.coins) coins, \(purchases.prices[package.id] ?? package.referencePrice)")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}

struct RechargePanel: View {
    var body: some View { WalletView() }
}

struct CoinUsesView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What coins unlock").font(.tati(.headline))
            HStack(spacing: 12) {
                Art(name: "gift-balloons", width: 38, height: 38)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Room gift effects").font(.tati(.subheadline).weight(.semibold))
                    Text("50–1,200 coins each · Quantity is shown before use").font(.tati(.caption)).foregroundStyle(Color.tatiOlive)
                }
            }
            HStack(spacing: 12) {
                Art(name: "host-frame", width: 38, height: 38)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Kitchen spotlight frame").font(.tati(.subheadline).weight(.semibold))
                    Text("300 coins · Unlock once for this profile").font(.tati(.caption)).foregroundStyle(Color.tatiOlive)
                }
            }
            HStack(spacing: 12) {
                Art(name: "notebook-market", width: 38, height: 38)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Recipe chapters").font(.tati(.subheadline).weight(.semibold))
                    Text("120 coins per chapter · Two recipes · Unlock once for this profile")
                        .font(.tati(.caption)).foregroundStyle(Color.tatiOlive)
                }
            }
            Text("Coins unlock recipe chapters, room effects and profile frames. Free recipes, shopping lists, tasting notes and safety tools do not require coins.")
                .font(.tati(.caption)).fixedSize(horizontal: false, vertical: true)
            Text("Bonus coins are used first. Room effects play on your screen and do not transfer coins to another user.")
                .font(.tati(.caption)).foregroundStyle(Color.tatiOlive)
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.7)).clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

struct WelcomeCoinsView: View {
    @EnvironmentObject private var store: MemberKitchenStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var arrived = false
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.tatiInk.opacity(0.72).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 18) {
                        ZStack {
                            Art(name: "coin-pile", width: 176, height: 136)
                                .scaleEffect(arrived ? 1 : 0.78)
                            Art(name: "coin", width: 30, height: 30).rotationEffect(.degrees(-18))
                                .offset(x: -100, y: arrived ? -25 : 8)
                            Art(name: "coin", width: 23, height: 23).rotationEffect(.degrees(22))
                                .offset(x: 100, y: arrived ? -52 : -12)
                        }.frame(height: 144).accessibilityHidden(true)
                        VStack(spacing: 7) {
                            Text("Come on in.").font(.tati(.title2, design: .serif).weight(.bold))
                            Text("Welcome to Tati. Bring your appetite and a little curiosity.").font(.tati(.subheadline)).multilineTextAlignment(.center)
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 7) {
                            Text("+\(MemberKitchenStore.welcomeCoins)").font(.tati(size: 44, weight: .heavy, design: .rounded)).monospacedDigit()
                            Text("coins").font(.tati(.headline))
                        }.foregroundStyle(Color.tatiOlive)
                        Text("Your welcome coins can open a recipe chapter, play a room effect or go towards a profile frame.")
                            .font(.tati(.caption)).multilineTextAlignment(.center)
                        TatiButton(title: "Let's look around") {
                            _ = store.change { $0.welcomeAcknowledged = true }
                        }
                    }.padding(.horizontal, 24).padding(.vertical, 30)
                        .frame(maxWidth: 350)
                        .background { Image("dialog-card").resizable(capInsets: EdgeInsets(top: 36, leading: 32, bottom: 36, trailing: 32)) }
                        .padding(.horizontal, 20).padding(.vertical, 24)
                        .frame(minHeight: geometry.size.height)
                        .frame(maxWidth: .infinity)
                }.scrollIndicators(.hidden)
            }
        }.foregroundStyle(Color.tatiInk).accessibilityAddTraits(.isModal)
            .onAppear {
                if reduceMotion { arrived = true }
                else { withAnimation(.spring(response: 0.65, dampingFraction: 0.7)) { arrived = true } }
            }
    }
}
