//
//  PassengerMainView.swift
//  CarpoolingSystem - Passenger Main Interface
//
//  Created on 2025-12-07
//  乘客端主界面：我的行程、支付、钱包
//

import SwiftUI

// MARK: - Passenger Main View
/// 乘客端主界面（Tab 结构）
struct PassengerMainView: View {
    
    @StateObject private var viewModel: FinalPassengerViewModel
    @State private var selectedTab: Int = 0
    @State private var showingTripCreation: Bool = false
    
    init(passengerID: String, passengerName: String, passengerPhone: String) {
        _viewModel = StateObject(wrappedValue: FinalPassengerViewModel(
            userID: passengerID,
            userName: passengerName,
            userPhone: passengerPhone
        ))
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: 我的行程
            MyTripsView(viewModel: viewModel, showingTripCreation: $showingTripCreation)
                .tabItem {
                    Label("我的行程", systemImage: "list.bullet")
                }
                .tag(0)
            
            // Tab 2: 钱包
            WalletView(viewModel: viewModel)
                .tabItem {
                    Label("钱包", systemImage: "creditcard")
                }
                .tag(1)
            
            // Tab 3: 个人中心
            PassengerProfileView(viewModel: viewModel)
                .tabItem {
                    Label("我的", systemImage: "person")
                }
                .tag(2)
        }
        .sheet(isPresented: $showingTripCreation) {
            TripCreationView(viewModel: viewModel)
        }
        .onAppear {
            viewModel.startListening()
        }
        .onDisappear {
            viewModel.stopListening()
        }
    }
}

// MARK: - My Trips View
/// 我的行程列表
struct MyTripsView: View {
    
    @ObservedObject var viewModel: FinalPassengerViewModel
    @Binding var showingTripCreation: Bool
    @State private var selectedTrip: TripRequest?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if viewModel.myPublishedTrips.isEmpty {
                    emptyView
                } else {
                    tripsList
                }
            }
            .navigationTitle("我的行程")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingTripCreation = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(item: $selectedTrip) { trip in
                TripDetailView(trip: trip, viewModel: viewModel)
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
        }
    }
    
    // MARK: - Trips List
    
    private var tripsList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.myPublishedTrips) { trip in
                    PassengerTripCard(trip: trip, viewModel: viewModel)
                        .onTapGesture {
                            selectedTrip = trip
                        }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Empty View
    
    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "car.circle")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            Text("还没有发布行程")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("点击右上角 + 发布第一个行程吧")
                .foregroundColor(.gray)
            
            Button(action: {
                showingTripCreation = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("发布行程")
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
    }
}

