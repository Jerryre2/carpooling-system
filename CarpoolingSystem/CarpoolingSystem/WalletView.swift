//
//  WalletView.swift
//  CarpoolingSystem - Wallet Management
//
//  Created on 2025-12-07
//  钱包管理：余额显示、充值、交易历史
//

import SwiftUI

// MARK: - Wallet View
/// 🎯 核心交付物：钱包页面
struct WalletView: View {
    
    @ObservedObject var viewModel: FinalPassengerViewModel
    @State private var showingTopUpSheet: Bool = false
    @State private var showingTransactionHistory: Bool = false
    
    // ✅ 新增：状态管理
    @State private var recentTransactions: [WalletTransaction] = []
    @State private var isLoadingTransactions: Bool = false
    @State private var showErrorAlert: Bool = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 余额卡片
                    balanceCard
                    
                    // 快捷操作
                    quickActions
                    
                    // 最近交易
                    recentTransactionsSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("💰 我的钱包")
            .navigationBarTitleDisplayMode(.large)
            // ✅ 新增：工具栏刷新按钮
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await refreshData()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .rotationEffect(.degrees(isLoadingTransactions ? 360 : 0))
                            .animation(isLoadingTransactions ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isLoadingTransactions)
                    }
                    .disabled(isLoadingTransactions)
                }
            }
            .sheet(isPresented: $showingTopUpSheet) {
                TopUpSheetView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingTransactionHistory) {
                TransactionHistoryView(viewModel: viewModel)
            }
            // ✅ 新增：错误提示
            .alert("加载失败", isPresented: $showErrorAlert) {
                Button("确定", role: .cancel) {}
                Button("重试") {
                    Task {
                        await loadRecentTransactions()
                    }
                }
            } message: {
                if let error = viewModel.errorAlert {
                    Text(error.message)
                }
            }
            // ✅ 新增：成功提示
            .alert("提示", isPresented: .constant(viewModel.successMessage != nil)) {
                Button("确定") {
                    viewModel.successMessage = nil
                }
            } message: {
                if let message = viewModel.successMessage {
                    Text(message)
                }
            }
            // ✅ 新增：自动加载数据
            .task {
                await loadRecentTransactions()
            }
            // ✅ 新增：监听充值成功后刷新
            .onChange(of: viewModel.successMessage) { message in
                if message != nil {
                    Task {
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        await loadRecentTransactions()
                    }
                }
            }
        }
    }
    
    // MARK: - Balance Card
    
    private var balanceCard: some View {
        VStack(spacing: 16) {
            // 余额标题
            Text("账户余额")
                .font(.headline)
                .foregroundColor(.white.opacity(0.9))
            
            // 余额金额
            if let user = viewModel.currentUser {
                Text("¥\(String(format: "%.2f", user.walletBalance))")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            } else {
                Text("¥0.00")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            
            // 用户信息
            if let user = viewModel.currentUser {
                HStack {
                    Image(systemName: "person.circle.fill")
                    Text(user.name)
                    Text("·")
                    Text(user.phone)
                }
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
            }
            
            // ✅ 新增：最后更新时间
            if let lastSync = viewModel.lastSyncTime {
                Text("更新于 \(formattedSyncTime(lastSync))")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(
            LinearGradient(
                colors: [Color.blue, Color.purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .shadow(color: Color.blue.opacity(0.3), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Quick Actions
    
    private var quickActions: some View {
        HStack(spacing: 16) {
            // 充值按钮
            Button(action: {
                showingTopUpSheet = true
            }) {
                VStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.green)
                    
                    Text("充值")
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 2)
            }
            
            // 交易记录按钮
            Button(action: {
                showingTransactionHistory = true
            }) {
                VStack(spacing: 8) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                    
                    Text("交易记录")
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 2)
            }
        }
    }
    
    // MARK: - Recent Transactions (✅ 增强版)
    
    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("最近交易")
                    .font(.headline)
                
                Spacer()
                
                // ✅ 新增：加载指示器
                if isLoadingTransactions {
                    ProgressView()
                        .scaleEffect(0.8)
                }
                
                Button("查看全部") {
                    showingTransactionHistory = true
                }
                .font(.caption)
            }
            
            // ✅ 增强：显示真实交易记录
            if isLoadingTransactions && recentTransactions.isEmpty {
                loadingView
            } else if recentTransactions.isEmpty {
                emptyTransactionView
            } else {
                VStack(spacing: 8) {
                    ForEach(recentTransactions.prefix(5)) { transaction in
                        RecentTransactionRow(transaction: transaction)
                    }
                }
            }
        }
    }
    
    // ✅ 新增：加载视图
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("加载中...")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // ✅ 增强：空状态视图
    private var emptyTransactionView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("暂无交易记录")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Button("立即充值") {
                showingTopUpSheet = true
            }
            .font(.caption)
            .foregroundColor(.blue)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - ✅ 新增：辅助方法
    
    /// 加载最近交易记录
    private func loadRecentTransactions() async {
        isLoadingTransactions = true
        
        let transactions = await viewModel.loadTransactionHistory()
        
        // 转换为 WalletTransaction
        recentTransactions = transactions
        
        isLoadingTransactions = false
        
        // 更新同步时间
        viewModel.lastSyncTime = Date()
    }
    
    /// 刷新所有数据
    private func refreshData() async {
        await viewModel.refresh()
        await loadRecentTransactions()
    }
    
    /// 格式化同步时间
    private func formattedSyncTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - ✅ 新增：最近交易行视图（简化版）
struct RecentTransactionRow: View {
    let transaction: WalletTransaction
    
    var body: some View {
        HStack {
            // 图标
            Image(systemName: iconName)
                .font(.title3)
                .foregroundColor(iconColor)
                .frame(width: 36, height: 36)
                .background(iconColor.opacity(0.1))
                .clipShape(Circle())
            
            // 交易信息
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.description)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // 金额
            Text(formattedAmount)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(amountColor)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private var iconName: String {
        switch transaction.type {
        case .payment:
            return "arrow.up.circle.fill"
        case .refund:
            return "arrow.counterclockwise.circle.fill"
        case .topUp:
            return "plus.circle.fill"
        case .earning:
            return "dollarsign.circle.fill"
        }
    }
    
    private var iconColor: Color {
        switch transaction.type {
        case .payment:
            return .red
        case .refund:
            return .orange
        case .topUp:
            return .green
        case .earning:
            return .blue
        }
    }
    
    private var amountColor: Color {
        switch transaction.type {
        case .payment:
            return .red
        case .refund, .topUp, .earning:
            return .green
        }
    }
    
    private var formattedAmount: String {
        let sign = (transaction.type == .payment) ? "-" : "+"
        return "\(sign)¥\(String(format: "%.2f", transaction.amount))"
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: transaction.createdAt)
    }
}

// MARK: - Top Up Sheet View
/// 充值弹窗
struct TopUpSheetView: View {
    
    @ObservedObject var viewModel: FinalPassengerViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedAmount: Double = 100
    @State private var customAmount: String = ""
    @State private var useCustomAmount: Bool = false
    
    private let presetAmounts: [Double] = [50, 100, 200, 500]
    
    var body: some View {
        NavigationView {
            Form {
                // 当前余额
                Section {
                    HStack {
                        Text("当前余额")
                        Spacer()
                        if let user = viewModel.currentUser {
                            Text("¥\(String(format: "%.2f", user.walletBalance))")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                // 充值金额选择
                Section(header: Text("选择充值金额")) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(presetAmounts, id: \.self) { amount in
                            Button(action: {
                                selectedAmount = amount
                                useCustomAmount = false
                            }) {
                                VStack(spacing: 4) {
                                    Text("¥\(Int(amount))")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                                .background(
                                    selectedAmount == amount && !useCustomAmount ?
                                    Color.blue : Color(.systemGray6)
                                )
                                .foregroundColor(
                                    selectedAmount == amount && !useCustomAmount ?
                                    .white : .primary
                                )
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // 自定义金额
                Section(header: Text("自定义金额")) {
                    HStack {
                        Text("¥")
                        TextField("输入金额", text: $customAmount)
                            .keyboardType(.decimalPad)
                            .onChange(of: customAmount) { newValue in
                                if !newValue.isEmpty {
                                    useCustomAmount = true
                                }
                            }
                    }
                }
                
                // 充值说明
                Section(footer: Text("充值金额将实时到账，充值后不可退款")) {
                    EmptyView()
                }
            }
            .navigationTitle("充值")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("确认充值") {
                        topUp()
                    }
                    .disabled(!canTopUp || viewModel.isLoading)
                }
            }
            // ✅ 新增：显示加载状态
            .overlay {
                if viewModel.isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    ProgressView("充值中...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                }
            }
        }
    }
    
    private var canTopUp: Bool {
        if useCustomAmount {
            return (Double(customAmount) ?? 0) > 0
        } else {
            return selectedAmount > 0
        }
    }
    
    private var finalAmount: Double {
        if useCustomAmount {
            return Double(customAmount) ?? 0
        } else {
            return selectedAmount
        }
    }
    
    private func topUp() {
        Task {
            await viewModel.topUpWallet(amount: finalAmount)
            
            if viewModel.successMessage != nil {
                dismiss()
            }
        }
    }
}

// MARK: - Transaction History View
/// 交易记录视图
struct TransactionHistoryView: View {
    
    @ObservedObject var viewModel: FinalPassengerViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var transactions: [WalletTransaction] = []
    @State private var isLoading: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                if isLoading {
                    ProgressView("加载中...")
                } else if transactions.isEmpty {
                    emptyView
                } else {
                    List {
                        ForEach(transactions) { transaction in
                            TransactionRowView(transaction: transaction)
                        }
                    }
                }
            }
            .navigationTitle("交易记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadTransactions()
            }
            // ✅ 新增：下拉刷新
            .refreshable {
                await loadTransactions()
            }
        }
    }
    
    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("暂无交易记录")
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func loadTransactions() async {
        isLoading = true
        transactions = await viewModel.loadTransactionHistory()
        isLoading = false
    }
}

// MARK: - Transaction Row View
/// 交易记录行视图
struct TransactionRowView: View {
    let transaction: WalletTransaction
    
    var body: some View {
        HStack {
            // 图标
            Image(systemName: iconName)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 40, height: 40)
                .background(iconColor.opacity(0.1))
                .clipShape(Circle())
            
            // 交易信息
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.description)
                    .font(.headline)
                
                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                // ✅ 新增：状态标签
                TransactionStatusBadge(status: transaction.status)
            }
            
            Spacer()
            
            // 金额
            Text(formattedAmount)
                .font(.headline)
                .foregroundColor(amountColor)
        }
        .padding(.vertical, 4)
    }
    
    private var iconName: String {
        switch transaction.type {
        case .payment:
            return "arrow.up.circle.fill"
        case .refund:
            return "arrow.counterclockwise.circle.fill"
        case .topUp:
            return "plus.circle.fill"
        case .earning:
            return "dollarsign.circle.fill"
        }
    }
    
    private var iconColor: Color {
        switch transaction.type {
        case .payment:
            return .red
        case .refund:
            return .orange
        case .topUp:
            return .green
        case .earning:
            return .blue
        }
    }
    
    private var amountColor: Color {
        switch transaction.type {
        case .payment:
            return .red
        case .refund, .topUp, .earning:
            return .green
        }
    }
    
    private var formattedAmount: String {
        let sign = (transaction.type == .payment) ? "-" : "+"
        return "\(sign)¥\(String(format: "%.2f", transaction.amount))"
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: transaction.createdAt)
    }
}

// MARK: - ✅ 新增：交易状态标签
struct TransactionStatusBadge: View {
    let status: WalletTransactionStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(status.color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(status.color.opacity(0.1))
            .cornerRadius(4)
    }
}

// MARK: - ✅ 新增：扩展
extension WalletTransactionStatus {
    var displayName: String {
        switch self {
        case .pending:
            return "处理中"
        case .completed:
            return "已完成"
        case .failed:
            return "失败"
        case .cancelled:
            return "已取消"
        }
    }
    
    var color: Color {
        switch self {
        case .pending:
            return .orange
        case .completed:
            return .green
        case .failed:
            return .red
        case .cancelled:
            return .gray
        }
    }
}

// MARK: - Preview
#if DEBUG
struct WalletView_Previews: PreviewProvider {
    static var previews: some View {
        WalletView(viewModel: FinalPassengerViewModel(
            userID: "preview_passenger",
            userName: "测试乘客",
            userPhone: "+853 6666 6666"
        ))
    }
}
#endif
