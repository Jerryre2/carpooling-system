import SwiftUI
import MapKit
import Combine

// MARK: - 1. Data Model Architecture

/// Ride status enumeration
enum RideStatus: String, Codable, CaseIterable {
    case pending = "pending"           // Awaiting Acceptance/Join
    case accepted = "accepted"         // Accepted/Confirmed, Tracking begins
    case enRoute = "enRoute"          // En route to pickup passengers
    case completed = "completed"       // Completed

    var displayName: String {
        switch self {
        case .pending: return "Awaiting"
        case .accepted: return "Confirmed"
        case .enRoute: return "En Route"
        case .completed: return "Completed"
        }
    }

    var color: Color {
        switch self {
        case .pending: return .orange
        case .accepted: return .blue
        case .enRoute: return .green
        case .completed: return .gray
        }
    }
}

/// Ride type enumeration with associated values
enum RideType: Codable, Equatable {
    case driverOffer(totalFare: Double)                    // Driver fixed price
    case studentRequest(maxPassengers: Int, unitFare: Double)  // Student request

    enum CodingKeys: String, CodingKey {
        case type, totalFare, maxPassengers, unitFare
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "driverOffer":
            let totalFare = try container.decode(Double.self, forKey: .totalFare)
            self = .driverOffer(totalFare: totalFare)
        case "studentRequest":
            let maxPassengers = try container.decode(Int.self, forKey: .maxPassengers)
            let unitFare = try container.decode(Double.self, forKey: .unitFare)
            self = .studentRequest(maxPassengers: maxPassengers, unitFare: unitFare)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Invalid ride type")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .driverOffer(let totalFare):
            try container.encode("driverOffer", forKey: .type)
            try container.encode(totalFare, forKey: .totalFare)
        case .studentRequest(let maxPassengers, let unitFare):
            try container.encode("studentRequest", forKey: .type)
            try container.encode(maxPassengers, forKey: .maxPassengers)
            try container.encode(unitFare, forKey: .unitFare)
        }
    }
}

/// User role enumeration
enum UserRole: String, Codable, CaseIterable {
    case driver = "Driver"
    case passenger = "Passenger"
}

/// Location coordinate structure
struct LocationCoordinate: Codable, Equatable {
    var latitude: Double
    var longitude: Double

    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    init(from coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }

    // Calculate distance in meters
    func distance(to other: LocationCoordinate) -> Double {
        let location1 = CLLocation(latitude: latitude, longitude: longitude)
        let location2 = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return location1.distance(from: location2)
    }
}

/// Passenger information
struct Passenger: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var currentLocation: LocationCoordinate?
    var joinedAt: Date
}

/// Main Ride structure
struct Ride: Identifiable, Codable {
    var id: UUID
    var publisherID: String          // Current publisher (may change when driver accepts)
    var publisherName: String
    var role: UserRole               // Publisher role
    var rideType: RideType          // Polymorphic type

    // Route information
    var startLocation: String
    var endLocation: String
    var startCoordinate: LocationCoordinate
    var endCoordinate: LocationCoordinate
    var departureTime: Date

    // Status tracking
    var status: RideStatus
    var totalCapacity: Int
    var availableSeats: Int
    var passengers: [Passenger]

    // Real-time location tracking
    var driverCurrentLocation: LocationCoordinate?

    // Metadata
    var createdAt: Date
    var notes: String?

    // MARK: - Computed Properties

    /// Unit price for passengers
    var unitPrice: Double {
        switch rideType {
        case .driverOffer(let totalFare):
            return totalFare / Double(totalCapacity)
        case .studentRequest(_, let unitFare):
            return unitFare
        }
    }

    /// Estimated revenue for driver
    var estimatedRevenue: Double {
        switch rideType {
        case .driverOffer(let totalFare):
            return totalFare
        case .studentRequest(_, let unitFare):
            let currentPassengers = totalCapacity - availableSeats
            return unitFare * Double(currentPassengers)
        }
    }

    /// Total fare display
    var totalFare: Double {
        switch rideType {
        case .driverOffer(let totalFare):
            return totalFare
        case .studentRequest(let maxPassengers, let unitFare):
            return unitFare * Double(maxPassengers)
        }
    }

    /// Current passenger count
    var currentPassengerCount: Int {
        totalCapacity - availableSeats
    }

