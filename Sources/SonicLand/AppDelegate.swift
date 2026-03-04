import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var windowManager: WindowManager!
    private var monitorManager: MonitorManager!
    private var workspaceManager: WorkspaceManager!
    private var layoutEngine: LayoutEngine!
    private var inputManager: InputManager!
    private var animationEngine: AnimationEngine!
    private var ruleEngine: RuleEngine!
    private var configParser: ConfigParser!
    private var configWatcher: ConfigWatcher!
    private var ipcServer: IPCServer!
    private var pluginManager: PluginManager!
    private var tickLoop: TickLoop!
    private var isBootstrapping = false
    private var currentTilingMode: TilingMode = .sharedSpace
    private var tilingModeMenuItems: [TilingMode: NSMenuItem] = [:]
    private var isTilingEnabled = true
    private var toggleMenuItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard Permissions.ensureAccessibility() else {
            NSLog("[SonicLand] Accessibility permission not granted. Exiting.")
            NSApp.terminate(nil)
            return
        }

        NSLog("[SonicLand] Accessibility permission granted. Starting up...")

        setupStatusBar()
        initializeSubsystems()

        NSLog("[SonicLand] All subsystems initialized. SonicLand is running.")
    }

    func applicationWillTerminate(_ notification: Notification) {
        NSLog("[SonicLand] Shutting down...")
        tickLoop?.stop()
        ipcServer?.stop()
        inputManager?.stop()
        configWatcher?.stop()
    }

    // MARK: - Status Bar

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }

        // Create a small tiling-grid template image for the menu bar
        let iconSize: CGFloat = 18
        let img = NSImage(size: NSSize(width: iconSize, height: iconSize), flipped: false) { rect in
            let inset: CGFloat = 2
            let gap: CGFloat = 2
            let area = rect.insetBy(dx: inset, dy: inset)
            let splitX = area.minX + area.width * 0.55
            let splitY = area.minY + area.height * 0.45

            NSColor.black.setFill()

            // Left tile
            let left = NSRect(x: area.minX, y: area.minY, width: splitX - area.minX - gap / 2, height: area.height)
            NSBezierPath(roundedRect: left, xRadius: 1.5, yRadius: 1.5).fill()

            // Top-right tile
            let topRight = NSRect(x: splitX + gap / 2, y: splitY + gap / 2, width: area.maxX - splitX - gap / 2, height: area.maxY - splitY - gap / 2)
            NSBezierPath(roundedRect: topRight, xRadius: 1.5, yRadius: 1.5).fill()

            // Bottom-right tile
            let bottomRight = NSRect(x: splitX + gap / 2, y: area.minY, width: area.maxX - splitX - gap / 2, height: splitY - area.minY - gap / 2)
            NSBezierPath(roundedRect: bottomRight, xRadius: 1.5, yRadius: 1.5).fill()

            return true
        }
        img.isTemplate = true
        button.image = img

        let menu = NSMenu()

        // Monitor Mode submenu
        let modeSubmenu = NSMenu()
        for mode in TilingMode.allCases {
            let item = NSMenuItem(title: mode.menuTitle, action: #selector(tilingModeSelected(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode.rawValue
            if mode == currentTilingMode {
                item.state = .on
            }
            modeSubmenu.addItem(item)
            tilingModeMenuItems[mode] = item
        }
        let modeItem = NSMenuItem(title: "Monitor Mode", action: nil, keyEquivalent: "")
        modeItem.submenu = modeSubmenu
        menu.addItem(modeItem)

        menu.addItem(NSMenuItem.separator())

        toggleMenuItem = NSMenuItem(title: "Disable Tiling", action: #selector(toggleTiling), keyEquivalent: "")
        toggleMenuItem.target = self
        menu.addItem(toggleMenuItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(
            title: "Quit SonicLand",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        statusItem.menu = menu
    }

    // MARK: - Subsystems

    private func initializeSubsystems() {
        // Load config first
        configParser = ConfigParser()
        let config = configParser.loadConfig()

        // Core managers — monitors and workspaces MUST be ready before window bootstrap
        monitorManager = MonitorManager()
        monitorManager.refresh()

        // Load tiling mode: UserDefaults first, then derive from config
        if let savedRaw = UserDefaults.standard.string(forKey: TilingMode.defaultsKey),
           let saved = TilingMode(rawValue: savedRaw) {
            currentTilingMode = saved
        } else {
            currentTilingMode = TilingMode.from(configMonitor: config.general.monitor)
        }
        NSLog("[SonicLand] Tiling mode: \(currentTilingMode.menuTitle)")

        // Only create workspaces for tiling-eligible monitors
        let tilingMonitors = monitorManager.tilingMonitors(filter: currentTilingMode.monitorFilter)
        NSLog("[SonicLand] Tiling on \(tilingMonitors.count) monitor(s) (filter: \(currentTilingMode.monitorFilter)):")
        for m in tilingMonitors {
            NSLog("[SonicLand]   \(m.name)")
        }

        workspaceManager = WorkspaceManager(monitorManager: monitorManager)
        for monitor in tilingMonitors {
            workspaceManager.ensureDefaultWorkspace(for: monitor.id)
        }

        windowManager = WindowManager()
        layoutEngine = LayoutEngine(config: config)
        animationEngine = AnimationEngine(config: config)
        ruleEngine = RuleEngine(config: config)

        // Suppress relayout during bootstrap
        isBootstrapping = true
        windowManager.delegate = self
        windowManager.bootstrap()
        isBootstrapping = false

        // Determine which monitor IDs are tiling-eligible
        let tilingMonitorIDs = Set(tilingMonitors.map { $0.id })

        // Assign all windows to their monitor's active workspace
        // Group tiled windows by workspace
        var windowsByWorkspace: [Int: [CGWindowID]] = [:]

        for window in windowManager.allWindows {
            ruleEngine.applyRules(to: window, workspaceManager: workspaceManager)

            // Find which monitor this window is on
            let windowMonitor = monitorManager.monitorContaining(rect: window.frame)
            let onTilingMonitor = windowMonitor.map { tilingMonitorIDs.contains($0.id) } ?? false

            if !onTilingMonitor {
                window.isFloating = true
                window.isModeFloated = true
            }

            // Assign to the active workspace for the window's monitor
            if window.workspaceID == 0 {
                if let monitor = windowMonitor,
                   let wsID = workspaceManager.activeWorkspaceID(for: monitor.id) {
                    window.workspaceID = wsID
                } else {
                    window.workspaceID = workspaceManager.activeWorkspace?.id ?? 1
                }
            }

            if !window.isFloating && !window.isMinimized {
                workspaceManager.addWindow(window.windowID, to: window.workspaceID)
                windowsByWorkspace[window.workspaceID, default: []].append(window.windowID)
            }
        }

        // Build fresh BSP tree for each workspace that has windows
        for (wsID, windowIDs) in windowsByWorkspace {
            var tree = BSPTree()
            for wid in windowIDs {
                tree.insert(windowID: wid)
            }
            if var ws = workspaceManager.workspace(for: wsID) {
                ws.layoutTree = tree
                workspaceManager.updateWorkspace(ws)
            }
            NSLog("[SonicLand] Workspace \(wsID): \(windowIDs.count) tiled windows")
        }

        NSLog("[SonicLand] Total: \(windowManager.allWindows.count) windows")

        // Input
        inputManager = InputManager(config: config)
        inputManager.actionHandler = { [weak self] action in
            self?.handleAction(action)
        }
        inputManager.start()

        // IPC
        ipcServer = IPCServer()
        ipcServer.commandHandler = { [weak self] command in
            self?.handleIPCCommand(command) ?? IPCResponse(status: .error, message: "Not ready")
        }
        ipcServer.start()

        // Config watcher
        configWatcher = ConfigWatcher { [weak self] in
            self?.reloadConfig()
        }
        configWatcher.start()

        // Plugin system
        pluginManager = PluginManager()

        // Compute and APPLY the initial layout
        // Compute and apply layout
        recomputeAllLayouts()
        NSLog("[SonicLand] Initial layout applied.")

        // Tick loop at 10Hz — check for window drift and re-tile
        tickLoop = TickLoop(fps: 10) { [weak self] in
            self?.tick()
        }
        tickLoop.start()
    }

    // MARK: - Tick

    private func tick() {
        windowManager.refreshWindowStates()

        // Don't re-tile while user is dragging (mouse button held down)
        let mouseDown = NSEvent.pressedMouseButtons & 1 != 0
        if mouseDown { return }

        // Check if any tiled window has been dragged away from its target
        var needsRelayout = false

        for window in windowManager.allWindows where !window.isFloating && !window.isMinimized {
            guard window.hasDrifted else { continue }

            let dragCenter = CGPoint(x: window.frame.midX, y: window.frame.midY)

            // Check for swap with another window (works in all modes)
            var bestSwapID: CGWindowID?
            var bestDistance: CGFloat = .greatestFiniteMagnitude

            for other in windowManager.allWindows where other.windowID != window.windowID && !other.isFloating && !other.isMinimized {
                guard let otherTarget = other.targetFrame else { continue }

                if otherTarget.contains(dragCenter) {
                    let otherCenter = CGPoint(x: otherTarget.midX, y: otherTarget.midY)
                    let dist = hypot(dragCenter.x - otherCenter.x, dragCenter.y - otherCenter.y)
                    if dist < bestDistance {
                        bestDistance = dist
                        bestSwapID = other.windowID
                    }
                }
            }

            if let swapID = bestSwapID {
                // Swap in the dragged window's workspace tree
                if var ws = workspaceManager.workspace(for: window.workspaceID) {
                    ws.layoutTree.swapWindows(window.windowID, swapID)
                    workspaceManager.updateWorkspace(ws)
                    NSLog("[SonicLand] Swapped \(window.appName) with \(windowManager.window(for: swapID)?.appName ?? "?")")
                }
                // If target is in a different workspace (cross-monitor swap in shared space),
                // also swap in that workspace's tree
                if let other = windowManager.window(for: swapID),
                   other.workspaceID != window.workspaceID {
                    if var otherWS = workspaceManager.workspace(for: other.workspaceID) {
                        otherWS.layoutTree.swapWindows(window.windowID, swapID)
                        workspaceManager.updateWorkspace(otherWS)
                    }
                }
            }

            needsRelayout = true
            break
        }

        if needsRelayout {
            recomputeAllLayouts()
        }

        pluginManager.onTick()
    }

    // MARK: - Layout

    private func recomputeAllLayouts() {
        guard isTilingEnabled else { return }
        if currentTilingMode == .sharedSpace && monitorManager.monitors.count > 1 {
            recomputeSharedSpaceLayout()
            return
        }
        recomputePerWorkspaceLayouts()
    }

    private func recomputePerWorkspaceLayouts() {
        for var workspace in workspaceManager.allWorkspaces {
            guard workspace.isVisible else { continue }
            guard let monitor = monitorManager.monitor(for: workspace.monitorID) else { continue }

            // Rebuild BSP tree from current tiling-eligible windows in this workspace
            let tiledWindowIDs = workspace.windowIDs.filter { wid in
                guard let w = windowManager.window(for: wid) else { return false }
                return !w.isFloating && !w.isMinimized
            }

            guard !tiledWindowIDs.isEmpty else { continue }

            // Rebuild tree if it has stale windows or is missing windows
            let treeIDs = Set(workspace.layoutTree.root.allWindowIDs)
            let expectedIDs = Set(tiledWindowIDs)
            if treeIDs != expectedIDs {
                var newTree = BSPTree()
                for wid in tiledWindowIDs {
                    newTree.insert(windowID: wid)
                }
                workspace.layoutTree = newTree
                workspaceManager.updateWorkspace(workspace)
            }

            let frames = workspace.layoutTree.computeFrames(
                in: monitor.visibleFrame,
                gaps: GapConfig(inner: layoutEngine.gapsInner, outer: layoutEngine.gapsOuter)
            )

            for (windowID, targetFrame) in frames {
                guard let window = windowManager.window(for: windowID) else { continue }

                // Only move if significantly different
                let dx = abs(window.frame.origin.x - targetFrame.origin.x)
                let dy = abs(window.frame.origin.y - targetFrame.origin.y)
                let dw = abs(window.frame.size.width - targetFrame.size.width)
                let dh = abs(window.frame.size.height - targetFrame.size.height)

                if dx > 2 || dy > 2 || dw > 2 || dh > 2 {
                    AccessibilityWrapper.setWindowFrame(window.axElement, frame: targetFrame)
                }
                window.targetFrame = targetFrame
            }
        }
    }

    // MARK: - Actions

    private func handleAction(_ action: KeyAction) {
        switch action {
        case .focusLeft:
            focusDirection(.left)
        case .focusRight:
            focusDirection(.right)
        case .focusUp:
            focusDirection(.up)
        case .focusDown:
            focusDirection(.down)
        case .moveLeft:
            moveWindowDirection(.left)
        case .moveRight:
            moveWindowDirection(.right)
        case .moveUp:
            moveWindowDirection(.up)
        case .moveDown:
            moveWindowDirection(.down)
        case .switchWorkspace(let id):
            switchWorkspace(id)
        case .moveToWorkspace(let id):
            moveToWorkspace(id)
        case .toggleFloat:
            toggleFloat()
        case .toggleLayoutDirection:
            toggleLayoutDirection()
        case .reloadConfig:
            reloadConfig()
        }
    }

    private func focusDirection(_ direction: Direction) {
        guard let currentWS = workspaceManager.activeWorkspace,
              let focusedID = currentWS.focusedWindowID else { return }

        if let targetID = layoutEngine.findNeighbor(
            of: focusedID, direction: direction, in: currentWS.layoutTree
        ) {
            if let window = windowManager.window(for: targetID) {
                AccessibilityWrapper.focusWindow(window.axElement, pid: window.pid)
                workspaceManager.setFocusedWindow(targetID, in: currentWS.id)
            }
        }
    }

    private func moveWindowDirection(_ direction: Direction) {
        guard var currentWS = workspaceManager.activeWorkspace,
              let focusedID = currentWS.focusedWindowID else { return }

        layoutEngine.moveWindow(focusedID, direction: direction, in: &currentWS.layoutTree)
        workspaceManager.updateWorkspace(currentWS)
        recomputeAllLayouts()
    }

    private func switchWorkspace(_ id: Int) {
        guard let currentWS = workspaceManager.activeWorkspace else { return }
        if currentWS.id == id { return }

        // Hide current workspace windows
        for windowID in currentWS.windowIDs {
            if let window = windowManager.window(for: windowID) {
                AccessibilityWrapper.setWindowPosition(window.axElement, position: CGPoint(x: -10000, y: -10000))
            }
        }

        workspaceManager.switchTo(workspaceID: id)

        // Show target workspace windows
        if let targetWS = workspaceManager.activeWorkspace {
            for windowID in targetWS.windowIDs {
                if let window = windowManager.window(for: windowID) {
                    if let target = window.targetFrame {
                        AccessibilityWrapper.setWindowFrame(window.axElement, frame: target)
                    }
                }
            }
        }

        recomputeAllLayouts()
        pluginManager.onWorkspaceChanged(from: currentWS.id, to: id)
    }

    private func moveToWorkspace(_ id: Int) {
        guard let currentWS = workspaceManager.activeWorkspace,
              let focusedID = currentWS.focusedWindowID else { return }

        workspaceManager.moveWindow(windowID: focusedID, to: id)

        if var srcWS = workspaceManager.workspace(for: currentWS.id) {
            layoutEngine.removeWindow(focusedID, from: &srcWS.layoutTree)
            workspaceManager.updateWorkspace(srcWS)
        }

        if let window = windowManager.window(for: focusedID) {
            AccessibilityWrapper.setWindowPosition(window.axElement, position: CGPoint(x: -10000, y: -10000))
        }

        if var dstWS = workspaceManager.workspace(for: id) {
            layoutEngine.insertWindow(focusedID, into: &dstWS.layoutTree)
            workspaceManager.updateWorkspace(dstWS)
        }
        recomputeAllLayouts()
    }

    private func toggleFloat() {
        guard var currentWS = workspaceManager.activeWorkspace,
              let focusedID = currentWS.focusedWindowID,
              let window = windowManager.window(for: focusedID) else { return }

        window.isFloating.toggle()

        if window.isFloating {
            layoutEngine.removeWindow(focusedID, from: &currentWS.layoutTree)
        } else {
            layoutEngine.insertWindow(focusedID, into: &currentWS.layoutTree)
        }
        workspaceManager.updateWorkspace(currentWS)

        recomputeAllLayouts()
    }

    private func toggleLayoutDirection() {
        guard var currentWS = workspaceManager.activeWorkspace,
              let focusedID = currentWS.focusedWindowID else { return }

        layoutEngine.toggleSplitDirection(at: focusedID, in: &currentWS.layoutTree)
        workspaceManager.updateWorkspace(currentWS)
        recomputeAllLayouts()
    }

    @objc private func reloadConfig() {
        NSLog("[SonicLand] Reloading configuration...")
        let config = configParser.loadConfig()
        layoutEngine.updateConfig(config)
        inputManager.updateConfig(config)
        animationEngine.updateConfig(config)
        ruleEngine.updateConfig(config)
        recomputeAllLayouts()
        NSLog("[SonicLand] Configuration reloaded.")
    }


    // MARK: - Toggle Tiling

    @objc private func toggleTiling() {
        isTilingEnabled.toggle()

        if isTilingEnabled {
            toggleMenuItem.title = "Disable Tiling"
            tickLoop.start()
            applyTilingMode()
            NSLog("[SonicLand] Tiling enabled.")
        } else {
            toggleMenuItem.title = "Enable Tiling"
            tickLoop.stop()
            NSLog("[SonicLand] Tiling disabled.")
        }
    }

    // MARK: - Monitor Mode

    @objc private func tilingModeSelected(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let mode = TilingMode(rawValue: rawValue) else { return }
        guard mode != currentTilingMode else { return }

        currentTilingMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: TilingMode.defaultsKey)

        // Update checkmarks
        for (m, item) in tilingModeMenuItems {
            item.state = m == mode ? .on : .off
        }

        applyTilingMode()
        NSLog("[SonicLand] Switched tiling mode to: \(mode.menuTitle)")
    }

    private func applyTilingMode() {
        let tilingMonitors = monitorManager.tilingMonitors(filter: currentTilingMode.monitorFilter)
        let tilingMonitorIDs = Set(tilingMonitors.map { $0.id })

        for window in windowManager.allWindows {
            let windowMonitor = monitorManager.monitorContaining(rect: window.frame)
            let onTilingMonitor = windowMonitor.map { tilingMonitorIDs.contains($0.id) } ?? false

            if !onTilingMonitor && !window.isFloating {
                // Float windows on non-tiling monitors
                window.isFloating = true
                window.isModeFloated = true
            } else if onTilingMonitor && window.isModeFloated {
                // Unfloat windows that were mode-floated and are now on tiling monitors
                window.isFloating = false
                window.isModeFloated = false
            }
        }

        // Rebuild workspaces for tiling monitors
        for monitor in tilingMonitors {
            workspaceManager.ensureDefaultWorkspace(for: monitor.id)
        }

        // Rebuild BSP trees for all visible workspaces
        for var workspace in workspaceManager.allWorkspaces {
            guard workspace.isVisible else { continue }

            let tiledWindowIDs = workspace.windowIDs.filter { wid in
                guard let w = windowManager.window(for: wid) else { return false }
                return !w.isFloating && !w.isMinimized
            }

            var newTree = BSPTree()
            for wid in tiledWindowIDs {
                newTree.insert(windowID: wid)
            }
            workspace.layoutTree = newTree
            workspaceManager.updateWorkspace(workspace)
        }

        recomputeAllLayouts()
    }

    private func recomputeSharedSpaceLayout() {
        let tilingMonitors = monitorManager.tilingMonitors(filter: currentTilingMode.monitorFilter)
        guard tilingMonitors.count > 1 else {
            recomputePerWorkspaceLayouts()
            return
        }

        let tilingMonitorIDs = Set(tilingMonitors.map { $0.id })

        // Collect ALL non-floating, non-minimized windows
        let allTiledWindows = windowManager.allWindows.filter { !$0.isFloating && !$0.isMinimized }
        guard !allTiledWindows.isEmpty else { return }

        // Group windows by the monitor they're CURRENTLY on (respects user placement)
        var windowsPerMonitor: [UInt32: [WindowNode]] = [:]
        for monitor in tilingMonitors {
            windowsPerMonitor[monitor.id] = []
        }

        for window in allTiledWindows {
            if let monitor = monitorManager.monitorContaining(rect: window.frame),
               tilingMonitorIDs.contains(monitor.id) {
                windowsPerMonitor[monitor.id]?.append(window)
            } else {
                // Window not on any tiling monitor — assign to primary tiling monitor
                windowsPerMonitor[tilingMonitors[0].id]?.append(window)
            }
        }

        // For each monitor: rebuild BSP and apply frames
        for monitor in tilingMonitors {
            guard let wsID = workspaceManager.activeWorkspaceID(for: monitor.id),
                  var workspace = workspaceManager.workspace(for: wsID) else { continue }

            let monitorWindows = windowsPerMonitor[monitor.id] ?? []
            let monitorWindowIDs = monitorWindows.map { $0.windowID }

            // Only rebuild BSP tree if window membership changed (preserves swap ordering)
            let currentIDs = Set(workspace.windowIDs)
            let newIDs = Set(monitorWindowIDs)
            if currentIDs != newIDs {
                workspace.windowIDs = monitorWindowIDs
                var newTree = BSPTree()
                for wid in monitorWindowIDs {
                    newTree.insert(windowID: wid)
                }
                workspace.layoutTree = newTree
            }
            workspaceManager.updateWorkspace(workspace)

            for window in monitorWindows {
                window.workspaceID = wsID
                window.monitorID = monitor.id
            }

            guard !monitorWindowIDs.isEmpty else { continue }

            let frames = workspace.layoutTree.computeFrames(
                in: monitor.visibleFrame,
                gaps: GapConfig(inner: layoutEngine.gapsInner, outer: layoutEngine.gapsOuter)
            )

            for (windowID, targetFrame) in frames {
                guard let window = windowManager.window(for: windowID) else { continue }

                let dx = abs(window.frame.origin.x - targetFrame.origin.x)
                let dy = abs(window.frame.origin.y - targetFrame.origin.y)
                let dw = abs(window.frame.size.width - targetFrame.size.width)
                let dh = abs(window.frame.size.height - targetFrame.size.height)

                if dx > 2 || dy > 2 || dw > 2 || dh > 2 {
                    AccessibilityWrapper.setWindowFrame(window.axElement, frame: targetFrame)
                }
                window.targetFrame = targetFrame
            }
        }
    }

    // MARK: - IPC

    private func handleIPCCommand(_ command: IPCCommand) -> IPCResponse {
        switch command {
        case .switchWorkspace(let id):
            switchWorkspace(id)
            return IPCResponse(status: .ok, data: nil)

        case .moveWindow(let workspaceID):
            moveToWorkspace(workspaceID)
            return IPCResponse(status: .ok, data: nil)

        case .listWindows:
            let windows = windowManager.allWindows.map { window in
                WindowInfo(
                    windowID: Int(window.windowID),
                    app: window.appName,
                    title: window.title ?? "",
                    frame: FrameInfo(x: window.frame.origin.x, y: window.frame.origin.y,
                                     width: window.frame.size.width, height: window.frame.size.height),
                    workspace: window.workspaceID,
                    floating: window.isFloating
                )
            }
            return IPCResponse(status: .ok, data: .windows(windows))

        case .listWorkspaces:
            let workspaces = workspaceManager.allWorkspaces.map { ws in
                WorkspaceInfo(id: ws.id, name: ws.name, windowCount: ws.windowIDs.count,
                              monitorID: ws.monitorID, focused: ws.id == workspaceManager.activeWorkspace?.id)
            }
            return IPCResponse(status: .ok, data: .workspaces(workspaces))

        case .reloadConfig:
            reloadConfig()
            return IPCResponse(status: .ok, data: nil)

        case .getActiveWorkspace:
            if let ws = workspaceManager.activeWorkspace {
                let info = WorkspaceInfo(id: ws.id, name: ws.name, windowCount: ws.windowIDs.count,
                                         monitorID: ws.monitorID, focused: true)
                return IPCResponse(status: .ok, data: .workspaces([info]))
            }
            return IPCResponse(status: .error, message: "No active workspace")

        case .focusWindow(let windowID):
            if let window = windowManager.window(for: CGWindowID(windowID)) {
                AccessibilityWrapper.focusWindow(window.axElement, pid: window.pid)
                return IPCResponse(status: .ok, data: nil)
            }
            return IPCResponse(status: .error, message: "Window not found")

        case .unknown(let cmd):
            return IPCResponse(status: .error, message: "Unknown command: \(cmd)")
        }
    }
}

// MARK: - WindowManagerDelegate

extension AppDelegate: WindowManagerDelegate {
    func windowManager(_ manager: WindowManager, didDetectNewWindow window: WindowNode) {
        // Skip relayout during bootstrap — we'll do one clean pass after
        guard !isBootstrapping else { return }

        NSLog("[SonicLand] New window: \(window.appName) - \(window.title ?? "untitled")")

        ruleEngine.applyRules(to: window, workspaceManager: workspaceManager)

        // Float windows that land on non-tiling monitors
        let tilingMonitors = monitorManager.tilingMonitors(filter: currentTilingMode.monitorFilter)
        let tilingMonitorIDs = Set(tilingMonitors.map { $0.id })
        let windowMonitor = monitorManager.monitorContaining(rect: window.frame)
        let onTilingMonitor = windowMonitor.map { tilingMonitorIDs.contains($0.id) } ?? false

        if !onTilingMonitor && !window.isFloating {
            window.isFloating = true
            window.isModeFloated = true
        }

        if window.workspaceID == 0 {
            if let monitor = windowMonitor,
               let wsID = workspaceManager.activeWorkspaceID(for: monitor.id) {
                window.workspaceID = wsID
                workspaceManager.addWindow(window.windowID, to: wsID)
            } else if let activeWS = workspaceManager.activeWorkspace {
                window.workspaceID = activeWS.id
                workspaceManager.addWindow(window.windowID, to: activeWS.id)
            }
        }

        if !window.isFloating {
            if var ws = workspaceManager.workspace(for: window.workspaceID) {
                layoutEngine.insertWindow(window.windowID, into: &ws.layoutTree)
                workspaceManager.updateWorkspace(ws)
            }
        }

        recomputeAllLayouts()
        pluginManager?.onWindowCreated(window: window)
    }

    func windowManager(_ manager: WindowManager, didRemoveWindow windowID: CGWindowID) {
        NSLog("[SonicLand] Window removed: \(windowID)")

        for var ws in workspaceManager.allWorkspaces {
            if ws.windowIDs.contains(windowID) {
                ws.windowIDs.removeAll { $0 == windowID }
                layoutEngine.removeWindow(windowID, from: &ws.layoutTree)
                workspaceManager.updateWorkspace(ws)
            }
        }

        recomputeAllLayouts()
        pluginManager?.onWindowDestroyed(windowID: windowID)
    }

    func windowManager(_ manager: WindowManager, didFocusWindow windowID: CGWindowID) {
        if let window = windowManager.window(for: windowID) {
            workspaceManager.setFocusedWindow(windowID, in: window.workspaceID)
        }
    }

    func windowManagerNeedsRelayout(_ manager: WindowManager) {
        recomputeAllLayouts()
    }
}
