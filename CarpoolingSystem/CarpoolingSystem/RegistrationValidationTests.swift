//
//  RegistrationValidationTests.swift
//  CarpoolingSystemTests
//
//  Test suite for registration validation logic
//

import XCTest
@testable import CarpoolingSystem

class RegistrationValidationTests: XCTestCase {
    
    // MARK: - Email Validation Tests
    
    func testCarpoolerEmailDomain() {
        // Valid email
        XCTAssertTrue(ValidationUtilities.validateCarpoolerEmail("student@must.edu.mo"))
        
        // Invalid emails
        XCTAssertFalse(ValidationUtilities.validateCarpoolerEmail("student@gmail.com"))
        XCTAssertFalse(ValidationUtilities.validateCarpoolerEmail("student@must.edu.cn"))
        XCTAssertFalse(ValidationUtilities.validateCarpoolerEmail("student@edu.mo"))
    }
    
    // MARK: - Password Validation Tests
    
    func testPasswordStrength() {
        // Valid passwords
        XCTAssertTrue(ValidationUtilities.validatePasswordStrength("Abc123"))
        XCTAssertTrue(ValidationUtilities.validatePasswordStrength("MyPass123"))
        XCTAssertTrue(ValidationUtilities.validatePasswordStrength("Test1A"))
        
        // Invalid passwords
        XCTAssertFalse(ValidationUtilities.validatePasswordStrength("abc123")) // No uppercase
        XCTAssertFalse(ValidationUtilities.validatePasswordStrength("ABC123")) // No lowercase
        XCTAssertFalse(ValidationUtilities.validatePasswordStrength("AbcDef")) // No digit
        XCTAssertFalse(ValidationUtilities.validatePasswordStrength("Ab1")) // Too short
    }
    
    func testPasswordErrorMessages() {
        let weakPassword = "abc123"
        let error = ValidationUtilities.getPasswordStrengthError(weakPassword)
        XCTAssertNotNil(error)
    }
    
    // MARK: - Phone Number Validation Tests
    
    func testChinaPhoneNumber() {
        // Valid
        XCTAssertTrue(ValidationUtilities.validatePhoneNumber(countryCode: "+86", phoneNumber: "13812345678"))
        XCTAssertTrue(ValidationUtilities.validatePhoneNumber(countryCode: "+86", phoneNumber: "18899887766"))
        
        // Invalid
        XCTAssertFalse(ValidationUtilities.validatePhoneNumber(countryCode: "+86", phoneNumber: "138123456")) // Too short
        XCTAssertFalse(ValidationUtilities.validatePhoneNumber(countryCode: "+86", phoneNumber: "138123456789")) // Too long
        XCTAssertFalse(ValidationUtilities.validatePhoneNumber(countryCode: "+86", phoneNumber: "1381234567a")) // Contains letter
    }
    
    func testMacauPhoneNumber() {
        // Valid
        XCTAssertTrue(ValidationUtilities.validatePhoneNumber(countryCode: "+853", phoneNumber: "66123456"))
        XCTAssertTrue(ValidationUtilities.validatePhoneNumber(countryCode: "+853", phoneNumber: "28888888"))
        
        // Invalid
        XCTAssertFalse(ValidationUtilities.validatePhoneNumber(countryCode: "+853", phoneNumber: "6612345")) // Too short
        XCTAssertFalse(ValidationUtilities.validatePhoneNumber(countryCode: "+853", phoneNumber: "661234567")) // Too long
        XCTAssertFalse(ValidationUtilities.validatePhoneNumber(countryCode: "+853", phoneNumber: "6612345a")) // Contains letter
    }
    
    // MARK: - Car Plate Validation Tests
    
    func testCarPlateNumber() {
        // Valid plates
        XCTAssertTrue(ValidationUtilities.validateCarPlate("M-12-34"))
        XCTAssertTrue(ValidationUtilities.validateCarPlate("MZ-AB-12"))
        XCTAssertTrue(ValidationUtilities.validateCarPlate("ABC123"))
        
        // Invalid plates
        XCTAssertFalse(ValidationUtilities.validateCarPlate(""))
        XCTAssertFalse(ValidationUtilities.validateCarPlate("A"))
    }
    
