//
//  ViewController.swift
//  WindowSwitcher
//
//  Created by Daniel Rodriguez Gil on 11/11/2018.
//  Copyright © 2018 Daniel Rodriguez Gil. All rights reserved.
//

import Cocoa
import HotKey

class HotKeyEntry : NSObject, NSCoding {
    var title : String = ""
    var app : String = ""
    
    init(title: String) {
        self.title = title
    }
    
    init(title: String, app: String) {
        self.title = title
        self.app = app
    }
    
    required convenience init(coder aDecoder: NSCoder) {
        let title = aDecoder.decodeObject(forKey: "title") as! String? ?? ""
        let app = aDecoder.decodeObject(forKey: "app") as! String? ?? ""
        
        
        self.init(title: title, app: app)
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(title, forKey: "title")
        aCoder.encode(app, forKey: "app")
    }
}

extension Array {
    mutating func move(from start: Index, to end: Index) {
        guard (0..<count) ~= start, (0...count) ~= end else { return }
        if start == end { return }
        let targetIndex = start < end ? end - 1 : end
        insert(remove(at: start), at: targetIndex)
    }
    
    mutating func move(with indexes: IndexSet, to toIndex: Index) {
        let movingData = indexes.map{ self[$0] }
        let targetIndex = toIndex - indexes.filter{ $0 < toIndex }.count
        for (i, e) in indexes.enumerated() {
            remove(at: e - i)
        }
        insert(contentsOf: movingData, at: targetIndex)
    }
}

class ViewController: NSViewController,NSTableViewDataSource,NSTableViewDelegate {
    
    fileprivate enum CellIdentifiers {
        static let slotCell = "slot"
        static let appCell = "app"
        static let titleCell = "title"
    }
    
    @IBOutlet weak var tableView: NSTableView!
    
    var hotKeysEvents : [HotKey] = []
    var hotKeys : [HotKeyEntry] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.doubleAction = #selector(doubleClick)
        tableView.registerForDraggedTypes([NSPasteboard.PasteboardType("public.data")])
        
