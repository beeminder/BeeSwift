// Part of BeeSwift. Copyright Beeminder

import SwiftUI
import BeeKit

struct SignInView: View {
    @StateObject private var viewModel = SignInViewModel()
    @State private var showingFailedSignInAlert = false
    @State private var showingMissingDataAlert = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.yellow
                .opacity(0.8)
                .ignoresSafeArea()
            
            HStack(alignment: .center) {
                
                VStack(alignment: .center, spacing: 15) {
                    Spacer()
                    
                    Image("website_logo_mid")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 200)
                        .padding(.bottom)
                    
                    VStack(spacing: 15) {
                        TextField("Email or username", text: $viewModel.email)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .submitLabel(.next)
                        
                        SecureField("Password", text: $viewModel.password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .textInputAutocapitalization(.never)
                            .submitLabel(.done)
                        
                        Button(action: signIn) {
                            Text("Sign In")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                        }
                        .background(Color.gray)
                        .cornerRadius(8)
                        .disabled(viewModel.isLoading)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 40)
                    
                    Spacer()
                    Spacer()
                    Spacer()
                }
                .padding()
                
            }
            .alert("Could not sign in", isPresented: $showingFailedSignInAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Invalid credentials")
            }
            .alert("Incomplete Account Details", isPresented: $showingMissingDataAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Username and Password are required")
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name(CurrentUserManager.failedSignInNotificationName))) { _ in
                viewModel.isLoading = false
                showingFailedSignInAlert = true
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name(CurrentUserManager.signedInNotificationName))) { _ in
                viewModel.isLoading = false
                dismiss()
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.2))
            }
        }
    }
    
    private func signIn() {
        guard !viewModel.email.trimmingCharacters(in: .whitespaces).isEmpty,
              !viewModel.password.isEmpty else {
            showingMissingDataAlert = true
            return
        }
        
        Task {
            await viewModel.signIn()
        }
    }
}

@MainActor
class SignInViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isLoading = false
    
    func signIn() async {
        isLoading = true
        
        do {
            try await Task.sleep(nanoseconds: 3_000_000_000)
        } catch {
            print("canceled early")
        }
        
        await ServiceLocator.currentUserManager.signInWithEmail(
            email.trimmingCharacters(in: .whitespaces),
            password: password
        )
    }
}

#Preview {
    SignInView()
}
