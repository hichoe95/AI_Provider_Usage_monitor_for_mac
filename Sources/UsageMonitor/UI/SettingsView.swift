import SwiftUI
import UsageMonitorCore

struct SettingsView: View {
    @StateObject private var settings = SettingsStore()
    @State private var openRouterKey: String = ""
    @State private var saveState: SaveState = .idle

    private enum SaveState {
        case idle, saving, saved, error
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                GroupBox(label: Label("Providers", systemImage: "bolt.fill")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Claude Code", isOn: $settings.claudeEnabled)
                        Toggle("Codex (OpenAI)", isOn: $settings.codexEnabled)
                        Toggle("Copilot (GitHub)", isOn: $settings.copilotEnabled)
                        Toggle("Gemini", isOn: $settings.geminiEnabled)
                        Toggle("OpenRouter", isOn: $settings.openRouterEnabled)
                    }
                    .padding(.top, 4)
                }

                GroupBox(label: Label("Refresh Interval", systemImage: "arrow.clockwise")) {
                    Picker("", selection: $settings.refreshInterval) {
                        Text("1 min").tag(60)
                        Text("5 min").tag(300)
                        Text("15 min").tag(900)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .padding(.top, 4)
                }

                GroupBox(label: Label("Menu Bar", systemImage: "menubar.rectangle")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Show all providers in menu bar", isOn: $settings.statusBarDetailedView)
                        Text("Displays icons with usage bars for each enabled provider.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.top, 4)
                }

                GroupBox(label: Label("Notifications", systemImage: "bell.badge")) {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Enable usage alerts", isOn: $settings.notificationsEnabled)

                        if settings.notificationsEnabled {
                            Divider()
                            Text("Claude").font(.callout).fontWeight(.semibold)
                            thresholdRow("5h limit", value: $settings.claude5hThreshold,
                                         range: 0...100, step: 5,
                                         display: "\(Int(settings.claude5hThreshold))%")
                            thresholdRow("7d limit", value: $settings.claude7dThreshold,
                                         range: 0...100, step: 5,
                                         display: "\(Int(settings.claude7dThreshold))%")
                            Divider()
                            Text("Codex").font(.callout).fontWeight(.semibold)
                            thresholdRow("5h limit", value: $settings.codex5hThreshold,
                                         range: 0...100, step: 5,
                                         display: "\(Int(settings.codex5hThreshold))%")
                            thresholdRow("7d limit", value: $settings.codex7dThreshold,
                                         range: 0...100, step: 5,
                                         display: "\(Int(settings.codex7dThreshold))%")
                            Divider()
                            Text("Copilot").font(.callout).fontWeight(.semibold)
                            thresholdRow("5h limit", value: $settings.copilot5hThreshold,
                                         range: 0...100, step: 5,
                                         display: "\(Int(settings.copilot5hThreshold))%")
                            thresholdRow("7d limit", value: $settings.copilot7dThreshold,
                                         range: 0...100, step: 5,
                                         display: "\(Int(settings.copilot7dThreshold))%")
                            Divider()
                            Text("Gemini").font(.callout).fontWeight(.semibold)
                            thresholdRow("5h limit", value: $settings.gemini5hThreshold,
                                         range: 0...100, step: 5,
                                         display: "\(Int(settings.gemini5hThreshold))%")
                            thresholdRow("7d limit", value: $settings.gemini7dThreshold,
                                         range: 0...100, step: 5,
                                         display: "\(Int(settings.gemini7dThreshold))%")
                            Divider()
                            thresholdRow("OpenRouter", value: $settings.openRouterThreshold,
                                         range: 0...50, step: 1,
                                         display: "< $\(String(format: "%.0f", settings.openRouterThreshold))")
                        }
                    }
                    .padding(.top, 4)
                }

                GroupBox(label: Label("Provider Limits", systemImage: "slider.horizontal.3")) {
                    VStack(alignment: .leading, spacing: 8) {
                        thresholdRow("Copilot monthly requests", value: $settings.copilotMonthlyRequestLimit,
                                     range: 50...3000, step: 50,
                                     display: "\(Int(settings.copilotMonthlyRequestLimit))")
                        Text("Copilot gauge % is normalized by this monthly request allowance.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.top, 4)
                }

                GroupBox(label: Label("API Key", systemImage: "key.fill")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("OpenRouter requires an API key.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        HStack(spacing: 8) {
                            SecureField("sk-or-v1-...", text: $openRouterKey)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit { saveOpenRouterKey() }

                            Button(action: { saveOpenRouterKey() }) {
                                Group {
                                    switch saveState {
                                    case .idle: Text("Save")
                                    case .saving: ProgressView().controlSize(.small)
                                    case .saved: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                    case .error: Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                                    }
                                }
                                .frame(width: 50)
                            }
                            .disabled(openRouterKey.isEmpty || saveState == .saving)
                        }
                        if saveState == .saved {
                            Text("Saved to Keychain").font(.caption).foregroundStyle(.green)
                        }
                        if saveState == .error {
                            Text("Failed to save").font(.caption).foregroundStyle(.red)
                        }
                        Divider().padding(.top, 4)
                        Text("Copilot auth: GH_TOKEN/GITHUB_TOKEN or ~/.copilot login session")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text("Gemini auth: GEMINI_API_KEY/GOOGLE_API_KEY or ~/.gemini OAuth session")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(16)
        }
        .frame(width: 420, height: 700)
        .onAppear {
            if settings.openRouterEnabled {
                loadOpenRouterKey()
            }
        }
        .onChange(of: settings.openRouterEnabled) { _, enabled in
            if enabled {
                loadOpenRouterKey()
            } else {
                openRouterKey = ""
                saveState = .idle
            }
        }
        .onDisappear {
            if !openRouterKey.isEmpty && saveState != .saved {
                saveOpenRouterKey()
            }
        }
    }

    private func thresholdRow(_ label: String, value: Binding<Double>,
                              range: ClosedRange<Double>, step: Double,
                              display: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label).font(.callout)
                Spacer()
                Text(display)
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: step)
                .controlSize(.small)
        }
    }

    private func saveOpenRouterKey() {
        guard !openRouterKey.isEmpty else { return }
        saveState = .saving
        Task {
            do {
                try await KeychainHelper.save(value: openRouterKey, for: "openrouter-api-key")
                saveState = .saved
                NotificationCenter.default.post(name: .credentialsDidChange, object: nil)
                try? await Task.sleep(for: .seconds(3))
                if saveState == .saved {
                    saveState = .idle
                }
            } catch {
                saveState = .error
            }
        }
    }

    private func loadOpenRouterKey() {
        Task {
            if let savedKey = try? await KeychainHelper.read(key: "openrouter-api-key") {
                openRouterKey = savedKey
            }
        }
    }
}

extension Notification.Name {
    static let credentialsDidChange = Notification.Name("credentialsDidChange")
}

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
#endif