    // MARK: - Insurance Expiry Date Validation Tests
    
    func testInsuranceExpiryDate() {
        let calendar = Calendar.current
        let today = Date()
        
        // Valid: 6 months + 1 day from now
        if let validDate = calendar.date(byAdding: .day, value: 181, to: today) {
            XCTAssertTrue(ValidationUtilities.validateInsuranceExpiry(validDate))
        }
        
        // Valid: Exactly 6 months from now
        if let exactDate = calendar.date(byAdding: .month, value: 6, to: today) {
            XCTAssertTrue(ValidationUtilities.validateInsuranceExpiry(exactDate))
        }
        
        // Invalid: 5 months from now
        if let tooSoonDate = calendar.date(byAdding: .month, value: 5, to: today) {
            XCTAssertFalse(ValidationUtilities.validateInsuranceExpiry(tooSoonDate))
        }
        
        // Invalid: Yesterday
        if let pastDate = calendar.date(byAdding: .day, value: -1, to: today) {
            XCTAssertFalse(ValidationUtilities.validateInsuranceExpiry(pastDate))
        }
    }
    
    // MARK: - Complete Form Validation Tests
    
    func testValidCarpoolerForm() {
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
        
        XCTAssertTrue(errors.isEmpty)
    }
    
    func testInvalidCarpoolerEmail() {
        let errors = ValidationUtilities.validateRegistrationForm(
            role: .carpooler,
            name: "John Doe",
            email: "john@gmail.com",
            password: "Test123",
            confirmPassword: "Test123",
            countryCode: "+853",
            phone: "66123456",
            carPlate: nil,
            insuranceExpiry: nil
        )
        
        XCTAssertFalse(errors.isEmpty)
        XCTAssertTrue(errors.contains { $0.contains("@must.edu.mo") })
    }
    
    func testValidCarOwnerForm() {
        let calendar = Calendar.current
        let validInsuranceDate = calendar.date(byAdding: .month, value: 7, to: Date())!
        
        let errors = ValidationUtilities.validateRegistrationForm(
            role: .carOwner,
            name: "Jane Smith",
            email: "jane@example.com",
            password: "Secure123",
            confirmPassword: "Secure123",
            countryCode: "+86",
            phone: "13812345678",
            carPlate: "M-12-34",
            insuranceExpiry: validInsuranceDate
        )
        
        XCTAssertTrue(errors.isEmpty)
    }
    
    func testCarOwnerInvalidInsurance() {
        let calendar = Calendar.current
        let invalidInsuranceDate = calendar.date(byAdding: .month, value: 3, to: Date())!
        
        let errors = ValidationUtilities.validateRegistrationForm(
            role: .carOwner,
            name: "Jane Smith",
            email: "jane@example.com",
            password: "Secure123",
            confirmPassword: "Secure123",
            countryCode: "+86",
            phone: "13812345678",
            carPlate: "M-12-34",
            insuranceExpiry: invalidInsuranceDate
        )
        
        XCTAssertFalse(errors.isEmpty)
        XCTAssertTrue(errors.contains { $0.contains("6 个月") })
    }
    
    func testPasswordMismatch() {
        let errors = ValidationUtilities.validateRegistrationForm(
            role: .carpooler,
            name: "Test User",
            email: "test@must.edu.mo",
            password: "Test123",
            confirmPassword: "Different456",
            countryCode: "+853",
            phone: "66123456",
            carPlate: nil,
            insuranceExpiry: nil
        )
        
        XCTAssertFalse(errors.isEmpty)
        XCTAssertTrue(errors.contains { $0.contains("不一致") })
    }
    
    func testWeakPassword() {
        let errors = ValidationUtilities.validateRegistrationForm(
            role: .carpooler,
            name: "Test User",
            email: "test@must.edu.mo",
            password: "weak",
            confirmPassword: "weak",
            countryCode: "+853",
            phone: "66123456",
            carPlate: nil,
            insuranceExpiry: nil
        )
        
        XCTAssertFalse(errors.isEmpty)
        XCTAssertTrue(errors.contains { $0.contains("强度") || $0.contains("大小写") })
    }
}
