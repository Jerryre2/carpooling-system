//
//  ProfileView.swift
//  CarpoolingSystem
//
//  专业的用户档案视图，集成登出功能
//

import SwiftUI
import FirebaseAuth

// MARK: - Profile Menu Item Model (菜单项模型)

/// 档案功能菜单项
struct ProfileMenuItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let color: Color
    let destination: AnyView?
    
    init(icon: String, title: String, color: Color = .blue, destination: AnyView? = nil) {
        self.icon = icon
        self.title = title
        self.color = color
        self.destination = destination
    }
}

// MARK: - Enhanced Profile View (增强的档案视图)

/// 用户档案主视图 - 替换 SimpleProfileView
struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showLogoutAlert = false
    @State private var showCreateProfileSheet = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // 用户信息头部
                    if let user = authManager.currentUser {
                        userHeaderSection(user: user)
                            .padding(.vertical, 30)
                        
                        // 统计信息卡片
                        statsSection(user: user)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 20)
                        
                        // 功能菜单列表
                        menuSection(user: user)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 30)
                        
                        // 登出按钮
                        logoutButton
                            .padding(.horizontal, 16)
                            .padding(.bottom, 30)
                    } else {
                        // 加载状态或错误提示
                        VStack(spacing: 20) {
                            ProgressView("加载中...")
                            
                            Text("正在获取用户信息...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            // 调试信息
                            if authManager.isLoggedIn {
                                VStack(spacing: 10) {
                                    Text("登录状态：已登录")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                    
                                    Text("用户数据：加载失败或不存在")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                    
                                    if let error = authManager.authError {
                                        Text("错误: \(error)")
                                            .font(.caption)
                                            .foregroundColor(.red)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal)
                                    }
                                    
                                    // 操作按钮
                                    HStack(spacing: 12) {
                                        // 重试按钮
                                        Button {
                                            if let uid = Auth.auth().currentUser?.uid {
                                                authManager.fetchUserProfile(uid: uid)
                                            }
                                        } label: {
                                            Label("重新加载", systemImage: "arrow.clockwise")
                                                .font(.subheadline)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 10)
                                                .background(Color.blue)
                                                .cornerRadius(8)
                                        }
                                        
                                        // 创建档案按钮
                                        Button {
                                            showCreateProfileSheet = true
                                        } label: {
                                            Label("创建档案", systemImage: "person.badge.plus")
                                                .font(.subheadline)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 10)
                                                .background(Color.cookiePrimary)
                                                .cornerRadius(8)
                                        }
                                    }
                                    .padding(.top, 10)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white)
                                        .shadow(color: .gray.opacity(0.1), radius: 5)
                                )
                                .padding(.horizontal)
                            }
                        }
                        .padding()
                    }
                }
            }
            .background(Color.cookieBackground.ignoresSafeArea())
            .navigationTitle("个人中心")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showCreateProfileSheet) {
            CreateProfileView()
        }
        .alert("登出", isPresented: $showLogoutAlert) {
            Button("取消", role: .cancel) { }
            Button("确认登出", role: .destructive) {
                withAnimation {
                    authManager.logout()
                }
            }
        } message: {
            Text("您确定要登出吗？")
        }
    }
    
    // MARK: - View Components
    
    /// 用户信息头部
    private func userHeaderSection(user: User) -> some View {
        VStack(spacing: 16) {
            // 用户头像
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.cookiePrimary.opacity(0.3), .cookiePrimary.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 110, height: 110)
                
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                    .foregroundColor(.cookiePrimary)
            }
            
            // 用户昵称
            Text(user.name)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.cookieText)
            
            // 用户邮箱
            Text(user.email)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // 角色标签
            HStack(spacing: 8) {
                Image(systemName: user.role == .carOwner ? "car.fill" : "figure.walk")
                    .font(.caption)
                
                Text(user.role.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(user.role == .carOwner ? Color.green.opacity(0.15) : Color.blue.opacity(0.15))
            )
            .foregroundColor(user.role == .carOwner ? .green : .blue)
            
            // 车主专属信息
            if user.role == .carOwner, let plate = user.carPlateNumber {
                HStack(spacing: 8) {
                    Image(systemName: "car.circle")
                        .foregroundColor(.cookiePrimary)
                    Text("车牌号: \(plate)")
                        .font(.subheadline)
                        .foregroundColor(.cookieText)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white)
                        .shadow(color: .gray.opacity(0.1), radius: 3, x: 0, y: 2)
                )
            }
        }
    }
    
    /// 统计信息卡片
    private func statsSection(user: User) -> some View {
        HStack(spacing: 12) {
            // 评分
            StatCard(
                icon: "star.fill",
                value: String(format: "%.1f", user.rating),
                label: "评分",
                color: .orange
            )
            
            // 完成行程
            StatCard(
                icon: "checkmark.circle.fill",
                value: "\(user.completedRides)",
                label: "完成行程",
                color: .green
            )
            
            // 加入天数
            StatCard(
                icon: "calendar",
                value: "\(daysSinceJoined(user.joinDate))",
                label: "天",
                color: .cookiePrimary
            )
        }
    }
    
    /// 功能菜单区域
    private func menuSection(user: User) -> some View {
        VStack(spacing: 16) {
            // 行程相关
            MenuGroupCard(title: "我的行程") {
                VStack(spacing: 0) {
                    MenuRowView(
                        icon: "car.fill",
                        title: "我发布的行程",
                        color: .blue,
                        destination: AnyView(MyPublishedRidesView(userID: user.id ?? ""))
                    )
                    
                    Divider()
                        .padding(.leading, 60)
                    
                    MenuRowView(
                        icon: "ticket.fill",
                        title: "我预订的行程",
                        color: .purple,
                        destination: AnyView(MyBookedRidesView(userID: user.id ?? ""))
                    )
                }
            }
            
            // 其他功能
            MenuGroupCard(title: "更多") {
                VStack(spacing: 0) {
                    MenuRowView(
                        icon: "gearshape.fill",
                        title: "设置",
                        color: .gray,
                        destination: AnyView(SettingsView())
                    )
                    
                    Divider()
                        .padding(.leading, 60)
                    
                    MenuRowView(
                        icon: "questionmark.circle.fill",
                        title: "帮助与反馈",
                        color: .orange,
                        destination: AnyView(HelpView())
                    )
                    
                    Divider()
                        .padding(.leading, 60)
                    
                    MenuRowView(
                        icon: "info.circle.fill",
                        title: "关于",
                        color: .blue,
                        destination: AnyView(AboutView())
                    )
                }
            }
        }
    }
    
    /// 登出按钮
    private var logoutButton: some View {
        Button {
            showLogoutAlert = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "arrow.right.square.fill")
                    .font(.title3)
                
                Text("登出")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [.red, .red.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(color: .red.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
    
    // MARK: - Helper Functions
    
    /// 计算加入天数
    private func daysSinceJoined(_ joinDate: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: joinDate, to: Date())
        return max(components.day ?? 0, 0)
    }
}

// MARK: - Supporting Views (辅助视图)

/// 统计卡片
struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.cookieText)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: .gray.opacity(0.1), radius: 5, x: 0, y: 3)
        )
    }
}

