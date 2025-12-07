# Quick Reference Guide: Registration Validation

## For Developers Working with the Registration Feature

---

## Quick Start

### Adding a New Validation Rule

1. **Add validation function to ValidationUtilities.swift:**
```swift
static func validateNewField(_ value: String) -> Bool {
    // Your validation logic here
    return isValid
}

static func getNewFieldError(_ value: String) -> String? {
    if !validateNewField(value) {
        return "Your error message"
    }
    return nil
}
```

2. **Add state variable in LoginView:**
```swift
@State private var newFieldError: String? = nil
```

3. **Add validation trigger in LoginView:**
```swift
func validateNewField() {
    if newField.isEmpty {
        newFieldError = nil
        return
    }
    newFieldError = ValidationUtilities.getNewFieldError(newField)
}
```

4. **Add to UI with error display:**
```swift
TextField("New Field", text: $newField)
    .onChange(of: newField) { _ in
        validateNewField()
    }

if let error = newFieldError {
    Text(error)
        .font(.caption)
        .foregroundColor(.red)
}
```

5. **Update form validation function:**
```swift
// In ValidationUtilities.validateRegistrationForm()
if let newFieldError = getNewFieldError(newField) {
    errors.append(newFieldError)
}
```

---

## Validation Functions Reference

### Email Validation
```swift
// Check if email ends with @must.edu.mo
ValidationUtilities.validateCarpoolerEmail(_ email: String) -> Bool

// Usage
if !ValidationUtilities.validateCarpoolerEmail("student@must.edu.mo") {
    // Invalid email
}
```

### Password Validation
```swift
// Check password strength (uppercase + lowercase + digit)
ValidationUtilities.validatePasswordStrength(_ password: String) -> Bool

// Get descriptive error message
ValidationUtilities.getPasswordStrengthError(_ password: String) -> String?

// Usage
if let error = ValidationUtilities.getPasswordStrengthError("weak") {
    print(error) // "密码强度不足 (需包含大小写字母和数字)"
}
```

### Phone Number Validation
```swift
// Validate phone number for specific country code
ValidationUtilities.validatePhoneNumber(countryCode: String, phoneNumber: String) -> Bool

// Get descriptive error message
ValidationUtilities.getPhoneValidationError(countryCode: String, phoneNumber: String) -> String?

// Usage
let isValid = ValidationUtilities.validatePhoneNumber(
    countryCode: "+853",
    phoneNumber: "66123456"
) // Returns true (8 digits for Macau)

let error = ValidationUtilities.getPhoneValidationError(
    countryCode: "+86",
    phoneNumber: "138"
) // Returns "中国大陆手机号必须为 11 位数字"
```

### Car Plate Validation
```swift
// Validate car plate number
ValidationUtilities.validateCarPlate(_ plate: String) -> Bool

// Get error message
ValidationUtilities.getCarPlateError(_ plate: String) -> String?
```

### Insurance Date Validation
```swift
// Check if date is at least 6 months from today
ValidationUtilities.validateInsuranceExpiry(_ expiryDate: Date) -> Bool

// Get error message
ValidationUtilities.getInsuranceExpiryError(_ expiryDate: Date) -> String?

// Usage
let futureDate = Calendar.current.date(byAdding: .month, value: 7, to: Date())!
let isValid = ValidationUtilities.validateInsuranceExpiry(futureDate) // true
```

### Complete Form Validation
```swift
// Validate entire registration form
ValidationUtilities.validateRegistrationForm(
    role: UserRole,
    name: String,
    email: String,
    password: String,
    confirmPassword: String,
    countryCode: String,
    phone: String,
    carPlate: String?,
    insuranceExpiry: Date?
) -> [String] // Returns array of error messages

// Usage
let errors = ValidationUtilities.validateRegistrationForm(
    role: .carpooler,
    name: "John Doe",
    email: "john@must.edu.mo",
    password: "Test123",
    confirmPassword: "Test123",
    countryCode: "+853",
    phone: "66123456",
    carPlate: nil,
    insuranceExpiry: nil
)

if errors.isEmpty {
    // Form is valid
} else {
    // Display errors to user
    errors.forEach { print($0) }
}
```

---

## Common Patterns

### Pattern 1: Real-time Field Validation
```swift
// In LoginView
@State private var fieldValue = ""
@State private var fieldError: String? = nil

// In body
TextField("Field Name", text: $fieldValue)
    .onChange(of: fieldValue) { _ in
        validateField()
    }

if let error = fieldError {
    Text(error)
        .font(.caption)
        .foregroundColor(.red)
}

// Validation function
func validateField() {
    if fieldValue.isEmpty {
        fieldError = nil
        return
    }
    fieldError = ValidationUtilities.getFieldError(fieldValue)
}
```

### Pattern 2: Password Toggle
```swift
@State private var password = ""
@State private var isPasswordVisible = false

HStack {
    if isPasswordVisible {
        TextField("密码", text: $password)
    } else {
        SecureField("密码", text: $password)
    }
    Button(action: { isPasswordVisible.toggle() }) {
        Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
            .foregroundColor(.gray)
    }
}
.padding(8)
.background(RoundedRectangle(cornerRadius: 5).stroke(Color.gray.opacity(0.3)))
```

