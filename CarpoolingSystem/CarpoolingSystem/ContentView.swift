import SwiftUI

import SwiftUI

// MARK: - Main Entry View
struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        if authManager.isLoggedIn {
            MainTabView()
        } else {
            LoginView()
        }
    }
}

// MARK: - Login / Register View
struct LoginView: View {
    // Shared Fields
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var name = ""
    @State private var phone = ""
    @State private var selectedCountryCode = "+853"
    
    // Role Selection
    @State private var selectedRole: UserRole = .passenger
    
    // Car Owner Specific Fields
    @State private var carPlate = ""
    @State private var insuranceExpiry = Date().addingTimeInterval(60 * 60 * 24 * 180) // Default to 6 months from now
    
    // UI State
    @State private var showForm = false
    @State private var showingRegister = false
    @State private var isPasswordVisible = false
    @State private var isConfirmPasswordVisible = false
    @State private var validationErrors: [String] = []
    @State private var carOffset: CGFloat = -200
    
    // Field-specific error states
    @State private var emailError: String? = nil
    @State private var passwordError: String? = nil
    @State private var phoneError: String? = nil
    @State private var carPlateError: String? = nil
    @State private var insuranceError: String? = nil
    
    @EnvironmentObject var authManager: AuthManager
    
    let countryCodes = CountryCode.supportedCodes
    
    var body: some View {
        ZStack {
            Color.cookieBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 30) {
                    // Animation Header
                    ZStack {
                        Image(systemName: "car.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.cookiePrimary)
                            .offset(x: carOffset)
                            .onAppear {
                                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: false)) {
                                    carOffset = 200
                                }
                            }
                    }
                    .frame(height: 100)
                    .padding(.top, 50)
                    
                    Text(showingRegister ? "注册新账号" : "欢迎回来")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.cookieText)
                    