    /// Formatted departure time
    var formattedDepartureTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, HH:mm"
        return formatter.string(from: departureTime)
    }

    /// Check if user has joined
    func hasUserJoined(userID: String) -> Bool {
        passengers.contains { $0.id == userID }
    }
}

// MARK: - 2. State Management (RideDataStore)

class RideDataStore: ObservableObject {
    @Published var rides: [Ride] = []
    @Published var currentUserID: String = "user_123"
    @Published var currentUserName: String = "John Doe"

    // Location update timer
    private var locationTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    init() {
        loadSampleData()
        startLocationSimulation()
    }

    // MARK: - Search Rides

    /// Search rides based on user role
    /// - Parameters:
    ///   - userRole: Driver or Passenger
    ///   - startLocation: Optional filter by start location
    ///   - endLocation: Optional filter by end location
    /// - Returns: Filtered rides array
    func searchRides(
        userRole: UserRole,
        startLocation: String? = nil,
        endLocation: String? = nil
    ) -> [Ride] {
        var filtered = rides.filter { ride in
            // Role-based filtering
            switch userRole {
            case .passenger:
                // Passengers only see driver offers
                if case .driverOffer = ride.rideType {
                    return ride.status == .pending || ride.status == .accepted
                }
                return false
            case .driver:
                // Drivers only see student requests
                if case .studentRequest = ride.rideType {
                    return ride.status == .pending
                }
                return false
            }
        }

        // Location filters
        if let start = startLocation {
            filtered = filtered.filter { $0.startLocation.localizedCaseInsensitiveContains(start) }
        }

        if let end = endLocation {
            filtered = filtered.filter { $0.endLocation.localizedCaseInsensitiveContains(end) }
        }

        return filtered.sorted { $0.departureTime < $1.departureTime }
    }

    // MARK: - Passenger Join

    /// Passenger joins a ride
    /// - Parameters:
    ///   - rideID: Ride identifier
    ///   - passengerID: Passenger identifier
    ///   - passengerName: Passenger name
    /// - Returns: Success or error message
    func joinRide(rideID: UUID, passengerID: String, passengerName: String) -> Result<Void, String> {
        guard let index = rides.firstIndex(where: { $0.id == rideID }) else {
            return .failure("Ride not found")
        }

        var ride = rides[index]

        // Pre-checks
        guard case .driverOffer = ride.rideType else {
            return .failure("Can only join driver-posted rides")
        }

        guard ride.availableSeats > 0 else {
            return .failure("No available seats")
        }

        guard !ride.hasUserJoined(userID: passengerID) else {
            return .failure("You have already joined this ride")
        }

        // Join logic
        ride.availableSeats -= 1
        let passenger = Passenger(
            id: passengerID,
            name: passengerName,
            currentLocation: getPassengerLocation(passengerID: passengerID),
            joinedAt: Date()
        )
        ride.passengers.append(passenger)

        // Update status if full
        if ride.availableSeats == 0 {
            ride.status = .accepted
        }

        rides[index] = ride
        return .success(())
    }

    // MARK: - Driver Acceptance

    /// Driver accepts a student request
    /// - Parameters:
    ///   - rideID: Ride identifier
    ///   - driverID: Driver identifier
    ///   - driverName: Driver name
    /// - Returns: Success or error message
    func acceptRequest(rideID: UUID, driverID: String, driverName: String) -> Result<Void, String> {
        guard let index = rides.firstIndex(where: { $0.id == rideID }) else {
            return .failure("Ride not found")
        }

        var ride = rides[index]

        // Pre-checks
        guard case .studentRequest = ride.rideType else {
            return .failure("Can only accept student-posted requests")
        }

        guard ride.status == .pending else {
            return .failure("Ride has already been accepted")
        }

        // Acceptance logic
        ride.publisherID = driverID
        ride.publisherName = driverName
        ride.status = .accepted
        ride.role = .driver

        // Initialize driver location (simulated)
        ride.driverCurrentLocation = LocationCoordinate(
            latitude: ride.startCoordinate.latitude + Double.random(in: -0.01...0.01),
            longitude: ride.startCoordinate.longitude + Double.random(in: -0.01...0.01)
        )

        rides[index] = ride
        return .success(())
    }

    // MARK: - Location Simulation

