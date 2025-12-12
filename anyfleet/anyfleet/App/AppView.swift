import SwiftUI

struct AppView: View {
    @StateObject private var coordinator = AppCoordinator()

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            HomeView(
                viewModel: HomeViewModel(coordinator: coordinator)
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
