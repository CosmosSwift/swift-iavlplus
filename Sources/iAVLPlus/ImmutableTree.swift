// ===----------------------------------------------------------------------===
//
//  This source file is part of the CosmosSwift open source project.
//
//  ImmutableTree.swift last updated 02/06/2020
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

// ImmutableTree is a container for an immutable AVL+ ImmutableTree. Changes are performed by
// swapping the internal root with a new one, while the container is mutable.
// Note that this tree is not thread-safe.
public struct ImmutableTree<Storage: NodeStorageProtocol>: CustomStringConvertible {
    public typealias Hash = Storage.Hasher.Hash
    public typealias Node = Storage.Node
    public typealias Key = Storage.Key
    public typealias Value = Storage.Value

    let ndb: Storage

    public var root: Node

    public var version: Int64

    public var size: Int64 {
        root.size
    }

    public var height: Int8 {
        root.height
    }

    // Hash returns the root hash.
    public var hash: Hash {
        root.hash
    }

    public var description: String {
        // TODO: implement
        ""
    }

    // return the next key in the tree, nil if this is there is no greater key in the tree
    public func next(key: Key) -> Key? {
        return root.next(key: key)
    }

    /*
     // hashWithCount returns the root hash and hash count.
     mutating public func hashWithCount() -> (Hash, Int64) {
         root.hashWithCount()
     }
     */

    public init(_ storage: Storage, _ version: Int64) throws {
        self.version = version
        root = try storage.root(at: version) ?? storage.makeEmpty()
        ndb = storage
    }

//    // Creates an in-memory instances
//    public init(_ root: Node, _ version: Int64 = 0) {
//        self.root = root
//        self.version = version
//        self.ndb = Storage(root, version)
//    }
//
//    // Creates both in-memory and persistent instances. Default behavior snapshots every version
//    public init(_ db: DB, _ cacheSize: Int) {
//        // TODO: implement
//        self.init(Node(key: Key(), value: Value(), version: 0))
//    }
//
//    // Creates ImmutableTree with specified pruning/writing strategy.
//    // Persists every `keepEvery` version to snapDB and saves last `keepRecent` versions to recentDB
//    public init(_ snapshotDB: DB, _ recentDB: DB, _ cacheSize: Int, _ options: [String:String]) {
//        // TODO: implement
//        self.init(Node(key: Key(), value: Value(), version: 0))
//    }

    // Clone creates a clone of the tree.
    // Used internally by MutableTree.
    public init(_ it: ImmutableTree) {
        root = it.root
        version = it.version
        ndb = it.ndb
    }

    // Has returns whether or not a key exists.
    public func has(_ key: Key) -> Bool {
        root.has(key)
    }

    public func clone(_ version: Int64) throws -> ImmutableTree<Storage> {
        // This is needed because the it holds a class.
        // maybe we should look at implementing COW
        // let db = try self.ndb.clone(version)
        return try ImmutableTree<Storage>(ndb, version)
    }

    // Get returns the index and value of the specified key if it exists, or nil
    // and the next index, if it doesn't.
    public func get(_ key: Key) -> (index: Int64, value: Value?) {
        root.get(key)
    }

    // GetByIndex gets the key and value at the specified index.
    public func getByIndex(_ index: Int64) -> (key: Key, value: Value)? {
        root.get(index)
    }

    // Iterate iterates over all keys of the tree, in order.
    // Returns true if callback returns true, false otherwise
    public func iterate(_ calling: (Key, Value) -> Bool) -> Bool {
        return root.traverse(true) { node in
            if let value = node.value {
                return calling(node.key, value)
            }
            return false
        }
    }

    // IterateRange makes a callback for all nodes with key between start and end non-inclusive.
    // If either are nil, then it is open on that side (nil, nil is the same as Iterate)
    public func iterateRange(_ start: Key, _ end: Key, _ ascending: Bool, _ calling: (Key, Value, Int64) -> Bool) -> Bool {
        return root.traverseInRange(from: start, to: end, ascending: ascending, inclusive: true, depth: 0) { node, _ in
            if let value = node.value {
                return calling(node.key, value, node.version)
            }
            return false
        }
    }

    public func nodeSize() -> Int {
        var size = 0
        _ = root.traverse(true) { _ in
            size += 1
            return false
        }
        return size
    }
}

