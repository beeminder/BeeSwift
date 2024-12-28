import SwiftUI

struct SignInButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let action: () -> Void
    let isDisabled: Bool
    
    init(action: @escaping () -> Void, isDisabled: Bool = false) {
        self.action = action
        self.isDisabled = isDisabled
    }
    
    var body: some View {
        Button(action: action) {
            Label("Sign In", systemImage: "iphone.and.arrow.forward.inward")
                .font(.system(size: 20))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
        }
        .buttonStyle(.bordered)
        .foregroundStyle(colorScheme == .dark ? Color.yellow : Color.black)
        .overlay {
            if colorScheme == .dark {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.yellow, lineWidth: 4)
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(.clear)
            }
        }
        .disabled(isDisabled)
    }
}
