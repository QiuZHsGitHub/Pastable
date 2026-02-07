import SwiftUI


struct GeneralSettingsView: View {
  @AppStorage("launchAtLogin") private var launchAtLogin = true
  @AppStorage("pasteAutomatically") private var pasteAutomatically = true
  @AppStorage("removeFormatting") private var removeFormatting = false
  @AppStorage("playSounds") private var playSounds = true
  @AppStorage("searchMode") private var searchMode: SearchService.SearchMode = .fuzzy
  
  var body: some View {
    Form {
      Section {
        Toggle("settings.general.launch_at_login", isOn: $launchAtLogin)
      }
      
      Section(header: Text("settings.general.behavior").font(.subheadline)) {
        Picker("settings.general.search_mode", selection: $searchMode) {
          Text("settings.general.search_mode.exact").tag(SearchService.SearchMode.exact)
          Text("settings.general.search_mode.fuzzy").tag(SearchService.SearchMode.fuzzy)
        }
        .pickerStyle(.menu)
        
        Toggle("settings.general.auto_paste", isOn: $pasteAutomatically)
        Toggle("settings.general.remove_formatting", isOn: $removeFormatting)
        Toggle("settings.general.play_sounds", isOn: $playSounds)
      }
    }
    .formStyle(.grouped)
    .scrollContentBackground(.hidden)
    .padding()
  }
}

#Preview {
  GeneralSettingsView()
}
