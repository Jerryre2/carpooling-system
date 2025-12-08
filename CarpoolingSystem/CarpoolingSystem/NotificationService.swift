//
//  NotificationService.swift
//  CarpoolingSystem - Push Notification System
//
//  Created on 2025-12-07
//  实现基于 Firebase Cloud Messaging 的推送通知系统
//

import Foundation
import FirebaseMessaging
import UserNotifications
import UIKit
// MARK: - Notification Type Enum
/// 通知类型枚举
enum NotificationType: String, Codable {
    case newRequest = "new_request"              // 新的拼车请求（发给司机）
    case requestAccepted = "request_accepted"    // 请求被接受（发给乘客）
    case requestRejected = "request_rejected"    // 请求被拒绝（发给乘客）
    case rideCancelled = "ride_cancelled"        // 行程被取消（发给所有相关人）
    case rideStarted = "ride_started"            // 行程开始（发给所有相关人）
    case rideCompleted = "ride_completed"        // 行程完成（发给所有相关人）
    case driverArriving = "driver_arriving"      // 司机即将到达（发给乘客）
    case passengerJoined = "passenger_joined"    // 新乘客加入（发给司机）
    case seatsFull = "seats_full"                // 座位已满（发给司机）
    
    var displayTitle: String {
        switch self {
        case .newRequest:
            return "🎫 新的拼车请求"
        case .requestAccepted:
            return "✅ 请求已接受"
        case .requestRejected:
            return "❌ 请求被拒绝"
        case .rideCancelled:
            return "🚫 行程已取消"
        case .rideStarted:
            return "🚗 行程已开始"
        case .rideCompleted:
            return "🏁 行程已完成"
        case .driverArriving:
            return "📍 司机即将到达"
        case .passengerJoined:
            return "👤 新乘客加入"
        case .seatsFull:
            return "🎉 座位已满"
        }
    }
}

// MARK: - Notification Content Model
/// 通知内容模型
struct NotificationContent: Codable {
    let type: NotificationType
    let rideID: String
    let title: String
    let body: String
    let senderID: String?
    let senderName: String?
    let timestamp: Date
    let additionalData: [String: String]?
    
    init(type: NotificationType,
         rideID: String,
         title: String,
         body: String,
         senderID: String? = nil,
         senderName: String? = nil,
         additionalData: [String: String]? = nil) {
        self.type = type
        self.rideID = rideID
        self.title = title
        self.body = body
        self.senderID = senderID
        self.senderName = senderName
        self.timestamp = Date()
        self.additionalData = additionalData
    }
}

// MARK: - Notification Service
/// 推送通知服务（商业级）
@MainActor
class NotificationService: NSObject, ObservableObject {
    
    // MARK: - Singleton
    static let shared = NotificationService()
    
    // MARK: - Published Properties
    @Published var fcmToken: String?
    @Published var notificationPermissionGranted: Bool = false
    @Published var receivedNotifications: [NotificationContent] = []
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let fcmTokenKey = "FCMToken"
    
    // MARK: - Initialization
    private override init() {
        super.init()
        loadSavedToken()
    }
    
    // MARK: - Setup & Authorization
    
    /// 请求通知权限
    func requestAuthorization() async -> Bool {
        do {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                print("✅ 通知权限已授予")
                notificationPermissionGranted = true
                await registerForRemoteNotifications()
                return true
                
            case .notDetermined:
                let granted = try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .badge, .sound])
                
                if granted {
                    print("✅ 用户授予通知权限")
                    notificationPermissionGranted = true
                    await registerForRemoteNotifications()
                } else {
                    print("❌ 用户拒绝通知权限")
                    notificationPermissionGranted = false
                }
                return granted
                
            case .denied:
                print("❌ 通知权限被拒绝")
                notificationPermissionGranted = false
                return false
                