### Pattern 3: Conditional Field Display
```swift
@State private var selectedRole: UserRole = .carpooler

// Only show for Car Owner
if selectedRole == .carOwner {
    TextField("车牌号码", text: $carPlate)
    DatePicker("保险过期日期", selection: $insuranceExpiry)
}

// Change validation based on role
if selectedRole == .carpooler {
    if !email.hasSuffix("@must.edu.mo") {
        emailError = "邮箱必须以 @must.edu.mo 结尾"
    }
}
```

### Pattern 4: Form Submission with Validation
```swift
func handleSubmit() {
    // Clear previous errors
    validationErrors = []
    
    // Validate all fields
    let errors = ValidationUtilities.validateRegistrationForm(/* ... */)
    
    if !errors.isEmpty {
        validationErrors = errors
        return
    }
    
    // Submit to backend
    authManager.register(/* ... */)
}
```

---

## Testing Examples

### Unit Test Template
```swift
import Testing
@testable import CarpoolingSystem

@Suite("Field Validation Tests")
struct FieldValidationTests {
    
    @Test("Valid input should pass")
    func validInput() async throws {
        let result = ValidationUtilities.validateField("valid input")
        #expect(result == true)
    }
    
    @Test("Invalid input should fail")
    func invalidInput() async throws {
        let result = ValidationUtilities.validateField("invalid")
        #expect(result == false)
    }
    
    @Test("Error message is descriptive")
    func errorMessage() async throws {
        let error = ValidationUtilities.getFieldError("invalid")
        #expect(error != nil)
        #expect(error?.contains("expected text") == true)
    }
}
```

### Running Tests
```bash
# Command Line
swift test

# Or in Xcode
Cmd + U
```

---

## Common Scenarios

### Scenario 1: User Switches Role During Registration

**Expected Behavior:**
- Form fields update to show/hide role-specific fields
- Validation errors are cleared
- Form remains in invalid state until all new fields are valid

**Implementation:**
```swift
Picker("身份", selection: $selectedRole) {
    Text("🚗 乘客").tag(UserRole.carpooler)
    Text("🚙 车主").tag(UserRole.carOwner)
}
.onChange(of: selectedRole) { _ in
    clearValidationErrors()
}
```

### Scenario 2: User Types Invalid Email (Carpooler)

**Expected Behavior:**
- Real-time validation shows error as user types
- Error message: "邮箱必须以 @must.edu.mo 结尾"
- Submit button remains disabled
- Error disappears when user corrects email

**Flow:**
```
User types: "john@gmail.com"
  → onChange triggered
  → validateEmailField() called
  → emailError = "邮箱必须以 @must.edu.mo 结尾"
  → UI shows red error text below field
  → isFormValid() returns false
  → Submit button disabled
```

### Scenario 3: User Selects Insurance Date Too Soon

**Expected Behavior:**
- User selects date less than 6 months away
- Error appears: "保险有效期必须至少还有 6 个月"
- Submit button disabled
- User must select later date

**Flow:**
```
Today: 2025-12-06
User selects: 2026-03-01 (3 months away)
  → onChange triggered
  → validateInsuranceField() called
  → ValidationUtilities.validateInsuranceExpiry() returns false
  → insuranceError = "保险有效期必须至少还有 6 个月"
  → UI shows error in red
  → isFormValid() returns false
```

### Scenario 4: User Changes Country Code Mid-Input

**Expected Behavior:**
- User types 8 digits for +853
- User switches to +86
- Validation error appears (needs 11 digits)
- User adds 3 more digits
- Error disappears

**Flow:**
```
phone = "66123456" (8 digits)
selectedCountryCode = "+853"
  → Valid ✓

User taps country selector, chooses +86
  → onChange triggered
  → validatePhoneField() called
  → ValidationUtilities.validatePhoneNumber("+86", "66123456") returns false
  → phoneError = "中国大陆手机号必须为 11 位数字"

User types "123"
phone = "66123456123" (11 digits)
  → onChange triggered
  → validatePhoneField() called
  → phoneError = nil
  → Valid ✓
```

---

## Debugging Tips

### Check Validation State
```swift
// Add to handleAction() for debugging
print("Form Valid: \(isFormValid())")
print("Validation Errors: \(validationErrors)")
print("Email Error: \(emailError ?? "none")")
print("Phone Error: \(phoneError ?? "none")")
```

### Test Specific Validation
```swift
// In Preview or test code
let result = ValidationUtilities.validatePhoneNumber(
    countryCode: "+853",
    phoneNumber: "12345678"
)
print("Valid: \(result)")
```

### Check Date Calculation
```swift
let calendar = Calendar.current
let today = calendar.startOfDay(for: Date())
let sixMonths = calendar.date(byAdding: .month, value: 6, to: today)!
let testDate = Date() // Your test date

print("Today: \(today)")
print("Six Months: \(sixMonths)")
print("Test Date: \(testDate)")
print("Valid: \(testDate >= sixMonths)")
```

---

## Configuration