                    VStack(spacing: 20) {
                        
                        if showingRegister {
                            // MARK: - Role Selection
                            VStack(alignment: .leading, spacing: 8) {
                                Text("选择身份")
                                    .font(.headline)
                                    .foregroundColor(.cookieText)
                                
                                Picker("身份", selection: $selectedRole) {
                                    Text("🚗 乘客 (Passenger)").tag(UserRole.passenger)
                                    Text("🚙 车主 (Car Owner)").tag(UserRole.carOwner)
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                .onChange(of: selectedRole) { _ in
                                    // Clear role-specific errors when switching roles
                                    clearValidationErrors()
                                }
                            }
                            
                            Divider().padding(.vertical, 5)
                            
                            // MARK: - Name Field
                            VStack(alignment: .leading, spacing: 4) {
                                TextField("昵称", text: $name)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                        }
                        
                        // MARK: - Email Field
                        VStack(alignment: .leading, spacing: 4) {
                            TextField(showingRegister && selectedRole == .passenger ? "Email (必须使用 @must.edu.mo)" : "Email", text: $email)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .onChange(of: email) { _ in 
                                    validateEmailField()
                                }
                            
                            if let error = emailError {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        
                        // MARK: - Password Fields
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                if isPasswordVisible {
                                    TextField("密码", text: $password)
                                        .onChange(of: password) { _ in
                                            if showingRegister {
                                                validatePasswordField()
                                            }
                                        }
                                } else {
                                    SecureField("密码", text: $password)
                                        .onChange(of: password) { _ in
                                            if showingRegister {
                                                validatePasswordField()
                                            }
                                        }
                                }
                                Button(action: { 
                                    isPasswordVisible.toggle()
                                }) {
                                    Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 5).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                            .background(Color.white.cornerRadius(5))
                            
                            if let error = passwordError {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        
                        if showingRegister {
                            // MARK: - Confirm Password Field
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    if isConfirmPasswordVisible {
                                        TextField("确认密码", text: $confirmPassword)
                                            .onChange(of: confirmPassword) { _ in
                                                validatePasswordMatch()
                                            }
                                    } else {
                                        SecureField("确认密码", text: $confirmPassword)
                                            .onChange(of: confirmPassword) { _ in
                                                validatePasswordMatch()
                                            }
                                    }
                                    Button(action: { 
                                        isConfirmPasswordVisible.toggle()
                                    }) {
                                        Image(systemName: isConfirmPasswordVisible ? "eye.slash.fill" : "eye.fill")
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 5).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                                .background(Color.white.cornerRadius(5))
                                
                                if !confirmPassword.isEmpty && password != confirmPassword {
                                    Text("两次密码输入不一致")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            
                            // MARK: - Phone Number Field
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 10) {
                                    // Country Code Selector
                                    Menu {
                                        ForEach(countryCodes) { countryCode in
                                            Button(action: { 
                                                selectedCountryCode = countryCode.code
                                                validatePhoneField()
                                            }) {
                                                HStack {
                                                    Text(countryCode.flag)
                                                    Text(countryCode.name)
                                                    Text(countryCode.code)
                                                    Spacer()
                                                    if selectedCountryCode == countryCode.code {
                                                        Image(systemName: "checkmark")
                                                    }
                                                }
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            if let selected = countryCodes.first(where: { $0.code == selectedCountryCode }) {
                                                Text(selected.flag)
                                                Text(selected.code)
                                                    .foregroundColor(.primary)
                                            }
                                            Image(systemName: "chevron.down")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                        .padding(8)
                                        .background(Color.white)
                                        .cornerRadius(5)
                                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.gray.opacity(0.3)))
                                    }
                                    
                                    // Phone Number Input
                                    TextField("手机号码", text: $phone)
                                        .keyboardType(.numberPad)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .onChange(of: phone) { newValue in
                                            // Filter to digits only
                                            phone = newValue.filter { "0123456789".contains($0) }
                                            validatePhoneField()
                                        }
                                }
                                
                                if let error = phoneError {
                                    Text(error)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                
                                // Show expected length hint
                                if phone.isEmpty {
                                    if let selected = countryCodes.first(where: { $0.code == selectedCountryCode }) {
                                        Text("需要 \(selected.digitCount) 位数字")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                            
                            // MARK: - Car Owner Specific Fields
                            if selectedRole == .carOwner {
                                Divider().padding(.vertical)
                                
                                VStack(alignment: .leading, spacing: 15) {
                                    HStack {
                                        Image(systemName: "car.fill")
                                            .foregroundColor(.cookiePrimary)
                                        Text("车辆信息")
                                            .font(.headline)
                                            .foregroundColor(.cookieText)
                                    }
                                    
                                    // Car Plate Field
                                    VStack(alignment: .leading, spacing: 4) {
                                        TextField("车牌号码 (例如: M-12-34)", text: $carPlate)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                            .autocapitalization(.allCharacters)
                                            .onChange(of: carPlate) { _ in
                                                validateCarPlateField()
                                            }
                                        
                                        if let error = carPlateError {
                                            Text(error)
                                                .font(.caption)
                                                .foregroundColor(.red)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                    
                                    // Insurance Expiry Date
                                    VStack(alignment: .leading, spacing: 4) {
                                        DatePicker("保险过期日期", selection: $insuranceExpiry, in: Date()..., displayedComponents: .date)
                                            .datePickerStyle(.compact)
                                            .onChange(of: insuranceExpiry) { _ in
                                                validateInsuranceField()
                                            }
                                        
                                        if let error = insuranceError {
                                            Text(error)
                                                .font(.caption)
                                                .foregroundColor(.red)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        } else {
                                            Text("保险有效期必须至少还有 6 个月")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // MARK: - Error Messages
                        if !validationErrors.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(validationErrors, id: \.self) { error in
                                    HStack(alignment: .top, spacing: 5) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.caption)
                                        Text(error)
                                            .font(.caption)
                                    }
                                    .foregroundColor(.red)
                                }
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        if let authError = authManager.authError {
                            HStack(alignment: .top, spacing: 5) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                Text(authError)
                                    .font(.caption)
                            }
                            .foregroundColor(.red)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        // MARK: - Action Button
                        Button(showingRegister ? "注册" : "登录") {
                            handleAction()
                        }
                        .buttonStyle(CookieButtonStyle(color: .cookiePrimary))
                        .disabled(showingRegister && !isFormValid())
                        .opacity((showingRegister && !isFormValid()) ? 0.6 : 1.0)
                        
                        Button(showingRegister ? "已有账号？登录" : "没有账号？注册") {
                            withAnimation {
                                showingRegister.toggle()
                                clearAllFields()
                                clearValidationErrors()
                                authManager.authError = nil
                            }
                        }
                        .foregroundColor(.cookiePrimary)
                    }
                    .padding()
                    .background(Color.white.opacity(0.9))
                    .cornerRadius(20)
                    .padding()
                }
            }
        }
    }
    
    // MARK: - Validation Logic
    
    /// Validate email field in real-time
    func validateEmailField() {
        if email.isEmpty {
            emailError = nil
            return
        }
        
        if showingRegister && selectedRole == .passenger {
            if !ValidationUtilities.validateCarpoolerEmail(email) {
                emailError = "邮箱必须以 @must.edu.mo 结尾"
            } else {
                emailError = nil
            }
        } else {
            emailError = nil
        }
    }
    
    /// Validate password strength in real-time
    func validatePasswordField() {
        if password.isEmpty {
            passwordError = nil
            return
        }
        
        passwordError = ValidationUtilities.getPasswordStrengthError(password)
    }
    
    /// Validate password match
    func validatePasswordMatch() {
        // This is handled inline in the UI
    }
    
    /// Validate phone number in real-time
    func validatePhoneField() {
        if phone.isEmpty {
            phoneError = nil
            return
        }
        
        phoneError = ValidationUtilities.getPhoneValidationError(countryCode: selectedCountryCode, phoneNumber: phone)
    }
    
    /// Validate car plate in real-time
    func validateCarPlateField() {
        if carPlate.isEmpty {
            carPlateError = nil
            return
        }
        
        carPlateError = ValidationUtilities.getCarPlateError(carPlate)
    }
    
    /// Validate insurance expiry date in real-time
    func validateInsuranceField() {
        insuranceError = ValidationUtilities.getInsuranceExpiryError(insuranceExpiry)
    }
    
    /// Check if entire form is valid
    func isFormValid() -> Bool {
        // For login, just check email and password not empty
        if !showingRegister {
            return !email.isEmpty && !password.isEmpty
        }
        
        // For registration, validate all fields
        let errors = ValidationUtilities.validateRegistrationForm(
            role: selectedRole,
            name: name,
            email: email,
            password: password,
            confirmPassword: confirmPassword,
            countryCode: selectedCountryCode,
            phone: phone,
            carPlate: selectedRole == .carOwner ? carPlate : nil,
            insuranceExpiry: selectedRole == .carOwner ? insuranceExpiry : nil
        )
        
        return errors.isEmpty
    }
    
    /// Clear all validation errors
    func clearValidationErrors() {
        validationErrors = []
        emailError = nil
        passwordError = nil
        phoneError = nil
        carPlateError = nil
        insuranceError = nil
    }
    
    /// Clear all form fields
    func clearAllFields() {
        email = ""
        password = ""
        confirmPassword = ""
        name = ""
        phone = ""
        carPlate = ""
        insuranceExpiry = Date().addingTimeInterval(60 * 60 * 24 * 180)
        selectedCountryCode = "+853"
        selectedRole = .passenger
        isPasswordVisible = false
        isConfirmPasswordVisible = false
    }
    
    /// Handle login or registration action
    func handleAction() {
        clearValidationErrors()
        
        if showingRegister {
            // Validate all fields before submission
            let errors = ValidationUtilities.validateRegistrationForm(
                role: selectedRole,
                name: name,
                email: email,
                password: password,
                confirmPassword: confirmPassword,
                countryCode: selectedCountryCode,
                phone: phone,
                carPlate: selectedRole == .carOwner ? carPlate : nil,
                insuranceExpiry: selectedRole == .carOwner ? insuranceExpiry : nil
            )
            
            if !errors.isEmpty {
                validationErrors = errors
                return
            }
            
            // Construct full phone number with country code
            let fullPhone = selectedCountryCode + phone
            
            // Call registration
            authManager.register(
                name: name,
                email: email,
                password: password,
                phone: fullPhone,
                role: selectedRole,
                carPlate: selectedRole == .carOwner ? carPlate : nil,
                insuranceExpiry: selectedRole == .carOwner ? insuranceExpiry : nil
            )
        } else {
            // Login
            if email.isEmpty || password.isEmpty {
                validationErrors = ["请输入邮箱和密码"]
                return
            }
            
            authManager.login(email: email, password: password)
        }
    }
}

// MARK: - 主 Tab 视图
struct MainTabView: View {
    var body: some View {
        TabView {
            SimpleHomeView()
                .tabItem { Label("找行程", systemImage: "car.side.fill") }
            
            AdvancedSearchView()
                .tabItem { Label("智能搜索", systemImage: "magnifyingglass") }
            
            SimplePublishView()
                .tabItem { Label("发布", systemImage: "plus.circle.fill") }
            
            ProfileView()
                .tabItem { Label("我的", systemImage: "person.crop.circle.fill") }
        }
        .tint(.cookiePrimary)
    }
}

// MARK: - 首页/查找视图
struct SimpleHomeView: View {
    @EnvironmentObject var rideService: RideService
    
    @State private var searchStart: String = ""
    @State private var searchEnd: String = ""

    var filteredRides: [Ride] {
        if searchStart.isEmpty && searchEnd.isEmpty {
            return rideService.rides
        }
        return rideService.rides.filter { ride in
            (searchStart.isEmpty || ride.startLocation.localizedCaseInsensitiveContains(searchStart)) &&
            (searchEnd.isEmpty || ride.endLocation.localizedCaseInsensitiveContains(searchEnd))
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack(spacing: 15) {
                    TextField("搜索出发地", text: $searchStart)
                        .padding(10)
                        .background(Color.white)
                        .cornerRadius(10)
                    
                    TextField("搜索目的地", text: $searchEnd)
                        .padding(10)
                        .background(Color.white)
                        .cornerRadius(10)
                }
                .padding()
                .background(Color.cookieBackground)
                
                if filteredRides.isEmpty {
                    ContentUnavailableView("暂无行程", systemImage: "magnifyingglass")
                } else {
                    List {
                        ForEach(filteredRides) { ride in
                            NavigationLink(destination: RideDetailView(ride: ride)) {
                                RideCard(ride: ride)
                            }
                            .listRowInsets(EdgeInsets())
                            .padding(.vertical, 8)
                            .padding(.horizontal, 15)
                            .listRowSeparator(.hidden)
                            .background(Color.cookieBackground)
                        }
                    }
                    .listStyle(.plain)
                    .background(Color.cookieBackground)
                }
            }
            .navigationTitle("拼车大厅")
        }
    }
}

// MARK: - 发布行程视图
struct SimplePublishView: View {
    @EnvironmentObject var rideService: RideService
    @EnvironmentObject var authManager: AuthManager
    
    @State private var startLocation: String = ""
    @State private var endLocation: String = ""
    @State private var departureDate: Date = Date().addingTimeInterval(3600)
    @State private var availableSeats: Int = 1
    @State private var pricePerSeat: Int = 20
    @State private var notes: String = ""
    @State private var isShowingSuccessMessage = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("行程信息") {
                    TextField("出发地点", text: $startLocation)
                    TextField("目标地点", text: $endLocation)
                    DatePicker("出发时间", selection: $departureDate, in: Date()...)
                }

                Section("座位与价格") {
                    Stepper("可用座位: \(availableSeats)", value: $availableSeats, in: 1...8)
                    Stepper("价格: \(pricePerSeat) MOP", value: $pricePerSeat, in: 0...500, step: 5)
                }
                
                Section("备注") {
                    TextField("备注信息", text: $notes)
                }
                
                Button("发布行程") {
                    publishRide()
                }
                .buttonStyle(CookieButtonStyle(color: .green))
                .disabled(startLocation.isEmpty || endLocation.isEmpty)
            }
            .navigationTitle("发布行程")
            .alert("发布成功", isPresented: $isShowingSuccessMessage) {
                Button("OK") { resetForm() }
            }
        }
    }
    
    func publishRide() {
        print("🚀 开始发布行程...")
        print("📍 出发地: \(startLocation)")
        print("📍 目的地: \(endLocation)")
        print("🕐 出发时间: \(departureDate)")
        print("💺 座位数: \(availableSeats)")
        print("💰 价格: \(pricePerSeat)")
        
        guard let user = authManager.currentUser else {
            print("❌ 错误: 用户未登录或用户信息为空")
            return
        }
        
        print("✅ 当前用户: \(user.name)")
        print("📱 用户电话: \(user.phone)")
        print("🆔 用户ID: \(user.id ?? "无ID")")
        
        let newRide = Ride(
            ownerID: user.id ?? "",
            ownerName: user.name,
            ownerPhone: user.phone,
            startLocation: startLocation,
            endLocation: endLocation,
            departureTime: departureDate,
            availableSeats: availableSeats,
            pricePerSeat: pricePerSeat,
            notes: notes,
            status: "Active",
            passengerIDs: []
        )
        
        print("📦 创建行程对象成功")
        print("🔄 调用 addRide...")
        
        rideService.addRide(newRide)
        
        print("✅ 行程已添加到服务")
        print("📊 当前总行程数: \(rideService.rides.count)")
        
        isShowingSuccessMessage = true
        print("🎉 显示成功消息")
    }
    
    func resetForm() {
        startLocation = ""
        endLocation = ""
        notes = ""
    }
}

// MARK: - 个人中心（已弃用 - 请使用 ProfileView.swift 中的新版本）
// 注意：此 SimpleProfileView 已被 ProfileView.swift 中更完善的版本替换
// 保留此代码仅供参考，实际使用的是新的 ProfileView

/*
struct SimpleProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        NavigationView {
            List {
                if let user = authManager.currentUser {
                    Section {
                        HStack {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .frame(width: 60, height: 60)
                                .foregroundColor(.gray)
                            VStack(alignment: .leading) {
                                Text(user.name).font(.headline)
                                Text(user.email).font(.subheadline).foregroundColor(.gray)
                                Text(user.role.rawValue).font(.caption).padding(4).background(Color.blue.opacity(0.1)).cornerRadius(4)
                            }
                        }
                        .padding(.vertical)
                        
                        if user.role == .carOwner, let plate = user.carPlateNumber {
                            Text("车牌号: \(plate)")
                        }
                    }
                    
                    Section("我的活动") {
                        NavigationLink(destination: MyPublishedRidesView(userID: user.id ?? "")) {
                            Label("我发布的行程", systemImage: "car")
                        }
                        NavigationLink(destination: MyBookedRidesView(userID: user.id ?? "")) {
                            Label("我预订的行程", systemImage: "ticket")
                        }
                    }
                    
                    Section {
                        Button("退出登录") {
                            authManager.logout()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("个人中心")
        }
    }
}
*/

// MARK: - 详情页
struct RideDetailView: View {
    let ride: Ride
    @EnvironmentObject var rideService: RideService
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    
    var isOwner: Bool {
        ride.ownerID == authManager.currentUser?.id
    }
    
    var isBooked: Bool {
        guard let uid = authManager.currentUser?.id else { return false }
        return ride.passengerIDs.contains(uid)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                // MARK: - Apple Maps 调用
                AppleMapView(startLocation: ride.startLocation, endLocation: ride.endLocation)
                    .frame(height: 250)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .shadow(color: .gray.opacity(0.2), radius: 5)
                
                // 信息展示
                VStack(alignment: .leading, spacing: 10) {
                    Text("\(ride.startLocation) → \(ride.endLocation)")
                        .font(.title2).bold()
                    
                    Divider()
                    
                    HStack {
                        Image(systemName: "clock")
                        Text("时间: \(ride.formattedDate)")
                    }
                    .foregroundColor(.gray)
                    
                    HStack {
                        Image(systemName: "person.2.fill")
                        Text("剩余座位: \(ride.availableSeats)")
                            .foregroundColor(ride.availableSeats > 0 ? .green : .red)
                    }
                    .foregroundColor(.gray)
                    
                    HStack {
                        Image(systemName: "yen.circle.fill")
                        Text("价格: ¥\(ride.pricePerSeat)")
                    }
                    .foregroundColor(.gray)
                    
                    // 根据当前用户角色显示不同信息
                    if isOwner {
                        // 车主看到：拼车小伙伴列表
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "person.3.fill")
                                Text("拼车小伙伴")
                                    .font(.headline)
                            }
                            .foregroundColor(.cookiePrimary)
                            
                            if ride.passengerIDs.isEmpty {
                                Text("暂无乘客加入")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .italic()
                            } else {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("已加入: \(ride.passengerIDs.count) 人")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                    
                                    // 这里可以扩展显示乘客详细信息
                                    ForEach(ride.passengerIDs, id: \.self) { passengerID in
                                        HStack {
                                            Image(systemName: "person.circle.fill")
                                                .font(.caption)
                                            Text("乘客 ID: \(passengerID.prefix(8))...")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.top, 8)
                        .padding(12)
                        .background(Color.cookiePrimary.opacity(0.1))
                        .cornerRadius(8)
                    } else {
                        // 乘客看到：车主信息
                        HStack {
                            Image(systemName: "car.fill")
                            Text("车主: \(ride.ownerName)")
                        }
                        .foregroundColor(.gray)
                    }
                    
                    if !ride.notes.isEmpty {
                        Text("备注: \(ride.notes)")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top, 5)
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .padding(.horizontal)
                
                // 按钮区域
                HStack {
                    if isOwner {
                        Button("删除行程") {
                            rideService.deleteRide(ride)
                            dismiss()
                        }
                        .buttonStyle(CookieButtonStyle(color: .red))
                    } else {
                        if isBooked {
                            Button("取消预订") {
                                if let uid = authManager.currentUser?.id {
                                    rideService.cancelBooking(ride: ride, userID: uid)
                                }
                            }
                            .buttonStyle(CookieButtonStyle(color: .orange))
                        } else if ride.availableSeats > 0 {
                            Button("立即加入") {
                                if let uid = authManager.currentUser?.id {
                                    rideService.bookRide(ride: ride, userID: uid)
                                }
                            }
                            .buttonStyle(CookieButtonStyle(color: .cookiePrimary))
                        } else {
                            Button("已满座") { }
                                .buttonStyle(CookieButtonStyle(color: .gray))
                                .disabled(true)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("行程详情")
        .background(Color.cookieBackground)
    }
}

// MARK: - 列表过滤辅助视图
struct MyPublishedRidesView: View {
    let userID: String
    @EnvironmentObject var rideService: RideService
    
    var myRides: [Ride] {
        rideService.rides.filter { $0.ownerID == userID }
    }
    
    var body: some View {
        List(myRides) { ride in
            NavigationLink(destination: RideDetailView(ride: ride)) {
                RideCard(ride: ride)
            }
        }
        .navigationTitle("我的发布")
    }
}

struct MyBookedRidesView: View {
    let userID: String
    @EnvironmentObject var rideService: RideService
    
    var bookedRides: [Ride] {
        rideService.rides.filter { $0.passengerIDs.contains(userID) }
    }
    
    var body: some View {
        List(bookedRides) { ride in
            NavigationLink(destination: RideDetailView(ride: ride)) {
                RideCard(ride: ride)
            }
        }
        .navigationTitle("我的预订")
    }
}

// MARK: - RideCard 组件
struct RideCard: View {
    let ride: Ride
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 路线
            HStack(spacing: 8) {
                Text(ride.startLocation)
                    .font(.headline)
                    .lineLimit(1)
                
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text(ride.endLocation)
                    .font(.headline)
                    .lineLimit(1)
            }
            .foregroundColor(.cookieText)
            
            // 时间和座位
            HStack {
                Label(ride.formattedDate, systemImage: "clock")
                    .font(.subheadline)
                    .foregroundColor(.cookieText.opacity(0.7))
                
                Spacer()
                
                Label("\(ride.availableSeats) 座", systemImage: "chair.fill")
                    .font(.subheadline)
                    .foregroundColor(ride.availableSeats > 0 ? .orange : .gray)
            }
            
            // 价格
            HStack {
                Text("价格")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text("¥\(ride.pricePerSeat)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: .gray.opacity(0.1), radius: 5, x: 0, y: 3)
        )
    }
}

// MARK: - ============================================
// MARK: - 智能搜索系统 (Advanced Search System)
// MARK: - ============================================

/// 高级搜索视图 - 支持时间、起点、终点的智能匹配
struct AdvancedSearchView: View {
    @EnvironmentObject var rideService: RideService
    @EnvironmentObject var authManager: AuthManager
    
    @State private var selectedTime: Date = Date()
    @State private var originInput: String = ""
    @State private var destinationInput: String = ""
    @State private var navigateToResults = false
    @State private var searchResults: [Ride] = []
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 标题区域
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.cookiePrimary)
                        
                        Text("智能搜索行程")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.cookieText)
                        
                        Text("输入您的出行信息，找到合适的拼车")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                    
                    // 搜索表单
                    VStack(spacing: 20) {
                        // 出发时间选择
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "clock.fill")
                                    .foregroundColor(.cookiePrimary)
                                Text("出发时间")
                                    .font(.headline)
                                    .foregroundColor(.cookieText)
                            }
                            
                            DatePicker(
                                "选择时间",
                                selection: $selectedTime,
                                in: Date()...,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: .gray.opacity(0.1), radius: 5, x: 0, y: 2)
                        
                        // 出发地输入
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "location.circle.fill")
                                    .foregroundColor(.green)
                                Text("出发地")
                                    .font(.headline)
                                    .foregroundColor(.cookieText)
                            }
                            
                            TextField("例如：横琴口岸", text: $originInput)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocorrectionDisabled()
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: .gray.opacity(0.1), radius: 5, x: 0, y: 2)
                        
                        // 目的地输入
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(.red)
                                Text("目的地")
                                    .font(.headline)
                                    .foregroundColor(.cookieText)
                            }
                            
                            TextField("例如：澳门科技大学", text: $destinationInput)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocorrectionDisabled()
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: .gray.opacity(0.1), radius: 5, x: 0, y: 2)
                        
                        // 搜索按钮
                        Button {
                            performSearch()
                        } label: {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .font(.title3)
                                Text("搜索行程")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [.cookiePrimary, .cookiePrimary.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                            .shadow(color: .cookiePrimary.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .disabled(!isFormValid)
                        .opacity(isFormValid ? 1.0 : 0.6)
                        
                        // 提示信息
                        if !isFormValid {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.orange)
                                Text("请至少输入出发地或目的地")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
            }
            .background(Color.cookieBackground.ignoresSafeArea())
            .navigationTitle("智能搜索")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $navigateToResults) {
                AdvancedSearchResultsView(searchResults: searchResults)
            }
        }
    }
    
