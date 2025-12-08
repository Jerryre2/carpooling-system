
import SwiftUI
// MARK: - Success Toast Component
/// 成功提示组件
/// 
struct SuccessToast: View {
    let message: String
    
    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(message)
                .foregroundColor(.white)
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(10)
        .padding(.top, 50)
    }
}
