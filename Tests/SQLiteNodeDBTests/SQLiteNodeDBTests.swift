// ===----------------------------------------------------------------------===
//
//  This source file is part of the CosmosSwift open source project.
//
//  SQLiteNodeDBTests.swift last updated 02/06/2020
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

import Foundation
@testable import iAVLPlusCore
@testable import SQLiteNodeDB
import XCTest

class NodeProtocolTests: XCTestCase {
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testEmptyRootAndAdd() throws {
        let tree = try SQLiteNodeStorage<Data, Data, TestHasher>()

        try tree.set(key: Data([1]), value: Data([1]))
        XCTAssertTrue(try tree.has(key: Data([1])))
    }

    func testKeyComparable() throws {
        XCTAssertLessThan(TestHasher.Hash(Data([0])), TestHasher.Hash(Data([1])))
        XCTAssertFalse(TestHasher.Hash(Data([0])) < TestHasher.Hash(Data([0])))
        XCTAssertGreaterThan(TestHasher.Hash(Data([1])), TestHasher.Hash(Data([0])))
    }

    func testNonEmptyRootAndAdd() throws {
        let tree = try SQLiteNodeStorage<Data, Data, TestHasher>()
        _ = try [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].reduce(1) { (i: Int64, u: UInt8) in

            try tree.set(key: Data([u]), value: Data([u]))
            print(tree.root)
            XCTAssertEqual(tree.root.size, i)
            XCTAssertEqual(tree.root.height, Int8(log2(Double(i) - 0.01) + 1))
            return i + 1
        }
    }

    func testNonEmptyRootAndAddAndRemove() throws {
        let tree = try SQLiteNodeStorage<Data, Data, TestHasher>()

        _ = try [0, 1, 2, 3, 4, 5, 6].reduce(1) { (i: Int64, u: UInt8) in

            try tree.set(key: Data([u]), value: Data([u]))
            print(tree.root)
            XCTAssertEqual(tree.root.size, i)
            XCTAssertEqual(tree.root.height, Int8(log2(Double(i) - 0.01) + 1))
            return i + 1
        }
        XCTAssertTrue(tree.root.has(Data([4])))
        tree.remove(key: Data([4]))
        XCTAssertFalse(tree.root.has(Data([4])))
        print(tree.root)
        XCTAssertEqual(tree.root.height, 3)
        XCTAssertEqual(tree.root.size, 6)
        // TODO: check structure of the tree
    }

    func testNonEmptyRootAndAddAndRemoveTwice() throws {
        let tree = try SQLiteNodeStorage<Data, Data, TestHasher>()

        _ = try [0, 1, 2, 3, 4, 5, 6].reduce(1) { (i: Int64, u: UInt8) in

            try tree.set(key: Data([u]), value: Data([u]))
            print(tree.root)
            XCTAssertEqual(tree.root.size, i)
            XCTAssertEqual(tree.root.height, Int8(log2(Double(i) - 0.01) + 1))
            return i + 1
        }
        XCTAssertTrue(tree.root.has(Data([4])))
        tree.remove(key: Data([4]))
        XCTAssertFalse(tree.root.has(Data([4])))
        tree.remove(key: Data([4]))
        print(tree.root)
        XCTAssertEqual(tree.root.height, 3)
        XCTAssertEqual(tree.root.size, 6)
        // TODO: check structure of the tree
    }

    func testNonEmptyRootAndAddReverse() throws {
        let tree = try SQLiteNodeStorage<Data, Data, TestHasher>()

        _ = try [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].reversed().reduce(1) { (i: Int64, u: UInt8) in

            try tree.set(key: Data([u]), value: Data([u]))
            print(tree.root)
            XCTAssertEqual(tree.root.size, i)
            XCTAssertEqual(tree.root.height, Int8(log2(Double(i) - 0.01) + 1))
            return i + 1
        }
        // TODO: check structure of the tree
    }

    func testNonEmptyRootAndAddNonOrder() throws {
        let tree = try SQLiteNodeStorage<Data, Data, TestHasher>()

        _ = try [0, 8, 2, 1, 7, 5, 3, 6, 4, 9].reversed().reduce(1) { (i: Int64, u: UInt8) in

            try tree.set(key: Data([u]), value: Data([u]))
            print(tree.root)
            let height = Int8(log2(Double(i) - 0.01) + 1)
            print("\(tree.root.height) <-> \(height)")
            return i + 1
        }
        XCTAssertEqual(tree.root.size, 10)
        XCTAssertEqual(tree.root.height, 4)

        // TODO: check structure of the tree
    }