    // MARK: - 辅助属性和方法
    
    /// 表单验证：至少需要出发地或目的地之一
    private var isFormValid: Bool {
        !originInput.isEmpty || !destinationInput.isEmpty
    }
    
    /// 执行搜索
    private func performSearch() {
        print("🔍 开始搜索...")
        print("📊 总行程数: \(rideService.rides.count)")
        print("📍 出发地: \(originInput)")
        print("📍 目的地: \(destinationInput)")
        print("🕐 选择时间: \(selectedTime)")
        
        var results = rideService.rides
        
        // 过滤出发地（模糊匹配，不区分大小写）
        if !originInput.isEmpty {
            results = results.filter { ride in
                ride.startLocation.localizedCaseInsensitiveContains(originInput)
            }
            print("✅ 出发地过滤后: \(results.count) 个行程")
        }
        
        // 过滤目的地（模糊匹配，不区分大小写）
        if !destinationInput.isEmpty {
            results = results.filter { ride in
                ride.endLocation.localizedCaseInsensitiveContains(destinationInput)
            }
            print("✅ 目的地过滤后: \(results.count) 个行程")
        }
        
        // 过滤时间（匹配前后2小时内的行程）
        results = results.filter { ride in
            let timeDifference = abs(ride.departureTime.timeIntervalSince(selectedTime))
            print("   行程出发时间: \(ride.departureTime), 时间差: \(Int(timeDifference/60)) 分钟")
            return timeDifference <= 7200  // 2小时 = 7200秒
        }
        print("✅ 时间过滤后: \(results.count) 个行程")
        
        // 只返回未过期的行程（出发时间在当前时间之后）
        let currentTime = Date()
        results = results.filter { ride in
            let isNotExpired = ride.departureTime > currentTime
            print("   行程 \(ride.startLocation)->\(ride.endLocation): 出发时间 \(ride.departureTime), 当前时间 \(currentTime), 未过期: \(isNotExpired)")
            return isNotExpired
        }
        print("✅ 未过期行程: \(results.count) 个")
        
        // 按出发时间排序（最近的在前）
        searchResults = results.sorted { $0.departureTime < $1.departureTime }
        
        print("🎯 最终搜索结果: \(searchResults.count) 个行程")
        
        // 导航到结果页面
        navigateToResults = true
        print("🚀 导航到结果页面")
    }
}

