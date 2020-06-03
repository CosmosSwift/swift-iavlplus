// ===----------------------------------------------------------------------===
//
//  This source file is part of the CosmosSwift open source project.
//
//  NodeProtocol.swift last updated 02/06/2020
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

public protocol NodeProtocol: CustomStringConvertible, Codable {
    associatedtype Key: Comparable & Codable & DataProtocol & InitialisableProtocol // & IteratorProtocol
    associatedtype Value: Codable & DataProtocol & InitialisableProtocol
    associatedtype Hasher: HasherProtocol

    var key: Key { get }
    var version: Int64 { get }

    var value: Value? { get } // only on leaf node
    // swiftlint:disable large_tuple
    var inner: (height: Int8, size: Int64, left: Self, right: Self)? { get } // only on inner node

    var hash: Hasher.Hash { get }

    var isEmpty: Bool { get }
}

extension NodeProtocol {
    public var height: Int8 {
        if let (height, _, _, _) = inner {
            return height
        } else {
            return 0
        }
    }

    public var size: Int64 {
        if let (_, size, _, _) = inner {
            return size
        } else {
            return 1
        }
    }

    public var balance: Int {
        if let (_, _, l, r) = inner {
            return Int(l.height - r.height)
        } else {
            return 0
        }
    }

    // Check if the node has a descendant with the given key.
    public func has(_ key: Key) -> Bool {
        if self.key == key { return true }
        if let (_, _, l, r) = inner {
            if key < self.key {
                return l.has(key)
            } else {
                return r.has(key)
            }
        } else {
            return false
        }
    }

    // next key in the tree after the given key.
    // TODO: there is a faster way to get to the next key by finding the leftmost
    //       node below the first inner node with key greater or equal to the key
    public func next(key: Key) -> Key? {
        var next: Key?
        iterate { (k, _) -> Bool in
            if k > key {
                next = k
                return true
            } else {
                return false
            }
        }
        return next
    }

    // Get a node under the node by key.
    public func get(_ key: Key) -> (index: Int64, value: Value?) {
        if let value = self.value {
            if self.key == key { return (0, value) }
            if self.key < key {
                return (1, nil)
            } else {
                return (0, nil)
            }
        } else if let (_, size, left, right) = inner {
            if key < self.key {
                return left.get(key)
            } else {
                let (i, v) = right.get(key)
                return (i + size - right.size, v)
            }
        }
        return (0, nil)
    }

    // Get a node under the node by index.
    public func get(_ index: Int64) -> (key: Key, value: Value)? {
        if let v = value {
            return index == 0 ? (key, v) : nil
        } else if let (_, _, l, r) = inner {
            if index < l.size {
                return l.get(index)
            } else {
                return r.get(index - l.size)
            }
        }
        return nil
    }

    // Iterate iterates over all keys of the tree, in order.
    // Returns true if callback returns true, false otherwise
    @discardableResult
    public func iterate(_ calling: (_ key: Key, _ value: Value) -> Bool, _ ascending: Bool = true) -> Bool {
        return traverse(ascending) { node in
            if let value = node.value {
                return calling(node.key, value)
            }
            return false
        }
    }

    // IterateRange makes a callback for all nodes with key between start and end non-inclusive.
    // If either are nil, then it is open on that side (nil, nil is the same as Iterate)
    @discardableResult
    public func iterateRange(_ start: Key, _ end: Key, _ ascending: Bool, _ calling: (Key, Value, Int64) -> Bool) -> Bool {
        return traverseInRange(from: start, to: end, ascending: ascending, inclusive: true, depth: 0) { node, _ in
            if let value = node.value {
                return calling(node.key, value, node.version)
            }
            return false
        }
    }

    // traverse is a wrapper over traverseInRange when we want the whole tree
    func traverse(_ ascending: Bool = true, _ calling: (Self) -> Bool) -> Bool {
        return traverseInRange(ascending: ascending) { n, _ in
            calling(n)
        }
    }

    func traverseInRange(from: Key? = nil, to: Key? = nil, ascending: Bool = true, inclusive: Bool = false, depth: UInt8 = 0, calling: (Self, UInt8) -> Bool) -> Bool {
        let afterStart = from == nil || from! < key
        let startOrAfter = afterStart || from! == key
        let beforeEnd = to == nil || key < to! || (inclusive && key == to!)

        var stop = false

        if let (_, _, left, right) = inner {
            if startOrAfter, beforeEnd {
                stop = calling(self, depth)
                if stop { return true }
            }
            if ascending { // check lower nodes, then higher
                if afterStart {
                    stop = left.traverseInRange(from: from, to: to, ascending: ascending, inclusive: inclusive, depth: depth + 1, calling: calling)
                }
                if stop { return true }
                if beforeEnd {
                    stop = right.traverseInRange(from: from, to: to, ascending: ascending, inclusive: inclusive, depth: depth + 1, calling: calling)
                }
            } else { // check the higher nodes first
                if beforeEnd {
                    stop = right.traverseInRange(from: from, to: to, ascending: ascending, inclusive: inclusive, depth: depth + 1, calling: calling)
                }
                if stop { return true }
                if afterStart {
                    stop = left.traverseInRange(from: from, to: to, ascending: ascending, inclusive: inclusive, depth: depth + 1, calling: calling)
                }
            }
        } else {
            if startOrAfter, beforeEnd {
                stop = calling(self, depth)
            }
        }
        return stop
    }
}

// MARK: Proof

extension NodeProtocol {
    /// If the key does not exist, returns the path to the next leaf left of key (w/
    /// path), except when key is less than the least item, in which case it returns
    /// a path to the least item.
    func pathToLeaf(_ key: Key?) -> (path: PathToLeaf<Self>, left: Self, exists: Bool) {
        var path = PathToLeaf<Self>()
        let (node, exists) = _pathToLeaf(key, &path)
        return (path, node, exists)
    }

