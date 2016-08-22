//
//  AppDelegate.swift
//  App
//
//  Created by LawLincoln on 16/8/22.
//  Copyright © 2016年 CodeEagle. All rights reserved.
//

import Cocoa
import MacDownRender
@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!


    func applicationDidFinishLaunching(aNotification: NSNotification) {
        
        
        func updatePreview(content: String) {
            let path = NSTemporaryDirectory() + "preview.html"
            guard let data = content.dataUsingEncoding(NSUTF8StringEncoding) else { return }
            do {
                try data.writeToFile(path, options: .AtomicWrite)
                Swift.print(path)
            } catch { }
            
        }
        
        func testExample() {
            
                if let path = NSBundle(forClass: AppDelegate.self).pathForResource("File", ofType: nil) {
                    do {
                        let content = try String(contentsOfFile: path)
                        (content as NSString).markdown({ (html) in
                            updatePreview(html)
                        })
                    } catch {}
                }
            
        }
        testExample()
        
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }


}