    /// Update driver's real-time location
    func updateDriverLocation(rideID: UUID, location: LocationCoordinate) {
        guard let index = rides.firstIndex(where: { $0.id == rideID }) else { return }
        rides[index].driverCurrentLocation = location
    }

    /// Simulate getting passenger's location
    func getPassengerLocation(passengerID: String) -> LocationCoordinate {
        // In real app, this would fetch from GPS/API
        // For demo, return random location near start
        return LocationCoordinate(
            latitude: 37.7749 + Double.random(in: -0.02...0.02),
            longitude: -122.4194 + Double.random(in: -0.02...0.02)
        )
    }

    /// Calculate ETA in minutes
    func calculateETA(driverLocation: LocationCoordinate, destinationLocation: LocationCoordinate) -> Int {
        let distance = driverLocation.distance(to: destinationLocation)
        // Assume average speed of 40 km/h = 666.67 m/min
        let minutes = Int(distance / 666.67)
        return max(1, minutes) // At least 1 minute
    }

    /// Start real-time location simulation
    private func startLocationSimulation() {
        locationTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.simulateLocationUpdates()
        }
    }

    /// Simulate location updates for active rides
    private func simulateLocationUpdates() {
        for index in rides.indices {
            guard rides[index].status == .accepted || rides[index].status == .enRoute else { continue }
            guard var currentLocation = rides[index].driverCurrentLocation else { continue }

            let destination = rides[index].startCoordinate

            // Move driver closer to destination
            let latDiff = destination.latitude - currentLocation.latitude
            let lonDiff = destination.longitude - currentLocation.longitude

            currentLocation.latitude += latDiff * 0.1
            currentLocation.longitude += lonDiff * 0.1

            rides[index].driverCurrentLocation = currentLocation

            // Check if arrived
            if currentLocation.distance(to: destination) < 100 {
                rides[index].status = .enRoute
            }
        }
    }

    /// Complete a ride
    func completeRide(rideID: UUID) -> Result<Void, String> {
        guard let index = rides.firstIndex(where: { $0.id == rideID }) else {
            return .failure("Ride not found")
        }

        rides[index].status = .completed
        return .success(())
    }

    // MARK: - Sample Data

    private func loadSampleData() {
        let now = Date()

        // Sample 1: Driver Offer
        rides.append(Ride(
            id: UUID(),
            publisherID: "driver_001",
            publisherName: "Alice Smith",
            role: .driver,
            rideType: .driverOffer(totalFare: 50.0),
            startLocation: "Downtown Campus",
            endLocation: "Airport",
            startCoordinate: LocationCoordinate(latitude: 37.7749, longitude: -122.4194),
            endCoordinate: LocationCoordinate(latitude: 37.6213, longitude: -122.3790),
            departureTime: now.addingTimeInterval(3600),
            status: .pending,
            totalCapacity: 4,
            availableSeats: 4,
            passengers: [],
            driverCurrentLocation: nil,
            createdAt: now,
            notes: "Comfortable sedan, AC available"
        ))

        // Sample 2: Driver Offer with some passengers
        rides.append(Ride(
            id: UUID(),
            publisherID: "driver_002",
            publisherName: "Bob Johnson",
            role: .driver,
            rideType: .driverOffer(totalFare: 60.0),
            startLocation: "North Station",
            endLocation: "Tech Park",
            startCoordinate: LocationCoordinate(latitude: 37.7849, longitude: -122.4294),
            endCoordinate: LocationCoordinate(latitude: 37.7949, longitude: -122.3894),
            departureTime: now.addingTimeInterval(7200),
            status: .accepted,
            totalCapacity: 3,
            availableSeats: 1,
            passengers: [
                Passenger(
                    id: "pass_001",
                    name: "Charlie",
                    currentLocation: LocationCoordinate(latitude: 37.7849, longitude: -122.4294),
                    joinedAt: now
                ),
                Passenger(
                    id: "pass_002",
                    name: "Diana",
                    currentLocation: LocationCoordinate(latitude: 37.7849, longitude: -122.4294),
                    joinedAt: now
                )
            ],
            driverCurrentLocation: LocationCoordinate(latitude: 37.7849, longitude: -122.4294),
            createdAt: now,
            notes: "SUV with extra luggage space"
        ))

        // Sample 3: Student Request
        rides.append(Ride(
            id: UUID(),
            publisherID: "student_001",
            publisherName: "Emma Wilson",
            role: .passenger,
            rideType: .studentRequest(maxPassengers: 3, unitFare: 15.0),
            startLocation: "University District",
            endLocation: "Shopping Mall",
            startCoordinate: LocationCoordinate(latitude: 37.7649, longitude: -122.4394),
            endCoordinate: LocationCoordinate(latitude: 37.7549, longitude: -122.4094),
            departureTime: now.addingTimeInterval(5400),
            status: .pending,
            totalCapacity: 3,
            availableSeats: 3,
            passengers: [],
            driverCurrentLocation: nil,
            createdAt: now,
            notes: "Looking for a ride to go shopping"
        ))

        // Sample 4: Student Request
        rides.append(Ride(
            id: UUID(),
            publisherID: "student_002",
            publisherName: "Frank Lee",
            role: .passenger,
            rideType: .studentRequest(maxPassengers: 2, unitFare: 20.0),
            startLocation: "Library",
            endLocation: "Sports Complex",
            startCoordinate: LocationCoordinate(latitude: 37.7749, longitude: -122.4094),
            endCoordinate: LocationCoordinate(latitude: 37.7849, longitude: -122.3994),
            departureTime: now.addingTimeInterval(1800),
            status: .pending,
            totalCapacity: 2,
            availableSeats: 2,
            passengers: [],
            driverCurrentLocation: nil,
            createdAt: now,
            notes: "Weekend game event"
        ))

        // Sample 5: Driver Offer - Full
        rides.append(Ride(
            id: UUID(),
            publisherID: "driver_003",
            publisherName: "Grace Chen",
            role: .driver,
            rideType: .driverOffer(totalFare: 40.0),
            startLocation: "West Campus",
            endLocation: "City Center",
            startCoordinate: LocationCoordinate(latitude: 37.7549, longitude: -122.4494),
            endCoordinate: LocationCoordinate(latitude: 37.7749, longitude: -122.4194),
            departureTime: now.addingTimeInterval(900),
            status: .enRoute,
            totalCapacity: 4,
            availableSeats: 0,
            passengers: [
                Passenger(id: "p1", name: "Henry", currentLocation: nil, joinedAt: now),
                Passenger(id: "p2", name: "Iris", currentLocation: nil, joinedAt: now),
                Passenger(id: "p3", name: "Jack", currentLocation: nil, joinedAt: now),
                Passenger(id: "p4", name: "Kate", currentLocation: nil, joinedAt: now)
            ],
            driverCurrentLocation: LocationCoordinate(latitude: 37.7549, longitude: -122.4494),
            createdAt: now,
            notes: "Electric vehicle, eco-friendly"
        ))
    }

    deinit {
        locationTimer?.invalidate()
    }
}

