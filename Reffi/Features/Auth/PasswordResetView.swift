import SwiftUI

struct PasswordResetView: View {
    @Environment(AuthStore.self) private var auth
    @State private var password = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ReffiSpace.s5) {
                    Text("Choose a new password").reffiType(.heading)
                    SecureField("New password", text: $password)
                        .textContentType(.newPassword)
                        .textFieldStyle(.roundedBorder)
                    Text("Use at least 6 characters.").reffiType(.caption)
                    if let error = auth.errorMessage {
                        Text(error).reffiType(.body).foregroundStyle(ReffiColor.urgentDark)
                    }
                    PaperButton(title: "Update password", isBusy: auth.busy) {
                        Task { await auth.updatePassword(password) }
                    }
                    .disabled(password.count < 6 || auth.busy)
                }
                .padding(ReffiSpace.s5)
            }
            .background(PaperCanvasBackground())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { auth.needsPasswordReset = false }
                }
            }
        }
        .presentationDetents([.large])
    }
}
