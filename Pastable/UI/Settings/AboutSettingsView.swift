import SwiftUI

struct AboutSettingsView: View {
  var body: some View {
    VStack(spacing: 16) {
      Image(nsImage: NSApp.applicationIconImage)
        .resizable()
        .frame(width: 80, height: 80)
      
      VStack(spacing: 4) {
        Text("Pastable")
          .font(.title2)
          .fontWeight(.bold)
        
        Text("Version 1.0.0")
          .foregroundStyle(.secondary)
      }
      
      VStack(spacing: 8) {
        Text("settings.about.description")
          .multilineTextAlignment(.center)
          .foregroundStyle(.secondary)
        

      }
      .padding(.top)
      
      Spacer()
      
      Text("settings.about.copyright")
        .font(.caption)
        .foregroundStyle(.tertiary)
    }
    .padding()
  }
}

#Preview {
  AboutSettingsView()
}