// MARK: - 3. UI Implementation

// MARK: - A. Passenger View

struct PassengerView: View {
    @ObservedObject var dataStore: RideDataStore
    @State private var selectedRide: Ride?
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showTracking = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Header
                    headerView

                    // Available rides
                    let availableRides = dataStore.searchRides(userRole: .passenger)

                    if availableRides.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(availableRides) { ride in
                            PassengerRideCard(
                                ride: ride,
                                currentUserID: dataStore.currentUserID,
                                onJoin: {
                                    handleJoinRide(ride)
                                },
                                onViewLocation: {
                                    selectedRide = ride
                                    showTracking = true
                                }
                            )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Find a Ride")
            .navigationBarTitleDisplayMode(.large)
            .alert("Notice", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .sheet(item: $selectedRide) { ride in
                RideTrackingView(
                    ride: ride,
                    dataStore: dataStore,
                    userRole: .passenger
                )
            }
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Welcome, \(dataStore.currentUserName)")
                .font(.title2)
                .fontWeight(.bold)
            Text("Find available rides from drivers")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "car.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("No Available Rides")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Check back later for new ride offers")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 100)
    }

    private func handleJoinRide(_ ride: Ride) {
        let result = dataStore.joinRide(
            rideID: ride.id,
            passengerID: dataStore.currentUserID,
            passengerName: dataStore.currentUserName
        )

        switch result {
        case .success:
            alertMessage = "Successfully joined the ride!"
        case .failure(let error):
            alertMessage = error
        }
        showAlert = true
    }
}

