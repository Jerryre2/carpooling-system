# Advanced Ride-Sharing Management System

## Overview

A comprehensive SwiftUI-based ride-sharing system supporting dual-direction posting (Driver Offers and Student Requests) with real-time location tracking and dynamic pricing.

## Architecture

### 1. Data Models

#### RideStatus Enum
Tracks the lifecycle of a ride:
- `pending`: Awaiting acceptance or passengers to join
- `accepted`: Confirmed and tracking begins
- `enRoute`: Driver en route to pickup location
- `completed`: Ride finished

#### RideType Enum (Polymorphic)
Supports two business models:
- `driverOffer(totalFare: Double)`: Driver posts with fixed total price
- `studentRequest(maxPassengers: Int, unitFare: Double)`: Student posts with per-person price

#### Ride Struct
Complete ride information including:
- **Basic Info**: ID, publisher details, role, route, timing
- **Capacity Tracking**: Total capacity, available seats, passenger list
- **Location Data**: Real-time driver location coordinates
- **Computed Properties**:
  - `unitPrice`: Price per seat (auto-calculated based on ride type)
  - `estimatedRevenue`: Driver's current revenue projection
  - `totalFare`: Maximum potential fare

### 2. State Management (RideDataStore)

Central `ObservableObject` managing all ride operations:

#### Search Operations
```swift
searchRides(userRole: UserRole, startLocation: String?, endLocation: String?) -> [Ride]
```
- Passengers see only driver offers (`driverOffer`)
- Drivers see only student requests (`studentRequest`)
- Optional location filtering

#### Passenger Operations
```swift
joinRide(rideID: UUID, passengerID: String, passengerName: String) -> Result<Void, String>
```
Pre-checks:
- Must be a driver-posted ride
- Available seats > 0
- User hasn't already joined

Actions:
- Decrements available seats
- Adds passenger to ride
- Updates ride status if full

#### Driver Operations
```swift
acceptRequest(rideID: UUID, driverID: String, driverName: String) -> Result<Void, String>
```
Pre-checks:
- Must be a student-posted ride
- Status must be pending

Actions:
- Changes publisher to driver
- Sets status to accepted
- Initializes driver location tracking

#### Location Services
```swift
updateDriverLocation(rideID: UUID, location: LocationCoordinate)
getPassengerLocation(passengerID: String) -> LocationCoordinate
calculateETA(driverLocation: LocationCoordinate, destinationLocation: LocationCoordinate) -> Int
```
- Real-time location updates (simulated every 3 seconds)
- ETA calculation based on distance and average speed (40 km/h)
- Automatic status progression as driver approaches destination

### 3. User Interface

#### A. Passenger View (`PassengerView`)

**Features:**
- Browse available driver offers
- Filter by route and time
- View ride details with highlighted unit price
- See available seat count (red highlight when low)

**Interactions:**
- **Pending rides**: "Confirm Join" button (with availability check)
- **Accepted rides (joined)**: "View Driver Location" button
- **Full rides**: Grayed out "Full" indicator

**Card Display:**
- Driver name and departure time
- Route with visual indicators
- Unit fare (blue highlight)
- Available seats (dynamic color: green/orange/red)
- Status badge
- Notes section

#### B. Driver View (`DriverView`)

**Features:**
- Browse student ride requests
- View potential revenue
- See passenger capacity requirements

**Interactions:**
- **Pending requests**: "Confirm Acceptance" button
- **Accepted rides**:
  - "Start Tracking Passengers" button
  - "Complete Ride" button
- Revenue display (green highlight)

**Card Display:**
- Student name and departure time
- Route information
- Estimated revenue vs. total fare
- Current passenger count
- Status badge
- Request notes

#### C. Real-time Tracking View (`RideTrackingView`)

**Shared Map Features:**
- Interactive MapKit integration
- Color-coded annotations:
  - 🟢 Green: Start location
  - 🔴 Red: End location
  - 🔵 Blue: Driver location
  - 🟠 Orange: Passenger locations

**Passenger View:**
- Driver's real-time location on map
- ETA display: "Estimated [X] minutes until arrival"
- Ride details panel
- Auto-updating as driver moves

**Driver View:**
- All passenger locations displayed
- Own location tracking
- Passenger list with location status
- Complete ride action

## Usage Guide

### Running the App

1. **Standalone Mode:**
   ```swift
   // Replace your main app entry point with:
   @main
   struct MyApp: App {
       var body: some Scene {
           WindowGroup {
               RideSharingDemoApp()
           }
       }
   }
   ```

