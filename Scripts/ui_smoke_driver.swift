#!/usr/bin/env swift

import Foundation
#if canImport(AppKit)
import AppKit
import ApplicationServices

enum UISmokeError: Error, CustomStringConvertible, Equatable {
    case accessibilityPermissionRequired
    case appNotFound
    case windowNotFound
    case elementNotFound(String)
    case actionFailed(String)
    case invalidState(String)

    var description: String {
        switch self {
        case .accessibilityPermissionRequired:
            return "Accessibility permission is required for AX automation"
        case .appNotFound:
            return "SmetaApp process is not running"
        case .windowNotFound:
            return "No visible window found"
        case .elementNotFound(let id):
            return "Element not found: \(id)"
        case .actionFailed(let msg):
            return "Action failed: \(msg)"
        case .invalidState(let msg):
            return "Invalid state: \(msg)"
        }
    }
}

let mode = CommandLine.arguments.dropFirst().first ?? "operational"

func hasAccessibilityPermission() -> Bool {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
    return AXIsProcessTrustedWithOptions(options)
}

func runningApp() -> NSRunningApplication? {
    NSRunningApplication.runningApplications(withBundleIdentifier: "SmetaApp").first
        ?? NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == "SmetaApp" })
}

func axApp(for processIdentifier: pid_t) -> AXUIElement {
    AXUIElementCreateApplication(processIdentifier)
}

func copyAttribute(_ element: AXUIElement, name: String) -> AnyObject? {
    var value: CFTypeRef?
    let status = AXUIElementCopyAttributeValue(element, name as CFString, &value)
    guard status == .success else { return nil }
    return value
}

func identifier(of element: AXUIElement) -> String? {
    copyAttribute(element, name: kAXIdentifierAttribute as String) as? String
}

func role(of element: AXUIElement) -> String? {
    copyAttribute(element, name: kAXRoleAttribute as String) as? String
}

func children(of element: AXUIElement) -> [AXUIElement] {
    (copyAttribute(element, name: kAXChildrenAttribute as String) as? [AXUIElement]) ?? []
}

func windows(of appElement: AXUIElement) -> [AXUIElement] {
    (copyAttribute(appElement, name: kAXWindowsAttribute as String) as? [AXUIElement]) ?? []
}

func currentWindow(of appElement: AXUIElement) -> AXUIElement? {
    windows(of: appElement).first(where: visible(of:)) ?? windows(of: appElement).first
}

func visible(of element: AXUIElement) -> Bool {
    (copyAttribute(element, name: kAXVisibleAttribute as String) as? Bool) ?? true
}

func value(of element: AXUIElement) -> String? {
    if let direct = copyAttribute(element, name: kAXValueAttribute as String) as? String {
        return direct
    }
    if let title = copyAttribute(element, name: kAXTitleAttribute as String) as? String {
        return title
    }
    return nil
}

func findElements(root: AXUIElement, where predicate: (AXUIElement) -> Bool) -> [AXUIElement] {
    var queue: [AXUIElement] = [root]
    var matched: [AXUIElement] = []
    while !queue.isEmpty {
        let current = queue.removeFirst()
        if predicate(current) {
            matched.append(current)
        }
        queue.append(contentsOf: children(of: current))
    }
    return matched
}

func findElement(root: AXUIElement, identifier target: String) -> AXUIElement? {
    findElements(root: root) { identifier(of: $0) == target }.first
}

func findButtonWithPrefix(root: AXUIElement, prefix: String, excluding: String) -> AXUIElement? {
    findElements(root: root) { element in
        guard role(of: element) == kAXButtonRole as String else { return false }
        guard let id = identifier(of: element), id.hasPrefix(prefix) else { return false }
        return id != "\(prefix)\(excluding)"
    }.first
}

func press(_ element: AXUIElement) throws {
    let status = AXUIElementPerformAction(element, kAXPressAction as CFString)
    guard status == .success else {
        throw UISmokeError.actionFailed("AXPress failed with status \(status.rawValue)")
    }
}

func waitUntil(timeout: TimeInterval, poll: TimeInterval = 0.2, condition: () -> Bool) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return true }
        RunLoop.current.run(until: Date().addingTimeInterval(poll))
    }
    return condition()
}

func textValue(root: AXUIElement, identifier target: String) -> String? {
    guard let element = findElement(root: root, identifier: target) else { return nil }
    return value(of: element)
}

func waitForElement(appElement: AXUIElement, identifier target: String, timeout: TimeInterval) -> AXUIElement? {
    let found = waitUntil(timeout: timeout) {
        guard let window = currentWindow(of: appElement) else { return false }
        return findElement(root: window, identifier: target) != nil
    }
    guard found, let window = currentWindow(of: appElement) else { return nil }
    return findElement(root: window, identifier: target)
}

