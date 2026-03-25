import SwiftUI
import UserNotifications

@main
struct GoldTrackerApp: App {
    // 在 App 启动时请求通知权限
    init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ 通知权限已获取")
            } else {
                print("❌ 通知权限被拒绝")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            VStack {
                Text("金价监控核心已启动")
                Text("请保持此应用在后台运行或直接关闭，您可以去桌面添加小组件了。")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
        }
    }
}
