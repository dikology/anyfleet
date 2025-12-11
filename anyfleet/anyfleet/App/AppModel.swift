import SwiftUI
import Combine

enum AppRoute: Hashable {
    case createCharter
}

@MainActor
final class AppModel: ObservableObject {
    @Published var path = NavigationPath()

    func navigate(to route: AppRoute) {
        path.append(route)
    }

    func popToRoot() {
        path.removeLast(path.count)
    }
}

