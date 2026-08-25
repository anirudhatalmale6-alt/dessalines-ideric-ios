import SwiftUI

@main
struct DessalinesBankApp: App {

    private let site = BankSite(
        url: URL(string: "https://dessalinesbank.com/")!,
        userAgentSuffix: "DessalinesBankApp/1.2",
        offlineTitle: "Ou pa konekte",
        offlineBody: "Dessalines Bank pa ka jwenn entènèt la. Tcheke done mobil ou oswa Wi-Fi ou epi eseye ankò.",
        offlineButton: "Eseye ankò",
        offlineNote: "Kont ou ak balans ou an sekirite. Nou pa voye anyen.",
        tint: Color(red: 0.90, green: 0.22, blue: 0.27)   // #e63946
    )

    var body: some Scene {
        WindowGroup {
            BankScreen(site: site)
                .preferredColorScheme(.dark)
        }
    }
}