    func testHas() throws {
        let tree = try SQLiteNodeStorage<Data, Data, TestHasher>()

        _ = try [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].reduce(1) { (i: Int64, u: UInt8) in

            try tree.set(key: Data([u]), value: Data([u]))
            print(tree.root)
            let height = Int8(log2(Double(i) - 0.01) + 1)
            print("\(tree.root.height) <-> \(height)")
            return i + 1
        }
        XCTAssertTrue(tree.root.has(Data([1])))
        XCTAssertFalse(tree.root.has(Data([10])))
    }

    func testGetByKey() throws {
        let tree = try SQLiteNodeStorage<Data, Data, TestHasher>()

        _ = try [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].reduce(1) { (i: Int64, u: UInt8) in

            try tree.set(key: Data([u]), value: Data([u]))
            print(tree.root)
            let height = Int8(log2(Double(i) - 0.01) + 1)
            print("\(tree.root.height) <-> \(height)")
            return i + 1
        }
        let node = tree.root.get(Data([6]))
        XCTAssertNotNil(node.value)
        XCTAssertEqual(node.index, 6)
        XCTAssertEqual(node.value!, Data([6]))
    }

    func testGetByIndex() throws {
        let tree = try SQLiteNodeStorage<Data, Data, TestHasher>()

        _ = try [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].reduce(1) { (i: Int64, u: UInt8) in

            try tree.set(key: Data([u]), value: Data([u]))
            print(tree.root)
            let height = Int8(log2(Double(i) - 0.01) + 1)
            print("\(tree.root.height) <-> \(height)")
            return i + 1
        }
        let node = tree.root.get(5)
        XCTAssertNotNil(node)
        print("\(node!.key.hex)")
        XCTAssertEqual(node!.key, Data([5]))
        XCTAssertEqual(node!.value, Data([5]))
    }

    func testNextExistsInRange() throws {
        let tree = try SQLiteNodeStorage<Data, Data, TestHasher>()

        _ = try [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].reduce(1) { (i: Int64, u: UInt8) in

            try tree.set(key: Data([u]), value: Data([u]))
            print(tree.root)
            let height = Int8(log2(Double(i) - 0.01) + 1)
            print("\(tree.root.height) <-> \(height)")
            return i + 1
        }
        let key = tree.root.next(key: Data([5]))
        XCTAssertNotNil(key)
        print("\(key!.hex)")
        XCTAssertEqual(key!.hex, "06")
    }

    func testNextExistsBeforeLeastKey() throws {
        let tree = try SQLiteNodeStorage<Data, Data, TestHasher>()

        _ = try [1, 2, 3, 4, 5, 6, 7, 8, 9].reduce(1) { (i: Int64, u: UInt8) in

            try tree.set(key: Data([u]), value: Data([u]))
            print(tree.root)
            let height = Int8(log2(Double(i) - 0.01) + 1)
            print("\(tree.root.height) <-> \(height)")
            return i + 1
        }
        let key = tree.root.next(key: Data([0]))
        XCTAssertNotNil(key)
        print("\(key!.hex)")
        XCTAssertEqual(key!.hex, "01")
    }

    func testNextNotExists() throws {
        let tree = try SQLiteNodeStorage<Data, Data, TestHasher>()

        _ = try [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].reduce(1) { (i: Int64, u: UInt8) in

            try tree.set(key: Data([u]), value: Data([u]))
            print(tree.root)
            let height = Int8(log2(Double(i) - 0.01) + 1)
            print("\(tree.root.height) <-> \(height)")
            return i + 1
        }
        let key = tree.root.next(key: Data([9]))
        XCTAssertNil(key)
    }

    func testIterate() throws {
        let tree = try SQLiteNodeStorage<Data, Data, TestHasher>()

        _ = try [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].reduce(1) { (i: Int64, u: UInt8) in

            try tree.set(key: Data([u]), value: Data([u]))
            // print(tree.root)
            // let height = Int8(log2(Double(i) - 0.01) + 1)
            // print("\(tree.root.height) <-> \(height)")
            return i + 1
        }

        var res: [UInt8] = []
        _ = tree.root.iterate { (k, v) -> Bool in
            print("{\(k.hex), \(v.hex)}")
            res.append(k[0])
            return false
        }

        XCTAssertEqual([0, 1, 2, 3, 4, 5, 6, 7, 8, 9], res)
    }