/*

 // ImmutableTree is a container for an immutable AVL+ ImmutableTree. Changes are performed by
 // swapping the internal root with a new one, while the container is mutable.
 // Note that this tree is not thread-safe.
 type ImmutableTree struct {
     root    *Node
     ndb     *nodeDB
     version int64
 }

 // NewImmutableTree creates both in-memory and persistent instances. Default behavior snapshots every version
 func NewImmutableTree(db dbm.DB, cacheSize int) *ImmutableTree {
     if db == nil {
         // In-memory Tree.
         return &ImmutableTree{}
     }
     return &ImmutableTree{
         // NodeDB-backed Tree.
         // memDB created but should never be written to
         ndb: newNodeDB(db, dbm.NewMemDB(), cacheSize, nil),
     }
 }

 // NewImmutableTreeWithOpts creates ImmutableTree with specified pruning/writing strategy.
 // Persists every `keepEvery` version to snapDB and saves last `keepRecent` versions to recentDB
 // If sync is true, writes on nodeDB.Commit are blocking
 func NewImmutableTreeWithOpts(snapDB dbm.DB, recentDB dbm.DB, cacheSize int, opts *Options) *ImmutableTree {
     return &ImmutableTree{
         // NodeDB-backed Tree.
         ndb: newNodeDB(snapDB, recentDB, cacheSize, opts),
     }
 }

 // String returns a string representation of Tree.
 func (t *ImmutableTree) String() string {
     leaves := []string{}
     t.Iterate(func(key []byte, val []byte) (stop bool) {
         leaves = append(leaves, fmt.Sprintf("%x: %x", key, val))
         return false
     })
     return "Tree{" + strings.Join(leaves, ", ") + "}"
 }

 // RenderShape provides a nested tree shape, ident is prepended in each level
 // Returns an array of strings, one per line, to join with "\n" or display otherwise
 func (t *ImmutableTree) RenderShape(indent string, encoder NodeEncoder) []string {
     if encoder == nil {
         encoder = defaultNodeEncoder
     }
     return t.renderNode(t.root, indent, 0, encoder)
 }

 // NodeEncoder will take an id (hash, or key for leaf nodes), the depth of the node,
 // and whether or not this is a leaf node.
 // It returns the string we wish to print, for iaviwer
 type NodeEncoder func(id []byte, depth int, isLeaf bool) string

 // defaultNodeEncoder can encode any node unless the client overrides it
 func defaultNodeEncoder(id []byte, depth int, isLeaf bool) string {
     prefix := "- "
     if isLeaf {
         prefix = "* "
     }
     if len(id) == 0 {
         return fmt.Sprintf("%s<nil>", prefix)
     }
     return fmt.Sprintf("%s%X", prefix, id)
 }

 func (t *ImmutableTree) renderNode(node *Node, indent string, depth int, encoder func([]byte, int, bool) string) []string {
     prefix := strings.Repeat(indent, depth)
     // handle nil
     if node == nil {
         return []string{fmt.Sprintf("%s<nil>", prefix)}
     }
     // handle leaf
     if node.isLeaf() {
         here := fmt.Sprintf("%s%s", prefix, encoder(node.key, depth, true))
         return []string{here}
     }

     // recurse on inner node
     here := fmt.Sprintf("%s%s", prefix, encoder(node.hash, depth, false))
     left := t.renderNode(node.getLeftNode(t), indent, depth+1, encoder)
     right := t.renderNode(node.getRightNode(t), indent, depth+1, encoder)
     result := append(left, here)
     result = append(result, right...)
     return result
 }

 // Size returns the number of leaf nodes in the tree.
 func (t *ImmutableTree) Size() int64 {
     if t.root == nil {
         return 0
     }
     return t.root.size
 }

 // Version returns the version of the tree.
 func (t *ImmutableTree) Version() int64 {
     return t.version
 }

 // Height returns the height of the tree.
 func (t *ImmutableTree) Height() int8 {
     if t.root == nil {
         return 0
     }
     return t.root.height
 }

 // Has returns whether or not a key exists.
 func (t *ImmutableTree) Has(key []byte) bool {
     if t.root == nil {
         return false
     }
     return t.root.has(t, key)
 }

 // Hash returns the root hash.
 func (t *ImmutableTree) Hash() []byte {
     if t.root == nil {
         return nil
     }
     hash, _ := t.root.hashWithCount()
     return hash
 }

 // hashWithCount returns the root hash and hash count.
 func (t *ImmutableTree) hashWithCount() ([]byte, int64) {
     if t.root == nil {
         return nil, 0
     }
     return t.root.hashWithCount()
 }

 // Get returns the index and value of the specified key if it exists, or nil
 // and the next index, if it doesn't.
 func (t *ImmutableTree) Get(key []byte) (index int64, value []byte) {
     if t.root == nil {
         return 0, nil
     }
     return t.root.get(t, key)
 }

 // GetByIndex gets the key and value at the specified index.
 func (t *ImmutableTree) GetByIndex(index int64) (key []byte, value []byte) {
     if t.root == nil {
         return nil, nil
     }
     return t.root.getByIndex(t, index)
 }

 // Iterate iterates over all keys of the tree, in order.
 func (t *ImmutableTree) Iterate(fn func(key []byte, value []byte) bool) (stopped bool) {
     if t.root == nil {
         return false
     }
     return t.root.traverse(t, true, func(node *Node) bool {
         if node.height == 0 {
             return fn(node.key, node.value)
         }
         return false
     })
 }

 // IterateRange makes a callback for all nodes with key between start and end non-inclusive.
 // If either are nil, then it is open on that side (nil, nil is the same as Iterate)
 func (t *ImmutableTree) IterateRange(start, end []byte, ascending bool, fn func(key []byte, value []byte) bool) (stopped bool) {
     if t.root == nil {
         return false
     }
     return t.root.traverseInRange(t, start, end, ascending, false, 0, func(node *Node, _ uint8) bool {
         if node.height == 0 {
             return fn(node.key, node.value)
         }
         return false
     })
 }

 // IterateRangeInclusive makes a callback for all nodes with key between start and end inclusive.
 // If either are nil, then it is open on that side (nil, nil is the same as Iterate)
 func (t *ImmutableTree) IterateRangeInclusive(start, end []byte, ascending bool, fn func(key, value []byte, version int64) bool) (stopped bool) {
     if t.root == nil {
         return false
     }
     return t.root.traverseInRange(t, start, end, ascending, true, 0, func(node *Node, _ uint8) bool {
         if node.height == 0 {
             return fn(node.key, node.value, node.version)
         }
         return false
     })
 }

 // Clone creates a clone of the tree.
 // Used internally by MutableTree.
 func (t *ImmutableTree) clone() *ImmutableTree {
     return &ImmutableTree{
         root:    t.root,
         ndb:     t.ndb,
         version: t.version,
     }
 }

 // nodeSize is like Size, but includes inner nodes too.
 func (t *ImmutableTree) nodeSize() int {
     size := 0
     t.root.traverse(t, true, func(n *Node) bool {
         size++
         return false
     })
     return size
 }

 */
