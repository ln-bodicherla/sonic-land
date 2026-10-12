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
    private var scratchpadManager: ScratchpadManager!
    private var overlayManager: OverlayManager!
    private var profileManager: ProfileManager!
    private var sessionManager: SessionManager!
    private var isBootstrapping = false
    private var currentTilingMode: TilingMode = .sharedSpace
    private var tilingModeMenuItems: [TilingMode: NSMenuItem] = [:]
    private var isTilingEnabled = true
    private var toggleMenuItem: NSMenuItem!
    private var gapsEnabled = true
    private var savedGaps: GapConfig?
    private var currentConfig: ConfigModel = ConfigModel()

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

        // Save session on quit
        if currentConfig.sessionRestore.saveOnQuit {
            sessionManager?.saveSession(
                workspaceManager: workspaceManager,
                windowManager: windowManager,
                tilingMode: currentTilingMode
            )
        }

        tickLoop?.stop()
        ipcServer?.stop()
        inputManager?.stop()
        configWatcher?.stop()
        overlayManager?.hideAll()
    }

    // MARK: - Status Bar

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }

        let iconSize: CGFloat = 18
        let img = NSImage(size: NSSize(width: iconSize, height: iconSize), flipped: false) { rect in
            let inset: CGFloat = 2
            let gap: CGFloat = 2
            let area = rect.insetBy(dx: inset, dy: inset)
            let splitX = area.minX + area.width * 0.55
            let splitY = area.minY + area.height * 0.45

            NSColor.black.setFill()

            let left = NSRect(x: area.minX, y: area.minY, width: splitX - area.minX - gap / 2, height: area.height)
            NSBezierPath(roundedRect: left, xRadius: 1.5, yRadius: 1.5).fill()

            let topRight = NSRect(x: splitX + gap / 2, y: splitY + gap / 2, width: area.maxX - splitX - gap / 2, height: area.maxY - splitY - gap / 2)
            NSBezierPath(roundedRect: topRight, xRadius: 1.5, yRadius: 1.5).fill()

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

        // Layout submenu
        let layoutSubmenu = NSMenu()
        for mode in LayoutMode.allCases {
            let item = NSMenuItem(title: mode.displayName, action: #selector(layoutModeSelected(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode.rawValue
            layoutSubmenu.addItem(item)
        }
        let layoutItem = NSMenuItem(title: "Layout Mode", action: nil, keyEquivalent: "")
        layoutItem.submenu = layoutSubmenu
        menu.addItem(layoutItem)

        // Profile submenu
        let profileSubmenu = NSMenu()
        let refreshProfiles = NSMenuItem(title: "Refresh", action: #selector(refreshProfileMenu(_:)), keyEquivalent: "")
        refreshProfiles.target = self
        profileSubmenu.addItem(refreshProfiles)
        let profileItem = NSMenuItem(title: "Profiles", action: nil, keyEquivalent: "")
        profileItem.submenu = profileSubmenu
        menu.addItem(profileItem)

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
        configParser = ConfigParser()
        currentConfig = configParser.loadConfig()
        let config = currentConfig

        monitorManager = MonitorManager()
        monitorManager.refresh()
        monitorManager.delegate = self

        if let savedRaw = UserDefaults.standard.string(forKey: TilingMode.defaultsKey),
           let saved = TilingMode(rawValue: savedRaw) {
            currentTilingMode = saved
        } else {
            currentTilingMode = TilingMode.from(configMonitor: config.general.monitor)
        }
        NSLog("[SonicLand] Tiling mode: \(currentTilingMode.menuTitle)")

        let tilingMonitors = monitorManager.tilingMonitors(filter: currentTilingMode.monitorFilter)
        NSLog("[SonicLand] Tiling on \(tilingMonitors.count) monitor(s)")

        workspaceManager = WorkspaceManager(monitorManager: monitorManager)
        for monitor in tilingMonitors {
            workspaceManager.ensureDefaultWorkspace(for: monitor.id)
        }

        // Apply workspace config from config file
        workspaceManager.applyWorkspaceConfig(config.workspaceConfig)

        windowManager = WindowManager()
        layoutEngine = LayoutEngine(config: config)
        animationEngine = AnimationEngine(config: config)
        ruleEngine = RuleEngine(config: config)
        overlayManager = OverlayManager()
        scratchpadManager = ScratchpadManager()
        profileManager = ProfileManager()
        sessionManager = SessionManager()

        // Register scratchpads from config
        for spConfig in config.scratchpads {
            let sp = Scratchpad(
                name: spConfig.name,
                appName: spConfig.app,
                bundleID: spConfig.bundleID,
                command: spConfig.command,
                defaultWidth: spConfig.width,
                defaultHeight: spConfig.height,
                centerOnShow: spConfig.center,
                autoHideOnFocusLost: spConfig.autoHide
            )
            scratchpadManager.register(sp)
        }

        // Restore session if enabled
        if config.sessionRestore.enabled {
            if let session = sessionManager.loadSession() {
                sessionManager.restoreWorkspaceMetadata(session: session, workspaceManager: workspaceManager)
                NSLog("[SonicLand] Session metadata restored")
            }
        }

        // Bootstrap windows
        isBootstrapping = true
        windowManager.delegate = self
        windowManager.bootstrap()
        isBootstrapping = false

        let tilingMonitorIDs = Set(tilingMonitors.map { $0.id })
        var windowsByWorkspace: [Int: [CGWindowID]] = [:]

        for window in windowManager.allWindows {
            ruleEngine.applyRules(to: window, workspaceManager: workspaceManager)

            let windowMonitor = monitorManager.monitorContaining(rect: window.frame)
            let onTilingMonitor = windowMonitor.map { tilingMonitorIDs.contains($0.id) } ?? false

            if !onTilingMonitor {
                window.isFloating = true
                window.isModeFloated = true
            }

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

            // Apply float geometry from rules
            if window.isFloating, let geo = window.floatGeometry {
                if window.centerOnOpen, let monitor = monitorManager.primaryMonitor {
                    let x = monitor.visibleFrame.midX - geo.width / 2
                    let y = monitor.visibleFrame.midY - geo.height / 2
                    AccessibilityWrapper.setWindowFrame(window.axElement,
                        frame: CGRect(x: x, y: y, width: geo.width, height: geo.height))
                } else if geo.origin.x != 0 || geo.origin.y != 0 {
                    AccessibilityWrapper.setWindowFrame(window.axElement, frame: geo)
                }
            }
        }

        // Build BSP trees for BSP-mode workspaces
        for (wsID, windowIDs) in windowsByWorkspace {
            if var ws = workspaceManager.workspace(for: wsID), ws.layoutMode == .bsp {
                var tree = BSPTree()
                for wid in windowIDs {
                    tree.insert(windowID: wid)
                }
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

        // Initial layout
        recomputeAllLayouts()
        NSLog("[SonicLand] Initial layout applied.")

        // Tick loop
        tickLoop = TickLoop(fps: 10) { [weak self] in
            self?.tick()
        }
        tickLoop.start()
    }

    // MARK: - Tick

    private func tick() {
        windowManager.refreshWindowStates()

        let mouseDown = NSEvent.pressedMouseButtons & 1 != 0
        if mouseDown { return }

        // Evaluate context rules periodically
        let contextActions = ruleEngine.evaluateContextRules(monitorManager: monitorManager)
        for action in contextActions {
            handleContextAction(action)
        }

        // Auto-hide scratchpads on focus loss
        if let activeWS = workspaceManager.activeWorkspace,
           let focusedID = activeWS.focusedWindowID {
            for window in windowManager.allWindows where window.windowID != focusedID {
                scratchpadManager.handleFocusLost(windowID: window.windowID, windowManager: windowManager)
            }
        }

        // Check for drift
        var needsRelayout = false

        for window in windowManager.allWindows where !window.isFloating && !window.isMinimized {
            // Skip DND workspaces
            if let ws = workspaceManager.workspace(for: window.workspaceID), ws.doNotDisturb {
                continue
            }

            guard window.hasDrifted else { continue }

            let dragCenter = CGPoint(x: window.frame.midX, y: window.frame.midY)
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
                if var ws = workspaceManager.workspace(for: window.workspaceID) {
                    ws.layoutTree.swapWindows(window.windowID, swapID)
                    workspaceManager.updateWorkspace(ws)
                    EventLog.shared.log(.windowSwapped,
                        "Swapped \(window.appName) with \(windowManager.window(for: swapID)?.appName ?? "?")")
                }
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

            let tiledWindowIDs = workspace.windowIDs.filter { wid in
                guard let w = windowManager.window(for: wid) else { return false }
                return !w.isFloating && !w.isMinimized && !w.isPseudoFullscreen
            }

            // Add sticky windows
            let stickyIDs = workspaceManager.stickyWindows(windowManager: windowManager)
                .filter { !tiledWindowIDs.contains($0) }

            let allTiledIDs = orderWindowIDs(tiledWindowIDs + stickyIDs, workspace: workspace)

            guard !allTiledIDs.isEmpty else { continue }

            let frames: [CGWindowID: CGRect]

            if workspace.layoutMode == .bsp {
                // Rebuild BSP tree if needed
                let treeIDs = Set(workspace.layoutTree.root.allWindowIDs)
                let expectedIDs = Set(allTiledIDs)
                if treeIDs != expectedIDs {
                    var newTree = BSPTree()
                    for wid in allTiledIDs {
                        newTree.insert(windowID: wid)
                    }
                    workspace.layoutTree = newTree
                    workspaceManager.updateWorkspace(workspace)
                }

                let effectiveGaps = workspace.gapsOverride ?? GapConfig(inner: layoutEngine.gapsInner, outer: layoutEngine.gapsOuter)
                frames = workspace.layoutTree.computeFrames(in: monitor.visibleFrame, gaps: effectiveGaps)
            } else {
                frames = layoutEngine.computeLayout(
                    windowIDs: allTiledIDs,
                    in: monitor.visibleFrame,
                    workspace: workspace
                )
            }

            applyFrames(frames)

            // Handle pseudo-fullscreen windows
            for wid in workspace.windowIDs {
                guard let w = windowManager.window(for: wid), w.isPseudoFullscreen else { continue }
                let fullFrame = monitor.visibleFrame
                if abs(w.frame.width - fullFrame.width) > 2 || abs(w.frame.height - fullFrame.height) > 2 {
                    AccessibilityWrapper.setWindowFrame(w.axElement, frame: fullFrame)
                }
                w.targetFrame = fullFrame
            }
        }
    }

    private func recomputeSharedSpaceLayout() {
        let tilingMonitors = monitorManager.tilingMonitors(filter: currentTilingMode.monitorFilter)
        guard tilingMonitors.count > 1 else {
            recomputePerWorkspaceLayouts()
            return
        }

        let tilingMonitorIDs = Set(tilingMonitors.map { $0.id })
        let allTiledWindows = windowManager.allWindows.filter { !$0.isFloating && !$0.isMinimized && !$0.isPseudoFullscreen }
        guard !allTiledWindows.isEmpty else { return }

        var windowsPerMonitor: [UInt32: [WindowNode]] = [:]
        for monitor in tilingMonitors {
            windowsPerMonitor[monitor.id] = []
        }

        for window in allTiledWindows {
            if let monitor = monitorManager.monitorContaining(rect: window.frame),
               tilingMonitorIDs.contains(monitor.id) {
                windowsPerMonitor[monitor.id]?.append(window)
            } else {
                windowsPerMonitor[tilingMonitors[0].id]?.append(window)
            }
        }

        for monitor in tilingMonitors {
            guard let wsID = workspaceManager.activeWorkspaceID(for: monitor.id),
                  var workspace = workspaceManager.workspace(for: wsID) else { continue }

            let monitorWindows = windowsPerMonitor[monitor.id] ?? []
            let monitorWindowIDs = monitorWindows.map { $0.windowID }
            let orderedIDs = orderWindowIDs(monitorWindowIDs, workspace: workspace)

            let currentIDs = Set(workspace.windowIDs)
            let newIDs = Set(orderedIDs)
            if currentIDs != newIDs {
                workspace.windowIDs = orderedIDs
                if workspace.layoutMode == .bsp {
                    var newTree = BSPTree()
                    for wid in orderedIDs {
                        newTree.insert(windowID: wid)
                    }
                    workspace.layoutTree = newTree
                }
            }
            workspaceManager.updateWorkspace(workspace)

            for window in monitorWindows {
                window.workspaceID = wsID
                window.monitorID = monitor.id
            }

            guard !orderedIDs.isEmpty else { continue }

            let frames: [CGWindowID: CGRect]
            if workspace.layoutMode == .bsp {
                let effectiveGaps = workspace.gapsOverride ?? GapConfig(inner: layoutEngine.gapsInner, outer: layoutEngine.gapsOuter)
                frames = workspace.layoutTree.computeFrames(in: monitor.visibleFrame, gaps: effectiveGaps)
            } else {
                frames = layoutEngine.computeLayout(
                    windowIDs: orderedIDs,
                    in: monitor.visibleFrame,
                    workspace: workspace
                )
            }

            applyFrames(frames)
        }
    }

    /// Order window IDs with pinned windows first (for master-stack and similar layouts).
    private func orderWindowIDs(_ windowIDs: [CGWindowID], workspace: Workspace) -> [CGWindowID] {
        var pinned: [CGWindowID] = []
        var normal: [CGWindowID] = []

        for wid in windowIDs {
            if let w = windowManager.window(for: wid), w.isPinned {
                pinned.append(wid)
            } else {
                normal.append(wid)
            }
        }

        return pinned + normal
    }

    /// Apply computed frames to actual windows.
    private func applyFrames(_ frames: [CGWindowID: CGRect]) {
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

    // MARK: - Actions

    private func handleAction(_ action: KeyAction) {
        switch action {
        // Focus
        case .focusLeft: focusDirection(.left)
        case .focusRight: focusDirection(.right)
        case .focusUp: focusDirection(.up)
        case .focusDown: focusDirection(.down)
        case .focusRecent: focusRecent()
        case .focusParent: break // TODO: BSP parent navigation
        case .focusMaster: focusMaster()

        // Move
        case .moveLeft: moveWindowDirection(.left)
        case .moveRight: moveWindowDirection(.right)
        case .moveUp: moveWindowDirection(.up)
        case .moveDown: moveWindowDirection(.down)
        case .moveToMaster: moveToMaster()
        case .pullToTile: pullToTile()
        case .ejectToFloat: ejectToFloat()

        // Resize
        case .growWidth: resizeWindow(axis: .horizontal, delta: 0.05)
        case .shrinkWidth: resizeWindow(axis: .horizontal, delta: -0.05)
        case .growHeight: resizeWindow(axis: .vertical, delta: 0.05)
        case .shrinkHeight: resizeWindow(axis: .vertical, delta: -0.05)
        case .normalizeSize: normalizeLayout()
        case .increaseMasterRatio: adjustMasterRatio(delta: 0.05)
        case .decreaseMasterRatio: adjustMasterRatio(delta: -0.05)
        case .increaseMasterCount: adjustMasterCount(delta: 1)
        case .decreaseMasterCount: adjustMasterCount(delta: -1)

        // Workspace
        case .switchWorkspace(let id): switchWorkspace(id)
        case .moveToWorkspace(let id): moveToWorkspace(id)
        case .nextWorkspace: nextWorkspace()
        case .previousWorkspace: previousWorkspace()
        case .recentWorkspace: recentWorkspace()

        // Layout
        case .toggleFloat: toggleFloat()
        case .toggleLayoutDirection: toggleLayoutDirection()
        case .cycleLayout: cycleLayout()
        case .setLayout(let mode): setLayout(mode)
        case .rotateClockwise: rotateWindows(.clockwise)
        case .rotateCounterClockwise: rotateWindows(.counterClockwise)

        // Fullscreen
        case .togglePseudoFullscreen: togglePseudoFullscreen()
        case .toggleMonocle: toggleMonocle()

        // Scratchpad
        case .toggleScratchpad(let name): toggleScratchpad(name)

        // System
        case .reloadConfig: reloadConfig()
        case .toggleGaps: toggleGaps()
        case .toggleOverlay: break
        }
    }

    // MARK: - Focus Actions

    private func focusDirection(_ direction: Direction) {
        guard let currentWS = workspaceManager.activeWorkspace,
              let focusedID = currentWS.focusedWindowID else { return }

        let targetID: CGWindowID?
        if currentWS.layoutMode == .bsp {
            targetID = layoutEngine.findNeighbor(of: focusedID, direction: direction, in: currentWS.layoutTree)
        } else {
            targetID = layoutEngine.findNeighbor(of: focusedID, direction: direction, in: currentWS.windowIDs)
        }

        if let targetID = targetID,
           let window = windowManager.window(for: targetID) {
            AccessibilityWrapper.focusWindow(window.axElement, pid: window.pid)
            workspaceManager.setFocusedWindow(targetID, in: currentWS.id)

            if currentConfig.overlay.showFocusRing, let frame = window.targetFrame ?? Optional(window.frame) {
                overlayManager.showFocusRing(frame: frame)
            }
        }
    }

    private func focusRecent() {
        // Focus the most recent window in the workspace that isn't currently focused
        guard let currentWS = workspaceManager.activeWorkspace,
              let focusedID = currentWS.focusedWindowID else { return }

        for wid in currentWS.windowIDs.reversed() {
            if wid != focusedID, let window = windowManager.window(for: wid) {
                AccessibilityWrapper.focusWindow(window.axElement, pid: window.pid)
                workspaceManager.setFocusedWindow(wid, in: currentWS.id)
                break
            }
        }
    }

    private func focusMaster() {
        guard let currentWS = workspaceManager.activeWorkspace,
              let firstID = currentWS.windowIDs.first,
              let window = windowManager.window(for: firstID) else { return }

        AccessibilityWrapper.focusWindow(window.axElement, pid: window.pid)
        workspaceManager.setFocusedWindow(firstID, in: currentWS.id)
    }

    // MARK: - Move Actions

    private func moveWindowDirection(_ direction: Direction) {
        guard var currentWS = workspaceManager.activeWorkspace,
              let focusedID = currentWS.focusedWindowID else { return }

        if currentWS.layoutMode == .bsp {
            layoutEngine.moveWindow(focusedID, direction: direction, in: &currentWS.layoutTree)
        } else {
            // Swap in window list
            guard let idx = currentWS.windowIDs.firstIndex(of: focusedID) else { return }
            let targetIdx: Int
            switch direction {
            case .left, .up: targetIdx = max(0, idx - 1)
            case .right, .down: targetIdx = min(currentWS.windowIDs.count - 1, idx + 1)
            }
            if targetIdx != idx {
                currentWS.windowIDs.swapAt(idx, targetIdx)
            }
        }
        workspaceManager.updateWorkspace(currentWS)
        recomputeAllLayouts()
    }

    private func moveToMaster() {
        guard var currentWS = workspaceManager.activeWorkspace,
              let focusedID = currentWS.focusedWindowID,
              let idx = currentWS.windowIDs.firstIndex(of: focusedID),
              idx > 0 else { return }

        currentWS.windowIDs.remove(at: idx)
        currentWS.windowIDs.insert(focusedID, at: 0)

        if let window = windowManager.window(for: focusedID) {
            window.isPinned = true
        }

        workspaceManager.updateWorkspace(currentWS)

        // Rebuild BSP tree for BSP mode
        if currentWS.layoutMode == .bsp {
            if var ws = workspaceManager.workspace(for: currentWS.id) {
                var newTree = BSPTree()
                for wid in ws.windowIDs {
                    newTree.insert(windowID: wid)
                }
                ws.layoutTree = newTree
                workspaceManager.updateWorkspace(ws)
            }
        }

        recomputeAllLayouts()
    }

    private func pullToTile() {
        guard var currentWS = workspaceManager.activeWorkspace,
              let focusedID = currentWS.focusedWindowID,
              let window = windowManager.window(for: focusedID),
              window.isFloating else { return }

        window.isFloating = false
        window.alwaysFloat = false
        layoutEngine.insertWindow(focusedID, into: &currentWS.layoutTree)
        workspaceManager.updateWorkspace(currentWS)
        recomputeAllLayouts()
        EventLog.shared.log(.windowTiled, "Pulled \(window.appName) to tile")
    }

    private func ejectToFloat() {
        guard var currentWS = workspaceManager.activeWorkspace,
              let focusedID = currentWS.focusedWindowID,
              let window = windowManager.window(for: focusedID),
              !window.isFloating else { return }

        window.isFloating = true
        layoutEngine.removeWindow(focusedID, from: &currentWS.layoutTree)
        workspaceManager.updateWorkspace(currentWS)
        recomputeAllLayouts()
        EventLog.shared.log(.windowFloated, "Ejected \(window.appName) to float")
    }

    // MARK: - Resize Actions

    private func resizeWindow(axis: ResizeAxis, delta: CGFloat) {
        guard var currentWS = workspaceManager.activeWorkspace,
              let focusedID = currentWS.focusedWindowID else { return }

        if currentWS.layoutMode == .bsp {
            currentWS.layoutTree.adjustRatio(for: focusedID, delta: delta)
            workspaceManager.updateWorkspace(currentWS)
        } else if currentWS.layoutMode == .masterStack {
            workspaceManager.adjustMasterRatio(for: currentWS.id, delta: delta)
        }
        recomputeAllLayouts()
    }

    private func normalizeLayout() {
        guard var currentWS = workspaceManager.activeWorkspace else { return }

        if currentWS.layoutMode == .bsp {
            layoutEngine.normalizeRatios(in: &currentWS.layoutTree)
            workspaceManager.updateWorkspace(currentWS)
        } else {
            workspaceManager.adjustMasterRatio(for: currentWS.id, delta: 0)
            if var ws = workspaceManager.workspace(for: currentWS.id) {
                ws.masterRatio = 0.5
                workspaceManager.updateWorkspace(ws)
            }
        }
        recomputeAllLayouts()
    }

    private func adjustMasterRatio(delta: CGFloat) {
        guard let currentWS = workspaceManager.activeWorkspace else { return }
        workspaceManager.adjustMasterRatio(for: currentWS.id, delta: delta)
        recomputeAllLayouts()
    }

    private func adjustMasterCount(delta: Int) {
        guard let currentWS = workspaceManager.activeWorkspace else { return }
        workspaceManager.adjustMasterCount(for: currentWS.id, delta: delta)
        recomputeAllLayouts()
    }

    // MARK: - Workspace Actions

    private func switchWorkspace(_ id: Int) {
        guard let currentWS = workspaceManager.activeWorkspace else { return }
        if currentWS.id == id { return }

        for windowID in currentWS.windowIDs {
            if let window = windowManager.window(for: windowID), !window.isSticky {
                AccessibilityWrapper.setWindowPosition(window.axElement, position: CGPoint(x: -10000, y: -10000))
            }
        }

        workspaceManager.switchTo(workspaceID: id)

        if let targetWS = workspaceManager.activeWorkspace {
            for windowID in targetWS.windowIDs {
                if let window = windowManager.window(for: windowID) {
                    if let target = window.targetFrame {
                        AccessibilityWrapper.setWindowFrame(window.axElement, frame: target)
                    }
                }
            }

            // Run startup actions for workspace
            if !targetWS.startupActions.isEmpty {
                for action in targetWS.startupActions {
                    runStartupAction(action)
                }
            }
        }

        recomputeAllLayouts()
        pluginManager.onWorkspaceChanged(from: currentWS.id, to: id)

        if currentConfig.overlay.showWorkspaceName,
           let ws = workspaceManager.workspace(for: id) {
            overlayManager.showWorkspaceName(ws.name)
        }

        if currentConfig.overlay.showWorkspaceMap {
            let wsData = workspaceManager.allWorkspaces.map { ws in
                (id: ws.id, name: ws.name, isActive: ws.id == id, windowCount: ws.windowIDs.count)
            }
            overlayManager.showWorkspaceMap(workspaces: wsData)
        }
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

    private func nextWorkspace() {
        if let id = workspaceManager.switchToNext() {
            if let ws = workspaceManager.workspace(for: id) {
                showWorkspaceSwitch(ws)
            }
            recomputeAllLayouts()
        }
    }

    private func previousWorkspace() {
        if let id = workspaceManager.switchToPrevious() {
            if let ws = workspaceManager.workspace(for: id) {
                showWorkspaceSwitch(ws)
            }
            recomputeAllLayouts()
        }
    }

    private func recentWorkspace() {
        if let id = workspaceManager.switchToRecent() {
            if let ws = workspaceManager.workspace(for: id) {
                showWorkspaceSwitch(ws)
            }
            recomputeAllLayouts()
        }
    }

    private func showWorkspaceSwitch(_ ws: Workspace) {
        // Hide/show windows for workspace switch
        for otherWS in workspaceManager.allWorkspaces where !otherWS.isVisible {
            for wid in otherWS.windowIDs {
                if let w = windowManager.window(for: wid), !w.isSticky {
                    AccessibilityWrapper.setWindowPosition(w.axElement, position: CGPoint(x: -10000, y: -10000))
                }
            }
        }
        for wid in ws.windowIDs {
            if let w = windowManager.window(for: wid), let target = w.targetFrame {
                AccessibilityWrapper.setWindowFrame(w.axElement, frame: target)
            }
        }

        if currentConfig.overlay.showWorkspaceName {
            overlayManager.showWorkspaceName(ws.name)
        }
    }

    // MARK: - Layout Actions

    private func toggleFloat() {
        guard var currentWS = workspaceManager.activeWorkspace,
              let focusedID = currentWS.focusedWindowID,
              let window = windowManager.window(for: focusedID) else { return }

        window.isFloating.toggle()

        if window.isFloating {
            layoutEngine.removeWindow(focusedID, from: &currentWS.layoutTree)
            EventLog.shared.log(.windowFloated, "Floated \(window.appName)")
        } else {
            layoutEngine.insertWindow(focusedID, into: &currentWS.layoutTree)
            EventLog.shared.log(.windowTiled, "Tiled \(window.appName)")
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

    private func cycleLayout() {
        guard let currentWS = workspaceManager.activeWorkspace else { return }
        if let newMode = workspaceManager.cycleLayout(for: currentWS.id) {
            recomputeAllLayouts()
            pluginManager.onLayoutModeChanged(workspaceID: currentWS.id, mode: newMode)

            if currentConfig.overlay.showLayoutName {
                overlayManager.showLayoutName(newMode.displayName)
            }
        }
    }

    private func setLayout(_ modeStr: String) {
        guard let mode = LayoutMode(rawValue: modeStr),
              let currentWS = workspaceManager.activeWorkspace else { return }

        workspaceManager.setLayoutMode(mode, for: currentWS.id)
        recomputeAllLayouts()
        pluginManager.onLayoutModeChanged(workspaceID: currentWS.id, mode: mode)

        if currentConfig.overlay.showLayoutName {
            overlayManager.showLayoutName(mode.displayName)
        }
    }

    private func rotateWindows(_ direction: RotationDirection) {
        guard var currentWS = workspaceManager.activeWorkspace,
              currentWS.windowIDs.count > 1 else { return }

        layoutEngine.rotateWindows(direction, in: &currentWS.windowIDs)

        // Rebuild BSP tree if in BSP mode
        if currentWS.layoutMode == .bsp {
            var newTree = BSPTree()
            for wid in currentWS.windowIDs {
                newTree.insert(windowID: wid)
            }
            currentWS.layoutTree = newTree
        }

        workspaceManager.updateWorkspace(currentWS)
        recomputeAllLayouts()
    }

    // MARK: - Fullscreen Actions

    private func togglePseudoFullscreen() {
        guard let currentWS = workspaceManager.activeWorkspace,
              let focusedID = currentWS.focusedWindowID,
              let window = windowManager.window(for: focusedID) else { return }

        window.isPseudoFullscreen.toggle()
        recomputeAllLayouts()
    }

    private func toggleMonocle() {
        guard let currentWS = workspaceManager.activeWorkspace else { return }

        if currentWS.layoutMode == .monocle {
            workspaceManager.setLayoutMode(.bsp, for: currentWS.id)
        } else {
            workspaceManager.setLayoutMode(.monocle, for: currentWS.id)
        }

        recomputeAllLayouts()

        if currentConfig.overlay.showLayoutName,
           let ws = workspaceManager.workspace(for: currentWS.id) {
            overlayManager.showLayoutName(ws.layoutMode.displayName)
        }
    }

    // MARK: - Scratchpad

    private func toggleScratchpad(_ name: String) {
        let result = scratchpadManager.toggle(
            name: name,
            windowManager: windowManager,
            monitorManager: monitorManager
        )

        if let windowID = result.windowID {
            if result.action == .shown {
                // Mark as floating and bring to front
                if let window = windowManager.window(for: windowID) {
                    window.isFloating = true
                }
            }
        }
    }

    // MARK: - Gaps

    private func toggleGaps() {
        if gapsEnabled {
            savedGaps = GapConfig(inner: layoutEngine.gapsInner, outer: layoutEngine.gapsOuter)
            var config = currentConfig
            config.general.gapsIn = 0
            config.general.gapsOut = 0
            layoutEngine.updateConfig(config)
            gapsEnabled = false
        } else {
            if let saved = savedGaps {
                var config = currentConfig
                config.general.gapsIn = saved.inner
                config.general.gapsOut = saved.outer
                layoutEngine.updateConfig(config)
            }
            gapsEnabled = true
        }
        recomputeAllLayouts()
    }

    // MARK: - Context Actions

    private func handleContextAction(_ action: ContextAction) {
        switch action {
        case .activateProfile(let name):
            activateProfile(name)
        case .setLayout(let mode):
            if let ws = workspaceManager.activeWorkspace {
                workspaceManager.setLayoutMode(mode, for: ws.id)
                recomputeAllLayouts()
            }
        case .setGaps(let inner, let outer):
            var config = currentConfig
            config.general.gapsIn = inner
            config.general.gapsOut = outer
            layoutEngine.updateConfig(config)
            recomputeAllLayouts()
        case .enableDND:
            if var ws = workspaceManager.activeWorkspaceMutable {
                ws.doNotDisturb = true
                workspaceManager.updateWorkspace(ws)
            }
        case .disableDND:
            if var ws = workspaceManager.activeWorkspaceMutable {
                ws.doNotDisturb = false
                workspaceManager.updateWorkspace(ws)
            }
        case .moveAppToWorkspace(let bundleID, let wsID):
            for w in windowManager.allWindows where w.bundleID == bundleID {
                moveWindowToWorkspace(w.windowID, workspaceID: wsID)
            }
        case .hideApp(let bundleID):
            for w in windowManager.allWindows where w.bundleID == bundleID {
                AccessibilityWrapper.setWindowPosition(w.axElement, position: CGPoint(x: -10000, y: -10000))
            }
        case .showNotification(let msg):
            overlayManager.showNotification(msg)
        }
    }

    private func moveWindowToWorkspace(_ windowID: CGWindowID, workspaceID: Int) {
        workspaceManager.moveWindow(windowID: windowID, to: workspaceID)
        if var ws = workspaceManager.workspace(for: workspaceID) {
            layoutEngine.insertWindow(windowID, into: &ws.layoutTree)
            workspaceManager.updateWorkspace(ws)
        }
    }

    // MARK: - Profile Actions

    private func activateProfile(_ name: String) {
        guard let profile = profileManager.activateProfile(name) else { return }

        // Apply workspace names and layouts
        for (id, wsName) in profile.workspaceNames {
            workspaceManager.renameWorkspace(id, to: wsName)
        }
        for (id, layoutStr) in profile.workspaceLayouts {
            if let mode = LayoutMode(rawValue: layoutStr) {
                workspaceManager.setLayoutMode(mode, for: id)
            }
        }

        // Apply gaps if set
        if let gIn = profile.gapsInner, let gOut = profile.gapsOuter {
            var config = currentConfig
            config.general.gapsIn = gIn
            config.general.gapsOut = gOut
            layoutEngine.updateConfig(config)
        }

        // Register scratchpads
        scratchpadManager.unregisterAll()
        for sp in profile.scratchpads {
            scratchpadManager.register(sp)
        }

        recomputeAllLayouts()
        overlayManager.showNotification("Profile: \(name)")
    }

    // MARK: - Startup Actions

    private func runStartupAction(_ action: String) {
        let task = Process()
        task.launchPath = "/bin/zsh"
        task.arguments = ["-c", action]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try? task.run()
    }

    // MARK: - Config Reload

    @objc private func reloadConfig() {
        NSLog("[SonicLand] Reloading configuration...")
        currentConfig = configParser.loadConfig()
        let config = currentConfig

        layoutEngine.updateConfig(config)
        inputManager.updateConfig(config)
        animationEngine.updateConfig(config)
        ruleEngine.updateConfig(config)

        // Update workspace configs
        workspaceManager.applyWorkspaceConfig(config.workspaceConfig)

        // Update scratchpads
        scratchpadManager.unregisterAll()
        for spConfig in config.scratchpads {
            let sp = Scratchpad(
                name: spConfig.name,
                appName: spConfig.app,
                bundleID: spConfig.bundleID,
                command: spConfig.command,
                defaultWidth: spConfig.width,
                defaultHeight: spConfig.height,
                centerOnShow: spConfig.center,
                autoHideOnFocusLost: spConfig.autoHide
            )
            scratchpadManager.register(sp)
        }

        recomputeAllLayouts()
        EventLog.shared.log(.configReloaded, "Configuration reloaded")
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

        for (m, item) in tilingModeMenuItems {
            item.state = m == mode ? .on : .off
        }

        applyTilingMode()
        NSLog("[SonicLand] Switched tiling mode to: \(mode.menuTitle)")
    }

    @objc private func layoutModeSelected(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let mode = LayoutMode(rawValue: rawValue),
              let currentWS = workspaceManager.activeWorkspace else { return }

        workspaceManager.setLayoutMode(mode, for: currentWS.id)
        recomputeAllLayouts()

        if currentConfig.overlay.showLayoutName {
            overlayManager.showLayoutName(mode.displayName)
        }
    }

    @objc private func refreshProfileMenu(_ sender: NSMenuItem) {
        guard let profileMenu = sender.menu else { return }

        // Remove all items except the refresh item
        while profileMenu.items.count > 1 {
            profileMenu.removeItem(at: profileMenu.items.count - 1)
        }

        profileMenu.addItem(NSMenuItem.separator())

        for profile in profileManager.allProfiles() {
            let item = NSMenuItem(
                title: profile.name,
                action: #selector(profileSelected(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = profile.name
            if profileManager.activeProfile == profile.name {
                item.state = .on
            }
            profileMenu.addItem(item)
        }
    }

    @objc private func profileSelected(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        activateProfile(name)
    }

    private func applyTilingMode() {
        let tilingMonitors = monitorManager.tilingMonitors(filter: currentTilingMode.monitorFilter)
        let tilingMonitorIDs = Set(tilingMonitors.map { $0.id })

        for window in windowManager.allWindows {
            let windowMonitor = monitorManager.monitorContaining(rect: window.frame)
            let onTilingMonitor = windowMonitor.map { tilingMonitorIDs.contains($0.id) } ?? false

            if !onTilingMonitor && !window.isFloating {
                window.isFloating = true
                window.isModeFloated = true
            } else if onTilingMonitor && window.isModeFloated {
                window.isFloating = false
                window.isModeFloated = false
            }
        }

        for monitor in tilingMonitors {
            workspaceManager.ensureDefaultWorkspace(for: monitor.id)
        }

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

    // MARK: - IPC

    private func handleIPCCommand(_ command: IPCCommand) -> IPCResponse {
        switch command {
        case .switchWorkspace(let id):
            switchWorkspace(id)
            return IPCResponse(status: .ok)

        case .moveWindow(let workspaceID):
            moveToWorkspace(workspaceID)
            return IPCResponse(status: .ok)

        case .listWindows:
            let windows = windowManager.allWindows.map { window in
                WindowInfo(
                    windowID: Int(window.windowID),
                    app: window.appName,
                    title: window.title ?? "",
                    frame: FrameInfo(x: window.frame.origin.x, y: window.frame.origin.y,
                                     width: window.frame.size.width, height: window.frame.size.height),
                    workspace: window.workspaceID,
                    floating: window.isFloating,
                    pinned: window.isPinned,
                    sticky: window.isSticky,
                    tags: Array(window.tags)
                )
            }
            return IPCResponse(status: .ok, data: .windows(windows))

        case .listWorkspaces:
            let workspaces = workspaceManager.allWorkspaces.map { ws in
                WorkspaceInfo(
                    id: ws.id, name: ws.name,
                    windowCount: ws.windowIDs.count,
                    monitorID: ws.monitorID,
                    focused: ws.id == workspaceManager.activeWorkspace?.id,
                    layout: ws.layoutMode.rawValue,
                    workspaceType: ws.workspaceType.rawValue,
                    masterRatio: ws.masterRatio,
                    masterCount: ws.masterCount
                )
            }
            return IPCResponse(status: .ok, data: .workspaces(workspaces))

        case .reloadConfig:
            reloadConfig()
            return IPCResponse(status: .ok)

        case .getActiveWorkspace:
            if let ws = workspaceManager.activeWorkspace {
                let info = WorkspaceInfo(
                    id: ws.id, name: ws.name,
                    windowCount: ws.windowIDs.count,
                    monitorID: ws.monitorID, focused: true,
                    layout: ws.layoutMode.rawValue,
                    workspaceType: ws.workspaceType.rawValue,
                    masterRatio: ws.masterRatio,
                    masterCount: ws.masterCount
                )
                return IPCResponse(status: .ok, data: .workspaces([info]))
            }
            return IPCResponse(status: .error, message: "No active workspace")

        case .focusWindow(let windowID):
            if let window = windowManager.window(for: CGWindowID(windowID)) {
                AccessibilityWrapper.focusWindow(window.axElement, pid: window.pid)
                return IPCResponse(status: .ok)
            }
            return IPCResponse(status: .error, message: "Window not found")

        case .toggleFloat:
            toggleFloat()
            return IPCResponse(status: .ok)

        case .setLayout(let layout):
            setLayout(layout)
            return IPCResponse(status: .ok)

        case .cycleLayout:
            cycleLayout()
            return IPCResponse(status: .ok)

        case .renameWorkspace(let id, let name):
            workspaceManager.renameWorkspace(id, to: name)
            return IPCResponse(status: .ok)

        case .createWorkspace(let name):
            let monitor = monitorManager.primaryMonitor?.id ?? 0
            let ws = workspaceManager.createWorkspace(name: name, monitorID: monitor)
            return IPCResponse(status: .ok, message: "Created workspace \(ws.id): \(ws.name)")

        case .getEventLog(let count):
            let entries = EventLog.shared.recentEntries(count: count)
            let events = entries.map { entry in
                let formatter = ISO8601DateFormatter()
                return EventInfo(
                    timestamp: formatter.string(from: entry.timestamp),
                    type: entry.type.rawValue,
                    message: entry.message
                )
            }
            return IPCResponse(status: .ok, data: .events(events))

        case .toggleScratchpad(let name):
            toggleScratchpad(name)
            return IPCResponse(status: .ok)

        case .listScratchpads:
            let sps = scratchpadManager.allScratchpads().map { sp in
                ScratchpadInfo(
                    name: sp.name,
                    app: sp.appName,
                    bundleID: sp.bundleID,
                    visible: scratchpadManager.isVisible(sp.name)
                )
            }
            return IPCResponse(status: .ok, data: .scratchpads(sps))

        case .saveSession:
            sessionManager.saveSession(
                workspaceManager: workspaceManager,
                windowManager: windowManager,
                tilingMode: currentTilingMode
            )
            return IPCResponse(status: .ok, message: "Session saved")

        case .restoreSession:
            if let session = sessionManager.loadSession() {
                sessionManager.restoreWorkspaceMetadata(session: session, workspaceManager: workspaceManager)
                sessionManager.matchAndRestoreWindows(session: session, windowManager: windowManager, workspaceManager: workspaceManager)
                recomputeAllLayouts()
                pluginManager.onSessionRestored()
                return IPCResponse(status: .ok, message: "Session restored")
            }
            return IPCResponse(status: .error, message: "No saved session found")

        case .listProfiles:
            let names = profileManager.allProfiles().map { $0.name }
            return IPCResponse(status: .ok, data: .profiles(names))

        case .activateProfile(let name):
            activateProfile(name)
            return IPCResponse(status: .ok)

        case .saveProfile(let name):
            _ = profileManager.captureCurrentState(
                name: name,
                workspaceManager: workspaceManager,
                layoutEngine: layoutEngine,
                config: currentConfig,
                scratchpadManager: scratchpadManager
            )
            return IPCResponse(status: .ok, message: "Profile '\(name)' saved")

        case .getLayoutInfo:
            if let ws = workspaceManager.activeWorkspace {
                let info = LayoutInfo(
                    mode: ws.layoutMode.rawValue,
                    windowCount: ws.windowIDs.count,
                    masterRatio: ws.masterRatio,
                    masterCount: ws.masterCount,
                    workspaceID: ws.id,
                    workspaceName: ws.name
                )
                return IPCResponse(status: .ok, data: .layout(info))
            }
            return IPCResponse(status: .error, message: "No active workspace")

        case .moveToMaster:
            moveToMaster()
            return IPCResponse(status: .ok)

        case .rotateWindows(let dir):
            rotateWindows(dir == "ccw" ? .counterClockwise : .clockwise)
            return IPCResponse(status: .ok)

        case .adjustMasterRatio(let delta):
            adjustMasterRatio(delta: CGFloat(delta))
            return IPCResponse(status: .ok)

        case .adjustMasterCount(let delta):
            adjustMasterCount(delta: delta)
            return IPCResponse(status: .ok)

        case .focusDirection(let dir):
            if let direction = parseDirection(dir) { focusDirection(direction) }
            return IPCResponse(status: .ok)

        case .moveDirection(let dir):
            if let direction = parseDirection(dir) { moveWindowDirection(direction) }
            return IPCResponse(status: .ok)

        case .growWidth:
            resizeWindow(axis: .horizontal, delta: 0.05)
            return IPCResponse(status: .ok)

        case .shrinkWidth:
            resizeWindow(axis: .horizontal, delta: -0.05)
            return IPCResponse(status: .ok)

        case .growHeight:
            resizeWindow(axis: .vertical, delta: 0.05)
            return IPCResponse(status: .ok)

        case .shrinkHeight:
            resizeWindow(axis: .vertical, delta: -0.05)
            return IPCResponse(status: .ok)

        case .normalize:
            normalizeLayout()
            return IPCResponse(status: .ok)

        case .togglePseudoFullscreen:
            togglePseudoFullscreen()
            return IPCResponse(status: .ok)

        case .unknown(let cmd):
            return IPCResponse(status: .error, message: "Unknown command: \(cmd)")
        }
    }

    private func parseDirection(_ str: String) -> Direction? {
        switch str.lowercased() {
        case "left": return .left
        case "right": return .right
        case "up": return .up
        case "down": return .down
        default: return nil
        }
    }
}

// MARK: - WindowManagerDelegate

extension AppDelegate: WindowManagerDelegate {
    func windowManager(_ manager: WindowManager, didDetectNewWindow window: WindowNode) {
        guard !isBootstrapping else { return }

        EventLog.shared.log(.windowCreated,
            "New window: \(window.appName) - \(window.title ?? "untitled")",
            details: ["windowID": "\(window.windowID)", "bundleID": window.bundleID])

        ruleEngine.applyRules(to: window, workspaceManager: workspaceManager)

        // Check if this window should be a scratchpad
        for sp in scratchpadManager.allScratchpads() {
            if let bundleID = sp.bundleID, window.bundleID.lowercased() == bundleID.lowercased() {
                scratchpadManager.assignWindow(window.windowID, toScratchpad: sp.name)
                window.isFloating = true
                break
            }
            if let appName = sp.appName, window.appName.lowercased().contains(appName.lowercased()) {
                scratchpadManager.assignWindow(window.windowID, toScratchpad: sp.name)
                window.isFloating = true
                break
            }
        }

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

        // Apply float geometry
        if window.isFloating, let geo = window.floatGeometry {
            if window.centerOnOpen, let monitor = monitorManager.primaryMonitor {
                let x = monitor.visibleFrame.midX - geo.width / 2
                let y = monitor.visibleFrame.midY - geo.height / 2
                AccessibilityWrapper.setWindowFrame(window.axElement,
                    frame: CGRect(x: x, y: y, width: geo.width, height: geo.height))
            }
        }

        recomputeAllLayouts()
        pluginManager?.onWindowCreated(window: window)
    }

    func windowManager(_ manager: WindowManager, didRemoveWindow windowID: CGWindowID) {
        EventLog.shared.log(.windowDestroyed, "Window removed: \(windowID)")

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

            // Show focus ring
            if currentConfig.overlay.showFocusRing {
                if let frame = window.targetFrame ?? Optional(window.frame) {
                    overlayManager.showFocusRing(frame: frame)
                }
            }

            // Auto-hide scratchpads when focusing non-scratchpad windows
            if !scratchpadManager.isScratchpadWindow(windowID) {
                for w in windowManager.allWindows where w.windowID != windowID {
                    scratchpadManager.handleFocusLost(windowID: w.windowID, windowManager: windowManager)
                }
            }
        }
    }

    func windowManagerNeedsRelayout(_ manager: WindowManager) {
        recomputeAllLayouts()
    }
}

// MARK: - MonitorManagerDelegate

extension AppDelegate: MonitorManagerDelegate {
    func monitorManager(_ manager: MonitorManager, profileChangedTo profile: String) {
        NSLog("[SonicLand] Monitor profile changed to: \(profile)")
        pluginManager.onMonitorProfileChanged(profile: profile)

        // Re-evaluate context rules immediately
        let actions = ruleEngine.forceContextEvaluation(monitorManager: monitorManager)
        for action in actions {
            handleContextAction(action)
        }

        // Rebuild workspaces for new monitor configuration
        applyTilingMode()
    }
}
