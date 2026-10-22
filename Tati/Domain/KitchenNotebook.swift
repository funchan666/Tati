import Foundation

struct RecipePantryLine: Identifiable, Decodable, Sendable {
    let pantryName: String
    let baseQuantity: Double
    let pantryUnit: String
    var id: String { pantryName }
    func shoppingQuantity(servings: Int, recipeServings: Int) -> Double {
        baseQuantity * Double(min(12, max(1, servings))) / Double(max(1, recipeServings))
    }
}
struct KitchenRecipe: Identifiable, Decodable, Sendable {
    let id: String
    let dishName: String
    let chapterID: String?
    let baseServings: Int
    let activeMinutes: Int
    let pantryLines: [RecipePantryLine]
    let methodSteps: [String]
    let allergenNote: String
}
struct RecipeChapter: Identifiable, Decodable, Sendable {
    let id: String
    let chapterName: String
    let chapterDescription: String
    let coinCost: Int
    let artworkName: String
    var recipes: [KitchenRecipe] { KitchenRecipes.all.filter { $0.chapterID == id } }
}
struct PantryChecklistLine: Codable, Identifiable {
    var id = UUID().uuidString
    let recipeID: String
    let pantryName: String
    let scaledQuantity: Double
    let pantryUnit: String
    let plannedServings: Int
    var isInBasket = false
}
struct CookingTrialNote: Codable, Identifiable {
    var id = UUID().uuidString
    let recipeID: String
    let cookedServings: Int
    let flavourObservation: String
    let nextAttempt: String
    let cookedAt: Date
}

enum KitchenRecipes {
    static var chapters: [RecipeChapter] { KitchenContentSnapshot.current?.notebook.chapters ?? [] }
    static var all: [KitchenRecipe] { KitchenContentSnapshot.current?.notebook.recipes ?? [] }
    static func recipe(_ recipeID: String) -> KitchenRecipe? { all.first { $0.id == recipeID } }
}

@MainActor extension MemberKitchenStore {
    func canOpenRecipe(_ recipe: KitchenRecipe) -> Bool {
        recipe.chapterID.map { account.recipeChapterUnlocks?.contains($0) == true } ?? true
    }
    func unlockRecipeChapter(_ chapter: RecipeChapter, recharge: @escaping () -> Void) {
        guard KitchenRecipes.chapters.contains(where: { $0.id == chapter.id }) else { return }
        requestSpend(chapter.coinCost, title: "Unlock \(chapter.chapterName)?", purpose: "Recipe chapter · \(chapter.chapterName)",
                     detail: "Two recipes, ingredient scaling and shopping lists. Unlock once for this profile. No recurring charge.", recharge: recharge,
                     valid: { self.account.recipeChapterUnlocks?.contains(chapter.id) != true },
                     edit: { value in
                         var chapters = value.recipeChapterUnlocks ?? []; chapters.insert(chapter.id); value.recipeChapterUnlocks = chapters
                     }, completed: {})
    }
    @discardableResult func planRecipeShopping(_ recipe: KitchenRecipe, servings: Int) -> Bool {
        guard account.signedIn, canOpenRecipe(recipe), (1...12).contains(servings) else { return false }
        return change { value in
            var list = value.pantryShoppingList ?? []
            list.removeAll { $0.recipeID == recipe.id }
            list.append(contentsOf: recipe.pantryLines.map {
                PantryChecklistLine(recipeID: recipe.id, pantryName: $0.pantryName,
                                    scaledQuantity: $0.shoppingQuantity(servings: servings, recipeServings: recipe.baseServings),
                                    pantryUnit: $0.pantryUnit, plannedServings: servings)
            })
            value.pantryShoppingList = list
        }
    }
    @discardableResult func saveCookingTrial(_ recipe: KitchenRecipe, servings: Int, observation: String, nextAttempt: String) -> Bool {
        let tasted = observation.trimmingCharacters(in: .whitespacesAndNewlines)
        let next = nextAttempt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard account.signedIn, canOpenRecipe(recipe), (1...12).contains(servings), !tasted.isEmpty,
              tasted.count <= 600, next.count <= 300 else { return false }
        flushDraft("tasting:" + recipe.id); flushDraft("next-cook:" + recipe.id)
        return change { value in
            var notes = value.cookingTrialNotes ?? []
            notes.append(CookingTrialNote(recipeID: recipe.id, cookedServings: servings, flavourObservation: tasted, nextAttempt: next, cookedAt: Date()))
            value.cookingTrialNotes = notes
            value.drafts.removeValue(forKey: "tasting:" + recipe.id)
            value.drafts.removeValue(forKey: "next-cook:" + recipe.id)
        }
    }
}
