import Foundation

struct RecipePantryLine: Identifiable {
    let pantryName: String
    let baseQuantity: Double
    let pantryUnit: String
    var id: String { pantryName }
    func shoppingQuantity(servings: Int, recipeServings: Int) -> Double {
        baseQuantity * Double(min(12, max(1, servings))) / Double(max(1, recipeServings))
    }
}
struct KitchenRecipe: Identifiable {
    let id: String
    let dishName: String
    let chapterID: String?
    let baseServings: Int
    let activeMinutes: Int
    let pantryLines: [RecipePantryLine]
    let methodSteps: [String]
    let allergenNote: String
}
struct RecipeChapter: Identifiable {
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
    static let chapters = [
        RecipeChapter(id: "sunday-brunch", chapterName: "Sunday brunch", chapterDescription: "French toast and a warm apple pan for a slower morning.", coinCost: 120, artworkName: "notebook-brunch"),
        RecipeChapter(id: "market-supper", chapterName: "Market supper", chapterDescription: "Two flexible vegetable dishes for the market bag you brought home.", coinCost: 120, artworkName: "notebook-market")
    ]
    static let all: [KitchenRecipe] = [
        .init(id: "basil-toast", dishName: "Tomato & basil toast", chapterID: nil, baseServings: 2, activeMinutes: 10,
              pantryLines: [.init(pantryName: "Bread", baseQuantity: 4, pantryUnit: "slices"), .init(pantryName: "Tomatoes", baseQuantity: 300, pantryUnit: "g"), .init(pantryName: "Olive oil", baseQuantity: 2, pantryUnit: "tbsp"), .init(pantryName: "Basil", baseQuantity: 8, pantryUnit: "leaves")],
              methodSteps: ["Toast the bread until the edges are crisp.", "Chop the tomatoes and toss with olive oil. Season to taste.", "Spoon onto the toast, tear over the basil and serve straight away."], allergenNote: "Contains wheat. Check your bread label for other allergens."),
        .init(id: "lemon-chickpeas", dishName: "Lemon chickpea bowl", chapterID: nil, baseServings: 2, activeMinutes: 15,
              pantryLines: [.init(pantryName: "Cooked chickpeas", baseQuantity: 400, pantryUnit: "g"), .init(pantryName: "Cucumber", baseQuantity: 200, pantryUnit: "g"), .init(pantryName: "Lemon juice", baseQuantity: 2, pantryUnit: "tbsp"), .init(pantryName: "Olive oil", baseQuantity: 1, pantryUnit: "tbsp")],
              methodSteps: ["Drain and rinse the cooked chickpeas.", "Dice the cucumber and combine with the chickpeas.", "Dress with lemon juice and olive oil. Taste before adding salt."], allergenNote: "Check packaged ingredients for allergens and cross-contact information."),
        .init(id: "morning-french-toast", dishName: "Golden French toast", chapterID: "sunday-brunch", baseServings: 2, activeMinutes: 15,
              pantryLines: [.init(pantryName: "Bread", baseQuantity: 4, pantryUnit: "slices"), .init(pantryName: "Eggs", baseQuantity: 2, pantryUnit: "whole"), .init(pantryName: "Milk", baseQuantity: 120, pantryUnit: "ml"), .init(pantryName: "Butter", baseQuantity: 15, pantryUnit: "g")],
              methodSteps: ["Whisk the eggs and milk in a shallow bowl.", "Dip each slice briefly on both sides. Melt the butter over medium heat.", "Cook each side until golden and the egg coating is fully set. Serve warm."], allergenNote: "Contains wheat, egg and milk. Cook the egg coating thoroughly."),
        .init(id: "warm-apple-pan", dishName: "Warm apple pan", chapterID: "sunday-brunch", baseServings: 2, activeMinutes: 15,
              pantryLines: [.init(pantryName: "Apples", baseQuantity: 300, pantryUnit: "g"), .init(pantryName: "Butter", baseQuantity: 10, pantryUnit: "g"), .init(pantryName: "Cinnamon", baseQuantity: 0.5, pantryUnit: "tsp"), .init(pantryName: "Plain yogurt", baseQuantity: 150, pantryUnit: "g")],
              methodSteps: ["Core and slice the apples evenly.", "Warm the butter in a pan, add the apples and cinnamon, and cook until tender. Add a splash of water if needed.", "Spoon over plain yogurt and serve warm."], allergenNote: "Contains milk. Check the yogurt label."),
        .init(id: "market-roast", dishName: "Roast market vegetables", chapterID: "market-supper", baseServings: 2, activeMinutes: 35,
              pantryLines: [.init(pantryName: "Carrots", baseQuantity: 250, pantryUnit: "g"), .init(pantryName: "Courgette", baseQuantity: 250, pantryUnit: "g"), .init(pantryName: "Olive oil", baseQuantity: 2, pantryUnit: "tbsp"), .init(pantryName: "Lemon juice", baseQuantity: 1, pantryUnit: "tbsp")],
              methodSteps: ["Heat the oven to 200°C. Cut the vegetables into similar bite-sized pieces.", "Toss with olive oil and spread out on a tray. Roast for about 25 minutes, turning once, until tender and browned.", "Finish with lemon juice and season to taste. Check tenderness rather than relying on time alone."], allergenNote: "Check all ingredients for your dietary needs. Oven times vary."),
        .init(id: "herby-white-beans", dishName: "Herby white beans", chapterID: "market-supper", baseServings: 2, activeMinutes: 20,
              pantryLines: [.init(pantryName: "Cooked white beans", baseQuantity: 400, pantryUnit: "g"), .init(pantryName: "Tomatoes", baseQuantity: 200, pantryUnit: "g"), .init(pantryName: "Olive oil", baseQuantity: 1, pantryUnit: "tbsp"), .init(pantryName: "Basil", baseQuantity: 8, pantryUnit: "leaves")],
              methodSteps: ["Drain and rinse the cooked beans. Chop the tomatoes.", "Warm the olive oil in a pan, add the tomatoes and cook until softened.", "Stir in the beans and a splash of water. Heat thoroughly, then finish with torn basil and seasoning."], allergenNote: "Use ready-cooked beans. Dried beans require separate safe preparation.")
    ]
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
