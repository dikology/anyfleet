import SwiftUI

struct AppView: View {
    @StateObject private var appModel = AppModel()

    var body: some View {
        NavigationStack(path: $appModel.path) {
            HomeView(
                viewModel: HomeViewModel(appModel: appModel)
            )
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .createCharter:
                    CreateCharterView()
                }
            }
        }
    }
}

#Preview {
    AppView()
}
