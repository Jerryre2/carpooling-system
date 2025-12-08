//
//  TripCreationView.swift
//  CarpoolingSystem - Trip Creation Form
//
//  Created on 2025-12-07
//  乘客发布行程表单
//

import SwiftUI
import MapKit

// MARK: - Trip Creation View
/// 🎯 核心交付物：乘客发布行程表单
struct TripCreationView: View {
    
    @ObservedObject var viewModel: FinalPassengerViewModel
    @Environment(\.dismiss) var dismiss
    
    // MARK: - Form State
    @State private var startLocation: String = ""
    @State private var endLocation: String = ""
    @State private var departureDate: Date = Date().addingTimeInterval(3600)
    @State private var numberOfPassengers: Int = 1
    @State private var pricePerPerson: String = "30"
    @State private var notes: String = ""
    
    // 临时坐标（实际应用中应该从地图选择）
    @State private var startCoordinate: Coordinate = Coordinate(latitude: 22.2015, longitude: 113.5495)
    @State private var endCoordinate: Coordinate = Coordinate(latitude: 22.1560, longitude: 113.5920)
    
    // UI State
    @State private var showingConfirmation: Bool = false
    
    var body: some View {
        NavigationView {
            Form {
                // 基本信息
                basicInfoSection
                
                // 乘客人数
                passengersSection
                
                // 费用设置
                priceSection
                
                // 备注
                notesSection
                
                // 预览
                previewSection
            }
            .navigationTitle("发布行程")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("发布") {
                        showingConfirmation = true
                    }
                    .disabled(!isFormValid)
                }
            }
            .alert("确认发布", isPresented: $showingConfirmation) {
                Button("取消", role: .cancel) { }
                Button("确认发布") {
                    publishTrip()
                }
            } message: {
                Text("确认发布此行程吗？总费用：¥\(calculatedTotalCost)")
            }
        }
    }
    
    // MARK: - Basic Info Section
    
    private var basicInfoSection: some View {
        Section(header: Text("行程信息")) {
            // 起点
            HStack {
                Image(systemName: "location.circle.fill")
                    .foregroundColor(.green)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("起点")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    TextField("请输入起点", text: $startLocation)
                }
            }
            
            // 终点
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.red)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("终点")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    TextField("请输入终点", text: $endLocation)
                }
            }
            
            // 出发时间
            DatePicker(
                "出发时间",
                selection: $departureDate,
                in: Date()...,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.compact)
        }
    }
    
    // MARK: - Passengers Section
    
    private var passengersSection: some View {
        Section(header: Text("乘客人数")) {
            Stepper("共 \(numberOfPassengers) 人", value: $numberOfPassengers, in: 1...4)
            
            Text("最多支持 4 人拼车")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
    
    // MARK: - Price Section
    
    private var priceSection: some View {
        Section(header: Text("费用设置"), footer: Text("总费用：¥\(calculatedTotalCost)")) {
            HStack {
                Text("单人费用")
                
                Spacer()
                
                TextField("单价", text: $pricePerPerson)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                
                Text("¥/人")
                    .foregroundColor(.gray)
            }
            
            if numberOfPassengers > 1 {
                HStack {
                    Text("人数")
                    Spacer()
                    Text("× \(numberOfPassengers)")
                        .foregroundColor(.gray)
                }
                
                HStack {
                    Text("总费用")
                        .fontWeight(.semibold)
                    Spacer()
                    Text("¥\(calculatedTotalCost)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            }
        }
    }
    
    // MARK: - Notes Section
    
    private var notesSection: some View {
        Section(header: Text("备注（可选）")) {
            TextEditor(text: $notes)
                .frame(height: 100)
        }
    }
    
    // MARK: - Preview Section
    
    private var previewSection: some View {
        Section(header: Text("行程预览")) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "arrow.right")
                        .foregroundColor(.blue)
                    Text("\(startLocation) → \(endLocation)")
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.orange)
                    Text(formattedDepartureTime)
                }
                
                HStack {
                    Image(systemName: "person.3.fill")
                        .foregroundColor(.blue)
                    Text("\(numberOfPassengers) 人")
                }
                
                HStack {
                    Image(systemName: "dollarsign.circle.fill")
                        .foregroundColor(.green)
                    Text("总费用 ¥\(calculatedTotalCost)")
                        .fontWeight(.bold)
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Computed Properties
    
    private var calculatedTotalCost: String {
        let price = Double(pricePerPerson) ?? 0
        let total = price * Double(numberOfPassengers)
        return String(format: "%.2f", total)
    }
    
    private var formattedDepartureTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM月dd日 HH:mm"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: departureDate)
    }
    
    private var isFormValid: Bool {
        return !startLocation.isEmpty &&
               !endLocation.isEmpty &&
               numberOfPassengers > 0 &&
               (Double(pricePerPerson) ?? 0) > 0
    }
    
    // MARK: - Actions
    
    private func publishTrip() {
        Task {
            let price = Double(pricePerPerson) ?? 0
            
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
            
            if viewModel.successMessage != nil {
                dismiss()
            }
        }
    }
}

// MARK: - Preview
#if DEBUG
struct TripCreationView_Previews: PreviewProvider {
    static var previews: some View {
        TripCreationView(viewModel: FinalPassengerViewModel.preview)
    }
}
#endif