/// 菜单组卡片
struct MenuGroupCard<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.cookieText)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            
            VStack(spacing: 0) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .shadow(color: .gray.opacity(0.1), radius: 5, x: 0, y: 3)
            )
        }
    }
}

/// 菜单行视图
struct MenuRowView: View {
    let icon: String
    let title: String
    let color: Color
    let destination: AnyView
    
    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 16) {
                // 图标
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.body)
                        .foregroundColor(color)
                }
                
                // 标题
                Text(title)
                    .font(.body)
                    .foregroundColor(.cookieText)
                
                Spacer()
                
                // 箭头指示器
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Additional Destination Views (额外的目标视图)

/// 设置视图
struct SettingsView: View {
    @AppStorage("enableNotifications") private var enableNotifications = true
    @AppStorage("enableLocationServices") private var enableLocationServices = true
    @AppStorage("enableDarkMode") private var enableDarkMode = false
    
    var body: some View {
        Form {
            Section("通用设置") {
                Toggle(isOn: $enableNotifications) {
                    Label("推送通知", systemImage: "bell.fill")
                }
                
                Toggle(isOn: $enableLocationServices) {
                    Label("位置服务", systemImage: "location.fill")
                }
                
                Toggle(isOn: $enableDarkMode) {
                    Label("深色模式", systemImage: "moon.fill")
                }
            }
            
            Section("隐私与安全") {
                NavigationLink {
                    PrivacyPolicyView()
                } label: {
                    Label("隐私政策", systemImage: "hand.raised.fill")
                }
                
                NavigationLink {
                    TermsOfServiceView()
                } label: {
                    Label("服务条款", systemImage: "doc.text.fill")
                }
            }
            
            Section("应用信息") {
                HStack {
                    Text("版本")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 帮助与反馈视图
struct HelpView: View {
    var body: some View {
        List {
            Section("常见问题") {
                NavigationLink("如何预订行程？") {
                    HelpDetailView(
                        title: "如何预订行程？",
                        content: """
                        1. 在"找行程"页面浏览可用行程
                        2. 点击感兴趣的行程查看详情
                        3. 确认出发时间和价格后，点击"立即加入"
                        4. 预订成功后可在"我的预订"中查看
                        """
                    )
                }
                
                NavigationLink("如何发布行程？") {
                    HelpDetailView(
                        title: "如何发布行程？",
                        content: """
                        1. 点击"发布"标签页
                        2. 填写出发地、目的地、出发时间
                        3. 设置可用座位数和价格
                        4. 添加备注信息（可选）
                        5. 点击"发布行程"按钮
                        """
                    )
                }
                
                NavigationLink("如何取消预订？") {
                    HelpDetailView(
                        title: "如何取消预订？",
                        content: """
                        1. 进入"我的预订"查看已预订的行程
                        2. 点击要取消的行程
                        3. 在详情页点击"取消预订"按钮
                        4. 确认取消操作
                        """
                    )
                }
            }
            
            Section("联系我们") {
                HStack {
                    Label("邮箱", systemImage: "envelope.fill")
                    Spacer()
                    Text("support@must.edu.mo")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                
                HStack {
                    Label("电话", systemImage: "phone.fill")
                    Spacer()
                    Text("+853 6612 3456")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                
                HStack {
                    Label("办公时间", systemImage: "clock.fill")
                    Spacer()
                    Text("周一至周五 9:00-18:00")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Section("反馈") {
                NavigationLink {
                    FeedbackView()
                } label: {
                    Label("发送反馈", systemImage: "paperplane.fill")
                }
            }
        }
        .navigationTitle("帮助与反馈")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 关于视图
struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // App 图标
                Image(systemName: "car.2.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                    .foregroundColor(.cookiePrimary)
                    .padding(.top, 40)
                
                // App 名称
                Text("拼车系统")
                    .font(.title)
                    .fontWeight(.bold)
                
                // 版本信息
                Text("版本 1.0.0")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Divider()
                    .padding(.horizontal, 40)
                
                // 简介
                VStack(alignment: .leading, spacing: 16) {
                    Text("关于我们")
                        .font(.headline)
                        .foregroundColor(.cookieText)
                    
                    Text("拼车系统是为 MUST 社区打造的便捷出行平台，致力于为学生和教职工提供安全、高效的拼车服务。")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineSpacing(4)
                    
                    Text("特色功能")
                        .font(.headline)
                        .foregroundColor(.cookieText)
                        .padding(.top, 8)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        FeatureRow(icon: "checkmark.circle.fill", text: "实时查找可用行程")
                        FeatureRow(icon: "checkmark.circle.fill", text: "快速发布拼车信息")
                        FeatureRow(icon: "checkmark.circle.fill", text: "安全的用户认证系统")
                        FeatureRow(icon: "checkmark.circle.fill", text: "行程管理和历史记录")
                    }
                }
                .padding(.horizontal, 32)
                
                Spacer()
                
                // 版权信息
                Text("© 2024 MUST 拼车系统")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 40)
            }
        }
        .background(Color.cookieBackground.ignoresSafeArea())
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 特性行
struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.green)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.cookieText)
        }
    }
}

/// 帮助详情视图
struct HelpDetailView: View {
    let title: String
    let content: String
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(content)
                    .font(.body)
                    .foregroundColor(.cookieText)
                    .lineSpacing(6)
                    .padding()
            }
        }
        .background(Color.cookieBackground.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 隐私政策视图
struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("隐私政策")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.bottom, 8)
                
                Text("我们非常重视您的隐私保护。本隐私政策说明了我们如何收集、使用和保护您的个人信息。")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Group {
                    SectionTitle(title: "信息收集")
                    Text("我们收集您主动提供的信息，包括姓名、邮箱、电话号码等注册信息。")
                    
                    SectionTitle(title: "信息使用")
                    Text("我们使用收集的信息来提供和改进拼车服务，确保用户之间的安全通信。")
                    
                    SectionTitle(title: "信息保护")
                    Text("我们采用行业标准的安全措施保护您的个人信息，包括数据加密和安全存储。")
                    
                    SectionTitle(title: "信息共享")
                    Text("未经您的同意，我们不会与第三方共享您的个人信息，除非法律要求。")
                }
            }
            .padding()
        }
        .background(Color.cookieBackground.ignoresSafeArea())
        .navigationTitle("隐私政策")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 服务条款视图
