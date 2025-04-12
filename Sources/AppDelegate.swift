import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        menuBarController = MenuBarController()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Clean up resources if needed
    }
}