            default:
                print("⚠️ 未知的通知权限状态")
                return false
            }
        } catch {
            print("❌ 请求通知权限失败: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 注册远程通知
    @MainActor
    private func registerForRemoteNotifications() async {
        // 在主线程上调用 UIApplication 方法
        #if os(iOS)
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
        #endif
        
        // 设置 Messaging 代理
        Messaging.messaging().delegate = self
        
        // 获取 FCM Token
        do {
            let token = try await Messaging.messaging().token()
            print("✅ 获取 FCM Token 成功: \(token)")
            self.fcmToken = token
            self.saveToken(token)
        } catch {
            print("❌ 获取 FCM Token 失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Send Notifications (通过 Cloud Functions 或后端)
    
    /// 发送新请求通知（发给司机）
    func sendNewRequestNotification(
        to driverID: String,
        rideID: String,
        passengerName: String
    ) async throws {
        let content = NotificationContent(
            type: .newRequest,
            rideID: rideID,
            title: "新的拼车请求",
            body: "\(passengerName) 想加入您的行程",
            senderName: passengerName
        )
        
        try await sendNotification(to: driverID, content: content)
    }
    
    /// 发送请求接受通知（发给乘客）
    func sendRequestAcceptedNotification(
        to passengerID: String,
        rideID: String,
        driverName: String
    ) async throws {
        let content = NotificationContent(
            type: .requestAccepted,
            rideID: rideID,
            title: "请求已接受",
            body: "\(driverName) 已接受您的拼车请求",
            senderName: driverName
        )
        
        try await sendNotification(to: passengerID, content: content)
    }
    
    /// 发送行程取消通知（发给所有相关人）
    func sendRideCancelledNotification(
        to userIDs: [String],
        rideID: String,
        cancellerName: String
    ) async throws {
        let content = NotificationContent(
            type: .rideCancelled,
            rideID: rideID,
            title: "行程已取消",
            body: "\(cancellerName) 取消了行程",
            senderName: cancellerName
        )
        
        for userID in userIDs {
            try await sendNotification(to: userID, content: content)
        }
    }
    
    /// 发送行程开始通知（发给所有相关人）
    func sendRideStartedNotification(
        to userIDs: [String],
        rideID: String,
        driverName: String,
        startLocation: String
    ) async throws {
        let content = NotificationContent(
            type: .rideStarted,
            rideID: rideID,
            title: "行程已开始",
            body: "\(driverName) 已从 \(startLocation) 出发",
            senderName: driverName,
            additionalData: ["startLocation": startLocation]
        )
        
        for userID in userIDs {
            try await sendNotification(to: userID, content: content)
        }
    }
    
    /// 发送行程完成通知（发给所有相关人）
    func sendRideCompletedNotification(
        to userIDs: [String],
        rideID: String,
        totalPrice: Double
    ) async throws {
        let content = NotificationContent(
            type: .rideCompleted,
            rideID: rideID,
            title: "行程已完成",
            body: "感谢使用拼车服务！总费用: ¥\(String(format: "%.2f", totalPrice))",
            additionalData: ["totalPrice": String(format: "%.2f", totalPrice)]
        )
        
        for userID in userIDs {
            try await sendNotification(to: userID, content: content)
        }
    }
    
    /// 发送司机即将到达通知（发给乘客）
    func sendDriverArrivingNotification(
        to passengerID: String,
        rideID: String,
        driverName: String,
        estimatedMinutes: Int
    ) async throws {
        let content = NotificationContent(
            type: .driverArriving,
            rideID: rideID,
            title: "司机即将到达",
            body: "\(driverName) 预计 \(estimatedMinutes) 分钟后到达",
            senderName: driverName,
            additionalData: ["eta": "\(estimatedMinutes)"]
        )
        
        try await sendNotification(to: passengerID, content: content)
    }
    
    /// 发送新乘客加入通知（发给司机）
    func sendPassengerJoinedNotification(
        to driverID: String,
        rideID: String,
        passengerName: String,
        remainingSeats: Int
    ) async throws {
        let content = NotificationContent(
            type: .passengerJoined,
            rideID: rideID,
            title: "新乘客加入",
            body: "\(passengerName) 已加入行程，剩余座位: \(remainingSeats)",
            senderName: passengerName,
            additionalData: ["remainingSeats": "\(remainingSeats)"]
        )
        
        try await sendNotification(to: driverID, content: content)
    }
    
    // MARK: - Core Send Function
    
    /// 核心发送通知函数（通过 Firebase Cloud Functions 或后端 API）
    private func sendNotification(to userID: String, content: NotificationContent) async throws {
        print("📤 发送通知给用户: \(userID)")
        print("   类型: \(content.type.displayTitle)")
        print("   内容: \(content.body)")
        
        // 实际应用中，这里应该调用 Cloud Functions 或后端 API
        // 示例：
        /*
         let url = URL(string: "https://your-backend.com/api/sendNotification")!
         var request = URLRequest(url: url)
         request.httpMethod = "POST"
         request.setValue("application/json", forHTTPHeaderField: "Content-Type")
         
         let payload: [String: Any] = [
             "targetUserID": userID,
             "notification": [
                 "title": content.title,
                 "body": content.body,
                 "type": content.type.rawValue,
                 "rideID": content.rideID
             ]
         ]
         
         request.httpBody = try JSONSerialization.data(withJSONObject: payload)
         
         let (data, response) = try await URLSession.shared.data(for: request)
         
         guard let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 else {
             throw NSError(domain: "NotificationService", code: -1, userInfo: nil)
         }
         
         print("✅ 通知发送成功")
         */
        
        // 开发阶段：使用本地通知模拟
        await sendLocalNotification(content: content)
    }
    
    // MARK: - Local Notification (Development)
    
    /// 发送本地通知（用于开发测试）
    private func sendLocalNotification(content: NotificationContent) async {
        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = content.title
        notificationContent.body = content.body
        notificationContent.sound = .default
        notificationContent.badge = 1
        
        // 附加数据
        notificationContent.userInfo = [
            "type": content.type.rawValue,
            "rideID": content.rideID
        ]
        
        // 立即触发
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: notificationContent,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("✅ 本地通知已发送")
        } catch {
            print("❌ 发送本地通知失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Token Management
    
    /// 保存 FCM Token
    private func saveToken(_ token: String) {
        userDefaults.set(token, forKey: fcmTokenKey)
        print("💾 FCM Token 已保存")
    }
    
    /// 加载已保存的 Token
    private func loadSavedToken() {
        if let token = userDefaults.string(forKey: fcmTokenKey) {
            self.fcmToken = token
            print("📂 已加载保存的 FCM Token")
        }
    }
    
    /// 更新用户的 FCM Token（保存到 Firestore）
    func updateUserFCMToken(userID: String, token: String) async throws {
        // 实际应用中，应该将 Token 保存到 Firestore
        /*
         let db = Firestore.firestore()
         try await db.collection("users").document(userID).updateData([
             "fcmToken": token,
             "lastTokenUpdate": FieldValue.serverTimestamp()
         ])
         
         print("✅ 用户 FCM Token 已更新")
         */
        
        print("✅ FCM Token 已更新: \(token)")
    }
    
    // MARK: - Handle Received Notifications
    
    /// 处理接收到的通知
    func handleReceivedNotification(_ userInfo: [AnyHashable: Any]) {
        print("📥 收到通知")
        
        guard let typeString = userInfo["type"] as? String,
              let type = NotificationType(rawValue: typeString),
              let rideID = userInfo["rideID"] as? String else {
            print("⚠️ 通知数据格式无效")
            return
        }
        
        let content = NotificationContent(
            type: type,
            rideID: rideID,
            title: userInfo["title"] as? String ?? type.displayTitle,
            body: userInfo["body"] as? String ?? "",
            senderID: userInfo["senderID"] as? String,
            senderName: userInfo["senderName"] as? String
        )
        
        receivedNotifications.append(content)
        
        print("✅ 通知已处理: \(type.displayTitle)")
        
        // 触发相应的业务逻辑
        handleNotificationAction(type: type, rideID: rideID)
    }
    
    /// 处理通知对应的业务逻辑
    private func handleNotificationAction(type: NotificationType, rideID: String) {
        switch type {
        case .newRequest:
            print("🎫 处理新请求: \(rideID)")
            // 跳转到请求列表页
            
        case .requestAccepted:
            print("✅ 请求已接受: \(rideID)")
            // 跳转到行程详情页
            
        case .rideCancelled:
            print("🚫 行程已取消: \(rideID)")
            // 刷新行程列表
            
        case .rideStarted:
            print("🚗 行程已开始: \(rideID)")
            // 打开实时追踪页
            
        case .rideCompleted:
            print("🏁 行程已完成: \(rideID)")
            // 打开评价页
            
        case .driverArriving:
            print("📍 司机即将到达: \(rideID)")
            // 显示提醒
            
        case .passengerJoined:
            print("👤 新乘客加入: \(rideID)")
            // 刷新乘客列表
            
        case .seatsFull:
            print("🎉 座位已满: \(rideID)")
            // 更新行程状态
            
        default:
            break
        }
    }
    
    // MARK: - Badge Management
    
    /// 清除应用角标
    func clearBadge() {
        #if os(iOS)
        Task { @MainActor in
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
        #endif
    }
    
    /// 设置角标数量
    func setBadgeCount(_ count: Int) {
        #if os(iOS)
        Task { @MainActor in
            UIApplication.shared.applicationIconBadgeNumber = count
        }
        #endif
    }
}

// MARK: - MessagingDelegate
extension NotificationService: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("📲 收到新的 FCM Token")
        
        guard let token = fcmToken else {
            print("⚠️ Token 为空")
            return
        }
        
        Task { @MainActor in
            self.fcmToken = token
            self.saveToken(token)
            
            print("✅ FCM Token 已更新: \(token)")
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationService: UNUserNotificationCenterDelegate {
    /// 应用在前台时收到通知
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        print("📥 应用在前台收到通知")
        
        let userInfo = notification.request.content.userInfo
        
        Task { @MainActor in
            self.handleReceivedNotification(userInfo)
        }
        
        // 在前台也显示通知
        completionHandler([.banner, .sound, .badge])
    }
    
    /// 用户点击通知
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        print("👆 用户点击了通知")
        
        let userInfo = response.notification.request.content.userInfo
        
        Task { @MainActor in
            self.handleReceivedNotification(userInfo)
        }
        
        completionHandler()
    }
}