struct TermsOfServiceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("服务条款")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.bottom, 8)
                
                Text("使用本应用即表示您同意以下服务条款。")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Group {
                    SectionTitle(title: "用户责任")
                    Text("用户应确保提供真实、准确的信息，并遵守所有适用的法律法规。")
                    
                    SectionTitle(title: "服务使用")
                    Text("用户同意仅将本服务用于合法目的，不得从事任何可能损害他人或系统的行为。")
                    
                    SectionTitle(title: "免责声明")
                    Text("本平台仅提供信息匹配服务，对用户之间的实际拼车行为不承担责任。")
                    
                    SectionTitle(title: "条款变更")
                    Text("我们保留随时修改本服务条款的权利，修改后的条款将在应用中公布。")
                }
            }
            .padding()
        }
        .background(Color.cookieBackground.ignoresSafeArea())
        .navigationTitle("服务条款")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 反馈视图
struct FeedbackView: View {
    @State private var feedbackText = ""
    @State private var selectedCategory = "功能建议"
    @State private var showingSuccessAlert = false
    @Environment(\.dismiss) private var dismiss
    
    let categories = ["功能建议", "问题报告", "其他反馈"]
    
    var body: some View {
        Form {
            Section("反馈类型") {
                Picker("类型", selection: $selectedCategory) {
                    ForEach(categories, id: \.self) { category in
                        Text(category).tag(category)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            Section("反馈内容") {
                TextEditor(text: $feedbackText)
                    .frame(minHeight: 150)
            }
            
            Section {
                Button {
                    submitFeedback()
                } label: {
                    Text("提交反馈")
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.white)
                }
                .listRowBackground(Color.cookiePrimary)
                .disabled(feedbackText.isEmpty)
            }
        }
        .navigationTitle("发送反馈")
        .navigationBarTitleDisplayMode(.inline)
        .alert("感谢您的反馈", isPresented: $showingSuccessAlert) {
            Button("确定") {
                dismiss()
            }
        } message: {
            Text("我们已收到您的反馈，会尽快处理。")
        }
    }
    
    func submitFeedback() {
        // 这里可以添加实际的反馈提交逻辑
        // 例如发送到后端API或Firebase
        showingSuccessAlert = true
    }
}

/// 章节标题
struct SectionTitle: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.cookieText)
            .padding(.top, 8)
    }
}

