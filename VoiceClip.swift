import Cocoa
import AVFoundation
import Carbon.HIToolbox

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var recorder: AVAudioRecorder?
    var isRecording = false
    var hotKeyRef: EventHotKeyRef?
    var modifierFlags: UInt32 = UInt32(shiftKey)
    var keyCode: UInt32 = UInt32(kVK_ANSI_V)
    var hotkeyLabel = "⇧V"
    
    static var shared: AppDelegate!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        
        // Request mic permission
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { _ in }
        default: break
        }
        
        // Load saved hotkey
        loadHotkeyPrefs()
        
        // Setup menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateIcon()
        buildMenu()
        
        // Register global hotkey
        registerHotKey()
    }
    
    func loadHotkeyPrefs() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "hotkeyCode") != nil {
            keyCode = UInt32(defaults.integer(forKey: "hotkeyCode"))
            modifierFlags = UInt32(defaults.integer(forKey: "hotkeyModifiers"))
            hotkeyLabel = defaults.string(forKey: "hotkeyLabel") ?? "⇧V"
        }
    }
    
    func saveHotkeyPrefs() {
        let defaults = UserDefaults.standard
        defaults.set(Int(keyCode), forKey: "hotkeyCode")
        defaults.set(Int(modifierFlags), forKey: "hotkeyModifiers")
        defaults.set(hotkeyLabel, forKey: "hotkeyLabel")
    }
    
    func updateIcon() {
        if let button = statusItem.button {
            if isRecording {
                button.image = NSImage(systemSymbolName: "record.circle.fill", accessibilityDescription: "Recording")
                button.image?.isTemplate = false
                // Tint red
                let config = NSImage.SymbolConfiguration(paletteColors: [.red])
                button.image = button.image?.withSymbolConfiguration(config)
            } else {
                button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "VoiceClip")
                button.image?.isTemplate = true
            }
        }
    }
    
    func buildMenu() {
        let menu = NSMenu()
        
        let statusText = isRecording ? "🔴 Recording..." : "Ready"
        let statusItem = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let hotkeyItem = NSMenuItem(title: "Hotkey: \(hotkeyLabel)", action: #selector(changeHotkey), keyEquivalent: "")
        menu.addItem(hotkeyItem)
        
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        self.statusItem.menu = menu
    }
    
    @objc func changeHotkey() {
        let alert = NSAlert()
        alert.messageText = "Set New Hotkey"
        alert.informativeText = "Press the key combination you want to use, then click OK.\n\nCurrent: \(hotkeyLabel)"
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
        let field = HotkeyField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        field.isEditable = false
        field.alignment = .center
        field.placeholderString = "Press keys here..."
        field.bezelStyle = .roundedBezel
        alert.accessoryView = field
        
        alert.window.makeFirstResponder(field)
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn, let captured = field.capturedKey {
            unregisterHotKey()
            keyCode = captured.keyCode
            modifierFlags = captured.modifiers
            hotkeyLabel = captured.label
            saveHotkeyPrefs()
            registerHotKey()
            buildMenu()
        }
    }
    
    func registerHotKey() {
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x564C4950) // "VLIP"
        hotKeyID.id = 1
        
        let status = RegisterEventHotKey(keyCode, modifierFlags, hotKeyID, GetEventDispatcherTarget(), 0, &hotKeyRef)
        if status != noErr {
            print("Failed to register hotkey: \(status)")
        }
        
        // Install handler
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetEventDispatcherTarget(), { (_, event, _) -> OSStatus in
            AppDelegate.shared.toggleRecording()
            return noErr
        }, 1, &eventType, nil, nil)
    }
    
    func unregisterHotKey() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }
    
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    func startRecording() {
        let tempDir = FileManager.default.temporaryDirectory
        let url = tempDir.appendingPathComponent("voiceclip_\(Int(Date().timeIntervalSince1970)).m4a")
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.record()
            isRecording = true
            updateIcon()
            buildMenu()
        } catch {
            print("Recording failed: \(error)")
        }
    }
    
    func stopRecording() {
        guard let recorder = recorder else { return }
        recorder.stop()
        isRecording = false
        updateIcon()
        buildMenu()
        
        let url = recorder.url
        self.recorder = nil
        
        // Convert to MP3 using ffmpeg, then copy to clipboard
        let mp3Url = url.deletingPathExtension().appendingPathExtension("mp3")
        
        DispatchQueue.global().async {
            // Try ffmpeg conversion
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg")
            process.arguments = ["-i", url.path, "-y", "-codec:a", "libmp3lame", "-qscale:a", "2", mp3Url.path]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            
            var finalUrl = url
            do {
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus == 0 {
                    finalUrl = mp3Url
                }
            } catch {
                // ffmpeg not available, use m4a
            }
            
            DispatchQueue.main.async {
                // Copy file to clipboard
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.writeObjects([finalUrl as NSURL])
                
                // Also set as file promise
                pasteboard.setString(finalUrl.path, forType: .fileURL)
                
                // Play sound
                NSSound(named: "Purr")?.play()
                
                // Clean up other file
                if finalUrl == mp3Url {
                    try? FileManager.default.removeItem(at: url)
                }
            }
        }
    }
}

class HotkeyField: NSTextField {
    struct CapturedKey {
        let keyCode: UInt32
        let modifiers: UInt32
        let label: String
    }
    var capturedKey: CapturedKey?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        var parts: [String] = []
        var mods: UInt32 = 0
        
        if event.modifierFlags.contains(.control) { parts.append("⌃"); mods |= UInt32(controlKey) }
        if event.modifierFlags.contains(.option) { parts.append("⌥"); mods |= UInt32(optionKey) }
        if event.modifierFlags.contains(.shift) { parts.append("⇧"); mods |= UInt32(shiftKey) }
        if event.modifierFlags.contains(.command) { parts.append("⌘"); mods |= UInt32(cmdKey) }
        
        let keyChar = event.charactersIgnoringModifiers?.uppercased() ?? "?"
        parts.append(keyChar)
        
        let label = parts.joined()
        self.stringValue = label
        capturedKey = CapturedKey(keyCode: UInt32(event.keyCode), modifiers: mods, label: label)
    }
}
