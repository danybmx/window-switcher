//
//  WindowSelectorViewController.swift
//  WindowSwitcher
//
//  Created by Daniel Rodriguez Gil on 10/02/2019.
//  Copyright © 2019 Daniel Rodriguez Gil. All rights reserved.
//

import Cocoa

class WindowSelectorViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    
    @IBOutlet weak var tableView: NSTableView!
    
    var callback : ((String) -> Void)?
    
    var applications : [String] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.doubleAction = #selector(selectWindow)
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        updateWindowList()
    }
    
    @IBAction func selectWindow(sender: AnyObject) {
        callback?(applications[tableView.selectedRow])
        self.view.window?.performClose(nil)
    }
    
    func updateWindowList() {
        let options = CGWindowListOption(arrayLiteral: CGWindowListOption.excludeDesktopElements)
        let windowListInfo = CGWindowListCopyWindowInfo(options, CGWindowID(0)) as NSArray? as? [[String: AnyObject]]
        for window in windowListInfo! {
            if window["kCGWindowOwnerName"] != nil {
                let appName = window["kCGWindowOwnerName"] as! String
                if (!applications.contains(appName)) {
                    applications.append(appName)
                }
            }
        }
        applications = applications.sorted()
        tableView.reloadData()
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return applications.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "app"), owner: nil) as? NSTableCellView {
            cell.textField?.stringValue = applications[row]
            return cell
        }
        
        return nil
    }
    
}