/// 高级搜索结果列表视图
struct AdvancedSearchResultsView: View {
    @EnvironmentObject var rideService: RideService
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    
    let searchResults: [Ride]
    
    var body: some View {
        ZStack {
            Color.cookieBackground.ignoresSafeArea()
            
            if searchResults.isEmpty {
                // 空状态视图
                VStack(spacing: 20) {
                    Image(systemName: "car.side.air.fresh")
                        .font(.system(size: 80))
                        .foregroundColor(.gray.opacity(0.3))
                    
                    Text("未找到匹配的行程")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.cookieText)
                    
                    Text("请尝试调整搜索条件")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button {
                        dismiss()
                    } label: {
                        Text("返回搜索")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .background(Color.cookiePrimary)
                            .cornerRadius(10)
                    }
                    .padding(.top, 20)
                }
            } else {
                // 结果列表
                ScrollView {
                    VStack(spacing: 16) {
                        // 结果统计
                        HStack {
                            Text("找到 \(searchResults.count) 个行程")
                                .font(.headline)
                                .foregroundColor(.cookieText)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        
                        // 行程卡片列表
                        ForEach(searchResults) { ride in
                            NavigationLink(destination: AdvancedRideDetailView(ride: ride)) {
                                AdvancedRideCard(ride: ride)
                                    .padding(.horizontal, 16)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        // 底部间距
                        Color.clear.frame(height: 20)
                    }
                }
            }
        }
        .navigationTitle("搜索结果")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 高级搜索专用的行程卡片
struct AdvancedRideCard: View {
    @EnvironmentObject var authManager: AuthManager
    let ride: Ride
    
    // 检查当前用户是否已加入
    private var isJoined: Bool {
        guard let uid = authManager.currentUser?.id else { return false }
        return ride.passengerIDs.contains(uid)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 顶部：时间和状态
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.cookiePrimary)
                    Text(ride.formattedDate)
                        .font(.headline)
                        .foregroundColor(.cookieText)
                }
                
                Spacer()
                
                // 剩余座位数（使用红色高亮显示紧迫性）
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                    Text("\(ride.availableSeats) 座")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                .foregroundColor(ride.availableSeats > 0 ? .red : .gray)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(ride.availableSeats > 0 ? Color.red.opacity(0.15) : Color.gray.opacity(0.15))
                )
            }
            
            Divider()
            
            // 路线信息
            HStack(spacing: 12) {
                // 出发地
                VStack(alignment: .leading, spacing: 4) {
                    Text("出发")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(ride.startLocation)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.cookieText)
                }
                
                // 箭头
                Image(systemName: "arrow.right")
                    .font(.title3)
                    .foregroundColor(.cookiePrimary)
                    .frame(maxWidth: .infinity)
                
                // 目的地
                VStack(alignment: .trailing, spacing: 4) {
                    Text("到达")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(ride.endLocation)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.cookieText)
                }
            }
            
            Divider()
            
            // 司机信息和价格
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.cookiePrimary)
                    Text(ride.ownerName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "yensign.circle.fill")
                        .foregroundColor(.green)
                    Text("\(ride.pricePerSeat)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            }
            
            // 状态标签
            if isJoined {
                HStack {
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("已加入")
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                    Spacer()
                }
            } else if ride.availableSeats == 0 {
                HStack {
                    Spacer()
                    Text("已满座")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    Spacer()
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .gray.opacity(0.15), radius: 10, x: 0, y: 5)
    }
}