2. **Integration Mode:**
   ```swift
   // Use as a feature within your existing app:
   @StateObject var rideDataStore = RideDataStore()

   // In your navigation:
   PassengerView(dataStore: rideDataStore)
   // or
   DriverView(dataStore: rideDataStore)
   ```

### Sample Data

The system includes 5 pre-loaded sample rides demonstrating:
- Driver offers (pending, active, full)
- Student requests (various capacities and prices)
- Different statuses and scenarios

### Key Features Demonstrated

1. **Polymorphic Pricing:**
   - Driver offer: $50 total → $12.50 per seat (4 seats)
   - Student request: $15 per passenger × 3 passengers = $45 total

2. **Real-time Updates:**
   - Location simulation updates every 3 seconds
   - Automatic ETA recalculation
   - Status transitions based on proximity

3. **Role-based Access:**
   - Passengers can only join driver offers
   - Drivers can only accept student requests
   - Clear separation of concerns

4. **State Management:**
   - Thread-safe Combine integration
   - Reactive UI updates via `@Published` properties
   - Consistent data flow

## Implementation Highlights

### Data Flow
```
User Action → RideDataStore Method → State Update → @Published Trigger → SwiftUI Re-render
```

### Location Simulation
```swift
// Simulates gradual movement toward destination
driverLocation += (destination - driverLocation) × 0.1
// Updates every 3 seconds via Timer
```

### ETA Calculation
```swift
distance (meters) / 666.67 (m/min at 40 km/h) = ETA in minutes
```

## Code Organization

- **Lines 1-250**: Data models and enums
- **Lines 251-550**: RideDataStore state management
- **Lines 551-750**: Passenger View implementation
- **Lines 751-950**: Driver View implementation
- **Lines 951-1200**: Real-time Tracking View
- **Lines 1201-1400**: Supporting UI components
- **Lines 1401-1450**: Main app demo entry point

## Technical Requirements

- **iOS**: 15.0+
- **Swift**: 5.5+
- **Frameworks**: SwiftUI, MapKit, Combine
- **Features**: No external dependencies

## Testing Scenarios

### Scenario 1: Passenger Journey
1. Launch app on Passenger tab
2. Browse driver offers
3. Select a ride with available seats
4. Tap "Confirm Join"
5. Switch to "View Driver Location"
6. Observe real-time tracking and ETA

### Scenario 2: Driver Journey
1. Launch app on Driver tab
2. Browse student requests
3. Select a profitable request
4. Tap "Confirm Acceptance"
5. Tap "Start Tracking Passengers"
6. View all passenger locations on map
7. Tap "Complete Ride" when finished

### Scenario 3: Dynamic Pricing
1. Compare different ride cards
2. Observe unit price calculation:
   - Driver offers: Total fare ÷ capacity
   - Student requests: Fixed unit fare
3. Watch estimated revenue update as passengers join

## Extensibility

### Adding Firebase Integration
```swift
class RideDataStore: ObservableObject {
    private let db = Firestore.firestore()

    func syncWithFirebase() {
        db.collection("rides").addSnapshotListener { snapshot, error in
            // Update rides array
        }
    }
}
```

### Adding Push Notifications
```swift
func joinRide(...) -> Result<Void, String> {
    // Existing logic...

    // Send notification to driver
    notificationService.send(
        to: ride.publisherID,
        message: "\(passengerName) joined your ride"
    )
}
```

### Adding Payment Integration
```swift
struct Ride {
    var paymentStatus: PaymentStatus
    var stripePaymentIntentID: String?
}
```

## Performance Considerations

- **Location Updates**: Throttled to 3-second intervals to reduce CPU usage
- **Map Rendering**: Only displays relevant annotations for current view
- **Data Filtering**: Efficient role-based filtering before UI rendering
- **Memory Management**: Automatic cleanup via `deinit` for timers

## Best Practices Demonstrated

1. ✅ **Single Responsibility**: Each struct/class has one clear purpose
2. ✅ **Computed Properties**: Dynamic calculations without stored redundancy
3. ✅ **Type Safety**: Enums with associated values for polymorphism
4. ✅ **Error Handling**: Result types for clear success/failure states
5. ✅ **UI Responsiveness**: Async state updates via Combine
6. ✅ **Code Reusability**: Modular components and views
7. ✅ **Documentation**: Comprehensive inline comments

## File Location

```
/home/user/carpooling-system/CarpoolingSystem/RideSharingSystem.swift
```

Total Lines: ~1,450
Total Size: ~60 KB

---

**Ready to run!** Simply open in Xcode and build. No configuration needed.
