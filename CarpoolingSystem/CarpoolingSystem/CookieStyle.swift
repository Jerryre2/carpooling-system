//
//  CookieStyle.swift
//  CarpoolingSystem
//
//  Created by 王宗岩 on 2025/10/23.
//

import SwiftUI

extension Color {
    static let cookiePrimary = Color(red: 1.0, green: 0.6, blue: 0.8) // 更明显的粉色
    static let cookieSecondary = Color(red: 0.8, green: 0.9, blue: 1.0)
    static let cookieAccent = Color(red: 1.0, green: 0.9, blue: 0.8)
    static let cookieBackground = Color(red: 0.98, green: 0.98, blue: 0.98)
    static let cookieText = Color(red: 0.2, green: 0.2, blue: 0.2) // 更深的文字颜色
}

struct CookieButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 25)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(color)
                    .shadow(color: color.opacity(0.3), radius: 5, x: 0, y: 3)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}