func runOperational() throws {
    guard let app = runningApp() else { throw UISmokeError.appNotFound }
    app.activate(options: [.activateIgnoringOtherApps])

    let appElement = axApp(for: app.processIdentifier)
    let hasWindow = waitUntil(timeout: 20) {
        windows(of: appElement).contains(where: visible(of:))
    }
    guard hasWindow else { throw UISmokeError.windowNotFound }
    guard let window = currentWindow(of: appElement) else {
        throw UISmokeError.windowNotFound
    }

    guard findElement(root: window, identifier: "smoke.operational.marker") != nil else {
        throw UISmokeError.elementNotFound("smoke.operational.marker")
    }

    guard let selectedBeforeRaw = textValue(root: window, identifier: "smoke.selectedProject"),
          let selectedBefore = selectedBeforeRaw.split(separator: ":").last.map(String.init) else {
        throw UISmokeError.invalidState("selected project marker missing")
    }

    guard let navProjects = waitForElement(appElement: appElement, identifier: "smoke.nav.projects", timeout: 8) else {
        throw UISmokeError.elementNotFound("smoke.nav.projects")
    }
    try press(navProjects)
    guard waitUntil(timeout: 8, condition: {
        guard let activeWindow = currentWindow(of: appElement) else { return false }
        return findElements(root: activeWindow) { element in
            guard role(of: element) == kAXButtonRole as String else { return false }
            guard let id = identifier(of: element) else { return false }
            return id.hasPrefix("smoke.project.select.")
        }.isEmpty == false
    }) else {
        throw UISmokeError.invalidState("Projects screen did not expose project-select actions in time")
    }

    let selectPrefix = "smoke.project.select."
    guard let projectsWindow = currentWindow(of: appElement),
          let selectOther = findButtonWithPrefix(root: projectsWindow, prefix: selectPrefix, excluding: selectedBefore) else {
        throw UISmokeError.elementNotFound("project-select button for alternate project")
    }
    try press(selectOther)

    let selectionChanged = waitUntil(timeout: 5) {
        guard let afterRaw = textValue(root: window, identifier: "smoke.selectedProject"),
              let after = afterRaw.split(separator: ":").last.map(String.init) else {
            return false
        }
        return after != selectedBefore
    }
    guard selectionChanged else {
        throw UISmokeError.invalidState("project selection did not change through UI")
    }

    guard let navCalculation = waitForElement(appElement: appElement, identifier: "smoke.nav.calculation", timeout: 8) else {
        throw UISmokeError.elementNotFound("smoke.nav.calculation")
    }
    try press(navCalculation)
    guard waitForElement(appElement: appElement, identifier: "smoke.calculate.run", timeout: 8) != nil else {
        throw UISmokeError.invalidState("Calculation screen did not expose calculate action in time")
    }

    guard let calculationWindow = currentWindow(of: appElement),
          let runCalculation = findElement(root: calculationWindow, identifier: "smoke.calculate.run") else {
        throw UISmokeError.elementNotFound("smoke.calculate.run")
    }
    try press(runCalculation)

    let hasRows = waitUntil(timeout: 6) {
        guard let rowsRaw = textValue(root: window, identifier: "smoke.calculationRows"),
              let rows = Int(rowsRaw.split(separator: ":").last ?? "0") else {
            return false
        }
        return rows > 0
    }
    guard hasRows else {
        throw UISmokeError.invalidState("calculation did not produce rows through UI path")
    }
}

func runControlledFailure() throws {
    guard let app = runningApp() else { throw UISmokeError.appNotFound }
    app.activate(options: [.activateIgnoringOtherApps])

    let appElement = axApp(for: app.processIdentifier)
    let hasWindow = waitUntil(timeout: 20) {
        windows(of: appElement).contains(where: visible(of:))
    }
    guard hasWindow else { throw UISmokeError.windowNotFound }

    guard let window = currentWindow(of: appElement) else {
        throw UISmokeError.windowNotFound
    }
    guard waitUntil(timeout: 8, condition: {
        guard let activeWindow = currentWindow(of: appElement) else { return false }
        return findElement(root: activeWindow, identifier: "smoke.startup.failure.title") != nil
    }) else {
        throw UISmokeError.elementNotFound("smoke.startup.failure.title")
    }
    if findElement(root: window, identifier: "smoke.operational.marker") != nil {
        throw UISmokeError.invalidState("operational marker is visible on controlled failure screen")
    }
}

do {
    guard hasAccessibilityPermission() else {
        throw UISmokeError.accessibilityPermissionRequired
    }
    switch mode {
    case "controlled_failure":
        try runControlledFailure()
        print("SMETA_UI_SMOKE verdict=PASS classification=controlled_launch_failure")
    default:
        try runOperational()
        print("SMETA_UI_SMOKE verdict=PASS classification=operational_runtime_success")
    }
    fflush(stdout)
    exit(0)
} catch {
    if let smokeError = error as? UISmokeError, smokeError == .accessibilityPermissionRequired {
        print("SMETA_UI_SMOKE verdict=BLOCKED classification=accessibility_permission_required details=\(smokeError)")
        fflush(stdout)
        exit(3)
    }
    print("SMETA_UI_SMOKE verdict=FAIL classification=\(mode) details=\(error)")
    fflush(stdout)
    exit(1)
}
#else
print("SMETA_UI_SMOKE verdict=FAIL classification=unsupported_platform details=ui smoke driver requires macOS")
exit(2)
#endif