struct PassengerRideCard: View {
    let ride: Ride
    let currentUserID: String
    let onJoin: () -> Void
    let onViewLocation: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(ride.publisherName)
                        .font(.headline)
                    Text(ride.formattedDepartureTime)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                statusBadge
            }

            Divider()

            // Route
            VStack(alignment: .leading, spacing: 8) {
                RouteRow(icon: "location.circle.fill", text: ride.startLocation, color: .green)
                RouteRow(icon: "location.circle.fill", text: ride.endLocation, color: .red)
            }

            Divider()

            // Pricing and Seats
            HStack(spacing: 20) {
                PriceInfoBox(
                    title: "Unit Fare",
                    value: "$\(String(format: "%.2f", ride.unitPrice))",
                    color: .blue
                )

                SeatInfoBox(
                    available: ride.availableSeats,
                    total: ride.totalCapacity
                )
            }

            // Notes
            if let notes = ride.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }

            // Action Button
            actionButton
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }

    private var statusBadge: some View {
        Text(ride.status.displayName)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(ride.status.color.opacity(0.2))
            .foregroundColor(ride.status.color)
            .cornerRadius(8)
    }

    @ViewBuilder
    private var actionButton: some View {
        let hasJoined = ride.hasUserJoined(userID: currentUserID)

        if ride.status == .accepted && hasJoined {
            Button(action: onViewLocation) {
                HStack {
                    Image(systemName: "map.fill")
                    Text("View Driver Location")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        } else if ride.status == .pending && ride.availableSeats > 0 && !hasJoined {
            Button(action: onJoin) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Confirm Join")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        } else if ride.availableSeats == 0 {
            Text("Full")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray.opacity(0.3))
                .foregroundColor(.gray)
                .cornerRadius(10)
        } else if hasJoined {
            Text("✓ Joined")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green.opacity(0.2))
                .foregroundColor(.green)
                .cornerRadius(10)
        }
    }
}

// MARK: - B. Driver View

struct DriverView: View {
    @ObservedObject var dataStore: RideDataStore
    @State private var selectedRide: Ride?
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showTracking = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Header
                    headerView

                    // Available student requests
                    let studentRequests = dataStore.searchRides(userRole: .driver)

                    if studentRequests.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(studentRequests) { ride in
                            DriverRideCard(
                                ride: ride,
                                currentUserID: dataStore.currentUserID,
                                onAccept: {
                                    handleAcceptRequest(ride)
                                },
                                onStartTracking: {
                                    selectedRide = ride
                                    showTracking = true
                                },
                                onComplete: {
                                    handleCompleteRide(ride)
                                }
                            )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Student Requests")
            .navigationBarTitleDisplayMode(.large)
            .alert("Notice", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .sheet(item: $selectedRide) { ride in
                RideTrackingView(
                    ride: ride,
                    dataStore: dataStore,
                    userRole: .driver
                )
            }
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Welcome, Driver \(dataStore.currentUserName)")
                .font(.title2)
                .fontWeight(.bold)
            Text("Accept student ride requests")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("No Student Requests")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Check back later for new requests")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 100)
    }

    private func handleAcceptRequest(_ ride: Ride) {
        let result = dataStore.acceptRequest(
            rideID: ride.id,
            driverID: dataStore.currentUserID,
            driverName: dataStore.currentUserName
        )

        switch result {
        case .success:
            alertMessage = "Successfully accepted the request!"
        case .failure(let error):
            alertMessage = error
        }
        showAlert = true
    }

    private func handleCompleteRide(_ ride: Ride) {
        let result = dataStore.completeRide(rideID: ride.id)

        switch result {
        case .success:
            alertMessage = "Ride completed successfully!"
        case .failure(let error):
            alertMessage = error
        }
        showAlert = true
    }
}

struct DriverRideCard: View {
    let ride: Ride
    let currentUserID: String
    let onAccept: () -> Void
    let onStartTracking: () -> Void
    let onComplete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(ride.publisherName)
                        .font(.headline)
                    Text(ride.formattedDepartureTime)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                statusBadge
            }

            Divider()

            // Route
            VStack(alignment: .leading, spacing: 8) {
                RouteRow(icon: "location.circle.fill", text: ride.startLocation, color: .green)
                RouteRow(icon: "location.circle.fill", text: ride.endLocation, color: .red)
            }

