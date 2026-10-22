import SwiftUI

struct TableGuidelinesView: View {
    var body: some View {
        TatiPage(title: "Our table rules") {
            Art(name: "support-mascot", width: 94, height: 106).frame(maxWidth: .infinity)
            Text("Leave room for everyone.").font(.tati(.largeTitle, design: .serif))
            rule("Keep food at the centre", "Recipes, markets, cooking questions and the meals you have tried belong here. Keep personal information and payment requests out of public posts.")
            rule("Respect the people at the table", "No sexual content, exploitation, threats, hate or harassment. Do not use Tati to arrange sexual services or target other people.")
            rule("Share what is yours", "Only use photos, videos and recipes you have permission to share. Do not claim another person's work as your own.")
            rule("Cook with care", "Check ingredient labels for your allergies. Do not post unsafe food challenges or medical and weight-loss promises.")
            rule("Use the safety controls", "The options on profiles, videos, comments and rooms let you report content or block its author. Blocking hides their content and conversations. You can manage blocked profiles in Settings.")
            SupportMailboxButton(subject: "Tati safety concern")
        }
    }
    private func rule(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStringKey(title)).font(.tati(.title3, design: .serif))
            Text(LocalizedStringKey(detail)).font(.tati(.body)).lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }.padding(.vertical, 12)
    }
}
