// ===----------------------------------------------------------------------===
//
//  This source file is part of the CosmosSwift open source project.
//
//  NodeStorageProtocolTests.swift last updated 02/06/2020
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

import iAVLPlus
import XCTest

class NodeStorageProtocolTests: XCTestCase {
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testNewStorageNode() throws {
        let tree = InMemoryNodeStorage<Data, Data, TestHasher>()

        _ = try [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].map {
            try tree.set(key: Data([$0]), value: Data([$0]))
        }
        XCTAssertEqual(tree.versions, [0])
        try tree.commit()
        XCTAssertEqual(tree.versions.sorted(), [0, 1])
    }

    func testAddVersion() throws {
        let tree = InMemoryNodeStorage<Data, Data, TestHasher>()

        _ = try [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].map {
            try tree.set(key: Data([$0]), value: Data([$0]))
        }
        try tree.commit()
        _ = try [10, 11, 12, 13, 14, 15, 16, 17, 18, 19].map {
            try tree.set(key: Data([$0]), value: Data([$0]))
        }
        try tree.commit()
        print("\(try tree.root(at: 0))")
        XCTAssertEqual(tree.versions.sorted(), [0, 1, 2])
        XCTAssertEqual(tree.version, 2)
    }

    func testAddVersionsAndDeleteLast() throws {
        let tree = InMemoryNodeStorage<Data, Data, TestHasher>()

        _ = try [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].map {
            try tree.set(key: Data([$0]), value: Data([$0]))
        }
        try tree.commit()
        _ = try [10, 11, 12, 13, 14, 15, 16, 17, 18, 19].map {
            try tree.set(key: Data([$0]), value: Data([$0]))
        }
        try tree.commit()
        print("\(try tree.root(at: 0))")
        XCTAssertEqual(tree.versions.sorted(), [0, 1, 2])
        _ = try [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].map {
            try tree.set(key: Data([$0]), value: Data([$0]))
        }
        try tree.commit()
        _ = try [10, 11, 12, 13, 14, 15, 16, 17, 18, 19].map {
            try tree.set(key: Data([$0]), value: Data([$0]))
        }
        try tree.commit()
        XCTAssertEqual(tree.versions.sorted(), [0, 1, 2, 3, 4])
        try tree.deleteLast()
        XCTAssertEqual(tree.versions.sorted(), [0, 1, 2, 3])
        XCTAssertEqual(tree.version, 3)
    }

    func testAddVersionsAndDelete2Last() throws {
        let tree = InMemoryNodeStorage<Data, Data, TestHasher>()

        _ = try [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].map {
            try tree.set(key: Data([$0]), value: Data([$0]))
        }
        try tree.commit()
        _ = try [10, 11, 12, 13, 14, 15, 16, 17, 18, 19].map {
            try tree.set(key: Data([$0]), value: Data([$0]))
        }
        try tree.commit()
        print("\(try tree.root(at: 0))")
        XCTAssertEqual(tree.versions.sorted(), [0, 1, 2])
        _ = try [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].map {
            try tree.set(key: Data([$0]), value: Data([$0]))
        }
        try tree.commit()
        _ = try [10, 11, 12, 13, 14, 15, 16, 17, 18, 19].map {
            try tree.set(key: Data([$0]), value: Data([$0]))
        }
        try tree.commit()
        XCTAssertEqual(tree.versions.sorted(), [0, 1, 2, 3, 4])
        try tree.deleteAll(from: 2)
        XCTAssertEqual(tree.versions.sorted(), [0, 1])
        XCTAssertEqual(tree.version, 2)
    }

    // TODO: test handling of orphans
    // TODO: test

    func testAddVersionsRollback() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    func testNewStorageNode2() throws {
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
