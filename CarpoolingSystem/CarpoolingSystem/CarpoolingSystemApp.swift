import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    return true
  }
}

@main
struct CarpoolingSystemApp: App {
    // 注册 AppDelegate 以初始化 Firebase
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    // 初始化我们的服务对象
    @StateObject var authManager = AuthManager.shared
    @StateObject var rideService = RideService()  // 保留旧的服务（用于旧页面）
    @StateObject var dataStore = RideDataStore()  // 新的数据存储（用于新的高级功能）
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(rideService)
                .environmentObject(dataStore)  // 添加新的数据存储
                // 设置界面的浅色模式，避免深色模式下颜色问题
                .preferredColorScheme(.light)
        }
    }
}