    /// pathToLeaf is a helper which recursively constructs the PathToLeaf.
    /// As an optimization the already constructed path is passed in as an argument
    /// and is shared among recursive calls.
    private func _pathToLeaf(_ key: Key?, _ path: inout PathToLeaf<Self>) -> (Self, Bool) {
        if let (h, s, l, r) = inner {
            if let key = key, key < self.key { // left side so we store the right hash
                path.append(ProofInnerNode(h, s, version, .right, r.hash))
                return l._pathToLeaf(key, &path)
            } else { // right side, so we store the left hash
                path.append(ProofInnerNode(h, s, version, .left, l.hash))
                return r._pathToLeaf(key, &path)
            }
        } else {
            if key == self.key {
                return (self, true)
            }
            return (self, false)
        }
    }
}

// MARK: RangeProof

extension NodeProtocol {
    // GetRangeWithProof gets key/value pairs within the specified range and limit.
    // keyStart is inclusive and keyEnd is exclusive.
    // If keyStart or keyEnd don't exist, the leaf before keyStart
    // or after keyEnd will also be included, but not be included in values.
    // If keyEnd-1 exists, no later leaves will be included.
    // If keyStart >= keyEnd and both not nil, panics.
    // Limit is never exceeded.
    public func getRangeWithProof(_ start: Key?, _ end: Key?, _ limit: UInt) throws -> (keys: [Key], value: [Value], proof: RangeProof<Self>) {
        var keys: [Key] = []
        var values: [Value] = []
        var leaves: [ProofLeafNode<Self>] = []

        if let s = start, let e = end, s >= e {
            throw IAVLErrors.generic(identifier: "NodeProtocol().getRangeWithProof()", reason: "if keyStart and keyEnd are present, need keyStart < keyEnd.")
        }

        // TODO: ensure all hashes are properly computed

        // Get the first key/value pair proof, which provides us with the left key.
        // Key doesn't exist, but instead we got the prev leaf (or the
        // first or last leaf), which provides proof of absence).
        let (path, left, _) = pathToLeaf(start)

        let startOK = start == nil || start! <= left.key
        let endOK = end == nil || left.key < end!

        // If left.key is in range, add it to key/values.
        if startOK && endOK {
            keys.append(left.key)
            values.append(left.value!)
        }
        // Either way, add to proof leaves.
        leaves.append(ProofLeafNode<Self>(key: left.key, valueHash: Hasher.hash(left.value!), version: left.version))

        // 1: Special case if limit is 1.
        // 2: Special case if keyEnd is left.key+1.
        let nextKey = next(key: left.key)
        // TODO: Check id nextKey works
        if limit == 1 || nextKey == nil || (end != nil && nextKey! >= end!) {
            return (keys, values, RangeProof<Self>(leftPath: path, leaves: leaves))
        }

        // Traverse starting from afterLeft, until keyEnd or the next leaf
        // after keyEnd.
        var innersq: [PathToLeaf<Self>] = []
        var inners = PathToLeaf<Self>()
        var leafCount = 1
        var pathCount = 0

        // TODO: check coverage of this function in tests as not sure that the above are passed by value

        _ = traverseInRange(from: nextKey, to: nil, ascending: true, inclusive: false, depth: 0) { (node, _) -> Bool in
            // Track when we diverge from path, or when we've exhausted path,
            // since the first innersq shouldn't include it.
            if pathCount != -1 {
                if path.count <= pathCount {
                    // We're done with path counting.
                    pathCount = -1
                } else {
                    let pn = path[pathCount]
                    // TODO: can an inner node ever have just left or just right? when that is the case, isn't this a leaf?
                    if let (height, _, left, right) = node.inner {
                        if pn.height != height ||
                            (pn.side == .left && pn.sideHash != left.hash) ||
                            (pn.side == .right && pn.sideHash != right.hash) {
                            // We've diverged, so start appending to inners.
                            pathCount = -1
                        } else {
                            pathCount += 1
                        }
                    }
                }
            }

            if let v = node.value {
                innersq.append(inners)
                inners = PathToLeaf()

                leaves.append(ProofLeafNode(key: node.key, valueHash: Hasher.hash(v), version: node.version))
                leafCount += 1

                // Terminate when we found enough leaves
                if limit > 0 && limit <= leafCount {
                    return true
                }

                // Terminate if we've found keyEnd or after.
                if end != nil && node.key >= end! {
                    return true
                }
                keys.append(node.key)
                values.append(v)

                // Terminate if we've found keyEnd-1 or after.
                // We don't want to fetch any leaves for it.
                let nextKey = self.next(key: left.key)
                if nextKey == nil || (end != nil && nextKey! >= end!) {
                    return true
                }
            } else if let (h, s, _, r) = node.inner {
                if pathCount < 0 { // Only process non redundant path items.
                    // left is nil for range proof inners
                    inners.append(ProofInnerNode<Self>(h, s, node.version, .right, r.hash))
                }
            }
            return false
        }
        return (keys, values, RangeProof<Self>(leftPath: path, innerNodes: innersq, leaves: leaves))
    }

    // GetWithProof gets the value under the key if it exists, or returns nil.
    // A proof of existence or absence is returned alongside the value.
    public func getWithProof(_ key: Key) throws -> (value: Value?, proof: RangeProof<Self>) {
        let nextKey = next(key: key)

        let (_, values, proof) = try getRangeWithProof(key, nextKey, 2)
        if values.count > 0, proof.leaves[0].key == key {
            return (values[0], proof)
        }
        return (nil, proof) // TODO: not sure what it means to return a nil Value?
    }
}