        let lastHotKeys = UserDefaults.standard.object(forKey: "characters") as! Data?
        if (lastHotKeys != nil) {
            do {
                try hotKeys = NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(lastHotKeys!) as! [HotKeyEntry]
                register()
            } catch {
                print("Can't get characters from datastore")
            }
        }
    }
    
    func tableView(_ tableView: NSTableView, writeRowsWith rowIndexes: IndexSet, to pboard: NSPasteboard) -> Bool {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: rowIndexes, requiringSecureCoding: false)
            let item = NSPasteboardItem()
            item.setData(data, forType: NSPasteboard.PasteboardType("public.data"))
            pboard.writeObjects([item])
            return true
        } catch {
            fatalError("Can't encode data: \(error)")
        }
        return false
        
    }
    
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        if dropOperation == .above {
            return .move
        }
        return []
    }
    
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        do {
            let pb = info.draggingPasteboard
            if let itemData = pb.pasteboardItems?.first?.data(forType: NSPasteboard.PasteboardType("public.data")),
                let indexes = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(itemData) as? IndexSet
            {
                hotKeys.move(with: indexes, to: row)
                unregister()
                register()
                update()
                let targetIndex = row - (indexes.filter{ $0 < row }.count)
                tableView.selectRowIndexes(IndexSet(targetIndex..<targetIndex+indexes.count), byExtendingSelection: false)
                return true
            }
        } catch {
            fatalError("Can't decode data: \(error)")
        }
        return false
    }
    
    @IBAction func createNewItem(_ sender: Any) {
        let name = showPrompt()
        if name != nil && name! != "" {
            hotKeys.append(HotKeyEntry.init(title: name!))
            unregister()
            register()
            update()
        }
    }
    
    func showPrompt(def: String = "") -> String? {
        let alert = NSAlert()
        alert.messageText = "Window title"
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
        let textField = NSTextField(string: def)
        textField.setFrameSize(NSSize.init(width: 180, height: 24))
        alert.accessoryView = textField
        alert.window.initialFirstResponder = textField
        
        let buttonPressed = alert.runModal()
        if buttonPressed == NSApplication.ModalResponse.alertFirstButtonReturn {
            return textField.stringValue
        }
        
        return nil
    }
    
    @objc func doubleClick(sender: AnyObject) {
        let newString = showPrompt(def: hotKeys[tableView.selectedRow].title)
        if newString != nil && newString! != "" {
            hotKeys[tableView.selectedRow].title = newString!
            unregister()
            register()
            update()
        }
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return hotKeys.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        var text : String = ""
        var identifier : String = ""
        
        if (tableColumn == tableView.tableColumns[0]) { // Slot
            text = String(row + 1)
            identifier = CellIdentifiers.slotCell
        } else if (tableColumn == tableView.tableColumns[1]) { // App
            text = hotKeys[row].app
            identifier = CellIdentifiers.appCell
        } else if (tableColumn == tableView.tableColumns[2]) { // Window
            text = hotKeys[row].title
            identifier = CellIdentifiers.titleCell
        }
        
        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: identifier), owner: nil) as? NSTableCellView {
            cell.textField?.stringValue = text
            return cell
        }
        
        return nil
    }
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if let windowSelectorViewController = segue.destinationController as? WindowSelectorViewController {
            windowSelectorViewController.callback = { message in
                if (message != "") {
                    let hkentry = HotKeyEntry.init(title: "", app: message)
                    self.hotKeys.append(hkentry)
                    self.unregister()
                    self.register()
                    self.update()
                }
            }
        }
    }
    
    @IBAction func removeItem(_ sender: Any) {
        let row = tableView.selectedRow
        if row > -1 {
            hotKeys.remove(at: row)
            unregister()
            register()
            tableView.reloadData()
            update()
        }
    }
    
    func register() {
        for (index, item) in hotKeys.enumerated() {
            let event = HotKey(keyCombo: KeyCombo(key: getKey(number: index + 1), modifiers: [.command]))
            event.keyDownHandler = {
                self.showWindow(app: item.app, title: item.title)
                print("Showing " + item.app + item.title)
            }
            hotKeysEvents.append(event)
        }
        
        tableView.reloadData()
    }
    
    func update() {
        do {
            let encodedData : Data
            try encodedData = NSKeyedArchiver.archivedData(withRootObject: hotKeys, requiringSecureCoding: false)
            UserDefaults.standard.set(encodedData, forKey: "characters")
            UserDefaults.standard.synchronize()
        } catch {
            print("Can't store characters")
        }
    }
    
    func getKey(number : Int) -> Key {
        switch number {
        case 1:
            return Key.one
        case 2:
            return Key.two
        case 3:
            return Key.three
        case 4:
            return Key.four
        case 5:
            return Key.five
        case 6:
            return Key.six
        case 7:
            return Key.seven
        case 8:
            return Key.eight
        case 9:
            return Key.nine
        case 0:
            return Key.zero
        default:
            return Key.one
        }
    }
    
    func unregister() {
        hotKeysEvents = []
    }

    func showWindow(app : String, title : String) {
        // Process
        var pid = -1
        
        let options = CGWindowListOption(arrayLiteral: CGWindowListOption.excludeDesktopElements)
        let windowListInfo = CGWindowListCopyWindowInfo(options, CGWindowID(0)) as NSArray? as? [[String: AnyObject]]
        
        if (title != "") {
            if (windowListInfo != nil) {
                for window in windowListInfo! {
                    if window["kCGWindowName"] != nil {
                        let windowName = window["kCGWindowName"] as! String
                        if windowName.range(of: title) != nil {
                            pid = window["kCGWindowOwnerPID"] as! Int
                        }
                    }
                }
            }
        } else {
            if (windowListInfo != nil) {
                for window in windowListInfo! {
                    if window["kCGWindowOwnerName"] != nil {
                        let windowName = window["kCGWindowOwnerName"] as! String
                        if windowName.range(of: app) != nil {
                            pid = window["kCGWindowOwnerPID"] as! Int
                        }
                    }
                }
            }
        }
        
        let runningApps = NSWorkspace.shared.runningApplications;
        
        for runningApp in runningApps {
            if pid >= 0 && pid == runningApp.processIdentifier {
                runningApp.activate(options: NSApplication.ActivationOptions.activateIgnoringOtherApps)
            }
        }
    }
    
}

