import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

class AuthManager: ObservableObject {
    @Published var currentUser: User?
    @Published var isLoggedIn: Bool = false
    @Published var authError: String?
    
    static let shared = AuthManager()
    private let db = Firestore.firestore()
    
    private init() {
        // 监听 Auth 状态变化（自动登录）
        Auth.auth().addStateDidChangeListener { auth, user in
            if let user = user {
                self.isLoggedIn = true
                self.fetchUserProfile(uid: user.uid)
            } else {
                self.isLoggedIn = false
                self.currentUser = nil
            }
        }
    }
    
    // MARK: - 登录
    func login(email: String, password: String) {
        self.authError = nil
        
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                self.authError = "登录失败: \(error.localizedDescription)"
            }
            // 成功后，addStateDidChangeListener 会自动触发 fetchUserProfile
        }
    }
    
    // MARK: - 注册 (更新：支持角色和车主信息)
    func register(name: String, email: String, password: String, phone: String, role: UserRole, carPlate: String? = nil, insuranceExpiry: Date? = nil) {
        self.authError = nil
        
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                self.authError = "注册失败: \(error.localizedDescription)"
                return
            }
            
            guard let uid = result?.user.uid else { return }
            
            // 在 Firestore 创建用户档案
            // 根据角色填充特定字段
            let newUser = User(
                id: uid, // 使用 Auth 的 uid 作为文档 ID
                name: name,
                email: email,
                phone: phone,
                rating: 5.0,
                completedRides: 0,
                joinDate: Date(),
                role: role,
                // 如果是车主，则保存车牌和保险日期，否则为 nil
                carPlateNumber: role == .carOwner ? carPlate : nil,
                insuranceExpiryDate: role == .carOwner ? insuranceExpiry : nil
            )
            
            do {
                try self.db.collection("users").document(uid).setData(from: newUser)
                // 成功后，auth listener 会自动处理
            } catch {
                self.authError = "保存用户信息失败: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - 拉取用户信息
    func fetchUserProfile(uid: String) {
        print("🔍 正在获取用户数据，UID: \(uid)")
        
        db.collection("users").document(uid).getDocument { snapshot, error in
            if let error = error {
                print("❌ 获取用户数据失败: \(error.localizedDescription)")
                self.authError = "获取用户数据失败: \(error.localizedDescription)"
                return
            }
            
            if let snapshot = snapshot {
                if snapshot.exists {
                    print("✅ 找到用户文档")
                    do {
                        self.currentUser = try snapshot.data(as: User.self)
                        print("✅ 用户数据解析成功: \(self.currentUser?.name ?? "未知")")
                    } catch {
                        print("❌ 用户数据解析失败: \(error.localizedDescription)")
                        self.authError = "用户数据解析失败"
                    }
                } else {
                    print("⚠️ 用户文档不存在")
                    self.authError = "用户数据不存在，请尝试重新创建"
                }
            }
        }
    }
    
    // MARK: - 为当前已登录用户创建档案（修复缺失数据）
    func createMissingUserProfile(name: String, phone: String, role: UserRole, carPlate: String? = nil, insuranceExpiry: Date? = nil) {
        guard let uid = Auth.auth().currentUser?.uid,
              let email = Auth.auth().currentUser?.email else {
            self.authError = "未找到已登录的用户"
            return
        }
        
        print("🔧 正在为用户创建档案，UID: \(uid)")
        
        let newUser = User(
            id: uid,
            name: name,
            email: email,
            phone: phone,
            rating: 5.0,
            completedRides: 0,
            joinDate: Date(),
            role: role,
            carPlateNumber: role == .carOwner ? carPlate : nil,
            insuranceExpiryDate: role == .carOwner ? insuranceExpiry : nil
        )
        
        do {
            try db.collection("users").document(uid).setData(from: newUser)
            print("✅ 用户档案创建成功")
            // 创建成功后重新获取
            self.fetchUserProfile(uid: uid)
        } catch {
            print("❌ 创建用户档案失败: \(error.localizedDescription)")
            self.authError = "创建用户档案失败: \(error.localizedDescription)"
        }
    }
    
    // MARK: - 退出
    func logout() {
        do {
            try Auth.auth().signOut()
            self.currentUser = nil
            self.isLoggedIn = false
        } catch {
            print("Error signing out: \(error)")
        }
    }
}
