import SwiftUI

private let notebookPaper = Color(red: 0.98, green: 0.96, blue: 0.91)

struct KitchenNotebookEntry: View {
    var body: some View {
        NavigationLink(destination: KitchenNotebookView()) {
            HStack(spacing: 16) {
                Image("notebook-table").resizable().scaledToFill()
                    .frame(width: 82, height: 92).clipped().clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 6) {
                    Text("Kitchen notebook").font(.tati(.title3, design: .serif))
                    Text("Scale a recipe. Keep what worked.").font(.tati(.subheadline))
                        .foregroundStyle(Color.tatiOlive).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Art(name: "chevron", width: 10, height: 16)
            }.padding(12).background(notebookPaper, in: RoundedRectangle(cornerRadius: 18))
                .foregroundStyle(Color.tatiInk)
        }.buttonStyle(.plain)
    }
}

struct KitchenNotebookView: View {
    @EnvironmentObject private var store: MemberKitchenStore
    var body: some View {
        VStack(spacing: 0) {
            TatiHeader(title: "Kitchen notebook")
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Image("notebook-table").resizable().scaledToFill()
                        .frame(height: 210).clipped().clipShape(RoundedRectangle(cornerRadius: 16))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cook it your way.").font(.tati(.largeTitle, design: .serif))
                        Text("Scale a recipe. Keep what worked.").font(.tati(.body)).foregroundStyle(Color.tatiOlive)
                    }
                    NavigationLink(destination: PantryShoppingView()) {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Shopping list").font(.tati(.title3, design: .serif))
                                Text("Ingredients for your next meal").font(.tati(.caption))
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            Text("Open").font(.tati(.subheadline, weight: .semibold)).foregroundStyle(Color.tatiLime)
                        }.padding(20).foregroundStyle(notebookPaper)
                            .background(Color.tatiInk, in: RoundedRectangle(cornerRadius: 16))
                    }.buttonStyle(.plain)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("At your table").font(.tati(.title2, design: .serif))
                        ForEach(KitchenRecipes.all.filter { $0.chapterID == nil }) { recipe in
                            NavigationLink(destination: RecipeCookingView(recipe: recipe)) { RecipeNotebookRow(recipe: recipe) }.buttonStyle(.plain)
                        }
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("A few pages further").font(.tati(.title2, design: .serif))
                        ForEach(KitchenRecipes.chapters) { chapter in
                            NavigationLink(destination: RecipeChapterView(chapter: chapter)) {
                                HStack(spacing: 14) {
                                    Image(chapter.artworkName).resizable().scaledToFill()
                                        .frame(width: 94, height: 100).clipped().clipShape(RoundedRectangle(cornerRadius: 12)).accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: 7) {
                                        Text(LocalizedStringKey(chapter.chapterName)).font(.tati(.title3, design: .serif))
                                        Text(LocalizedStringKey(store.account.recipeChapterUnlocks?.contains(chapter.id) == true ? "Ready to cook" : "120 coins · Unlock once"))
                                            .font(.tati(.caption)).foregroundStyle(Color.tatiOlive)
                                    }.frame(maxWidth: .infinity, alignment: .leading)
                                    Art(name: "chevron", width: 10, height: 16)
                                }
                            }.buttonStyle(.plain)
                        }
                    }
                    CookingTrialHistory()
                }.padding(18).frame(maxWidth: 680).frame(maxWidth: .infinity)
            }
        }.foregroundStyle(Color.tatiInk).background { notebookPaper.ignoresSafeArea(.container) }.tatiScreen()
    }
}

private struct RecipeNotebookRow: View {
    let recipe: KitchenRecipe
    var showsDisclosure = true
    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(LocalizedStringKey(recipe.dishName)).font(.tati(.headline))
                Text("About \(recipe.activeMinutes) min · Serves \(recipe.baseServings)")
                    .font(.tati(.caption)).foregroundStyle(Color.tatiOlive)
            }.frame(maxWidth: .infinity, alignment: .leading)
            if showsDisclosure { Art(name: "chevron", width: 10, height: 16) }
        }.padding(.vertical, 14).frame(minHeight: 64)
            .overlay(alignment: .bottom) { Color.tatiOlive.opacity(0.14).frame(height: 1) }
    }
}

