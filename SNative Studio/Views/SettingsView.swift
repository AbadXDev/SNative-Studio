import SwiftUI

struct SettingsView: View {
    @Bindable var model: SettingsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(
                    title: "Ajustes",
                    subtitle: "La apariencia se aplica al momento y se conserva la próxima vez que abras SNative Studio."
                )

                StudioCard(title: "Apariencia") {
                    Picker("Tema", selection: $model.appearance) {
                        ForEach(AppearancePreference.allCases) { preference in
                            Text(preference.title).tag(preference)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    Text(explanation)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(28)
            .frame(maxWidth: 720, alignment: .leading)
        }
    }

    private var explanation: String {
        switch model.appearance {
        case .light:
            "Tema claro. Es el valor predeterminado."
        case .dark:
            "Tema oscuro."
        case .automatic:
            "Sigue la apariencia del sistema."
        }
    }
}