            Divider()

            // Revenue and Capacity Info
            HStack(spacing: 20) {
                RevenueInfoBox(
                    revenue: ride.estimatedRevenue,
                    totalFare: ride.totalFare
                )

                PassengerCountBox(
                    current: ride.currentPassengerCount,
                    max: ride.totalCapacity
                )
            }

            // Notes
            if let notes = ride.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }

            // Action Button
            actionButton
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }

    private var statusBadge: some View {
        Text(ride.status.displayName)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(ride.status.color.opacity(0.2))
            .foregroundColor(ride.status.color)
            .cornerRadius(8)
    }

    @ViewBuilder
    private var actionButton: some View {
        if ride.status == .pending {
            Button(action: onAccept) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Confirm Acceptance")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        } else if ride.status == .accepted {
            VStack(spacing: 8) {
                Button(action: onStartTracking) {
                    HStack {
                        Image(systemName: "map.fill")
                        Text("Start Tracking Passengers")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }

                Button(action: onComplete) {
                    HStack {
                        Image(systemName: "flag.checkered")
                        Text("Complete Ride")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
        } else if ride.status == .enRoute {
            Button(action: onComplete) {
                HStack {
                    Image(systemName: "flag.checkered")
                    Text("Complete Ride")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
    }
}

// MARK: - C. Real-time Tracking View

struct RideTrackingView: View {
    let ride: Ride
    @ObservedObject var dataStore: RideDataStore
    let userRole: UserRole
    @Environment(\.dismiss) var dismiss

    @State private var region: MKCoordinateRegion
    @State private var eta: Int = 0

    init(ride: Ride, dataStore: RideDataStore, userRole: UserRole) {
        self.ride = ride
        self.dataStore = dataStore
        self.userRole = userRole

        // Initialize map region
        let center = ride.driverCurrentLocation?.clCoordinate ?? ride.startCoordinate.clCoordinate
        _region = State(initialValue: MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        ))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Map View
                Map(coordinateRegion: $region, annotationItems: mapAnnotations) { annotation in
                    MapAnnotation(coordinate: annotation.coordinate) {
                        AnnotationView(annotation: annotation)
                    }
                }
                .frame(height: 400)
                .onAppear {
                    updateETA()
                }
                .onReceive(dataStore.$rides) { _ in
                    updateMapRegion()
                    updateETA()
                }

                // Info Panel
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // ETA Display (Passenger view)
                        if userRole == .passenger, let driverLoc = currentRide?.driverCurrentLocation {
                            ETACard(eta: eta, status: currentRide?.status ?? .pending)
                        }

                        // Ride Info
                        RideInfoCard(ride: currentRide ?? ride)

                        // Passenger List (Driver view)
                        if userRole == .driver {
                            PassengerListCard(passengers: currentRide?.passengers ?? [])
                        }
                    }
                    .padding()
                }
                .background(Color(.systemGroupedBackground))
            }
            .navigationTitle("Ride Tracking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var currentRide: Ride? {
        dataStore.rides.first { $0.id == ride.id }
    }

    private var mapAnnotations: [MapAnnotation] {
        var annotations: [MapAnnotation] = []

        // Start location
        annotations.append(MapAnnotation(
            id: "start",
            coordinate: ride.startCoordinate.clCoordinate,
            title: ride.startLocation,
            type: .start
        ))

        // End location
        annotations.append(MapAnnotation(
            id: "end",
            coordinate: ride.endCoordinate.clCoordinate,
            title: ride.endLocation,
            type: .end
        ))

        // Driver location
        if let driverLoc = currentRide?.driverCurrentLocation {
            annotations.append(MapAnnotation(
                id: "driver",
                coordinate: driverLoc.clCoordinate,
                title: "Driver",
                type: .driver
            ))
        }

        // Passenger locations (driver view)
        if userRole == .driver {
            for passenger in currentRide?.passengers ?? [] {
                if let loc = passenger.currentLocation {
                    annotations.append(MapAnnotation(
                        id: passenger.id,
                        coordinate: loc.clCoordinate,
                        title: passenger.name,
                        type: .passenger
                    ))
                }
            }
        }

        return annotations
    }

    private func updateMapRegion() {
        if let driverLoc = currentRide?.driverCurrentLocation {
            region.center = driverLoc.clCoordinate
        }
    }

    private func updateETA() {
        guard let driverLoc = currentRide?.driverCurrentLocation else { return }
        eta = dataStore.calculateETA(
            driverLocation: driverLoc,
            destinationLocation: ride.startCoordinate
        )
    }
}

// MARK: - Supporting Map Types

struct MapAnnotation: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let title: String
    let type: AnnotationType

    enum AnnotationType {
        case start, end, driver, passenger
    }
}

struct AnnotationView: View {
    let annotation: MapAnnotation

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.system(size: 24))
                .foregroundColor(.white)
                .padding(8)
                .background(backgroundColor)
                .clipShape(Circle())
                .shadow(radius: 3)

            Text(annotation.title)
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white)
                .cornerRadius(8)
                .shadow(radius: 2)
        }
    }

    private var iconName: String {
        switch annotation.type {
        case .start: return "mappin.circle.fill"
        case .end: return "flag.fill"
        case .driver: return "car.fill"
        case .passenger: return "person.fill"
        }
    }

    private var backgroundColor: Color {
        switch annotation.type {
        case .start: return .green
        case .end: return .red
        case .driver: return .blue
        case .passenger: return .orange
        }
    }
}