private struct RecipeChapterView: View {
    let chapter: RecipeChapter
    @EnvironmentObject private var store: MemberKitchenStore
    @State private var recharging = false
    private var unlocked: Bool { store.account.recipeChapterUnlocks?.contains(chapter.id) == true }
    var body: some View {
        TatiPage(title: chapter.chapterName) {
            Image(chapter.artworkName).resizable().scaledToFit().frame(maxHeight: 240)
                .frame(maxWidth: .infinity).clipShape(RoundedRectangle(cornerRadius: 16)).accessibilityHidden(true)
            Text(LocalizedStringKey(chapter.chapterName)).font(.tati(.largeTitle, design: .serif))
            Text(LocalizedStringKey(chapter.chapterDescription)).font(.tati(.body)).padding(.bottom, 12)
            ForEach(chapter.recipes) { recipe in
                if unlocked {
                    NavigationLink(destination: RecipeCookingView(recipe: recipe)) { RecipeNotebookRow(recipe: recipe) }.buttonStyle(.plain)
                } else { RecipeNotebookRow(recipe: recipe, showsDisclosure: false).accessibilityElement(children: .combine) }
            }
            if !unlocked {
                Text("Two recipes, ingredient scaling and shopping lists. Unlock once for this profile. No recurring charge.")
                    .font(.tati(.subheadline)).foregroundStyle(Color.tatiOlive).padding(.vertical, 12)
                TatiButton(title: "Unlock · 120 coins", enabled: store.storageFailure == nil) {
                    store.unlockRecipeChapter(chapter) { recharging = true }
                }
                Text("Your unlocked chapters stay with this profile. Deleting the profile removes access.")
                    .font(.tati(.caption)).foregroundStyle(Color.tatiOlive)
            }
        }.sheet(isPresented: $recharging) { NavigationStack { WalletView() }.overlay { NoticeLayer() } }
    }
}

