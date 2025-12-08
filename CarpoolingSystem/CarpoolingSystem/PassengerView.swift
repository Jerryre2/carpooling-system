//
//  PassengerView.swift
//  Advanced Ride-Sharing System
//
//  Created on 2025-12-07
//

import SwiftUI

// MARK: - Passenger View
/// 乘客视角主界面
struct PassengerRideListView: View {
    @EnvironmentObject var dataStore: RideDataStore
    @EnvironmentObject var authManager: AuthManager
    
    @State private var searchText: String = ""
    @State private var showCompletedRides: Bool = false
    
    var filteredRides: [AdvancedRide] {
        let baseRides = dataStore.searchRides(userRole: .passenger)
        
        if searchText.isEmpty {
            return baseRides
        }
        
        return baseRides.filter { ride in
            ride.startLocation.localizedCaseInsensitiveContains(searchText) ||
            ride.endLocation.localizedCaseInsensitiveContains(searchText) ||
            ride.publisherName.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.cookieBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 搜索栏
                    HStack(spacing: 12) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                            TextField("搜索出发地或目的地", text: $searchText)
                                .autocorrectionDisabled()
                        }
                        .padding(10)
                        .background(Color.white)
                        .cornerRadius(10)
                        
                        if !searchText.isEmpty {
                            Button("取消") {
                                searchText = ""
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }
                            .foregroundColor(.cookiePrimary)
                        }
                    }
                    .padding()
                    
                    // 行程列表
                    if filteredRides.isEmpty {
                        ContentUnavailableView(
                            "暂无可用行程",
                            systemImage: "car.side.air.fresh",
                            description: Text("目前没有司机发布的行程\n请稍后再试")
                        )
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(filteredRides) { ride in
                                    NavigationLink(destination: PassengerRideDetailView(ride: ride)) {
                                        PassengerRideCard(ride: ride)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("🎓 乘客找车")
            .navigationBarTitleDisplayMode(.large)
            .alert("提示", isPresented: .constant(dataStore.errorMessage != nil || dataStore.successMessage != nil)) {
                Button("确定") {
                    dataStore.errorMessage = nil
                    dataStore.successMessage = nil
                }
            } message: {
                if let error = dataStore.errorMessage {
                    Text(error)
                } else if let success = dataStore.successMessage {
                    Text(success)
                }
            }
        }
    }
}

// MARK: - Passenger Ride Card
/// 乘客视角的行程卡片
struct PassengerRideCard: View {
    @EnvironmentObject var dataStore: RideDataStore
    @EnvironmentObject var authManager: AuthManager
    
    let ride: AdvancedRide
    
    private var isJoined: Bool {
        guard let currentUserID = authManager.currentUser?.id else { return false }
        return ride.passengers.contains { $0.id == currentUserID }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 顶部：时间和状态
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.cookiePrimary)
                    Text(ride.formattedDepartureTime)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.cookieText)
                }
                
                Spacer()
                
                // 状态标签
                HStack(spacing: 4) {
                    Image(systemName: ride.status.icon)
                        .font(.caption2)
                    Text(ride.statusLabel)
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(statusColor)
                .cornerRadius(8)
            }
            
            Divider()
            
            // 路线信息
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("出发")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(ride.startLocation)
                        .font(.body)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                        .lineLimit(1)
                }
                
                Image(systemName: "arrow.right")
                    .font(.title3)
                    .foregroundColor(.cookiePrimary)
                    .frame(maxWidth: .infinity)
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("到达")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(ride.endLocation)
                        .font(.body)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                        .lineLimit(1)
                }
            }
            
            Divider()
            
            // 关键信息：客单价 + 剩余座位
            HStack(spacing: 20) {
                // 客单价（高亮显示）
                VStack(alignment: .leading, spacing: 4) {
                    Text("客单价")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Image(systemName: "yensign.circle.fill")
                            .foregroundColor(.orange)
                        Text(String(format: "%.0f", ride.unitPrice))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    }
                }
                
                Spacer()
                
                // 剩余座位（高亮显示）
                VStack(alignment: .trailing, spacing: 4) {
                    Text("剩余座位")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(ride.isFull ? .gray : .red)
                        Text("\(ride.availableSeats)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(ride.isFull ? .gray : .red)
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(10)
            
            // 司机信息
            HStack(spacing: 8) {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.cookiePrimary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("司机")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(ride.publisherName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.cookieText)
                }
            }
            
            // 行程备注（如果有）
            if !ride.notes.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "note.text")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(ride.notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            // 状态提示
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
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(8)
                    Spacer()
                }
            } else if ride.isFull {
                HStack {
                    Spacer()
                    Text("已满座")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.15))
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
    
    private var statusColor: Color {
        switch ride.status {
        case .pending: return .orange
        case .accepted: return .green
        case .enRoute: return .blue
        case .completed: return .gray
        }
    }
}

// MARK: - Passenger Ride Detail View
/// 乘客视角的行程详情页
struct PassengerRideDetailView: View {
    @EnvironmentObject var dataStore: RideDataStore
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    
    let ride: AdvancedRide
    
