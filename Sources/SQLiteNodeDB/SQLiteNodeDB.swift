// ===----------------------------------------------------------------------===
//
//  This source file is part of the CosmosSwift open source project.
//
//  SQLiteNodeDB.swift last updated 02/06/2020
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
import GRDB
import iAVLPlusCore

private extension DataProtocol {
    var hex: String {
        reduce("") { $0 + String(format: "%02X", $1) }
    }
}

/// This implementation keeps one version in memory and stores committed version to disk in an SQLite database
/// `self.version` contains the current version which still needs to be committed to the database
public final class SQLiteNodeStorage<Key: Comparable & Codable & DataProtocol & InitialisableProtocol, Value: Codable & DataProtocol & InitialisableProtocol, Hasher: HasherProtocol>: NodeStorageProtocol {
    public typealias Key = Key
    public typealias Value = Value
    public typealias Hasher = Hasher
    public typealias Hash = Hasher.Hash
    public typealias Node = SQLiteNode<Key, Value, Hasher>

    var roots = [Int64: Hash]()
    public var orphans: [Hash] = []
    public var version: Int64 = 0

    public var versions: [Int64] {
        [Int64](roots.keys)
    }

    /// Contains all new nodes created in memory not yet saved to the database.
    /// Flushed after calls to `commit()` or `rollback()`
    private var newNodes: [Node] = []

    private var dbQueue: DatabaseQueue

    /// Contains all nodes which have been loaded from the database or created in memory
    private var nodeCache: [Hash: Node] = [:]

    /// Create a new SQLiteNodeStorage from a db file
    /// If the db is not provided, creates an in memory database
    public init(_ path: String? = nil) throws {
        if let path = path {
            dbQueue = try DatabaseQueue(path: path)
        } else {
            dbQueue = DatabaseQueue()
        }

        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            try db.create(table: "node") { t in
                t.column("hash", .text).primaryKey().check { length($0) <= 64 } // 32 bytes hash
                t.column("root_version", .integer)
                // key is not part of a node to allow handling of empty nodes
                // there is no extra space used as a leaf can't be an inner and vice versa
            }

            try db.create(table: "leaf") { t in
                t.column("hash", .text).primaryKey().references("node", onDelete: .cascade).notNull()
                t.column("key", .blob).notNull()
                t.column("value", .blob).notNull()
                t.column("version", .integer).notNull()
            }

            try db.create(table: "inner") { t in
                t.column("hash", .text).primaryKey().references("node", onDelete: .cascade).notNull()
                t.column("key", .blob).notNull()
                t.column("height", .integer).notNull()
                t.column("size", .integer).notNull()
                t.column("left", .text).references("node", onDelete: .cascade) // 32 bytes hash
                t.column("right", .text).references("node", onDelete: .cascade) // 32 bytes hash
                t.column("version", .integer).notNull()
            }

            try db.create(table: "orphan") { t in
                t.column("hash", .text).primaryKey().references("node", onDelete: .cascade).notNull()
                t.column("until", .integer).notNull()
            }
        }