    func testIterateDescending() throws {
        let tree = try SQLiteNodeStorage<Data, Data, TestHasher>()

        _ = try [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].reduce(1) { (i: Int64, u: UInt8) in

            try tree.set(key: Data([u]), value: Data([u]))
            // print(tree.root)
            // let height = Int8(log2(Double(i) - 0.01) + 1)
            // print("\(tree.root.height) <-> \(height)")
            return i + 1
        }
        var res: [UInt8] = []
        _ = tree.root.iterate(false) { (k, v) -> Bool in
            print("{\(k.hex), \(v.hex)}")
            res.append(k[0])
            return false
        }

        XCTAssertEqual([0, 1, 2, 3, 4, 5, 6, 7, 8, 9].reversed(), res)
    }

    func testIterateRange() throws {
        let tree = try SQLiteNodeStorage<Data, Data, TestHasher>()

        _ = try [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].reduce(1) { (i: Int64, u: UInt8) in

            try tree.set(key: Data([u]), value: Data([u]))
            // print(tree.root)
            // let height = Int8(log2(Double(i) - 0.01) + 1)
            // print("\(tree.root.height) <-> \(height)")
            return i + 1
        }
        var res: [UInt8] = []

        _ = tree.root.iterateRange(Data([4]), Data([9]), true) { (k, _, _) -> Bool in
            res.append(k[0])
            return false
        }

        XCTAssertEqual([4, 5, 6, 7, 8, 9], res)
    }

    func testIterateSubRange() throws {
        let tree = try SQLiteNodeStorage<Data, Data, TestHasher>()

        _ = try [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].map {
            try tree.set(key: Data([$0]), value: Data([$0]))
        }

        var res: [UInt8] = []

        _ = tree.root.iterateRange(Data([4]), Data([8]), true) { (k, _, _) -> Bool in
            res.append(k[0])
            return false
        }

        XCTAssertEqual([4, 5, 6, 7, 8], res)
    }

    func testTraverseNonInclusive() throws {
        let tree = try SQLiteNodeStorage<Data, Data, TestHasher>()

        _ = try [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].map {
            try tree.set(key: Data([$0]), value: Data([$0]))
        }

        var res: [UInt8] = []

        _ = tree.root.traverseInRange(from: Data([4]), to: Data([8]), ascending: true) { (k, _) -> Bool in
            if k.value != nil { // only append leaf
                res.append(k.key[0])
            }
            return false
        }

        XCTAssertEqual([4, 5, 6, 7], res)
    }

    func testPathToLeafExisting() throws {
        let tree = try SQLiteNodeStorage<Data, Data, TestHasher>()

        _ = try [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].map {
            try tree.set(key: Data([$0]), value: Data([$0]))
        }
        print("\(tree.root)")

        let (ptl, l, b) = tree.root.pathToLeaf(Data([4]))

        for i in 0 ..< ptl.count {
            print("\(ptl[i])")
        }
        XCTAssertEqual(l.key, Data([4]))
        XCTAssertTrue(b) // exists
    }

    func testPathToLeafAbsentInRange() throws {
        let tree = try SQLiteNodeStorage<Data, Data, TestHasher>()

        _ = try [0, 1, 2, 3, 5, 6, 7, 8, 9].map {
            try tree.set(key: Data([$0]), value: Data([$0]))
        }
        print("\(tree.root)")

        let (ptl, l, b) = tree.root.pathToLeaf(Data([4]))

        for i in 0 ..< ptl.count {
            print("\(ptl[i])")
        }
        XCTAssertEqual(l.key.hex, "03") // left of where key would be
        XCTAssertFalse(b) // doesn't exists
    }

    func testPathToLeafAbsentOutOfRange() throws {
        let tree = try SQLiteNodeStorage<Data, Data, TestHasher>()

        _ = try [1, 2, 3, 4, 5, 6, 7, 8, 9].map {
            try tree.set(key: Data([$0]), value: Data([$0]))
        }
        print("\(tree.root)")

        let (ptl, l, b) = tree.root.pathToLeaf(Data([0]))

        for i in 0 ..< ptl.count {
            print("\(ptl[i])")
        }
        XCTAssertEqual(l.key.hex, "01") // smallest key item
        XCTAssertTrue(ptl.verify(l.hash, tree.root))
        XCTAssertFalse(b) // doesn't exists
    }

