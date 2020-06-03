// ===----------------------------------------------------------------------===
//
//  This source file is part of the CosmosSwift open source project.
//
//  NodeKeyTest.swift last updated 02/06/2020
//
//  Copyright © 2020 Katalysis B.V. and the CosmosSwift project authors.
//  Licensed under Apache License v2.0
//
//  See LICENSE.txt for license information
//  See CONTRIBUTORS.txt for the list of CosmosSwift project authors
//
//  SPDX-License-Identifier: Apache-2.0
//
// ===----------------------------------------------------------------------===

import iAVLPlusLegacy
import XCTest

class KeyPathTest: XCTestCase {
    let hash0: TestHasher.Hash = TestHasher(bytes: [UInt8](repeating: 9, count: 32))!.hash

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testKeyFormatBytes() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.

        _ = NodeKey<TestHasher, TestWire>.node(hash0)
        _ = NodeKey<TestHasher, TestWire>.orphan(0, 1, hash0)
        _ = NodeKey<TestHasher, TestWire>.root(2)
    }

    func testNegativeKeys() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        _ = NodeKey<TestHasher, TestWire>.orphan(-100, -200, hash0)
    }

    func testKeyFormat() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    func testOverflow() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        measure {
            // Put the code you want to measure the time of here.
        }
    }
}
