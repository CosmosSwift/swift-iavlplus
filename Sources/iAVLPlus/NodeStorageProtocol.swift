// ===----------------------------------------------------------------------===
//
//  This source file is part of the CosmosSwift open source project.
//
//  NodeStorageProtocol.swift last updated 02/06/2020
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

public protocol NodeStorageProtocol: CustomStringConvertible {
    associatedtype Node: NodeProtocol
    typealias Key = Node.Key
    typealias Value = Node.Value
    typealias Hasher = Node.Hasher

    /// Current working root (unless just reset or committed, not committed yet)
    var root: Node { get }

    /// Current working version (not committed yet)
    var version: Int64 { get set }

    /// Orphans organized by version
//    var orphans: [Node.Hasher.Hash: Int64] {get set}

    /// All available versions from the Storage
    var versions: [Int64] { get }

    // init(_ root: Node, _ version: Int64)

    // func get(hash: Hasher.Hash) throws -> Node

    // func getRoots() throws -> [Node]

    /// Get the root node at provided version.
    /// - Parameter version: requested version number
    /// - returns: the corresponding root node or nil if doesn't exist
    func root(at version: Int64) throws -> Node?

    func get(key: Key, at version: Int64) throws -> (index: Int64, value: Value?)

    func get(index: Int64, at version: Int64) throws -> (key: Key, value: Value)?
    func has(key: Key, at version: Int64) throws -> Bool
    func next(key: Key, at version: Int64) throws -> Key?

    func get(key: Key) throws -> (index: Int64, value: Value?)
    func get(index: Int64) throws -> (key: Key, value: Value)?
    func has(key: Key) throws -> Bool
    func next(key: Key) throws -> Key?

    // func save(branch: Node, checkLatestVersion: Bool) throws -> Data
    // func save(root: Node, version: Int64) throws
    // func saveEmpty(version: Int64) throws
    // func save(orphans: [Node], version: Int64) throws
    // func save(node: Node, flushToDisk: Bool) throws
    // func save(tree: Node, version: Int64) throws -> Data

    /// Deletes the last saved version, adjusts the current version number accordingly
    /// It will delete the root and the orphans
    /// The current version is set to the deleted version, and the current orphans are set to the orphans of the deleted version
    func deleteLast() throws

    /// Deletes all versions from version `from` onwards.
    /// The roots and orphans are adjusted as if deleteLast() was called as many times as needed to reach version `from`
    /// The current version is set to from, as well as corresponding orphans list.
    func deleteAll(from: Int64) throws

    // func prune() throws -> [Int64]
    // func clone(_ version: Int64) throws -> Self

    /// Rolls back all changes to the tree since last save.
    /// That means that the root is now the same as the root as of `version - 1` and the orphans list for version `version` is empty
    /// `version` remains as is
    func rollback()

    /// Commits changes to the tree by saving them in the backing Storage.
    /// `version` is incremented, current root is set to just saved version and orphans for this version is set to empty.
    func commit() throws

    var description: String { get }

    /// Adds or Updates a leaf in the tree and recalculates (hashes, size, height, balancing) the tree when required.
    /// When the item is updated, will return true. Returns false otherwise
    /// This will lead to updating the tree and orphans for the current version
    func set(key: Key, value: Value) throws -> Bool

    /// Removes the leaf with key `key` if it exists.
    /// If the leaf exists, removes the leaf node, returns its value and `true` and rebalances the tree as needed
    /// it also adjusts as hashes, size and height where needed.
    /// If the leaf doesn't exist, returns nil fort he value and false for the removed boolean.
    func remove(key: Key) -> (Value?, Bool)

    // MARK: Encapsulation of node creation

    func makeEmpty() -> Node
    func makeLeaf(key: Key, value: Value) -> Node
    func makeInner(key: Key, left: Node, right: Node) -> Node
}

public extension NodeStorageProtocol {
//    init(_ root: Node) {
//        self.init(root, 0)
//    }

    /// Get the index and value for the node at key `key` at version `version`
    /// Will throw if the version doesn't exist
    /// If the key doesn't exists, returns -1 for the index and nil for the value
    func get(key: Key, at version: Int64) throws -> (index: Int64, value: Value?) {
        if let root = try self.root(at: version) {
            return root.get(key)
        }
        throw IAVLErrors.generic(identifier: "NodeStorageProtocol().get()", reason: "no root for version \(version)")
    }