    func testGetWithProofExistingKey() throws {
        let tree = try SQLiteNodeStorage<Data, Data, TestHasher>()

        _ = try [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].map {
            try tree.set(key: Data([$0]), value: Data([$0]))
        }
        print("\(tree.root)")

        let (v, p) = try tree.root.getWithProof(Data([4]))

        print("\(p)")

        for k in p.keys {
            print("\(k.hex)")
        }

        XCTAssertNotNil(v)
        XCTAssertEqual(v!.hex, "04")
    }

    func testGetWithProofExistingKeyAndVerifyItem() throws {
        let tree = try SQLiteNodeStorage<Data, Data, TestHasher>()

        _ = try [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].map {
            try tree.set(key: Data([$0]), value: Data([$0]))
        }
        print("\(tree.root)")

        let (v, p) = try tree.root.getWithProof(Data([4]))

        print("\(p)")
        print("\(p.rootHash!.hex)")
        XCTAssertEqual(p.rootHash!.hex, tree.root.hash.hex)
        print("\(p.treeEnd)")

        for k in p.keys {
            print("\(k.hex)")
        }

        XCTAssertNotNil(v)
        XCTAssertEqual(v!.hex, "04")
    }

    func testGetWithProofNonExistingKey() throws {
        let tree = try SQLiteNodeStorage<Data, Data, TestHasher>()

        _ = try [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].map {
            try tree.set(key: Data([$0]), value: Data([$0]))
        }
        print("\(tree.root)")

        let (v, p) = try tree.root.getWithProof(Data([10]))

        print("\(p)")
        XCTAssertNil(v)
    }

    func testGetWithProofNonExistingKeyAndVerifyAbsence() throws {
        let tree = try SQLiteNodeStorage<Data, Data, TestHasher>()

        _ = try [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].map {
            try tree.set(key: Data([$0]), value: Data([$0]))
        }
        print("\(tree.root)")

        let (v, p) = try tree.root.getWithProof(Data([10]))

        print("\(p)")
        XCTAssertNil(v)
        print("\(p.leaves[0].key.hex)")
        XCTAssertTrue(p.treeEnd)

        p.verify(tree.root.hash)
        XCTAssertThrowsError(try p.verifyItem(tree.root.hash, Data([10]), Data([10])))
        XCTAssertNoThrow(try p.verifyAbsence(tree.root.hash, Data([10])))

        // TODO: also try to verify on multiple different versions of the root
    }

    // TODO: build tree in reverse and do the same as above

    // TODO: insert items in various places in the tree and check structure

    func testCommit() throws {
        // let tree = try SQLiteNodeStorage<Data, Data, TestHasher>("/Users/keuzo/test.db")
        let tree = try SQLiteNodeStorage<Data, Data, TestHasher>()

        _ = try [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].map {
            try tree.set(key: Data([$0]), value: Data([$0]))
        }
        try tree.commit()
        _ = try [10, 11, 12, 13, 14, 15, 16, 17, 18, 19].map {
            try tree.set(key: Data([$0]), value: Data([$0]))
        }
        try tree.commit()
        print("\(tree.root(at: 0))")
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
    }

    func testLoadFromExistingDB() throws {
        let tree = try SQLiteNodeStorage<Data, Data, TestHasher>("/tmp/temp.db")
        _ = try [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].map {
            try tree.set(key: Data([$0]), value: Data([$0]))
        }
        try tree.commit()
        _ = try [10, 11, 12, 13, 14, 15, 16, 17, 18, 19].map {
            try tree.set(key: Data([$0]), value: Data([$0]))
        }
        try tree.commit()
        print("\(tree.root(at: 0))")
        _ = try [0, 1, 2, 3, 4, 5, 6, 7, 8, 9].map {
            try tree.set(key: Data([$0]), value: Data([$0]))
        }
        try tree.commit()
        _ = try [10, 11, 12, 13, 14, 15, 16, 17, 18, 19].map {
            try tree.set(key: Data([$0]), value: Data([$0]))
        }
        try tree.commit()

        let tree2 = try SQLiteNodeStorage<Data, Data, TestHasher>("/tmp/temp.db")
        print("\(tree2.roots)")
        print("\(tree2.version)")
        print("\(tree2.root)")
        let (_, _, l, r) = tree2.root.inner!
        print("\(l)")
        print("\(r)")
    }

    func testPerformanceTreeCreation() throws {
        // This is an example of a performance test case.
        let tree = try SQLiteNodeStorage<Data, Data, TestHasher>()
        measure {
            for j in 0 ..< 10 {
                for i in 0 ..< 1000 {
                    let d = Data(String(i * j).utf8)
                    _ = try? tree.set(key: d, value: d)
                }
                try? tree.commit()
            }
        }
    }
}
