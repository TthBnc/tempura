import AppKit
import TempuraCore

guard let singleInstanceLock = SingleInstanceLock.tempura() else {
    exit(0)
}

let application = NSApplication.shared
let appDelegate = AppDelegate()

application.delegate = appDelegate
application.setActivationPolicy(.accessory)
application.run()

_ = singleInstanceLock