private struct RecipeCookingView: View {
    let recipe: KitchenRecipe
    @EnvironmentObject private var store: MemberKitchenStore
    @Environment(\.dismiss) private var dismiss
    @State private var servings = 2
    @State private var shoppingAdded = false
    @State private var observation = ""
    @State private var nextAttempt = ""
    @State private var ownerID: String?
    @State private var noteSaved = false
    private var ownsNotebook: Bool { store.account.signedIn && ownerID == store.account.profile.id && store.canOpenRecipe(recipe) }
    var body: some View {
        TatiPage(title: recipe.dishName) {
            Image("notebook-table").resizable().scaledToFill().frame(height: 150).clipped()
                .clipShape(RoundedRectangle(cornerRadius: 16)).accessibilityHidden(true)
            Text(LocalizedStringKey(recipe.dishName)).font(.tati(.largeTitle, design: .serif))
            Text("About \(recipe.activeMinutes) minutes").font(.tati(.subheadline)).foregroundStyle(Color.tatiOlive)
            ViewThatFits(in: .horizontal) {
                HStack { Text("At your table").font(.tati(.headline)); Spacer(minLength: 10); servingControls }
                VStack(alignment: .leading, spacing: 10) { Text("At your table").font(.tati(.headline)); servingControls }
            }.padding(.vertical, 16)
            Text("Ingredients").font(.tati(.title2, design: .serif))
            ForEach(recipe.pantryLines) { line in
                HStack(alignment: .firstTextBaseline) {
                    Text(LocalizedStringKey(line.pantryName)).frame(maxWidth: .infinity, alignment: .leading)
                    Text(line.shoppingQuantity(servings: servings, recipeServings: recipe.baseServings), format: .number.precision(.fractionLength(0...2))).monospacedDigit()
                    Text(LocalizedStringKey(line.pantryUnit))
                }.font(.tati(.body)).padding(.vertical, 5)
            }
            Text("Quantities scale with servings. Pan size and cooking time may need a separate adjustment.")
                .font(.tati(.caption)).foregroundStyle(Color.tatiOlive)
            TatiButton(title: shoppingAdded ? "Update shopping list" : "Add to shopping list", secondary: true, enabled: ownsNotebook && store.storageFailure == nil) {
                shoppingAdded = store.planRecipeShopping(recipe, servings: servings)
            }
            if shoppingAdded { Text("Ingredients added. Adding again replaces this recipe's quantities.").font(.tati(.caption)) }
            Text("At the stove").font(.tati(.title2, design: .serif)).padding(.top, 20)
            ForEach(Array(recipe.methodSteps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 14) {
                    Text("\(index + 1)").font(.tati(.title3, design: .serif)).frame(width: 24)
                    Text(LocalizedStringKey(step)).font(.tati(.body)).lineSpacing(4).frame(maxWidth: .infinity, alignment: .leading)
                }.padding(.vertical, 8)
            }
            Text(LocalizedStringKey(recipe.allergenNote)).font(.tati(.caption)).foregroundStyle(Color.tatiOlive)
            Text("Your tasting note").font(.tati(.title2, design: .serif)).padding(.top, 20)
            Text("Only you can see these notes.").font(.tati(.caption)).foregroundStyle(Color.tatiOlive)
            TatiEditingField(label: "What worked?", placeholder: "The crisp edges, the lemon, the little changes…", text: $observation, limit: 600, multiline: true)
            TatiEditingField(label: "Next time", placeholder: "One change worth trying", text: $nextAttempt, limit: 300, multiline: true)
            TatiButton(title: "Keep this note", enabled: ownsNotebook && !observation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && store.storageFailure == nil) {
                store.flushDraft("tasting:" + recipe.id); store.flushDraft("next-cook:" + recipe.id)
                if store.saveCookingTrial(recipe, servings: servings, observation: observation, nextAttempt: nextAttempt) {
                    observation = ""; nextAttempt = ""; noteSaved = true
                }
            }
            if noteSaved { Text("Tasting note saved in your notebook.").font(.tati(.caption)) }
            CookingTrialHistory(recipeID: recipe.id).padding(.top, 16)
        }
        .onAppear {
            guard ownerID == nil else { return }
            ownerID = store.account.profile.id; servings = recipe.baseServings
            observation = store.account.drafts["tasting:" + recipe.id] ?? ""
            nextAttempt = store.account.drafts["next-cook:" + recipe.id] ?? ""
        }
        .onChange(of: observation) { _, text in if ownsNotebook { store.scheduleDraft("tasting:" + recipe.id, text: text); if !text.isEmpty { noteSaved = false } } }
        .onChange(of: nextAttempt) { _, text in if ownsNotebook { store.scheduleDraft("next-cook:" + recipe.id, text: text); if !text.isEmpty { noteSaved = false } } }
        .onDisappear { if ownsNotebook { store.flushDraft("tasting:" + recipe.id); store.flushDraft("next-cook:" + recipe.id) } }
        .onChange(of: store.account.profile.id) { _, _ in dismiss() }
        .onChange(of: store.account.signedIn) { _, signedIn in if !signedIn { dismiss() } }
    }
    private var servingControls: some View {
        HStack(spacing: 14) {
            Button("Fewer") { servings -= 1; shoppingAdded = false }.disabled(servings <= 1)
            Text("Serves \(servings)").font(.tati(.headline)).monospacedDigit()
            Button("More") { servings += 1; shoppingAdded = false }.disabled(servings >= 12)
        }.font(.tati(.subheadline, weight: .semibold)).buttonStyle(NotebookTextButton())
    }
}