    /// Get the key and value for the node at index `index` at version `version`
    /// Will throw if the version doesn't exist
    /// If the index doesn't exists, returns nil
    func get(index: Int64, at version: Int64) throws -> (key: Key, value: Value)? {
        if let root = try self.root(at: version) {
            return root.get(index)
        }
        throw IAVLErrors.generic(identifier: "NodeStorageProtocol().get()", reason: "no root for version \(version)")
    }

    func has(key: Key, at version: Int64) throws -> Bool {
        if let root = try self.root(at: version) {
            return root.has(key)
        }
        throw IAVLErrors.generic(identifier: "NodeStorageProtocol().get()", reason: "no root for version \(version)")
    }

    func next(key: Key, at version: Int64) throws -> Self.Key? {
        if let root = try self.root(at: version) {
            return root.next(key: key)
        }
        throw IAVLErrors.generic(identifier: "NodeStorageProtocol().get()", reason: "no root for version \(version)")
    }

    var root: Node {
        if let root = try? self.root(at: version) {
            return root
        }
        return makeEmpty()
    }

    func get(key: Key) throws -> (index: Int64, value: Value?) {
        try get(key: key, at: version)
    }

    func get(index: Int64) throws -> (key: Key, value: Value)? {
        try get(index: index, at: version)
    }

    func has(key: Key) throws -> Bool {
        try has(key: key, at: version)
    }

    func next(key: Key) throws -> Key? {
        try next(key: key, at: version)
    }

    func recursiveSet(_ node: Node, _ key: Key, _ value: Value, _ version: Int64, orphans: inout [Node]) throws -> (node: Node, updated: Bool) {
        let newVersion = version
        if node.isEmpty {
            return (makeLeaf(key: key, value: value), false)
        } else if let (_, _, l, r) = node.inner {
            orphans.append(node)
            let left, right: Node
            let updated: Bool
            if key < node.key {
                (left, updated) = try recursiveSet(l, key, value, newVersion, orphans: &orphans)
                right = r
            } else {
                left = l
                (right, updated) = try recursiveSet(r, key, value, newVersion, orphans: &orphans)
            }
            if updated {
                return (makeInner(key: node.key, left: left, right: right), true)
            } else {
                if let balanced = balance(node.key, left, right, newVersion, orphans: &orphans) {
                    return (balanced, false)
                } else {
                    return (makeInner(key: node.key, left: left, right: right), false)
                }
            }
        } else {
            if key < node.key {
                let new = makeLeaf(key: key, value: value)
                return (makeInner(key: node.key, left: new, right: node), false)
            } else if key > node.key {
                let new = makeLeaf(key: key, value: value)
                return (makeInner(key: key, left: node, right: new), false)
            } else {
                orphans.append(node)
                return (makeLeaf(key: key, value: value), true)
            }
        }
    }

    // removes the node corresponding to the passed key and balances the tree.
    // It returns:
    // - the node that replaces the orig. node after remove
    // - new leftmost leaf key for tree after successfully removing 'key' if changed.
    // - the removed value
    // - the orphaned nodes.
    // swiftlint:disable large_tuple
    func recursiveRemove(node: Node, key: Key, version: Int64, orphans: inout [Node]) -> (newSelf: Node?, newKey: Key?, newValue: Value?) {
        let newVersion = version
        if node.isEmpty {
            return (nil, nil, nil)
        } else if let (_, _, l, r) = node.inner {
            if key < node.key {
                // key < node.key; we go to the left to find the key:
                let (newLeftNode, newKey, value) = recursiveRemove(node: l, key: key, version: newVersion, orphans: &orphans)
                if orphans.count == 0 {
                    return (node, nil, value)
                } else {
                    orphans.append(node)
                    if let newLeftNode = newLeftNode {
                        if let balanced = balance(node.key, newLeftNode, r, newVersion, orphans: &orphans) {
                            return (balanced, newKey, value)
                        } else {
                            return (makeInner(key: node.key, left: newLeftNode, right: r), newKey, value)
                        }
                    } else { // left node held value, was removed
                        return (r, node.key, value)
                    }
                }
            } else {
                // node.key <= key; either found or look to the right:
                let (newRightNode, newKey, value) = recursiveRemove(node: r, key: key, version: newVersion, orphans: &orphans)
                if orphans.count == 0 {
                    return (node, nil, value)
                } else {
                    orphans.append(node)
                    if let newRightNode = newRightNode {
                        if let balanced = balance(node.key, l, newRightNode, newVersion, orphans: &orphans) {
                            return (balanced, newKey, value)
                        } else {
                            return (makeInner(key: newKey ?? node.key, left: l, right: newRightNode), newKey, value)
                        }
                    } else { // right node held value, was removed
                        return (l, node.key, value)
                    }
                }
            }
        } else {
            if key == node.key {
                orphans.append(node)
                return (nil, nil, node.value)
            } else {
                return (node, nil, nil)
            }
        }
    }

