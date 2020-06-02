// ===----------------------------------------------------------------------===
//
//  This source file is part of the CosmosSwift open source project.
//
//  InMemoryNode.swift last updated 02/06/2020
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

// TODO: Inner Nodes currently keep the whole structure of below them
// this means that when the tree is big, it needs to fit fully in memory.
// to protect against this, we should construct the tree such that it can load only sub parts of itself in memory, and request the missing parts when needed.
// we would use the left/right hashes to do this, but we want to keep the api such that the user of the tree doesn't need
// to care about this optimization

// a possibility could be that l and r fromNodeType.innner are computed, based on the l and r hashes which are stored
// an ordered list of storage db (in mem, local, remote?) is used to do the lookup when not present
// and a memory claiming strategy is put in place to keep the memory footprint within a specific range.

// Node is a class to allow copy on write behaviour

private extension DataProtocol {
    var hex: String {
        reduce("") { $0 + String(format: "%02X", $1) }
    }
}

public final class InMemoryNodeStorage<Key: Comparable & Codable & DataProtocol & InitialisableProtocol, Value: Codable & DataProtocol & InitialisableProtocol, Hasher: HasherProtocol>: NodeStorageProtocol {
    public typealias Key = Key

    public typealias Value = Value

    public typealias Hasher = Hasher
    public typealias Hash = Hasher.Hash

    public typealias Node = InMemoryNode<Key, Value, Hasher>

    var roots = [Int64: Node]()

    public var orphans: [Hash: Int64] = [:]

    public var version: Int64 = 0

    public var versions: [Int64] {
        [Int64](roots.keys)
    }

    public init() {
        version = 0
        roots[version] = Node.empty()
    }

    public init(_ root: Node, _ version: Int64) {
        self.version = version
        roots[version] = root
    }

    public func root(at version: Int64) throws -> InMemoryNode<Key, Value, Hasher>? {
        return roots[version]
    }

    public func rollback() {
        orphans = [:]
        roots[version] = roots[version - 1]
    }

    @discardableResult
    public func set(key: Key, value: Value) throws -> Bool {
        let newRoot: Node
        let updated: Bool
        var o: [Node] = []

        if let root = roots[version] {
            (newRoot, updated) = try recursiveSet(root, key, value, version, orphans: &o)
        } else { // no node, add as root
            newRoot = Node(key: key, value: value, version: version)
            updated = false
        }
        roots[version] = newRoot
        return updated
    }

    @discardableResult
    public func remove(key: Key) -> (Value?, Bool) {
        var o: [Node] = []

        if let root = roots[version] {
            let (newRoot, _, value) = recursiveRemove(node: root, key: key, version: version, orphans: &o)
            if let newRoot = newRoot, o.count > 0 { // newRoot != nil
                roots[version] = newRoot
                return (value, true)
            }
        }
        return (nil, false)
    }

    public func deleteLast() throws {
        roots[version] = nil
        orphans = [:]
        version -= 1
    }

    public func deleteAll(from: Int64) throws {
        for k in roots.filter({ $0.key >= from }).keys {
            roots[k] = nil
        }
        // TODO: reset funcntion to

        version = from
    }

    public func commit() throws {
        version += 1
        roots[version] = roots[version - 1]
        orphans = [:]
        return
    }

    public func makeEmpty() -> InMemoryNode<Key, Value, Hasher> {
        Node.empty()
    }

    public func makeLeaf(key: Key, value: Value) -> Node {
        Node(key: key, value: value, version: version)
    }

    public func makeInner(key: Key, left: Node, right: Node) -> Node {
        Node(key: key, left: left, right: right, version: version)
    }

    public var description: String {
        "InMemoryNodeStorage"
    }
}

public final class InMemoryNode<Key: Comparable & Codable & DataProtocol & InitialisableProtocol, Value: Codable & DataProtocol & InitialisableProtocol, Hasher: HasherProtocol>: NodeProtocol {
    public static func empty() -> InMemoryNode<Key, Value, Hasher> {
        return InMemoryNode<Key, Value, Hasher>()
    }

    public typealias Hash = Hasher.Hash

    indirect enum NodeType: Codable {
        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            if let v = try values.decodeIfPresent(Value.self, forKey: .v) {
                self = .leaf(v)
            } else {
                let h = try values.decode(Int8.self, forKey: .h)
                let s = try values.decode(Int64.self, forKey: .s)
                let l = try values.decode(InMemoryNode.self, forKey: .l)
                let r = try values.decode(InMemoryNode.self, forKey: .r)
                self = .inner(h, s, l, r)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .empty:
                break
            case let .leaf(v):
                try container.encode(v, forKey: .v)
            case let .inner(h, s, l, r):
                try container.encode(h, forKey: .h)
                try container.encode(s, forKey: .s)
                try container.encode(l, forKey: .l)
                try container.encode(r, forKey: .r)
            }
        }

        case leaf(_ value: Value)
        // swiftlint:disable large_tuple
        case inner(_ height: Int8, _ size: Int64, _ left: InMemoryNode, _ right: InMemoryNode)
        case empty
        // case dangling // a dangling node is a node which only has a hash

        public enum CodingKeys: CodingKey {
            case v
            case h
            case s
            case l
            case r
        }
    }

    private let _key: Key?

    public var key: Key {
        _key!
    }

    public let version: Int64

    let nodeType: NodeType

    // the hash is computed as follows:
    // amino encoding of: Int8(height), VarInt(size), VarInt(version)
    //           if Leaf: Data(key), Data(hash(value))
    //              else: Data(leftHash), Data(rightHash)
    // then take the hash of that
    public let hash: Hash

    public var isEmpty: Bool {
        _key == nil
    }

    private init() {
        _key = nil
        nodeType = .empty
        version = 0
        hash = Hasher.hash(Data())
    }

    public required init(key: Key, value: Value, version: Int64) {
        _key = key
        nodeType = .leaf(value)
        self.version = version
        hash = Hasher.hashLeaf(key: key, valueHash: Hasher.hash(value), version: version)
    }

    public required init(key: Key, left: InMemoryNode<Key, Value, Hasher>, right: InMemoryNode<Key, Value, Hasher>, version: Int64) {
        _key = key
        let h = Swift.max(left.height, right.height) + 1
        let s = left.size + right.size
        nodeType = .inner(h, s, left, right)
        self.version = version
        hash = Hasher.hashInner(height: h, size: s, leftHash: left.hash, rightHash: right.hash, version: version)
    }

    public var value: Value? {
        switch nodeType {
        case let .leaf(v):
            return v
        default:
            return nil
        }
    }

    public var inner: (height: Int8, size: Int64, left: InMemoryNode<Key, Value, Hasher>, right: InMemoryNode<Key, Value, Hasher>)? {
        switch nodeType {
        case let .inner(h, s, l, r):
            return (h, s, l, r)
        default:
            return nil
        }
    }

    public var description: String {
        var str: String
        switch nodeType {
        case .empty:
            str = "Empty"
        case let .leaf(v):

            str = "Leaf: {\(key.hex), \(v.hex)}, v: \(version), #: \(hash.hex)\n"
        case let .inner(h, s, l, r):
            str = "Inner: {\(key.hex), h: \(h), s: \(s), L: \(l.hash.hex), R: \(r.hash.hex)}, v: \(version), #: \(hash.hex)}\n"
            str += "-\(l)"
            str += "-\(r)"
        }
        return str
    }
}
