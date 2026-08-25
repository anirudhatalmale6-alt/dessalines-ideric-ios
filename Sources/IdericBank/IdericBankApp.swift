import SwiftUI

@main
struct IdericBankApp: App {

    private let site = BankSite(
        url: URL(string: "https://idericbank.com/")!,
        userAgentSuffix: "IdericBankApp/1.0",
        offlineTitle: "You are offline",
        offlineBody: "Ideric Bank could not reach the internet. Check your mobile data or Wi-Fi and try again.",
        offlineButton: "Try again",
        offlineNote: "Your account and your balance are safe. Nothing was sent.",
        tint: Color(red: 0.07, green: 0.23, blue: 0.72)   // #123bb8
    )

    var body: some Scene {
        WindowGroup {
            BankScreen(site: site)
                .preferredColorScheme(.light)
        }
    }
}
