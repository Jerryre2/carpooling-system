//
//  PassengerTestView.swift
//  CarpoolingSystem
//
//  Created by 葛泰泽 on 08/12/2025.
//
//
//  PassengerTestView.swift
//  CarpoolingSystem - 临时测试入口
//
//  Created on 2025-12-07
//

import SwiftUI

struct PassengerTestView: View {
    @StateObject private var viewModel = FinalPassengerViewModel(
        userID: "test_passenger_001",
        userName: "测试用户",
        userPhone: "+853 6666 6666"
    )
    
    @State private var showWallet = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // 用户信息卡片
                    userInfoCard
                    
                    // 钱包入口按钮
                    walletButton
                    
                    // 测试功能按钮
                    testButtons
                }
                .padding()
            }
            .navigationTitle("乘客端测试")
            .background(Color(.systemGroupedBackground))
            .sheet(isPresented: $showWallet) {
                WalletView(viewModel: viewModel)
            }
        }
    }
    
    // MARK: - 用户信息卡片
    private var userInfoCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text(viewModel.currentUserName)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(viewModel.currentUserPhone)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // 显示余额
            HStack {
                Text("钱包余额:")
                    .foregroundColor(.secondary)
                
                Text(viewModel.formatPrice(viewModel.walletBalance))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5)
    }
    
    // MARK: - 钱包按钮
    private var walletButton: some View {
        Button(action: {
            showWallet = true
        }) {
            HStack {
                Image(systemName: "wallet.pass.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("我的钱包")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("点击查看详情")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.white)
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.blue, Color.purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: Color.blue.opacity(0.3), radius: 5)
        }
    }
    
    // MARK: - 测试按钮
    private var testButtons: some View {
        VStack(spacing: 12) {
            Text("快速测试功能")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // 充值测试
            Button(action: {
                Task {
                    await viewModel.topUpWallet(amount: 100)
                }
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.green)
                    
                    Text("测试充值 ¥100")
                    
                    Spacer()
                    
                    if viewModel.isLoading {
                        ProgressView()
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
            }
            .disabled(viewModel.isLoading)
            
            // 刷新余额
            Button(action: {
                Task {
                    await viewModel.refresh()
                }
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.blue)
                    
                    Text("刷新余额")
                    
                    Spacer()
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
            }
            
            // 查看交易记录
            Button(action: {
                Task {
                    let transactions = await viewModel.loadTransactionHistory()
                    print("📝 交易记录数量: \(transactions.count)")
                }
            }) {
                HStack {
                    Image(systemName: "list.bullet")
                        .foregroundColor(.orange)
                    
                    Text("加载交易记录")
                    
                    Spacer()
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - Preview
#if DEBUG
struct PassengerTestView_Previews: PreviewProvider {
    static var previews: some View {
        PassengerTestView()
    }
}
#endif
