//
//  DriverCarpoolHallView.swift
//  CarpoolingSystem - Driver Carpool Hall
//
//  Created on 2025-12-07
//  司机端拼车大厅：浏览乘客发布的订单并接单
//

import SwiftUI
import CoreLocation

// MARK: - Driver Carpool Hall View
/// 司机端拼车大厅（商业级 SwiftUI 实现）
struct DriverCarpoolHallView: View {
    
    @StateObject private var viewModel: DriverViewModel
    @State private var searchText: String = ""
    @State private var showFilterSheet: Bool = false
    @State private var showSortOptions: Bool = false
    @State private var selectedTrip: TripRequest?
    
    init(driverID: String, driverName: String, driverPhone: String) {
        _viewModel = StateObject(wrappedValue: DriverViewModel(
            driverID: driverID,
            driverName: driverName,
            driverPhone: driverPhone
        ))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景色
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 搜索栏
                    searchBar
                    
                    // 筛选和排序工具栏
                    filterToolbar
                    
                    // 行程列表
                    if viewModel.isLoading && viewModel.filteredTrips.isEmpty {
                        loadingView
                    } else if viewModel.filteredTrips.isEmpty {
                        emptyView
                    } else {
                        tripsList
                    }
                }
            }
            .navigationTitle("🚗 拼车大厅")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    refreshButton
                }
            }
            .sheet(isPresented: $showFilterSheet) {
                FilterSheetView(viewModel: viewModel)
            }
            .sheet(item: $selectedTrip) { trip in
                TripDetailSheet(trip: trip, viewModel: viewModel)
            }
            .alert(item: $viewModel.errorAlert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    primaryButton: .default(Text("重试")) {
                        alert.retryAction?()
                    },
                    secondaryButton: .cancel()
                )
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
        .onAppear {
            viewModel.startListening()
        }
        .onDisappear {
            viewModel.stopListening()
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("搜索起点、终点或乘客姓名", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .onChange(of: searchText) { newValue in
                    viewModel.searchTrips(keyword: newValue)
                }
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    viewModel.applyFilters()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    // MARK: - Filter Toolbar
    
    private var filterToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // 筛选按钮
                Button(action: {
                    showFilterSheet = true
                }) {
                    HStack {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        Text("筛选")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(20)
                }
                
                // 排序选项
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button(action: {
                        viewModel.sortOption = option
                    }) {
                        HStack {
                            Image(systemName: option.icon)
                            Text(option.displayName)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            viewModel.sortOption == option ?
                            Color.blue : Color(.systemGray6)
                        )
                        .foregroundColor(
                            viewModel.sortOption == option ?
                            .white : .primary
                        )
                        .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Trips List
    
    private var tripsList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.filteredTrips) { trip in
                    TripCardView(trip: trip, viewModel: viewModel)
                        .onTapGesture {
                            selectedTrip = trip
                        }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("正在加载订单...")
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty View
    
    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "car.circle")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            Text("暂无可接订单")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("稍后再来看看吧")
                .foregroundColor(.gray)
            
            Button(action: {
                Task {
                    await viewModel.refresh()
                }
            }) {
                Text("刷新")
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Refresh Button
    
    private var refreshButton: some View {
        Button(action: {
            Task {
                await viewModel.refresh()
            }
        }) {
            Image(systemName: "arrow.clockwise")
        }
    }
}

// MARK: - Trip Card View
/// 订单卡片视图
struct TripCardView: View {
    let trip: TripRequest
    @ObservedObject var viewModel: DriverViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部：乘客信息和预期收入
            HStack(alignment: .top) {
                // 乘客信息
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.blue)
                        
                        Text(trip.passengerName)
                            .font(.headline)
                    }
                    
                    HStack {
                        Image(systemName: "person.3.fill")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text("\(trip.numberOfPassengers) 人")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                // 🎯 预期收入（核心交付物）
                VStack(alignment: .trailing, spacing: 4) {
                    Text("预期收入")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("¥\(String(format: "%.2f", trip.expectedIncome))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            }
            .padding()
            
            Divider()
            
            // 中部：路线信息
            VStack(spacing: 12) {
                // 起点
                HStack {
                    Image(systemName: "location.circle.fill")
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("起点")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text(trip.startLocation)
                            .font(.body)
                    }
                    
                    Spacer()
                    
                    if let distance = viewModel.calculateDistance(to: trip) {
                        Text(viewModel.formatDistance(distance))
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                // 终点
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.red)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("终点")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text(trip.endLocation)
                            .font(.body)
                    }
                    
                    Spacer()
                }
                
                // 出发时间
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("出发时间")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text(trip.formattedDepartureTime)
                            .font(.body)
                    }
                    
                    Spacer()
                    
                    // 倒计时
                    if trip.minutesUntilDeparture > 0 {
                        Text("\(trip.minutesUntilDeparture)分钟后")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding()
            
            Divider()
            
            // 底部：备注和接单按钮
            HStack {
                if !trip.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("备注")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text(trip.notes)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                // 🎯 立即接单按钮（核心交付物）
                Button(action: {
                    Task {
                        await viewModel.acceptTrip(trip)
                    }
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("立即接单")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(viewModel.isLoading)
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Filter Sheet View
/// 筛选条件弹窗
struct FilterSheetView: View {
    @ObservedObject var viewModel: DriverViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedDate: Date = Date()
    @State private var useTimeFilter: Bool = false
    @State private var maxPrice: Double = 100
    @State private var usePriceFilter: Bool = false
    
    var body: some View {
        NavigationView {
            Form {
                // 时间筛选
                Section(header: Text("出发时间（±10分钟窗口）")) {
                    Toggle("启用时间筛选", isOn: $useTimeFilter)
                    
                    if useTimeFilter {
                        DatePicker(
                            "目标时间",
                            selection: $selectedDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }
                
                // 价格筛选
                Section(header: Text("价格筛选")) {
                    Toggle("启用价格筛选", isOn: $usePriceFilter)
                    
                    if usePriceFilter {
                        VStack(alignment: .leading) {
                            Text("最高单价: ¥\(Int(maxPrice))")
                            Slider(value: $maxPrice, in: 10...200, step: 5)
                        }
                    }
                }
                
                // 清空按钮
                Section {
                    Button(action: {
                        viewModel.clearFilters()
                        useTimeFilter = false
                        usePriceFilter = false
                        dismiss()
                    }) {
                        Text("清空筛选")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("筛选条件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("应用") {
                        applyFilters()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func applyFilters() {
        if useTimeFilter {
            viewModel.searchFilter.departureTime = selectedDate
        } else {
            viewModel.searchFilter.departureTime = nil
        }
        
        if usePriceFilter {
            viewModel.searchFilter.maxPricePerPerson = maxPrice
        } else {
            viewModel.searchFilter.maxPricePerPerson = nil
        }
        
        viewModel.applyFilters()
    }
}

// MARK: - Trip Detail Sheet
/// 行程详情弹窗
struct TripDetailSheet: View {
    let trip: TripRequest
    @ObservedObject var viewModel: DriverViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 乘客信息卡片
                    passengerInfoCard
                    
                    // 路线信息卡片
                    routeInfoCard
                    
                    // 费用信息卡片
                    priceInfoCard
                    
                    // 接单按钮
                    acceptButton
                }
                .padding()
            }
            .navigationTitle("订单详情")
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
    
    private var passengerInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("乘客信息")
                .font(.headline)
            
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.title)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.passengerName)
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text(trip.passengerPhone)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            
            HStack {
                Image(systemName: "person.3.fill")
                    .foregroundColor(.blue)
                
                Text("共 \(trip.numberOfPassengers) 人")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var routeInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("路线信息")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 16) {
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
        .shadow(radius: 2)
    }
    
    private var priceInfoCard: some View {
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
                    Text("预期收入")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("¥\(String(format: "%.2f", trip.expectedIncome))")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var acceptButton: some View {
        Button(action: {
            Task {
                await viewModel.acceptTrip(trip)
                dismiss()
            }
        }) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text("立即接单")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(viewModel.isLoading)
    }
}

// ⚠️ SuccessToast 已移除 - 使用 SharedComponents.swift 中的定义

// MARK: - Preview
#if DEBUG
struct DriverCarpoolHallView_Previews: PreviewProvider {
    static var previews: some View {
        DriverCarpoolHallView(
            driverID: "driver_preview",
            driverName: "测试司机",
            driverPhone: "+853 8888 8888"
        )
    }
}
#endif
