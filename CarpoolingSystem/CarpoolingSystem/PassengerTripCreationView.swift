//
//  PassengerTripCreationView.swift
//  CarpoolingSystem - Passenger Trip Creation
//
//  Created on 2025-12-07
//  乘客端发布行程表单
//

import SwiftUI
import MapKit

// MARK: - Trip Creation View
/// 乘客发布行程表单
struct PassengerTripCreationView: View {
    
    @StateObject private var viewModel: RefactoredPassengerViewModel
    @Environment(\.dismiss) var dismiss
    
    // MARK: - Form Fields
    
    @State private var startLocation: String = ""
    @State private var endLocation: String = ""
    @State private var departureDate: Date = Date().addingTimeInterval(3600)
    @State private var numberOfPassengers: Int = 1
    @State private var pricePerPerson: String = ""
    @State private var notes: String = ""
    
    // 坐标（可以通过地图选择或地理编码获取）
    @State private var startCoordinate: Coordinate = Coordinate(latitude: 22.2015, longitude: 113.5495)
    @State private var endCoordinate: Coordinate = Coordinate(latitude: 22.1560, longitude: 113.5920)
    
    @State private var showingAlert: Bool = false
    @State private var alertMessage: String = ""
    
    init(userID: String, userName: String, userPhone: String) {
        _viewModel = StateObject(wrappedValue: RefactoredPassengerViewModel(
            userID: userID,
            userName: userName,
            userPhone: userPhone
        ))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景色
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 标题卡片
                        headerCard
                        
                        // 表单
                        formSection
                        
                        // 费用预览
                        costPreviewCard
                        
                        // 提交按钮
                        submitButton
                    }
                    .padding()
                }
            }
            .navigationTitle("📝 发布行程")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .alert("提示", isPresented: $showingAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .overlay(alignment: .top) {
                if let message = viewModel.successMessage {
                    SuccessToast(message: message)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                viewModel.successMessage = nil
                                // 发布成功后关闭页面
                                dismiss()
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
    
    // MARK: - Header Card
    
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "car.circle.fill")
                    .font(.title)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("发布拼车需求")
                        .font(.headline)
                    
                    Text("填写您的出行信息，等待司机接单")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - Form Section
    
    private var formSection: some View {
        VStack(spacing: 16) {
            // 起点
            VStack(alignment: .leading, spacing: 8) {
                Label("起点", systemImage: "location.circle.fill")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                TextField("请输入起点地址", text: $startLocation)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
            }
            
            // 终点
            VStack(alignment: .leading, spacing: 8) {
                Label("终点", systemImage: "mappin.circle.fill")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                TextField("请输入终点地址", text: $endLocation)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
            }
            
            Divider()
            
            // 出发时间
            VStack(alignment: .leading, spacing: 8) {
                Label("出发时间", systemImage: "clock.fill")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                DatePicker(
                    "",
                    selection: $departureDate,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.automatic)
            }
            
            Divider()
            
            // 人数
            VStack(alignment: .leading, spacing: 8) {
                Label("乘客人数", systemImage: "person.3.fill")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Stepper(value: $numberOfPassengers, in: 1...10) {
                    Text("\(numberOfPassengers) 人")
                        .font(.headline)
                }
            }
            
            // 单人费用
            VStack(alignment: .leading, spacing: 8) {
                Label("单人费用", systemImage: "dollarsign.circle.fill")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                HStack {
                    Text("¥")
                        .foregroundColor(.gray)
                    
                    TextField("0.00", text: $pricePerPerson)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
            
            Divider()
            
            // 备注
            VStack(alignment: .leading, spacing: 8) {
                Label("备注信息（可选）", systemImage: "note.text")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                TextEditor(text: $notes)
                    .frame(height: 100)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - Cost Preview Card
    
    private var costPreviewCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("费用预览")
                    .font(.headline)
                
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("单人费用")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("¥\(pricePerPerson.isEmpty ? "0.00" : pricePerPerson)")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                Image(systemName: "multiply")
                    .foregroundColor(.gray)
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("人数")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("\(numberOfPassengers)")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                Image(systemName: "equal")
                    .foregroundColor(.gray)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("总费用")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text("¥\(calculateTotalCost())")
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
    
    // MARK: - Submit Button
    
    private var submitButton: some View {
        Button(action: {
            Task {
                await submitTrip()
            }
        }) {
            HStack {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "checkmark.circle.fill")
                    Text("确认发布")
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                isFormValid() ? Color.blue : Color.gray
            )
            .foregroundColor(.white)
            .cornerRadius(12)
            .shadow(radius: isFormValid() ? 5 : 0)
        }
        .disabled(!isFormValid() || viewModel.isLoading)
    }
    
    // MARK: - Helper Methods
    
    private func isFormValid() -> Bool {
        return !startLocation.isEmpty &&
               !endLocation.isEmpty &&
               !pricePerPerson.isEmpty &&
               Double(pricePerPerson) != nil &&
               Double(pricePerPerson)! > 0 &&
               numberOfPassengers > 0 &&
               departureDate > Date()
    }
    
    private func calculateTotalCost() -> String {
        guard let price = Double(pricePerPerson) else {
            return "0.00"
        }
        
        let total = price * Double(numberOfPassengers)
        return String(format: "%.2f", total)
    }
    
    private func submitTrip() async {
        // 验证表单
        guard isFormValid() else {
            alertMessage = "请填写完整信息"
            showingAlert = true
            return
        }
        
        guard let price = Double(pricePerPerson) else {
            alertMessage = "价格格式错误"
            showingAlert = true
            return
        }
        
        // 发布行程
        await viewModel.publishTrip(
            startLocation: startLocation,
            startCoordinate: startCoordinate,
            endLocation: endLocation,
            endCoordinate: endCoordinate,
            departureTime: departureDate,
            numberOfPassengers: numberOfPassengers,
            pricePerPerson: price,
            notes: notes
        )
    }
}

// MARK: - Preview
#if DEBUG
struct PassengerTripCreationView_Previews: PreviewProvider {
    static var previews: some View {
        PassengerTripCreationView(
            userID: "preview_user",
            userName: "测试用户",
            userPhone: "+853 6666 6666"
        )
    }
}
#endif