    @State private var showJoinAlert = false
    @State private var showCancelAlert = false
    
    private var currentRide: AdvancedRide? {
        dataStore.getRide(by: ride.id)
    }
    
    private var isJoined: Bool {
        guard let currentUserID = authManager.currentUser?.id,
              let ride = currentRide else { return false }
        return ride.passengers.contains { $0.id == currentUserID }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                // 行程状态卡片
                statusCard
                
                // 路线信息
                routeCard
                
                // 价格和座位信息
                priceAndSeatsCard
                
                // 司机信息
                driverInfoCard
                
                // 备注信息
                if !ride.notes.isEmpty {
                    notesCard
                }
                
                // 操作按钮
                actionButtons
                
                Spacer(minLength: 20)
            }
            .padding()
        }
        .background(Color.cookieBackground.ignoresSafeArea())
        .navigationTitle("行程详情")
        .navigationBarTitleDisplayMode(.inline)
        .alert("确认加入行程", isPresented: $showJoinAlert) {
            Button("取消", role: .cancel) { }
            Button("确认加入", role: .destructive) {
                handleJoinRide()
            }
        } message: {
            Text("确定要加入此行程吗？加入后将为您预留座位。")
        }
        .alert("确认取消", isPresented: $showCancelAlert) {
            Button("不取消", role: .cancel) { }
            Button("确认取消", role: .destructive) {
                handleCancelJoin()
            }
        } message: {
            Text("确定要取消此行程吗？")
        }
    }
    
    // MARK: - Subviews
    
    private var statusCard: some View {
        HStack(spacing: 16) {
            Image(systemName: ride.status.icon)
                .font(.system(size: 40))
                .foregroundColor(.cookiePrimary)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("行程状态")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(ride.statusLabel)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.cookieText)
            }
            
            Spacer()
            
            Text(ride.formattedDepartureTime)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 5)
    }
    
    private var routeCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "map.fill")
                    .foregroundColor(.cookiePrimary)
                Text("行程路线")
                    .font(.headline)
                    .foregroundColor(.cookieText)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "location.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("出发地")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(ride.startLocation)
                            .font(.body)
                            .fontWeight(.semibold)
                    }
                }
                
                Divider().padding(.leading, 35)
                
                HStack(spacing: 12) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("目的地")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(ride.endLocation)
                            .font(.body)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 5)
    }
    
    private var priceAndSeatsCard: some View {
        HStack(spacing: 20) {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "yensign.circle.fill")
                        .font(.title2)
                        .foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("客单价")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "¥%.0f", ride.unitPrice))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
            
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "person.2.fill")
                        .font(.title2)
                        .foregroundColor(ride.isFull ? .gray : .red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("剩余座位")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(ride.availableSeats)/\(ride.totalCapacity)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(ride.isFull ? .gray : .red)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background((ride.isFull ? Color.gray : Color.red).opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    private var driverInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.cookiePrimary)
                Text("司机信息")
                    .font(.headline)
                    .foregroundColor(.cookieText)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("姓名：")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(ride.publisherName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("电话：")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(ride.publisherPhone)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 5)
    }
    
    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "note.text")
                    .foregroundColor(.cookiePrimary)
                Text("行程备注")
                    .font(.headline)
                    .foregroundColor(.cookieText)
                Spacer()
            }
            
            Text(ride.notes)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.1), radius: 5)
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            if let currentRide = currentRide {
                if currentRide.status == .accepted || currentRide.status == .enRoute {
                    // 如果行程已接单，显示查看位置按钮
                    NavigationLink(destination: RideTrackingView(ride: currentRide, viewerRole: .passenger)) {
                        HStack {
                            Spacer()
                            Image(systemName: "location.fill")
                                .font(.title3)
                            Text("查看司机位置")
                                .font(.headline)
                                .fontWeight(.bold)
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                }
                
                if isJoined {
                    Button {
                        showCancelAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                            Text("取消行程")
                                .font(.headline)
                                .fontWeight(.bold)
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 16)
                        .background(Color.orange)
                        .cornerRadius(12)
                    }
                } else if currentRide.canJoin {
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
                                colors: [.green, .green.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                } else {
                    Button { } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "xmark.circle")
                                .font(.title3)
                            Text(currentRide.isFull ? "已满座" : "无法加入")
                                .font(.headline)
                                .fontWeight(.bold)
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 16)
                        .background(Color.gray)
                        .cornerRadius(12)
                    }
                    .disabled(true)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func handleJoinRide() {
        guard let user = authManager.currentUser else {
            dataStore.errorMessage = "请先登录"
            return
        }
        
        dataStore.joinRide(
            ride: ride,
            passengerID: user.id ?? "",
            passengerName: user.name,
            passengerPhone: user.phone
        )
    }
    
    private func handleCancelJoin() {
        guard let user = authManager.currentUser else {
            dataStore.errorMessage = "请先登录"
            return
        }
        
        dataStore.cancelJoin(ride: ride, passengerID: user.id ?? "")
    }
}
