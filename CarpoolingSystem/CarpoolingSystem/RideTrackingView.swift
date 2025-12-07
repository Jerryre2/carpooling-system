//
//  RideTrackingView.swift
//  Advanced Ride-Sharing System
//
//  Created on 2025-12-07
//

import SwiftUI
import MapKit

// MARK: - Viewer Role
enum ViewerRole {
    case passenger  // 乘客视角：查看司机位置
    case driver     // 司机视角：查看乘客位置
}

// MARK: - Ride Tracking View
/// 实时位置追踪视图
struct RideTrackingView: View {
    @EnvironmentObject var dataStore: RideDataStore
    @Environment(\.dismiss) var dismiss
    
    let ride: AdvancedRide
    let viewerRole: ViewerRole
    
    @State private var region: MKCoordinateRegion
    @State private var estimatedMinutes: Int = 0
    
    init(ride: AdvancedRide, viewerRole: ViewerRole) {
        self.ride = ride
        self.viewerRole = viewerRole
        
        // 设置初始地图区域
        let initialLocation: CLLocationCoordinate2D
        if let driverLocation = ride.driverCurrentLocation {
            initialLocation = CLLocationCoordinate2D(
                latitude: driverLocation.latitude,
                longitude: driverLocation.longitude
            )
        } else {
            // 默认位置（澳门）
            initialLocation = CLLocationCoordinate2D(latitude: 22.1987, longitude: 113.5439)
        }
        
        _region = State(initialValue: MKCoordinateRegion(
            center: initialLocation,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        ))
    }
    
    var body: some View {
        ZStack {
            // 地图视图
            Map(coordinateRegion: $region, annotationItems: annotationItems) { item in
                MapAnnotation(coordinate: item.coordinate) {
                    VStack(spacing: 4) {
                        Image(systemName: item.icon)
                            .font(.title)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Circle().fill(item.color))
                            .shadow(radius: 5)
                        
                        Text(item.title)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .padding(4)
                            .background(
                                Capsule()
                                    .fill(Color.white)
                                    .shadow(radius: 2)
                            )
                    }
                }
            }
            .edgesIgnoringSafeArea(.all)
            
            // 顶部信息卡片
            VStack {
                infoCard
                Spacer()
            }
            .padding()
        }
        .navigationTitle("实时追踪")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            calculateETA()
        }
    }
    
    // MARK: - Subviews
    
    private var infoCard: some View {
        VStack(spacing: 16) {
            // 行程信息
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(ride.startLocation)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Image(systemName: "arrow.down")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(ride.endLocation)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("状态")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Image(systemName: ride.status.icon)
                            .font(.caption)
                        Text(ride.statusLabel)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.green)
                }
            }
            
            Divider()
            
            // ETA 信息（仅乘客视角）
            if viewerRole == .passenger {
                HStack {
                    Image(systemName: "timer")
                        .foregroundColor(.blue)
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("预计到达时间")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("约 \(estimatedMinutes) 分钟")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                    Spacer()
                }
            }
            
            // 司机/乘客数量信息
            if viewerRole == .driver {
                HStack {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(.orange)
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("当前乘客")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(ride.passengers.count) 人")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    }
                    Spacer()
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: .gray.opacity(0.3), radius: 10, x: 0, y: 5)
        )
    }
    
    // MARK: - Map Annotations
    
    private var annotationItems: [MapAnnotationItem] {
        var items: [MapAnnotationItem] = []
        
        // 添加司机位置（如果有）
        if let driverLocation = ride.driverCurrentLocation {
            items.append(MapAnnotationItem(
                id: "driver",
                coordinate: CLLocationCoordinate2D(
                    latitude: driverLocation.latitude,
                    longitude: driverLocation.longitude
                ),
                title: viewerRole == .passenger ? "司机位置" : "我的位置",
                icon: "car.fill",
                color: .blue
            ))
        }
        
        // 添加乘客位置（司机视角）
        if viewerRole == .driver {
            for (index, passenger) in ride.passengers.enumerated() {
                if let location = dataStore.getPassengerLocation(passengerID: passenger.id) {
                    items.append(MapAnnotationItem(
                        id: passenger.id,
                        coordinate: CLLocationCoordinate2D(
                            latitude: location.latitude,
                            longitude: location.longitude
                        ),
                        title: passenger.name,
                        icon: "person.fill",
                        color: .orange
                    ))
                }
            }
        }
        
        // 添加目的地位置
        if let destination = ride.destinationLocation {
            items.append(MapAnnotationItem(
                id: "destination",
                coordinate: CLLocationCoordinate2D(
                    latitude: destination.latitude,
                    longitude: destination.longitude
                ),
                title: "目的地",
                icon: "mappin.circle.fill",
                color: .red
            ))
        }
        
        return items
    }
    
    // MARK: - Helper Methods
    
    private func calculateETA() {
        guard let driverLocation = ride.driverCurrentLocation,
              let destination = ride.destinationLocation else {
            estimatedMinutes = 0
            return
        }
        
        estimatedMinutes = dataStore.calculateETA(
            driverLocation: driverLocation,
            destinationLocation: destination
        )
    }
}

// MARK: - Map Annotation Item
struct MapAnnotationItem: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let title: String
    let icon: String
    let color: Color
}

// MARK: - Preview
#Preview {
    let demoRide = AdvancedRide(
        rideType: .driverOffer(totalFare: 100),
        publisherID: "demo-driver",
        publisherName: "张司机",
        publisherPhone: "+853 6666 8888",
        startLocation: "横琴口岸",
        endLocation: "澳门科技大学",
        departureTime: Date().addingTimeInterval(3600),
        totalCapacity: 4,
        status: .accepted,
        driverCurrentLocation: (latitude: 22.1987, longitude: 113.5439),
        destinationLocation: (latitude: 22.1544, longitude: 113.5597)
    )
    
    return NavigationStack {
        RideTrackingView(ride: demoRide, viewerRole: .passenger)
            .environmentObject(RideDataStore())
    }
}
