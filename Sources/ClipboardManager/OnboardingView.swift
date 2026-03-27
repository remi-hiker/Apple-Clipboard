import SwiftUI
import AppKit

/// Three-step first-launch tutorial shown once to new users.
struct OnboardingView: View {

    @State private var step = 0
    @State private var accessibilityGranted = AXIsProcessTrusted()

    let onComplete: () -> Void

    // Poll accessibility status while the user is on that step.
    private let ticker = Timer.publish(every: 0.8, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            stepContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.25), value: step)

            Divider()
            bottomBar
        }
        .frame(width: 500, height: 400)
        .background(Color(.windowBackgroundColor))
        .onReceive(ticker) { _ in
            if step == 1 { accessibilityGranted = AXIsProcessTrusted() }
        }
    }

    // MARK: - Step pages

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0:  welcomePage
        case 1:  accessibilityPage
        default: readyPage
        }
    }

    private var welcomePage: some View {
        VStack(spacing: 20) {
            Image(systemName: "clipboard.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            Text("Welcome to Clipboard Manager")
                .font(.title2.bold())

            Text("Keep your last 25 copied items — text, images, and files — always within reach. One click pastes directly into whatever you're working on.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            HStack(spacing: 32) {
                featurePill(icon: "clock", label: "25-item history")
                featurePill(icon: "pin.fill", label: "Pin favourites")
                featurePill(icon: "magnifyingglass", label: "Search instantly")
            }
            .padding(.top, 4)
        }
        .padding(40)
    }

    private var accessibilityPage: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(accessibilityGranted ? Color.green.opacity(0.12) : Color.orange.opacity(0.12))
                    .frame(width: 88, height: 88)
                Image(systemName: accessibilityGranted ? "checkmark.shield.fill" : "hand.raised.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(accessibilityGranted ? .green : .orange)
            }

            Text("Enable Accessibility Access")
                .font(.title2.bold())

            Text(accessibilityGranted
                 ? "Access granted — you're good to go."
                 : "Clipboard Manager needs Accessibility permission to paste items directly into your apps. Your data never leaves your Mac.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            if !accessibilityGranted {
                Button("Open System Settings") {
                    NSWorkspace.shared.open(
                        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                    )
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(40)
    }

    private var readyPage: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)

            Text("You're all set!")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 12) {
                instructionRow(
                    icon: "keyboard",
                    title: "Open the panel",
                    detail: "Press ⌘⇧: from any app")
                instructionRow(
                    icon: "cursorarrow.click",
                    title: "Paste instantly",
                    detail: "Click any item — it pastes straight into your last active app")
                instructionRow(
                    icon: "pin.fill",
                    title: "Pin what matters",
                    detail: "Hover an item and tap the pin to keep it forever")
            }
            .padding(.horizontal, 8)
        }
        .padding(40)
    }

    // MARK: - Bottom navigation bar

    private var bottomBar: some View {
        HStack {
            // Step dots
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(i == step ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 7, height: 7)
                }
            }

            Spacer()

            if step > 0 {
                Button("Back") { step -= 1 }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
            }

            Button(step < 2 ? "Next" : "Get Started") {
                if step < 2 { step += 1 } else { onComplete() }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: [])
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 16)
    }

    // MARK: - Helpers

    private func featurePill(icon: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(.tint)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func instructionRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.medium))
                Text(detail).font(.callout).foregroundColor(.secondary)
            }
        }
    }
}
