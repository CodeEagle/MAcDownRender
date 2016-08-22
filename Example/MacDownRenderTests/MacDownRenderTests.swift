//
//  MacDownRenderTests.swift
//  MacDownRenderTests
//
//  Created by LawLincoln on 16/8/22.
//  Copyright © 2016年 CodeEagle. All rights reserved.
//

import XCTest
import MacDownRender
class MacDownRenderTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    func asyncTest(timeout: NSTimeInterval = 30, block: (XCTestExpectation) -> ()) {
        let expectation: XCTestExpectation = expectationWithDescription("Swift Expectations")
        block(expectation)
        waitForExpectationsWithTimeout(timeout) { (error) -> Void in
            if error != nil {
                XCTFail("time out: \(error)")
            } else {
                XCTAssert(true, "success")
            }
        }
    }
    
    func updatePreview(content: String) {
        let path = NSTemporaryDirectory() + "preview.html"
        guard let data = content.dataUsingEncoding(NSUTF8StringEncoding) else { return }
        do {
            try data.writeToFile(path, options: .AtomicWrite)
            NSWorkspace.sharedWorkspace().openFile("file:///"+path, withApplication: "com.apple.Safari")
        } catch { }
        
    }
    
    func testExample() {
        asyncTest { (e) in
            if let path = NSBundle(forClass: MacDownRenderTests.self).pathForResource("File", ofType: nil) {
                do {
                    let content = try String(contentsOfFile: path)
                    (content as NSString).markdown({ (html) in
                        self.updatePreview(html)
                        e.fulfill()
                    })
                } catch {}
            }
        }
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock {
            // Put the code you want to measure the time of here.
        }
    }
    
}
