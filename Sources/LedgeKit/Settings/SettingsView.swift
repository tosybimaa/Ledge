import SwiftUI

enum SettingsPage: String, CaseIterable, Identifiable {
    case general = "General", media = "Media", fileTray = "File Tray"
    case sensory = "Sensory", battery = "Battery", focus = "Focus", weather = "Weather"
    case lockScreen = "Lock Screen", faceUnlock = "Face Unlock", accessories = "Accessories"
    case appearance = "Appearance", update = "Update"

    var id: Self { self }

    static let main: [SettingsPage] = [.general, .appearance, .media, .fileTray]
    static let overlays: [SettingsPage] = [.sensory, .battery, .focus, .weather, .lockScreen, .faceUnlock, .accessories]
    static let account: [SettingsPage] = [.update]

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .appearance: "paintpalette.fill"
        case .media: "play.fill"
        case .fileTray: "folder.fill"
        case .sensory: "speaker.wave.2.fill"
        case .battery: "bolt.fill"
        case .focus: "moon.fill"
        case .weather: "cloud.fill"
        case .lockScreen: "lock.fill"
        case .faceUnlock: "faceid"
        case .accessories: "airpodspro"
        case .update: "arrow.down.circle.fill"
        }
    }

    @ViewBuilder var content: some View {
        switch self {
        case .general: GeneralPage()
        case .appearance: AppearancePage()
        case .media: MediaPage()
        case .fileTray: ComingSoon(symbol: "tray", text: "File Tray is in development\nand will be available in a future update.")
        case .sensory: SensoryPage()
        case .battery: BatteryPage()
        case .focus: FocusPage()
        case .weather: WeatherPage()
        case .lockScreen: LockScreenPage()
        case .faceUnlock: ComingSoon(symbol: "faceid", text: "Face unlock is in development\nand will be available in a future update.")
        case .accessories: AccessoriesPage()
        case .update: UpdatePage()
        }
    }
}

/// 600 × 810 pt window: 178 pt sidebar, page title at the top of the content side.
struct SettingsView: View {
    @State private var page = SettingsPage.general
    @State private var search = ""

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(page: $page, search: $search)
                .frame(width: 178)
                .background(Color.black.opacity(0.14))
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: page.symbol).ledgeFont(20, .semibold)
                    Text(page.rawValue).ledgeFont(20, .bold)
                }
                .padding(EdgeInsets(top: 57, leading: 22, bottom: 26, trailing: 20))
                page.content
                    .id(page)
                    .transition(.opacity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .animation(.smooth(duration: 0.25), value: page)
        .ignoresSafeArea(.container, edges: .top)
        .frame(minWidth: 600, idealWidth: 600, minHeight: 560, idealHeight: 810)
        .preferredColorScheme(.dark)
        .glassWindow()
        .withLook()
    }
}

/// Search, then 44 pt rows on a 50 pt pitch with 30 pt icon tiles; Update pinned at the bottom.
struct SettingsSidebar: View {
    @Binding var page: SettingsPage
    @Binding var search: String
    @Environment(\.look) private var look

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").ledgeFont(12, .medium).foregroundStyle(.secondary)
                TextField("Search", text: $search).textFieldStyle(.plain).ledgeFont(13)
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: look.r(10), style: .continuous))
            .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    rows(SettingsPage.main)
                    Divider().padding(.horizontal, 10).padding(.vertical, 6)
                    Text("Overlays")
                        .ledgeFont(11, .semibold)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 10)
                    rows(SettingsPage.overlays)
                    // Update scrolls with the rest instead of being pinned under the list.
                    Divider().padding(.horizontal, 10).padding(.vertical, 6)
                    rows(SettingsPage.account)
                }
                .padding(.bottom, 12)
            }
            .scrollIndicators(.never)
        }
        .padding(EdgeInsets(top: 57, leading: 16, bottom: 0, trailing: 16))
    }

    private func rows(_ pages: [SettingsPage]) -> some View {
        ForEach(pages.filter { search.isEmpty || $0.rawValue.localizedCaseInsensitiveContains(search) }) { p in
            Button { page = p } label: {
                HStack(spacing: 10) {
                    Image(systemName: p.symbol)
                        .ledgeFont(13, .semibold)
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: look.r(8), style: .continuous))
                    // One line always: shrink a little rather than wrap ("Appearanc / e").
                    Text(p.rawValue).ledgeFont(13, .semibold).lineLimit(1).minimumScaleFactor(0.7)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .frame(height: 44)
                .background(page == p ? Color.white.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: look.r(10), style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(page == p ? .isSelected : [])
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView().frame(width: 600, height: 810)
    }
}