private struct NotebookTextButton: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.padding(.horizontal, 12).frame(minHeight: 44)
            .background(Color.tatiLime.opacity(configuration.isPressed ? 0.5 : 0.85), in: RoundedRectangle(cornerRadius: 12))
            .opacity(enabled ? 1 : 0.4)
    }
}

private struct PantryShoppingView: View {
    @EnvironmentObject private var store: MemberKitchenStore
    private var lines: [PantryChecklistLine] { store.account.pantryShoppingList ?? [] }
    private var recipeIDs: [String] { Array(Set(lines.map(\.recipeID))).sorted() }
    var body: some View {
        TatiPage(title: "Shopping list") {
            Text("For the market bag").font(.tati(.largeTitle, design: .serif))
            if lines.isEmpty {
                Text("Open a recipe, choose your servings and add its ingredients here.").font(.tati(.body)).padding(.vertical, 24)
            }
            ForEach(recipeIDs, id: \.self) { recipeID in
                if let recipe = KitchenRecipes.recipe(recipeID) {
                    HStack {
                        Text(LocalizedStringKey(recipe.dishName)).font(.tati(.headline)).frame(maxWidth: .infinity, alignment: .leading)
                        Button("Remove") { _ = store.change { $0.pantryShoppingList?.removeAll { $0.recipeID == recipeID } } }
                            .buttonStyle(NotebookTextButton()).font(.tati(.caption))
                    }.padding(.top, 14)
                    ForEach(lines.filter { $0.recipeID == recipeID }) { line in
                        Button {
                            _ = store.change { value in
                                guard let index = value.pantryShoppingList?.firstIndex(where: { $0.id == line.id }) else { return }
                                value.pantryShoppingList?[index].isInBasket.toggle()
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Art(name: "check-pink", width: 22, height: 22).opacity(line.isInBasket ? 1 : 0.15)
                                Text(LocalizedStringKey(line.pantryName)).strikethrough(line.isInBasket).frame(maxWidth: .infinity, alignment: .leading)
                                Text(line.scaledQuantity, format: .number.precision(.fractionLength(0...2))).monospacedDigit()
                                Text(LocalizedStringKey(line.pantryUnit))
                            }.font(.tati(.body)).frame(minHeight: 48)
                        }.buttonStyle(.plain).accessibilityValue(line.isInBasket ? "In your basket" : "Still needed")
                    }
                }
            }
        }
    }
}

private struct CookingTrialHistory: View {
    var recipeID: String? = nil
    @EnvironmentObject private var store: MemberKitchenStore
    private var notes: [CookingTrialNote] { Array((store.account.cookingTrialNotes ?? []).filter { recipeID == nil || $0.recipeID == recipeID }.reversed()) }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your tasting notes").font(.tati(.title2, design: .serif))
            if notes.isEmpty { Text("Keep the small changes worth repeating.").font(.tati(.subheadline)).foregroundStyle(Color.tatiOlive) }
            ForEach(notes) { note in
                VStack(alignment: .leading, spacing: 9) {
                    if let recipe = KitchenRecipes.recipe(note.recipeID) { Text(LocalizedStringKey(recipe.dishName)).font(.tati(.headline)) }
                    Text(note.cookedAt, style: .date).font(.tati(.caption)).foregroundStyle(Color.tatiOlive)
                    Text(note.flavourObservation).font(.tati(.body))
                    if !note.nextAttempt.isEmpty {
                        Text("Next time").font(.tati(.caption, weight: .semibold))
                        Text(note.nextAttempt).font(.tati(.subheadline))
                    }
                    Button("Delete note") {
                        store.confirm("Delete tasting note?", "This removes this note from your notebook.", button: "Delete", destructive: true) {
                            _ = store.change { $0.cookingTrialNotes?.removeAll { $0.id == note.id } }
                        }
                    }.buttonStyle(NotebookTextButton()).font(.tati(.caption))
                }.padding(.vertical, 14).frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .bottom) { Color.tatiOlive.opacity(0.14).frame(height: 1) }
            }
        }
    }
}