// MARK: - Supporting UI Components

struct RouteRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(text)
                .font(.subheadline)
        }
    }
}

struct PriceInfoBox: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SeatInfoBox: View {
    let available: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Available Seats")
                .font(.caption)
                .foregroundColor(.secondary)
            HStack(spacing: 4) {
                Text("\(available)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(available > 0 ? .green : .red)
                Text("/ \(total)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct RevenueInfoBox: View {
    let revenue: Double
    let totalFare: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Estimated Revenue")
                .font(.caption)
                .foregroundColor(.secondary)
            HStack(spacing: 4) {
                Text("$\(String(format: "%.2f", revenue))")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                Text("/ $\(String(format: "%.0f", totalFare))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PassengerCountBox: View {
    let current: Int
    let max: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Passengers")
                .font(.caption)
                .foregroundColor(.secondary)
            HStack(spacing: 4) {
                Text("\(current)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                Text("/ \(max)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ETACard: View {
    let eta: Int
    let status: RideStatus

    var body: some View {
        HStack {
            Image(systemName: "clock.fill")
                .font(.title2)
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text("Estimated Arrival")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(eta) minutes")
                    .font(.title3)
                    .fontWeight(.bold)
            }

            Spacer()

            Text(status.displayName)
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(status.color.opacity(0.2))
                .foregroundColor(status.color)
                .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 3)
    }
}

struct RideInfoCard: View {
    let ride: Ride

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ride Details")
                .font(.headline)

            Divider()

            InfoRow(label: "Driver", value: ride.publisherName)
            InfoRow(label: "Departure", value: ride.formattedDepartureTime)
            InfoRow(label: "From", value: ride.startLocation)
            InfoRow(label: "To", value: ride.endLocation)
            InfoRow(label: "Capacity", value: "\(ride.totalCapacity) seats")

            if let notes = ride.notes, !notes.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(notes)
                        .font(.subheadline)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 3)
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

struct PassengerListCard: View {
    let passengers: [Passenger]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Passengers (\(passengers.count))")
                .font(.headline)

            if passengers.isEmpty {
                Text("No passengers yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                Divider()

                ForEach(passengers) { passenger in
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.blue)
                        Text(passenger.name)
                            .font(.subheadline)
                        Spacer()
                        if passenger.currentLocation != nil {
                            Image(systemName: "location.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 3)
    }
}

// MARK: - 4. Main App Demo

struct RideSharingDemoApp: View {
    @StateObject private var dataStore = RideDataStore()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            PassengerView(dataStore: dataStore)
                .tabItem {
                    Label("Find Ride", systemImage: "car.fill")
                }
                .tag(0)

            DriverView(dataStore: dataStore)
                .tabItem {
                    Label("Drive", systemImage: "person.fill")
                }
                .tag(1)
        }
    }
}

// MARK: - Preview

struct RideSharingDemoApp_Previews: PreviewProvider {
    static var previews: some View {
        RideSharingDemoApp()
    }
}