// MARK: - Create Profile View (创建档案视图)

/// 创建用户档案视图（修复缺失数据）
struct CreateProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var phone = ""
    @State private var selectedRole: UserRole = .carpooler
    @State private var carPlate = ""
    @State private var insuranceExpiry = Date().addingTimeInterval(60 * 60 * 24 * 180)
    @State private var showSuccessAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    TextField("姓名", text: $name)
                    TextField("电话号码", text: $phone)
                        .keyboardType(.phonePad)
                }
                
                Section("选择身份") {
                    Picker("身份", selection: $selectedRole) {
                        Text("🚗 乘客 (Carpooler)").tag(UserRole.carpooler)
                        Text("🚙 车主 (Car Owner)").tag(UserRole.carOwner)
                    }
                    .pickerStyle(.segmented)
                }
                
                if selectedRole == .carOwner {
                    Section("车主信息") {
                        TextField("车牌号", text: $carPlate)
                            .textInputAutocapitalization(.characters)
                        
                        DatePicker("保险到期日", selection: $insuranceExpiry, displayedComponents: .date)
                    }
                }
                
                Section {
                    Button {
                        createProfile()
                    } label: {
                        HStack {
                            Spacer()
                            Text("创建档案")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!isFormValid)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("为什么需要创建档案？")
                            .font(.headline)
                            .foregroundColor(.cookieText)
                        
                        Text("您的账号已经登录成功，但是缺少用户档案信息。这可能是因为注册时数据保存失败。请填写上述信息来完成档案创建。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("创建用户档案")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .alert("创建成功", isPresented: $showSuccessAlert) {
                Button("确定") {
                    dismiss()
                }
            } message: {
                Text("您的用户档案已成功创建！")
            }
        }
    }
    
    var isFormValid: Bool {
        !name.isEmpty && !phone.isEmpty && (selectedRole == .carpooler || !carPlate.isEmpty)
    }
    
    func createProfile() {
        authManager.createMissingUserProfile(
            name: name,
            phone: phone,
            role: selectedRole,
            carPlate: selectedRole == .carOwner ? carPlate : nil,
            insuranceExpiry: selectedRole == .carOwner ? insuranceExpiry : nil
        )
        
        // 等待一下让数据保存
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if authManager.currentUser != nil {
                showSuccessAlert = true
            }
        }
    }
}

// MARK: - Preview Provider (预览)

#Preview("Profile View") {
    let authManager = AuthManager.shared
    // 模拟登录状态
    authManager.isLoggedIn = true
    authManager.currentUser = User(
        id: "1",
        name: "张三",
        email: "zhangsan@must.edu.mo",
        phone: "+853 66123456",
        rating: 4.8,
        completedRides: 15,
        joinDate: Date().addingTimeInterval(-60 * 60 * 24 * 30), // 30天前
        role: .carOwner,
        carPlateNumber: "M-12-34",
        insuranceExpiryDate: Date().addingTimeInterval(60 * 60 * 24 * 180)
    )
    
    return ProfileView()
        .environmentObject(authManager)
}