/// 高级搜索专用的详情页面（带确认加入功能）
struct AdvancedRideDetailView: View {
    let ride: Ride
    @EnvironmentObject var rideService: RideService
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    
    @State private var showJoinAlert = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    var isOwner: Bool {
        ride.ownerID == authManager.currentUser?.id
    }
    
    var isBooked: Bool {
        guard let uid = authManager.currentUser?.id else { return false }
        return ride.passengerIDs.contains(uid)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 地图
                AppleMapView(startLocation: ride.startLocation, endLocation: ride.endLocation)
                    .frame(height: 250)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .shadow(color: .gray.opacity(0.2), radius: 5)
                
                // 信息卡片
                VStack(alignment: .leading, spacing: 10) {
                    Text("\(ride.startLocation) → \(ride.endLocation)")
                        .font(.title2).bold()
                    
                    Divider()
                    
                    HStack {
                        Image(systemName: "clock")
                        Text("时间: \(ride.formattedDate)")
                    }
                    .foregroundColor(.gray)
                    
                    HStack {
                        Image(systemName: "person.2.fill")
                        Text("剩余座位: \(ride.availableSeats)")
                            .foregroundColor(ride.availableSeats > 0 ? .green : .red)
                    }
                    .foregroundColor(.gray)
                    
                    HStack {
                        Image(systemName: "yen.circle.fill")
                        Text("价格: ¥\(ride.pricePerSeat)")
                    }
                    .foregroundColor(.gray)
                    
                    if isOwner {
                        // 车主看到：拼车小伙伴
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "person.3.fill")
                                Text("拼车小伙伴")
                                    .font(.headline)
                            }
                            .foregroundColor(.cookiePrimary)
                            
                            if ride.passengerIDs.isEmpty {
                                Text("暂无乘客加入")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .italic()
                            } else {
                                Text("已加入: \(ride.passengerIDs.count) 人")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(.top, 8)
                        .padding(12)
                        .background(Color.cookiePrimary.opacity(0.1))
                        .cornerRadius(8)
                    } else {
                        HStack {
                            Image(systemName: "car.fill")
                            Text("车主: \(ride.ownerName)")
                        }
                        .foregroundColor(.gray)
                    }
                    
                    if !ride.notes.isEmpty {
                        Text("备注: \(ride.notes)")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top, 5)
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .padding(.horizontal)
                
                // 按钮区域
                if !isOwner {
                    if isBooked {
                        Button("取消预订") {
                            if let uid = authManager.currentUser?.id {
                                rideService.cancelBooking(ride: ride, userID: uid)
                                dismiss()
                            }
                        }
                        .buttonStyle(CookieButtonStyle(color: .orange))
                        .padding(.horizontal)
                    } else if ride.availableSeats > 0 {
                        Button {
                            showJoinAlert = true
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                Text("确认加入")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                Spacer()
                            }
                            .foregroundColor(.white)
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
                        .padding(.horizontal)
                    } else {
                        Button("已满座") { }
                            .buttonStyle(CookieButtonStyle(color: .gray))
                            .disabled(true)
                            .padding(.horizontal)
                    }
                }
            }
        }
        .navigationTitle("行程详情")
        .background(Color.cookieBackground)
        .alert("加入行程确认", isPresented: $showJoinAlert) {
            Button("取消", role: .cancel) { }
            Button("确认加入", role: .destructive) {
                handleJoinRide()
            }
        } message: {
            Text("您确定要加入此行程吗？加入后将锁定您的座位。")
        }
        .alert("加入成功", isPresented: $showSuccessAlert) {
            Button("好的") {
                dismiss()
            }
        } message: {
            Text("您已成功加入此行程，请准时出发！")
        }
        .alert("加入失败", isPresented: $showErrorAlert) {
            Button("知道了") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func handleJoinRide() {
        guard let uid = authManager.currentUser?.id else {
            errorMessage = "请先登录"
            showErrorAlert = true
            return
        }
        
        if ride.availableSeats <= 0 {
            errorMessage = "手慢了！座位已满"
            showErrorAlert = true
            return
        }
        
        if ride.passengerIDs.contains(uid) {
            errorMessage = "您已经加入过这个行程了"
            showErrorAlert = true
            return
        }
        
        rideService.bookRide(ride: ride, userID: uid)
        showSuccessAlert = true
    }
}