    // MARK: balancing function

    // balance() takes an inner node's components and returns a balanced version of that node if required. It returns nil otherwise.
    // it performs the rotations directly allowing to optimize the LR and RL cases, as intermediate nodes are not created.
    // creation of intermediate nodes is costly in this implementation because Nodes are immutable and therefore size, height and hash are generated upon creation.
    // it also updates the list of orphans created by this process
    // swiftlint:disable function_body_length
    func balance(_ key: Key, _ left: Node, _ right: Node, _: Int64, orphans: inout [Node]) -> Node? {
        let l = left
        let r = right
        let balance = l.height - r.height

        if balance > 1 {
            guard let (_, _, ll, lr) = l.inner else {
                return nil
            }
            if l.balance > 0 { // node.left can't be a leaf
                // Left Left Case
                let newInner, balanced: Node
                // perform a rotateRight(node)
                newInner = makeInner(key: key, left: lr, right: r)
                balanced = makeInner(key: l.key, left: ll, right: newInner)
                orphans.append(l)
                return balanced
            } else {
                // Left Right Case
                let newLeftInner, newRightInner, balanced: Node
                guard let (_, _, lrl, lrr) = lr.inner else {
                    return nil
                }
                // perform a rotateLeft(l) and a rotateRight(node)
                newLeftInner = makeInner(key: l.key, left: ll, right: lrl)
                newRightInner = makeInner(key: key, left: lrr, right: r)
                balanced = makeInner(key: lr.key, left: newLeftInner, right: newRightInner)
                orphans.append(contentsOf: [l, lr])
                return balanced
            }
        } else if balance < -1 {
            guard let (_, _, rl, rr) = r.inner else {
                return nil
            }
            if r.balance < 0 { // node.right can't be a leaf
                // Right Right Case
                let newInner, balanced: Node
                // perform a rotateLeft(node)
                newInner = makeInner(key: key, left: l, right: rl)
                balanced = makeInner(key: r.key, left: newInner, right: rr)
                orphans.append(r)
                return balanced
            } else {
                // Right Left Case
                let newLeftInner, newRightInner, balanced: Node
                guard let (_, _, rll, rlr) = rl.inner else {
                    return nil
                }
                // perform a rotateLeft(l) and a rotateRight(node)
                newLeftInner = makeInner(key: key, left:
                    l, right: rll)
                newRightInner = makeInner(key: r.key, left: rlr, right: rr)
                balanced = makeInner(key: rl.key, left: newLeftInner, right: newRightInner)
                orphans.append(contentsOf: [r, rl])
                return balanced
            }
        } else {
            // Nothing changed
            return nil
        }
    }
}

public extension NodeStorageProtocol {
    // GetVersionedWithProof gets the value under the key at the specified version
    // if it exists, or returns nil.
    func getVersionedWithProof(_ key: Key, _ version: Int64) throws -> (Value?, RangeProof<Node>) {
        guard let root = try? self.root(at: version) else {
            throw IAVLErrors.generic(identifier: "NodeStorageProtocol().getVersionedRangeWithProof", reason: "Version doesn't exist")
        }
        return try root.getWithProof(key)
    }

    // GetVersionedRangeWithProof gets key/value pairs within the specified range
    // and limit.
    // swiftlint:disable large_tuple
    func getVersionedRangeWithProof(_ start: Key, _ end: Key, _ limit: UInt, _ version: Int64) throws -> (
        keys: [Key], values: [Value], proof: RangeProof<Node>
    ) {
        guard let root = try? self.root(at: version) else {
            throw IAVLErrors.generic(identifier: "NodeStorageProtocol().getVersionedRangeWithProof", reason: "Version doesn't exist")
        }

        let (k, v, rp) = try root.getRangeWithProof(start, end, limit)

        return (k, v, rp)
    }
}
