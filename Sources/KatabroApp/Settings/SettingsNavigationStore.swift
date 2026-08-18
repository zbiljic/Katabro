import Observation

@MainActor
@Observable
final class SettingsNavigationStore {
    var selectedPane: SettingsPane

    init(
        selectedPane: SettingsPane = .general
    ) {
        self.selectedPane = selectedPane
    }

    func select(
        _ pane: SettingsPane
    ) {
        selectedPane = pane
    }
}
