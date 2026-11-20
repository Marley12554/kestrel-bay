// macOS smoke test. Pass the URL of a running export with ?qa=1.
import AppKit
import WebKit

guard CommandLine.arguments.count == 2,
      let url = URL(string: CommandLine.arguments[1]) else {
    fatalError("Supply a game URL with qa=1")
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let window = NSWindow(contentRect: NSRect(x: 80, y: 80, width: 1100, height: 576),
                      styleMask: [.titled, .closable], backing: .buffered, defer: false)
let configuration = WKWebViewConfiguration()
configuration.websiteDataStore = .nonPersistent()
let game = WKWebView(frame: window.contentView!.bounds, configuration: configuration)
window.contentView = game
window.title = "Kestrel Bay launch check"
window.orderFrontRegardless()
game.load(URLRequest(url: url))

// Physical Play-button and pointer-capture input are covered in godot-web.cjs.
// Here, exercise Apple's GPU process through startup and a night flight.
let startedAt = Date()
var polling = false
var lastState = ""
var flightStarted: Date?
let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
    if Date().timeIntervalSince(startedAt) > 120 {
        print("WebKit timed out at", lastState)
        exit(2)
    }
    if polling { return }
    polling = true
    game.evaluateJavaScript("""
      (() => {
        const s = window.kbGodotState;
        if (document.querySelector('#graphics-recovery')) return 'context lost';
        if (!s?.warmup.ready) return (window.kbBootStages || []).at(-1) || 'loading';
        if (!s.started) { kbGodotCommand('start'); return 'entering'; }
        if (!window.flightRequested) { window.flightRequested=true; kbGodotCommand('flyover'); }
        return s.vehicle.startsWith('Plane') && s.night ? 'flying' : 'started';
      })()
      """) { value, _ in
        polling = false
        guard let state = value as? String else { return }
        if state != lastState { print(state); fflush(stdout); lastState = state }
        if state == "context lost" { exit(1) }
        if state == "flying" {
            if flightStarted == nil { flightStarted = Date() }
            if Date().timeIntervalSince(flightStarted!) >= 4 { exit(0) }
        }
    }
}
app.run()
