// ShieldConfigurationExtension.swift
// Kzu — Custom shield overlay UI

import ManagedSettingsUI
import ManagedSettings
import UIKit

// MARK: - Shield Configuration Extension

/// Provides a custom-branded shield overlay that appears when the child
/// tries to open a blocked app during a LEARNING_BLOCK.
///
/// Instead of the generic Screen Time shield, this shows Kzu-branded
/// messaging that encourages the child to return to their flow.
class KzuShieldConfiguration: ShieldConfigurationDataSource {

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        buildShieldConfig(
            title: "You're in the Flow! 🧘",
            subtitle: "Return to Kzu to continue your learning journey.\nGreat things are built with focus."
        )
    }

    override func configuration(
        shielding application: Application,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        buildShieldConfig(
            title: "Stay in Your Flow ✨",
            subtitle: "This app is resting while you learn.\nYou'll unlock the Game Hub soon!"
        )
    }

    override func configuration(
        shielding webDomain: WebDomain
    ) -> ShieldConfiguration {
        buildShieldConfig(
            title: "Focus Time 🎯",
            subtitle: "This site will be available after your learning block.\nKeep going — you're doing great!"
        )
    }

    override func configuration(
        shielding webDomain: WebDomain,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        buildShieldConfig(
            title: "Focus Time 🎯",
            subtitle: "Return to Kzu.\nYour break is just around the corner."
        )
    }

    // MARK: - Build Config

    private func buildShieldConfig(title: String, subtitle: String) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterial,
            backgroundColor: UIColor(red: 0.98, green: 0.96, blue: 0.92, alpha: 1.0),
            icon: nil,  // Uses app icon
            title: ShieldConfiguration.Label(
                text: title,
                color: UIColor(red: 0.10, green: 0.12, blue: 0.22, alpha: 1.0)
            ),
            subtitle: ShieldConfiguration.Label(
                text: subtitle,
                color: UIColor(red: 0.18, green: 0.22, blue: 0.36, alpha: 1.0)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Return to Kzu",
                color: UIColor(red: 0.98, green: 0.96, blue: 0.92, alpha: 1.0)
            ),
            primaryButtonBackgroundColor: UIColor(red: 0.10, green: 0.12, blue: 0.22, alpha: 1.0),
            secondaryButtonLabel: nil
        )
    }
}
