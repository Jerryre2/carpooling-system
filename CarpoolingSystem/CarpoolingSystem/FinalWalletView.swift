//
//  FinalWalletView.swift
//  CarpoolingSystem - Final Wallet View (No Conflicts)
//
//  Created on 2025-12-07
//  完全无冲突的钱包页面
//

import SwiftUI

// MARK: - Final Wallet View
struct FinalWalletView: View {
    
    @ObservedObject var viewModel: FinalPassengerViewModel
    @State private var showTopUpSheet: Bool = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 余额卡片
                    balanceCard
                    
                    // 快捷充值
                    quickTopUpButtons
                    
                    // 交易记录占位
                    transactionsPlaceholder
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("💰 我的钱包")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showTopUpSheet) {
                TopUpSheet(viewModel: viewModel)
            }
            .overlay(alignment: .top) {
                if let message = viewModel.successMessage {
                    SuccessToast(message: message)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                viewModel.successMessage = nil
                            }
                        }
                }
            }
            .alert(item: $viewModel.errorAlert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("确定"))
                )
            }
        }
        .onAppear {
            viewModel.startListening()
        }
        .onDisappear {
            viewModel.stopListening()
        }
    }
    
    // MARK: - Balance Card
    
    private var balanceCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("账户余额")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.9))
                
                Spacer()
                
                Image(systemName: "dollarsign.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.9))
            }
            
            Text("¥\(String(format: "%.2f", viewModel.walletBalance))")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.white)
            
            Button(action: {
                showTopUpSheet = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("立即充值")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white.opacity(0.2))
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [Color.blue, Color.purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .shadow(radius: 5)
    }
    
    // MARK: - Quick Top Up Buttons
    
    private var quickTopUpButtons: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("快捷充值")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach([50.0, 100.0, 200.0, 500.0], id: \.self) { amount in
                    Button(action: {
                        Task {
                            await viewModel.topUpWallet(amount: amount)
                        }
                    }) {
                        VStack(spacing: 8) {
                            Text("¥\(Int(amount))")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("充值")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(Color(.systemBackground))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                        .shadow(radius: 2)
                    }
                    .disabled(viewModel.isLoading)
                }
            }
        }
    }
    
    // MARK: - Transactions Placeholder
    
    private var transactionsPlaceholder: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("交易记录")
                .font(.headline)
            
            VStack(spacing: 12) {
                Text("暂无交易记录")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
            }
        }
    }
}

// MARK: - Top Up Sheet
struct TopUpSheet: View {
    @ObservedObject var viewModel: FinalPassengerViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var amount: String = ""
    
    let quickAmounts: [Double] = [50, 100, 200, 500, 1000]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 当前余额
                VStack(spacing: 8) {
                    Text("当前余额")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("¥\(String(format: "%.2f", viewModel.walletBalance))")
                        .font(.title)
                        .fontWeight(.bold)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // 输入金额
                VStack(alignment: .leading, spacing: 8) {
                    Text("充值金额")
                        .font(.headline)
                    
                    HStack {
                        Text("¥")
                            .foregroundColor(.gray)
                        
                        TextField("请输入金额", text: $amount)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                
                // 快捷选择
                VStack(alignment: .leading, spacing: 8) {
                    Text("快捷选择")
                        .font(.headline)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(quickAmounts, id: \.self) { quickAmount in
                            Button(action: {
                                amount = String(format: "%.0f", quickAmount)
                            }) {
                                Text("¥\(Int(quickAmount))")
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        amount == String(format: "%.0f", quickAmount) ?
                                        Color.blue : Color(.systemGray6)
                                    )
                                    .foregroundColor(
                                        amount == String(format: "%.0f", quickAmount) ?
                                        .white : .primary
                                    )
                                    .cornerRadius(10)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // 确认充值按钮
                Button(action: {
                    Task {
                        if let value = Double(amount), value > 0 {
                            await viewModel.topUpWallet(amount: value)
                            if viewModel.errorAlert == nil {
                                dismiss()
                            }
                        }
                    }
                }) {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("确认充值")
                        }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isAmountValid() ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!isAmountValid() || viewModel.isLoading)
            }
            .padding()
            .navigationTitle("充值")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func isAmountValid() -> Bool {
        guard let value = Double(amount) else { return false }
        return value > 0 && value <= 10000
    }
}

// MARK: - Success Toast
struct SuccessToast1: View {
    let message: String
    
    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(message)
                .font(.subheadline)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 10)
        .padding()
    }
}

// MARK: - Preview
#if DEBUG
struct FinalWalletView_Previews: PreviewProvider {
    static var previews: some View {
        FinalWalletView(viewModel: FinalPassengerViewModel.preview)
    }
}
#endif
