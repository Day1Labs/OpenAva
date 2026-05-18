#if targetEnvironment(macCatalyst)
    import Foundation
    import UIKit

    enum CatalystGlobalCommand: String {
        case openModelSettings
        case focusInput
        case openWorkspace
        case openRecentWorkspace
    }

    extension Notification.Name {
        static let openAvaCatalystGlobalCommand = Notification.Name("openAva.catalyst.globalCommand")
    }

    enum CatalystGlobalCommandCenter {
        static let workspaceIDUserInfoKey = "workspaceID"
        private static let sceneIDUserInfoKey = "sceneID"
        private static var activeSceneID: String?

        static func markActive(sceneID: String) {
            activeSceneID = sceneID
        }

        static func post(_ command: CatalystGlobalCommand, workspaceID: UUID? = nil) {
            var userInfo: [String: Any] = ["command": command.rawValue]
            if let workspaceID {
                userInfo[workspaceIDUserInfoKey] = workspaceID.uuidString
            }
            if let activeSceneID {
                userInfo[sceneIDUserInfoKey] = activeSceneID
            }

            NotificationCenter.default.post(
                name: .openAvaCatalystGlobalCommand,
                object: nil,
                userInfo: userInfo
            )
        }

        static func resolve(_ notification: Notification) -> CatalystGlobalCommand? {
            guard let rawValue = notification.userInfo?["command"] as? String,
                  let command = CatalystGlobalCommand(rawValue: rawValue)
            else {
                return nil
            }
            return command
        }

        static func workspaceID(from notification: Notification) -> UUID? {
            guard let rawValue = notification.userInfo?[workspaceIDUserInfoKey] as? String else {
                return nil
            }
            return UUID(uuidString: rawValue)
        }

        static func targetsScene(_ sceneID: String, notification: Notification) -> Bool {
            guard let targetSceneID = notification.userInfo?[sceneIDUserInfoKey] as? String else {
                return true
            }
            return targetSceneID == sceneID
        }
    }

    extension AppDelegate {
        override func buildMenu(with builder: UIMenuBuilder) {
            super.buildMenu(with: builder)
            guard builder.system == .main else { return }

            configureOpenAvaMainMenu(with: builder)
        }

        private func configureOpenAvaMainMenu(with builder: UIMenuBuilder) {
            removeUnsupportedDefaultMenus(with: builder)
            builder.replace(menu: .file, with: buildWorkspaceMenu())
            builder.replace(menu: .view, with: buildChatMenu())
            builder.insertSibling(buildSettingsMenu(), afterMenu: .preferences)
        }

        private func removeUnsupportedDefaultMenus(with builder: UIMenuBuilder) {
            [
                UIMenu.Identifier.edit,
                .format,
                .help,
                .services,
            ].forEach { identifier in
                builder.remove(menu: identifier)
            }
        }

        private func buildWorkspaceMenu() -> UIMenu {
            let recentMenu = buildOpenRecentMenu()
            var children: [UIMenuElement] = [
                UIKeyCommand(
                    title: "Open Workspace...",
                    action: #selector(handleOpenWorkspaceFromMenu(_:)),
                    input: "o",
                    modifierFlags: .command
                ),
            ]
            if let recentMenu {
                children.append(recentMenu)
            }

            return UIMenu(
                title: "Workspace",
                identifier: .file,
                children: children
            )
        }

        private func buildChatMenu() -> UIMenu {
            UIMenu(
                title: "Chat",
                identifier: .view,
                children: [
                    UIKeyCommand(
                        title: L10n.tr("chat.command.focusInput"),
                        action: #selector(handleFocusInputFromMenu(_:)),
                        input: "l",
                        modifierFlags: .command
                    ),
                ]
            )
        }

        private func buildSettingsMenu() -> UIMenu {
            UIMenu(
                title: "",
                options: .displayInline,
                children: [
                    UIKeyCommand(
                        title: L10n.tr("settings.llm.navigationTitle"),
                        image: UIImage(systemName: "cpu"),
                        action: #selector(handleOpenModelSettingsFromMenu(_:)),
                        input: ",",
                        modifierFlags: .command
                    ),
                ]
            )
        }

        private func buildOpenRecentMenu() -> UIMenu? {
            let workspaceState = ProjectWorkspaceStore.load()
            let recentCommands = workspaceState.workspaces
                .sorted { lhs, rhs in
                    if lhs.lastAccessedAtMs != rhs.lastAccessedAtMs {
                        return lhs.lastAccessedAtMs > rhs.lastAccessedAtMs
                    }
                    return lhs.resolvedName.localizedStandardCompare(rhs.resolvedName) == .orderedAscending
                }
                .map { workspace in
                    UICommand(
                        title: workspace.resolvedName,
                        subtitle: workspace.displayPath,
                        action: #selector(handleOpenRecentWorkspaceFromMenu(_:)),
                        propertyList: workspace.id.uuidString,
                        state: workspace.id == workspaceState.activeWorkspaceID ? .on : .off
                    )
                }

            guard !recentCommands.isEmpty else { return nil }

            return UIMenu(
                title: "Open Recent",
                identifier: UIMenu.Identifier("openAva.openRecentWorkspaces"),
                children: recentCommands
            )
        }

        @objc private func handleOpenModelSettingsFromMenu(_: Any?) {
            CatalystGlobalCommandCenter.post(.openModelSettings)
        }

        @objc private func handleFocusInputFromMenu(_: Any?) {
            CatalystGlobalCommandCenter.post(.focusInput)
        }

        @objc private func handleOpenWorkspaceFromMenu(_: Any?) {
            CatalystGlobalCommandCenter.post(.openWorkspace)
        }

        @objc private func handleOpenRecentWorkspaceFromMenu(_ sender: UICommand) {
            guard let rawWorkspaceID = sender.propertyList as? String,
                  let workspaceID = UUID(uuidString: rawWorkspaceID)
            else {
                return
            }
            CatalystGlobalCommandCenter.post(.openRecentWorkspace, workspaceID: workspaceID)
        }
    }
#endif