        try migrator.migrate(dbQueue)
        // load roots
        try loadRoot(from: 0)
        version = (roots.keys.max() ?? -1) + 1
        roots[version] = roots[version - 1]
    }

    public func root(at _: Int64) -> Node? {
        if let hash = roots[version], let root = try? loadNode(from: hash) {
            return root
        }
        return nil
    }

    public func rollback() {
        orphans = []
        // flush the cache of all newNodes
        _ = newNodes.map {
            self.nodeCache[$0.hash] = nil
        }
        newNodes = []
        // roots contains current working version
        roots[version] = roots[version - 1]
    }

    @discardableResult
    public func set(key: Key, value: Value) throws -> Bool {
        let newRoot: Node
        let updated: Bool
        var o: [Node] = []

        if let hash = roots[version], let root = try? loadNode(from: hash) {
            (newRoot, updated) = try recursiveSet(root, key, value, version, orphans: &o)
        } else { // no node, add as root
            newRoot = makeLeaf(key: key, value: value)
            updated = false
        }
        // queue orphans for addition in the DB
        _ = o.map { node in
            if node.version < self.version { // only add orphan nodes which were saved to the DB
                self.orphans.append(node.hash)
            } else { // orphans which were created as part of this version should be removed from newNodes
                self.newNodes.removeAll { $0.hash == node.hash }
            }
        }
        roots[version] = newRoot.hash
        return updated
    }

    @discardableResult
    public func remove(key: Key) -> (Value?, Bool) {
        if let hash = roots[version], let root = try? loadNode(from: hash) {
            var o: [Node] = []
            let (newRoot, _, value) = recursiveRemove(node: root, key: key, version: version, orphans: &o)
            if let newRoot = newRoot, o.count > 0 { // newRoot != nil
                // queue orphans for addition in the DB
                _ = o.map { node in
                    if node.version < self.version { // only add orphan nodes which were saved to the DB
                        self.orphans.append(node.hash)
                    } else { // orphans which were created as part of this version should be removed from newNodes
                        self.newNodes.removeAll { $0.hash == node.hash }
                    }
                }
                roots[version] = newRoot.hash
                return (value, true)
            }
        }
        return (nil, false)
    }

    public func commit() throws {
        // save nodes, roots and orphans
        try save()
        // TODO: all saved nodes from the cache need to be updated?
        // not if we keep track of nodes to `dd in other structure (newRoots newNodes)
        version += 1
        roots[version] = roots[version - 1]
        return
    }

    public func makeEmpty() -> Node {
        let n = Node.empty(version)
        newNodes.append(n)
        nodeCache[n.hash] = n
        return n
    }

    public func makeLeaf(key: Key, value: Value) -> Node {
        let n = Node(key: key, value: value, version: version)
        newNodes.append(n)
        nodeCache[n.hash] = n
        return n
    }

    public func makeInner(key: Key, left: Node, right: Node) -> Node {
        let n = Node(key: key, left: left, right: right, version: version)
        newNodes.append(n)
        nodeCache[n.hash] = n
        return n
    }

    public var description: String {
        // TODO: implement
        "SQLiteNodeStorage"
    }

    public func deleteLast() throws {
        rollback()
    }

    public func deleteAll(from _: Int64) throws {
        // TODO: implement
        return
    }

    private func loadOrphans(from: Int64) throws {
        // TODO: implement
        _ = try dbQueue.read { db in
            try Row.fetchAll(db, sql: """
                SELECT hash AS hash, until AS until FROM orphan
                WHERE until >= :from
            """, arguments: ["from": from])
        }
    }

    private func loadRoot(from: Int64) throws {
        let roots = try dbQueue.read { db in
            try Row.fetchAll(db, sql: """
            SELECT hash AS hash, root_version AS version FROM node AS n
            WHERE root_version NOT NULL AND root_version  >= :from
            """, arguments: ["from": from])
        }

        _ = roots.map { row in
            let hash: Hash = Hash(bytes: String(row["hash"]).toData()!)
            let version: Int64 = row["version"]
            self.roots[version] = hash
        }
    }

    /// Load the node with given `hash` from the database
    /// if `lazy` is set to true will only load a single node
    /// if `lazy`is set to false, will load the full tree below the node
    fileprivate func loadNode(from hash: Hash, lazy _: Bool = true) throws -> Node? {
        if let node = nodeCache[hash] {
            return node
        }

        guard let row = try? dbQueue.read({ db in
            try Row.fetchOne(db, sql: """
                        SELECT hash AS hash, version AS version, 0 AS height, 1 AS size, key AS key, value AS value, null AS leftHash, null AS rightHash FROM leaf
                        WHERE hash = :hash

                        UNION

                        SELECT hash AS hash, version AS version, height AS height, size AS size, key AS key, null AS value, left AS leftHash, right AS rightHash FROM inner
                        WHERE hash = :hash
            """, arguments: ["hash": hash.hex])
        }) else {
            return nil
        }
        let node: Node
        let version: Int64 = row["version"]
        if let lhStr = (row["leftHash"] as? String), let rhStr = (row["rightHash"] as? String) { // Inner
            // swiftlint:disable force_cast
            let key: Key = Key(bytes: (row["key"] as! String).toData()!)
            // swiftlint:disable force_cast
            let hash: Hash = Hash(bytes: (row["hash"] as! String).toData()!)
            let h: Int8 = row["height"]
            let s: Int64 = row["size"]
            let lh: Hash = Hash(bytes: lhStr.toData()!)
            let rh: Hash = Hash(bytes: rhStr.toData()!)
            node = Node(hash: hash, key: key, height: h, size: s, leftHash: lh, rightHash: rh, version: version, storage: self)
        } else if let valueStr = row["value"] as? String { // Leaf
            // swiftlint:disable force_cast
            let key: Key = Key(bytes: (row["key"] as! String).toData()!)
            // swiftlint:disable force_cast
            let hash: Hash = Hash(bytes: (row["hash"] as! String).toData()!)
            let value: Value = Value(bytes: valueStr.toData()!)
            node = Node(hash: hash, key: key, value: value, version: version, storage: self)
        } else { // Empty
            node = Node.empty(version)
        }

        nodeCache[hash] = node
        return node
    }

    /// Load the node with given `hash` from the database and all nodes below to a maximum depth of `depth`
    /// if `depth` == 0, only load the node
    fileprivate func loadNode(from _: Hash, depth _: UInt8) -> Node? {
        // TODO: go to the database to lazy load a node
        return nil
    }

    private func save() throws {
        // https://dba.stackexchange.com/questions/46410/how-do-i-insert-a-row-which-contains-a-foreign-key
        try dbQueue.write { db in
            // Nodes
            _ = try self.newNodes.map { node in
                try db.execute(
                    sql: "INSERT INTO node (hash, root_version) VALUES (?, ?)",
                    arguments: [node.hash.hex, node.hash == self.roots[self.version] ? self.version : nil]
                )
                switch node.nodeType {
                case let .leaf(v):
                    try db.execute(
                        sql: "INSERT INTO leaf (hash, key, value, version) VALUES (?, ?, ?, ?)",
                        arguments: [node.hash.hex, node.key.hex, Data(v.map { $0 }), self.version]
                    )
                case let .inner(h, s, l, r):
                    try db.execute(
                        sql: "INSERT INTO inner (hash, key, height, size, left, right, version) VALUES (?, ?, ?, ?, ?, ?, ?)",
                        arguments: [node.hash.hex, node.key.hex, h, s, l.hash.hex, r.hash.hex, self.version]
                    )
                default: // .empty only stored if root, .innerDB already comes from DB
                    break
                }
            }

            // Orphans
            _ = try self.orphans.map { o in
                try db.execute(
                    sql: "INSERT INTO orphan (hash, until) VALUES (?, ?)",
                    arguments: [o.hex, self.version]
                )
            }
            self.newNodes = []
            self.orphans = []
        }
    }
}

