//
//  ValidationUtilities.swift
//  CarpoolingSystem
//
//  Created for enhanced registration validation
//

import Foundation

struct ValidationUtilities {
    
    // MARK: - Email Validation
    
    /// Validates that email ends with @must.edu.mo for Carpooler role
    static func validateCarpoolerEmail(_ email: String) -> Bool {
        return email.hasSuffix("@must.edu.mo")
    }
    
    // MARK: - Password Validation
    
    /// Validates password strength: must contain uppercase, lowercase, and digit
    static func validatePasswordStrength(_ password: String) -> Bool {
        let hasUppercase = password.rangeOfCharacter(from: .uppercaseLetters) != nil
        let hasLowercase = password.rangeOfCharacter(from: .lowercaseLetters) != nil
        let hasDigit = password.rangeOfCharacter(from: .decimalDigits) != nil
        
        return hasUppercase && hasLowercase && hasDigit && password.count >= 6
    }
    
    /// Gets password validation error message
    static func getPasswordStrengthError(_ password: String) -> String? {
        if password.isEmpty { return nil }
        
        let hasUppercase = password.rangeOfCharacter(from: .uppercaseLetters) != nil
        let hasLowercase = password.rangeOfCharacter(from: .lowercaseLetters) != nil
        let hasDigit = password.rangeOfCharacter(from: .decimalDigits) != nil
        
        if !hasUppercase || !hasLowercase || !hasDigit {
            return "密码强度不足 (需包含大小写字母和数字)"
        }
        
        if password.count < 6 {
            return "密码长度至少为 6 位"
        }
        
        return nil
    }
    
    // MARK: - Phone Number Validation
    
    /// Validates phone number based on country code
    static func validatePhoneNumber(countryCode: String, phoneNumber: String) -> Bool {
        // Only allow digits
        let isDigitsOnly = phoneNumber.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil
        
        guard isDigitsOnly else { return false }
        
        switch countryCode {
        case "+86":
            return phoneNumber.count == 11
        case "+853":
            return phoneNumber.count == 8
        default:
            return false
        }
    }
    
    /// Gets phone number validation error message
    static func getPhoneValidationError(countryCode: String, phoneNumber: String) -> String? {
        if phoneNumber.isEmpty { return nil }
        
        let isDigitsOnly = phoneNumber.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil
        
        if !isDigitsOnly {
            return "手机号只能包含数字"
        }
        
        switch countryCode {
        case "+86":
            if phoneNumber.count != 11 {
                return "中国大陆手机号必须为 11 位数字"
            }
        case "+853":
            if phoneNumber.count != 8 {
                return "澳门手机号必须为 8 位数字"
            }
        default:
            return "不支持的国家/地区代码"
        }
        
        return nil
    }
    
    // MARK: - Car Plate Validation
    
    /// Validates car plate number (basic check for Macau format)
    static func validateCarPlate(_ plate: String) -> Bool {
        // Basic validation: not empty and reasonable length
        // Macau plates typically: M-12-34 or similar formats
        let trimmed = plate.trimmingCharacters(in: .whitespaces)
        return trimmed.count >= 2 && trimmed.count <= 15
    }
    
    /// Gets car plate validation error message
    static func getCarPlateError(_ plate: String) -> String? {
        if plate.isEmpty { return "车牌号不能为空" }
        
        let trimmed = plate.trimmingCharacters(in: .whitespaces)
        if trimmed.count < 2 {
            return "车牌号格式不正确"
        }
        
        return nil
    }
    
    // MARK: - Insurance Date Validation
    
    /// Validates that insurance expiry date is at least 6 months from today
    static func validateInsuranceExpiry(_ expiryDate: Date) -> Bool {
        let calendar = Calendar.current
        
        // Get today at start of day to avoid time zone issues
        let today = calendar.startOfDay(for: Date())
        
        // Calculate 6 months from today
        guard let sixMonthsLater = calendar.date(byAdding: .month, value: 6, to: today) else {
            return false
        }
        
        // Get expiry date at start of day
        let expiryDateStart = calendar.startOfDay(for: expiryDate)
        
        // Expiry date must be >= 6 months from now
        return expiryDateStart >= sixMonthsLater
    }
    
    /// Gets insurance validation error message
    static func getInsuranceExpiryError(_ expiryDate: Date) -> String? {
        if !validateInsuranceExpiry(expiryDate) {
            return "保险有效期必须至少还有 6 个月"
        }
        return nil
    }
    
    // MARK: - Combined Form Validation
    
    /// Validates complete registration form
    static func validateRegistrationForm(
        role: AppUserRole,  // 使用 AppUserRole 而不是 UserRole
        name: String,
        email: String,
        password: String,
        confirmPassword: String,
        countryCode: String,
        phone: String,
        carPlate: String?,
        insuranceExpiry: Date?
    ) -> [String] {
        var errors: [String] = []
        
        // Common validations
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append("昵称不能为空")
        }
        
        if email.isEmpty {
            errors.append("邮箱不能为空")
        } else if role == .passenger && !validateCarpoolerEmail(email) {
            errors.append("乘客邮箱必须以 @must.edu.mo 结尾")
        }
        
        if password.isEmpty {
            errors.append("密码不能为空")
        } else if let pwdError = getPasswordStrengthError(password) {
            errors.append(pwdError)
        }
        
        if password != confirmPassword {
            errors.append("两次密码输入不一致")
        }
        
        if let phoneError = getPhoneValidationError(countryCode: countryCode, phoneNumber: phone) {
            errors.append(phoneError)
        }
        
        // Car Owner specific validations
        if role == .carOwner {
            if let plate = carPlate, !plate.isEmpty {
                if let plateError = getCarPlateError(plate) {
                    errors.append(plateError)
                }
            } else {
                errors.append("车牌号不能为空")
            }
            
            if let expiry = insuranceExpiry {
                if let insuranceError = getInsuranceExpiryError(expiry) {
                    errors.append(insuranceError)
                }
            }
        }
        
        return errors
    }
}

// MARK: - Country Code Model

struct CountryCode: Identifiable {
    let id = UUID()
    let code: String
    let flag: String
    let name: String
    let digitCount: Int
    
    static let supportedCodes: [CountryCode] = [
        CountryCode(code: "+853", flag: "🇲🇴", name: "澳门", digitCount: 8),
        CountryCode(code: "+86", flag: "🇨🇳", name: "中国大陆", digitCount: 11)
    ]
}