// MARK: - Passenger Trip Card
/// 乘客行程卡片
struct PassengerTripCard: View {
    let trip: TripRequest
    @ObservedObject var viewModel: FinalPassengerViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部：状态和时间
            HStack {
                // 状态标签
                HStack {
                    Image(systemName: trip.status.icon)
                    Text(trip.status.displayName)
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(statusColor(for: trip.status).opacity(0.2))
                .foregroundColor(statusColor(for: trip.status))
                .cornerRadius(20)
                
                Spacer()
                
                Text(trip.formattedDepartureTime)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
            
            Divider()
            
            // 中部：路线信息
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "location.circle.fill")
                        .foregroundColor(.green)
                    
                    Text(trip.startLocation)
                        .font(.body)
                    
                    Spacer()
                }
                
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.red)
                    
                    Text(trip.endLocation)
                        .font(.body)
                    
                    Spacer()
                }
            }
            .padding()
            
            Divider()
            
            // 底部：费用和操作
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("总费用")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("¥\(String(format: "%.2f", trip.totalCost))")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                // 根据状态显示不同的按钮
                actionButton(for: trip)
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - Status Color Helper
    private func statusColor(for status: TripStatus) -> Color {
        switch status {
        case .pending:
            return .orange
        case .accepted:
            return .blue
        case .awaitingPayment:
            return .purple
        case .paid:
            return .green
        case .inProgress:
            return .indigo
        case .completed:
            return .gray
        case .cancelled:
            return .red
        }
    }
    
    @ViewBuilder
    private func actionButton(for trip: TripRequest) -> some View {
        switch trip.status {
        case .pending:
            Text("等待接单")
                .font(.caption)
                .foregroundColor(.orange)
            
        case .accepted:
            Text("司机已接单")
                .font(.caption)
                .foregroundColor(.blue)
            
        case .awaitingPayment:
            // 🎯 核心功能：支付按钮
            Button(action: {
                Task {
                    await viewModel.payForTrip(trip: trip)
                }
            }) {
                HStack {
                    Image(systemName: "creditcard.fill")
                    Text("立即支付")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(canPay(trip) ? Color.purple : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(viewModel.isLoading || !canPay(trip))
            
        case .paid:
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("已支付")
                    .foregroundColor(.green)
            }
            .font(.caption)
            
        case .inProgress:
            Text("行程中")
                .font(.caption)
                .foregroundColor(.indigo)
            
        case .completed:
            Text("已完成")
                .font(.caption)
                .foregroundColor(.gray)
            
        case .cancelled:
            Text("已取消")
                .font(.caption)
                .foregroundColor(.red)
        }
    }
    
    // MARK: - Can Pay Helper
    private func canPay(_ trip: TripRequest) -> Bool {
        guard let user = viewModel.currentUser else { return false }
        return user.walletBalance >= trip.totalCost
    }
}

// MARK: - Trip Detail View
/// 行程详情视图
struct TripDetailView: View {
    let trip: TripRequest
    @ObservedObject var viewModel: FinalPassengerViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 状态卡片
                    statusCard
                    
                    // 路线信息
                    routeCard
                    
                    // 司机信息（如果已接单）
                    if trip.isAccepted, let driverName = trip.driverName {
                        driverCard(driverName: driverName, driverPhone: trip.driverPhone ?? "")
                    }
                    
                    // 费用信息
                    priceCard
                    
                    // 操作按钮
                    actionButtons
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("行程详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Status Color Helper
    private func statusColor(for status: TripStatus) -> Color {
        switch status {
        case .pending:
            return .orange
        case .accepted:
            return .blue
        case .awaitingPayment:
            return .purple
        case .paid:
            return .green
        case .inProgress:
            return .indigo
        case .completed:
            return .gray
        case .cancelled:
            return .red
        }
    }
    
    // MARK: - Status Card
    
    private var statusCard: some View {
        HStack {
            Image(systemName: trip.status.icon)
                .font(.title)
                .foregroundColor(statusColor(for: trip.status))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(trip.status.displayName)
                    .font(.title3)
                    .fontWeight(.semibold)
                
                if trip.status == .awaitingPayment {
                    Text("请尽快支付以确保行程")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Route Card
    
    private var routeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("路线信息")
                .font(.headline)
            
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "location.circle.fill")
                        .foregroundColor(.green)
                    VStack(alignment: .leading) {
                        Text("起点")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(trip.startLocation)
                    }
                }
                
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.red)
                    VStack(alignment: .leading) {
                        Text("终点")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(trip.endLocation)
                    }
                }
                
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.orange)
                    VStack(alignment: .leading) {
                        Text("出发时间")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(trip.formattedDepartureTime)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Driver Card
    
    private func driverCard(driverName: String, driverPhone: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("司机信息")
                .font(.headline)
            
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(driverName)
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text(driverPhone)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Button(action: {
                    // 拨打电话
                    if let url = URL(string: "tel://\(driverPhone.replacingOccurrences(of: " ", with: ""))") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Image(systemName: "phone.fill")
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Price Card
    
    private var priceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("费用信息")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("单人费用")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("¥\(String(format: "%.2f", trip.pricePerPerson))")
                        .font(.title3)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("人数")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(trip.numberOfPassengers) 人")
                        .font(.title3)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("总费用")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("¥\(String(format: "%.2f", trip.totalCost))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Can Pay Helper
    private func canPay(_ trip: TripRequest) -> Bool {
        guard let user = viewModel.currentUser else { return false }
        return user.walletBalance >= trip.totalCost
    }
    
    // MARK: - Action Buttons
    
    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // 支付按钮
            if trip.needsPayment {
                Button(action: {
                    Task {
                        await viewModel.payForTrip(trip: trip)
                        if viewModel.successMessage != nil {
                            dismiss()
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "creditcard.fill")
                        Text("立即支付 ¥\(String(format: "%.2f", trip.totalCost))")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        canPay(trip) ? Color.purple : Color.gray
                    )
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!canPay(trip) || viewModel.isLoading)
                
                if !canPay(trip) {
                    Text("余额不足，请先充值")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            // 取消按钮
            if trip.status == .pending || trip.status == .accepted {
                Button(action: {
                    Task {
                        await viewModel.cancelTrip(tripID: trip.id)
                        if viewModel.successMessage != nil {
                            dismiss()
                        }
                    }
                }) {
                    Text("取消行程")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(12)
                }
                .disabled(viewModel.isLoading)
            }
        }
    }
}

// MARK: - Passenger Profile View
/// 乘客个人中心
struct PassengerProfileView: View {
    @ObservedObject var viewModel: FinalPassengerViewModel
    
    var body: some View {
        NavigationView {
            List {
                // 用户信息
                Section {
                    if let user = viewModel.currentUser {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.name)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text(user.phone)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical)
                    }
                }
                
                // 统计信息
                Section(header: Text("统计")) {
                    if let user = viewModel.currentUser {
                        HStack {
                            Text("订单总数")
                            Spacer()
                            Text("\(user.totalTripsAsPassenger)")
                                .foregroundColor(.blue)
                        }
                        
                        HStack {
                            Text("评分")
                            Spacer()
                            HStack {
                                ForEach(0..<5) { index in
                                    Image(systemName: "star.fill")
                                        .foregroundColor(index < Int(user.rating) ? .yellow : .gray)
                                }
                            }
                        }
                    }
                }
                
                // 设置
                Section(header: Text("设置")) {
                    Button(action: {
                        // TODO: 退出登录
                    }) {
                        Text("退出登录")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("个人中心")
        }
    }
}

// MARK: - Success Toast Component
/// 成功提示组件


// MARK: - Preview
#if DEBUG
struct PassengerMainView_Previews: PreviewProvider {
    static var previews: some View {
        PassengerMainView(
            passengerID: "passenger_preview",
            passengerName: "测试乘客",
            passengerPhone: "+853 6666 6666"
        )
    }
}
#endif