public final class SQLiteNode<Key: Comparable & Codable & DataProtocol & InitialisableProtocol, Value: Codable & DataProtocol & InitialisableProtocol, Hasher: HasherProtocol>: NodeProtocol {
    public static func empty(_ version: Int64 = 0) -> SQLiteNode<Key, Value, Hasher> {
        return SQLiteNode<Key, Value, Hasher>(version: version)
    }

    public typealias Hash = Hasher.Hash

    private weak var storage: SQLiteNodeStorage<Key, Value, Hasher>?

    indirect enum NodeType {
        case leaf(_ value: Value)
        // swiftlint:disable large_tuple
        case inner(_ height: Int8, _ size: Int64, _ left: SQLiteNode, _ right: SQLiteNode)
        case empty
        case leafDB(_ value: Value)
        case innerDB(_ height: Int8, _ size: Int64, _ leftHash: Hash, _ rightHash: Hash)
        case emptyDB // TODO: needed?
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

    private init(version: Int64) {
        _key = nil
        nodeType = .empty
        self.version = version
        hash = Hasher.hash(Data())
    }

    fileprivate init(hash: Hash, key: Key, value: Value, version: Int64, storage: SQLiteNodeStorage<Key, Value, Hasher>) {
        _key = key
        nodeType = .leafDB(value)
        self.version = version
        self.hash = hash
        self.storage = storage
    }

    fileprivate init(hash: Hash, key: Key, height: Int8, size: Int64, leftHash: Hash, rightHash: Hash, version: Int64, storage: SQLiteNodeStorage<Key, Value, Hasher>) {
        _key = key
        nodeType = .innerDB(height, size, leftHash, rightHash)
        self.version = version
        self.hash = hash
        self.storage = storage
    }

    fileprivate init(key: Key, value: Value, version: Int64) {
        _key = key
        nodeType = .leaf(value)
        self.version = version
        hash = Hasher.hashLeaf(key: key, valueHash: Hasher.hash(value), version: version)
    }

    fileprivate init(key: Key, left: SQLiteNode<Key, Value, Hasher>, right: SQLiteNode<Key, Value, Hasher>, version: Int64) {
        _key = key
        let h = Swift.max(left.height, right.height) + 1
        let s = left.size + right.size
        nodeType = .inner(h, s, left, right)
        self.version = version
        hash = Hasher.hashInner(height: h, size: s, leftHash: left.hash, rightHash: right.hash, version: version)
    }

    fileprivate init(key: Key, height: Int8, size: Int64, leftHash: Hash, rightHash: Hash, version: Int64) {
        _key = key
        nodeType = .innerDB(height, size, leftHash, rightHash)
        self.version = version
        hash = Hasher.hashInner(height: height, size: size, leftHash: leftHash, rightHash: rightHash, version: version)
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)

        version = try values.decode(Int64.self, forKey: .version)
        _key = try? values.decodeIfPresent(Key.self, forKey: .key)
        let nodeType: NodeType
        if _key == nil {
            nodeType = .empty
            hash = Hasher.hash(Data())
        } else {
            hash = try values.decode(Hash.self, forKey: .hash)
            if let v = try values.decodeIfPresent(Value.self, forKey: .value) {
                nodeType = .leaf(v)
            } else {
                let h = try values.decode(Int8.self, forKey: .height)
                let s = try values.decode(Int64.self, forKey: .size)
                let l = try values.decode(SQLiteNode.self, forKey: .leftHash)
                let r = try values.decode(SQLiteNode.self, forKey: .rightHash)
                nodeType = .inner(h, s, l, r)
            }
        }
        self.nodeType = nodeType
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)

