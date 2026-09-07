import SwiftUI

/// Offline policy shared by authentication and the settings footer.
/// Publication blockers and the evidence behind this text: docs/PRIVACY_POLICY_REVIEW.md.
struct PrivacyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ReffiSpace.s6) {
                    VStack(alignment: .leading, spacing: ReffiSpace.s2) {
                        Text("Release review draft")
                            .reffiType(.caption)
                            .accessibilityIdentifier("privacy.reviewStatus")
                        Text("This policy is not yet effective. International processing details and server retention periods are being verified before release.")
                            .reffiType(.caption).foregroundStyle(ReffiColor.ink2)
                        Text("Reffi stores your fridge on this device. Signing in and sharing usage data involve separate server processing.")
                            .reffiType(.body)
                    }
                    section("Who operates Reffi", "Reffi is operated by Jongmin Lee and Heejae Eo for users in the United States and South Korea. Both operators handle privacy inquiries and requests through lee1993ljm@gmail.com. If you contact us, we use your email address, message and any information you choose to attach to respond and handle your request. These messages are handled through Gmail, provided by Google LLC. Please do not send passwords or information that is unnecessary for your request.")
                    Link(destination: URL(string: "mailto:lee1993ljm@gmail.com")!) {
                        Text(verbatim: "lee1993ljm@gmail.com")
                            .reffiType(.body)
                            .frame(minHeight: 44, alignment: .leading)
                    }
                    .tint(ReffiColor.blueDark)
                    .accessibilityLabel("Email the privacy contact")
                    section("Your fridge and preferences", "Reffi stores your ingredient names, quantities, purchase details, use-by dates, shopping list, saved recipes and cooking history on this device. Your nickname, household setting, cuisine preferences, dislikes and allergy entries are also stored locally. These entries support fridge management, recommendations and reminders. They are not uploaded to the Reffi server or synced between devices. Optional usage records and searches you open on YouTube are described separately below.")
                    section("Receipt images", "When you scan a receipt or select a photo, Apple Vision reads its text on your device. Reffi does not upload the image or the full recognized text to a server, and does not save a copy of the image in its app data. Ingredient and store details that you confirm are saved to your local fridge. Photos already in your photo library remain there until you delete them separately.")
                    section("Account and security information", "Creating or using an account sends your email address and authentication information to Supabase, Inc., our authentication and database provider. Supabase processes account identifiers, a password hash, session tokens, email verification and password reset events, and sign-in timestamps. Network and security logs can include your IP address, client information and request outcomes. These records support the account service you request, prevent misuse and help diagnose errors. Account and security requests still occur when usage sharing is off. You can use the core fridge features as a guest without supplying an email address.")
                    section("Optional usage data", "Share usage data is off by default. When you turn it on, Reffi records screen visits, actions and their times, cooking and inventory counts, food icon categories, built-in recipe identifiers, the household category, language and notification choices, receipt recognition counts, app and OS versions, device model, locale, and app-generated installation and session identifiers. Records sent to Supabase are linked to your account or anonymous account identifier. We use them to understand feature use and improve reliability and usability. The records exclude email text, ingredient and store names, receipt images, custom recipe content, nickname and allergy entries. Reffi does not sell personal information, use these records for advertising, or track you across other companies’ apps and websites. Declining sharing does not limit core features.")
                    section("Tracking choices", "Reffi does not use advertising identifiers or third-party advertising trackers. The native app does not read browser Do Not Track signals; use Share usage data in Settings to control optional analytics. Opening an external link is a separate action, and the destination may apply its own cookie, account and tracking settings. We do not change those external settings for you.")
                    section("Permissions you control", "Camera access is used to scan receipts. The system photo picker provides only the photos you select. Notification permission is used for local use-by reminders; the current app does not use a remote push service. You can decline these permissions and add ingredients manually. You can change camera and notification permissions in iOS Settings. Reffi does not request access to contacts, microphone or precise location. Device motion is used locally to move ingredients on the home screen; it is not stored or sent to a server, and you can turn off Tilt gravity in Settings.")
                    section("Providers and international processing", "Supabase, Inc. provides account authentication and database hosting for Reffi, including storage of shared usage records. The project’s primary database is in Seoul, South Korea. Google LLC also processes messages sent to our Gmail contact address. These providers and their infrastructure and support providers may process information outside your country. The Seoul database location does not mean that all support, email delivery and security processing stays in South Korea. The other processing countries, recipients and contacts, transfer basis, and applicable retention periods are being verified before this policy takes effect.")
                    section("When you open YouTube", "Recipe video search opens YouTube only when you choose it. The search URL includes the displayed recipe or ingredient names, which can include names you entered yourself. YouTube receives that search query and handles the visit under Google’s privacy policy, including any account or browser information available to it. Reffi does not upload your full fridge or allergy list through this link. Skip video search if you do not want the search terms sent to YouTube.")
                    section("Retention and deletion", "Local fridge and profile data stay on this device until you remove them, reset the current account’s data, erase this device’s app data, or delete the app. Signing out keeps a separate local copy for that account. Erase this device clears local fridge and profile data for all accounts on the device and signs you out; it does not delete server accounts. Turning usage sharing off stops new optional records and clears unsent records. Previously sent records remain in the active database until account deletion or a completed deletion request. Delete account requests deletion of your server account and its usage records, then clears that account’s local fridge and profile after the server confirms success. If deletion fails, the app reports the failure. The current project does not have scheduled database backups. Provider security logs and privacy inquiry messages have separate retention and deletion procedures that are being verified before release. Copies in your device’s system backups are controlled by your backup settings. Removing the app alone does not delete a server account.")
                    section("Your privacy rights", "You may exercise applicable rights to access, correct or delete personal information, restrict processing, and withdraw optional consent, directly or through an authorized representative. You can edit local entries in the app, turn off usage sharing in Settings, and use the account and device deletion controls. Requests involving server records require the privacy email address listed above; limited identity verification may be needed to protect your information. Any refusal or restriction must have an applicable legal basis and be explained. You may also contact the data protection authority in your country.")
                    section("Security and recommendations", "The app uses encrypted HTTPS connections for server requests and separates local data by account. Server data access is restricted by authentication and database access rules. Recipe matching and receipt text recognition run on your device. This version does not send your fridge, allergy entries or receipt images to an external generative AI service or use them to train a Reffi AI model. Recommendations do not determine legal rights or access to essential services. Keep your device locked and review its backup settings to protect local information.")
                    section("Children’s privacy", "Reffi is a general-audience service and is not directed to children. It is not intended for children under 13 in the United States or under 14 in South Korea. We do not ask for birth dates or provide a guardian-consent flow in this version. If you believe a child has provided personal information to us, a parent or guardian can contact lee1993ljm@gmail.com. We will review the report, stop any processing that lacks a lawful basis, and delete the relevant information as required by applicable law. A statement that the service is not for children does not override children’s legal protections.")
                    section("Changes to this policy", "The final policy will state its effective date. Changes to the purposes, information collected, recipients or retention periods will be reflected here, with notice or separate consent where required by applicable law. This review copy has no effective date yet.")
                    VStack(alignment: .leading, spacing: ReffiSpace.s2) {
                        Text("Privacy resources").reffiType(.subhead).accessibilityAddTraits(.isHeader)
                        Link("Supabase service providers", destination: URL(string: "https://supabase.com/legal/customer-resources/subprocessor-list")!)
                            .frame(minHeight: 44, alignment: .leading)
                        Link("Google Privacy Policy", destination: URL(string: "https://policies.google.com/privacy")!)
                            .frame(minHeight: 44, alignment: .leading)
                        Link("Korea Privacy Portal", destination: URL(string: "https://www.privacy.go.kr")!)
                            .frame(minHeight: 44, alignment: .leading)
                    }
                    .reffiType(.caption)
                    .tint(ReffiColor.blueDark)
                }
                .padding(ReffiSpace.s5)
                .frame(maxWidth: 680, alignment: .leading)
                .frame(maxWidth: .infinity)
                .textSelection(.enabled)
            }
            .accessibilityIdentifier("privacy.content")
            .background(PaperCanvasBackground())
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func section(_ title: LocalizedStringKey, _ text: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: ReffiSpace.s3) {
            Text(title).reffiType(.subhead).accessibilityAddTraits(.isHeader)
            Text(text).reffiType(.body).foregroundStyle(ReffiColor.ink2)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
