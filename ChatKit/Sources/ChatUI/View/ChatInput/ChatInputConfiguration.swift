//
//  ChatInputConfiguration.swift
//  ChatUI
//

import UIKit

public struct ChatInputPermissionPresentation: Equatable {
    public var title: String
    public var systemImageName: String

    public init(title: String, systemImageName: String) {
        self.title = title
        self.systemImageName = systemImageName
    }
}

public struct ChatInputContextUsagePresentation: Equatable {
    public var usedFraction: CGFloat
    public var accessibilityLabel: String

    public init(usedFraction: CGFloat, accessibilityLabel: String) {
        self.usedFraction = usedFraction
        self.accessibilityLabel = accessibilityLabel
    }
}

/// Configuration for the chat input view behavior and contents.
@MainActor
public struct ChatInputConfiguration {
    public var pasteLargeTextAsFile: Bool
    public var compressImage: Bool
    public var quickSettingItems: [QuickSettingItem]
    public var controlPanelItems: [ControlPanelItem]
    public var permissionPresentation: ChatInputPermissionPresentation?
    public var contextUsagePresentation: ChatInputContextUsagePresentation?

    public static let `default` = ChatInputConfiguration()

    public init(
        pasteLargeTextAsFile: Bool = true,
        compressImage: Bool = true,
        quickSettingItems: [QuickSettingItem] = [],
        controlPanelItems: [ControlPanelItem] = ControlPanelItem.defaults,
        permissionPresentation: ChatInputPermissionPresentation? = nil,
        contextUsagePresentation: ChatInputContextUsagePresentation? = nil
    ) {
        self.pasteLargeTextAsFile = pasteLargeTextAsFile
        self.compressImage = compressImage
        self.quickSettingItems = quickSettingItems
        self.controlPanelItems = controlPanelItems
        self.permissionPresentation = permissionPresentation
        self.contextUsagePresentation = contextUsagePresentation
    }
}