### Supported Country Codes
```swift
// In ValidationUtilities.swift
struct CountryCode {
    static let supportedCodes: [CountryCode] = [
        CountryCode(code: "+853", flag: "🇲🇴", name: "澳门", digitCount: 8),
        CountryCode(code: "+86", flag: "🇨🇳", name: "中国大陆", digitCount: 11)
    ]
}

// To add new country:
CountryCode(code: "+852", flag: "🇭🇰", name: "香港", digitCount: 8)
```

### Password Requirements
```swift
// Current: Uppercase + Lowercase + Digit + Min 6 chars
// To modify, edit ValidationUtilities.validatePasswordStrength()

// Example: Add special character requirement
let hasSpecial = password.rangeOfCharacter(
    from: CharacterSet(charactersIn: "!@#$%^&*")
) != nil
return hasUppercase && hasLowercase && hasDigit && hasSpecial
```

### Insurance Period
```swift
// Current: 6 months minimum
// To change, edit ValidationUtilities.validateInsuranceExpiry()

// Example: Change to 12 months
guard let twelveMonthsLater = calendar.date(
    byAdding: .month,
    value: 12,  // Changed from 6
    to: today
) else { return false }
```

---

## Error Messages Reference

### English → Chinese Mapping

| Validation | Chinese Error Message | English Translation |
|------------|----------------------|---------------------|
| Email domain | "邮箱必须以 @must.edu.mo 结尾" | "Email must end with @must.edu.mo" |
| Password strength | "密码强度不足 (需包含大小写字母和数字)" | "Password strength insufficient (requires uppercase, lowercase, and digit)" |
| Password mismatch | "两次密码输入不一致" | "Passwords do not match" |
| Phone (Macau) | "澳门手机号必须为 8 位数字" | "Macau phone must be 8 digits" |
| Phone (China) | "中国大陆手机号必须为 11 位数字" | "China phone must be 11 digits" |
| Phone format | "手机号只能包含数字" | "Phone can only contain digits" |
| Car plate | "车牌号格式不正确" | "Car plate format incorrect" |
| Insurance | "保险有效期必须至少还有 6 个月" | "Insurance must be valid for at least 6 more months" |

---

## Performance Considerations

### Real-time Validation
- Runs on every keystroke for some fields
- Keep validation functions lightweight
- Avoid network calls in validation
- Use debouncing if validation is expensive

### Form Validation
- Only runs on submit button tap
- Collects all errors in single pass
- More expensive validations can go here

### State Updates
- Each @State change triggers view re-render
- Minimize unnecessary state updates
- Group related state changes

---

## Security Notes

### Client-Side Validation
- **Purpose:** User experience and early feedback
- **Not sufficient:** Always validate on backend
- **Can be bypassed:** Never rely solely on client validation

### Password Handling
- Uses SecureField by default (dots/asterisks)
- Toggle shows plain text temporarily
- Never log passwords
- Backend should hash passwords (Firebase handles this)

### Data Transmission
- Phone numbers stored with country code prefix
- Dates converted to ISO format by Firebase
- Email addresses case-insensitive in Firebase Auth

---

## Migration Guide

### From Old Registration (if applicable)

**Old Code:**
```swift
TextField("Email", text: $email)
TextField("Password", text: $password)
Button("Register") {
    authManager.register(email: email, password: password)
}
```

**New Code:**
```swift
// Add validation states
@State private var emailError: String? = nil
@State private var passwordError: String? = nil

// Add validation
TextField("Email", text: $email)
    .onChange(of: email) { _ in validateEmailField() }

if let error = emailError {
    Text(error).foregroundColor(.red)
}

// Validate before submit
Button("Register") {
    let errors = ValidationUtilities.validateRegistrationForm(/* ... */)
    if errors.isEmpty {
        authManager.register(/* ... */)
    }
}
```

---

## Support & Resources

### Files to Reference
- **ValidationUtilities.swift** - All validation logic
- **ContentView.swift (LoginView)** - UI implementation
- **RegistrationValidationTests.swift** - Test examples
- **REGISTRATION_IMPLEMENTATION.md** - Full documentation
- **REGISTRATION_UI_FLOW.md** - Visual diagrams

### Common Issues

**Issue:** Date validation fails on different devices
**Solution:** Always use `Calendar.current.startOfDay()` to normalize dates

**Issue:** Phone validation not working
**Solution:** Check that country code is from supported list

**Issue:** Form always invalid
**Solution:** Check `isFormValid()` logic, add debug prints

**Issue:** Errors not clearing
**Solution:** Call `clearValidationErrors()` when appropriate

---

## Changelog

### Version 1.0 (Current)
- ✅ Role-based registration
- ✅ Real-time field validation
- ✅ Comprehensive error messages
- ✅ Phone validation for +86 and +853
- ✅ Insurance 6-month validation
- ✅ Password strength validation
- ✅ Email domain validation for carpoolers
- ✅ Car plate validation
- ✅ Show/hide password toggle
- ✅ Complete test coverage

### Future Enhancements
- 🔄 More country codes
- 🔄 Email verification flow
- 🔄 Password strength meter
- 🔄 Photo upload for car/insurance
- 🔄 Localization (EN/ZH/PT)
