import ServiceManagement

@MainActor
enum LaunchAtLoginController {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var statusMessage: String {
        switch SMAppService.mainApp.status {
        case .enabled:
            return "Tempura opens automatically when you log in."
        case .notRegistered:
            return "Start Tempura automatically after you sign in."
        case .requiresApproval:
            return "Allow Tempura in System Settings to finish enabling this."
        case .notFound:
            return "Install Tempura in Applications to enable this."
        @unknown default:
            return "Open at Login status is unavailable."
        }
    }

    static func setEnabled(_ enabled: Bool) throws {
        let service = SMAppService.mainApp

        if enabled {
            if service.status != .enabled {
                try service.register()
            }
        } else if service.status == .enabled || service.status == .requiresApproval {
            try service.unregister()
        }
    }
}