        switch nodeType {
        case .empty, .emptyDB:
            break
        case let .leaf(v), let .leafDB(v):
            try container.encode(hash, forKey: .hash)
            try container.encode(_key!, forKey: .key)
            try container.encode(v, forKey: .value)
        case let .inner(h, s, l, r):
            try container.encode(hash, forKey: .hash)
            try container.encode(_key!, forKey: .key)
            try container.encode(h, forKey: .height)
            try container.encode(s, forKey: .size)
            try container.encode(l.hash, forKey: .leftHash)
            try container.encode(r.hash, forKey: .rightHash)
        case let .innerDB(h, s, l, r):
            try container.encode(hash, forKey: .hash)
            try container.encode(_key!, forKey: .key)
            try container.encode(h, forKey: .height)
            try container.encode(s, forKey: .size)
            try container.encode(l, forKey: .leftHash)
            try container.encode(r, forKey: .rightHash)
        }
    }

    enum CodingKeys: String, CodingKey {
        case hash = "h"
        case key = "k"
        case value = "p"
        case version = "v"
        case height = "hg"
        case size = "s"
        case leftHash = "lh"
        case rightHash = "rh"
    }

    public var value: Value? {
        switch nodeType {
        case let .leaf(v):
            return v
        case let .leafDB(v):
            return v
        default:
            return nil
        }
    }

    public var inner: (height: Int8, size: Int64, left: SQLiteNode<Key, Value, Hasher>, right: SQLiteNode<Key, Value, Hasher>)? {
        switch nodeType {
        case let .inner(h, s, l, r):
            return (h, s, l, r)
        case let .innerDB(h, s, lh, rh):
            // TODO: what version should be returned for .empty node?
            return (h, s, LazyBox<Hash, SQLiteNode<Key, Value, Hasher>>(computation: { ((try? self.storage?.loadNode(from: $0)) ?? SQLiteNode<Key, Value, Hasher>(version: 0)) }).value(input: lh), LazyBox<Hash, SQLiteNode<Key, Value, Hasher>>(computation: { ((try? self.storage?.loadNode(from: $0)) ?? SQLiteNode<Key, Value, Hasher>(version: 0)) }).value(input: rh))
        default:
            return nil
        }
    }

    public var description: String {
        var str: String
        switch nodeType {
        case .empty:
            str = "Empty"
        case .emptyDB:
            str = "EmptyDB"
        case let .leaf(v):
            str = "Leaf: {\(key.hex), \(v.hex)}, v: \(version), #: \(hash.hex)\n"
        case let .leafDB(v):
            str = "LeafDB: {\(key.hex), \(v.hex)}, v: \(version), #: \(hash.hex)\n"
        case let .inner(h, s, l, r):
            str = "Inner: {\(key.hex), h: \(h), s: \(s), L: \(l.hash.hex), R: \(r.hash.hex)}, v: \(version), #: \(hash.hex)}\n"
            str += "-\(l)"
            str += "-\(r)"
        case let .innerDB(h, s, l, r):
            str = "InnerDB: {\(key.hex), h: \(h), s: \(s), L: \(l.hex), R: \(r.hex)}, v: \(version), #: \(hash.hex)}\n"
            str += "-\(l)"
            str += "-\(r)"
        }
        return str
    }
}
