import SwiftUI

struct AboutSettingsView: View {
  private let supportEmail = "h593526370@gmail.com"

  private var appName: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
      ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
      ?? "Pastable"
  }

  private var versionLine: String {
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    return build == version ? "Version \(version)" : "Version \(version) (\(build))"
  }

  private var supportURL: URL? {
    URL(string: "mailto:\(supportEmail)")
  }

  var body: some View {
    VStack(spacing: 16) {
      Image(nsImage: NSApp.applicationIconImage)
        .resizable()
        .frame(width: 80, height: 80)
      
      VStack(spacing: 4) {
        Text(appName)
          .font(.title2)
          .fontWeight(.bold)
        
        Text(versionLine)
          .foregroundStyle(.secondary)
      }
      
      Text("settings.about.description")
        .multilineTextAlignment(.center)
        .foregroundStyle(.secondary)

      if let supportURL {
        VStack(spacing: 6) {
          Text("settings.about.contact")
            .font(.footnote)
            .foregroundStyle(.secondary)

          Link(destination: supportURL) {
            Label(supportEmail, systemImage: "envelope")
              .font(.system(size: 13, weight: .medium))
          }
        }
      }
      
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
