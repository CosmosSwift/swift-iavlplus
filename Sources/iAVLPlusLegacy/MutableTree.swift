// ===----------------------------------------------------------------------===
//
//  This source file is part of the CosmosSwift open source project.
//
//  MutableTree.swift last updated 03/06/2020
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
import iAVLPlusCore

/// The `MutableTree` implementation aims to mimic the equivalent Go `MutableTree`.
/// However, the design we implement ere is such that we have encapsulated the storage and access
/// to the nodes into the `NodeStorageProtocol`. Therefore, any loading, saving, deleting, managing of
/// cache, memory and such is expected to be handled and delegated to the storage implementation itself.
/// We are providing this struct because as part of the design process, it was implemented before eventually
/// being carved out in favour of the `NodeStorageProtocol` and the `NodeProtocol`. As it may be
/// useful as part of the coming development of future CosmosSwift milestones, we keep it as suc for now, albeit
/// as part of the Legacy module.
public struct MutableTree<Storage: NodeStorageProtocol>: CustomStringConvertible {
    public typealias Hash = Storage.Hasher.Hash
    public typealias Key = Storage.Key
    public typealias Value = Storage.Value
    public typealias Hasher = Storage.Hasher

    public var current: (root: Storage.Node, version: Int64)
    public var lastSaved: (root: Storage.Node, version: Int64)

    public var versions: [Int64] {
        ndb.versions.sorted()
    }

    public var version: Int64 {
        ndb.version
    }

    public var ndb: Storage

    /// We implement here a simple initializer taking a storage instance. The specific
    /// strategies around caching, pruning, managing memory and speed of access are
    /// intended to be implemented by the type of storage provided dependin on the specific
    /// use case.
    public init(_ db: inout Storage) throws {
        ndb = db
        current = (ndb.root, ndb.version)
        if ndb.version > 2 {
            lastSaved = (try ndb.root(at: ndb.version - 1)!, ndb.version - 1)
        } else {
            lastSaved = (ndb.makeEmpty(), 0)
        }
    }

    /// `isEmpty` returns whether or not the tree has any keys.
    public var isEmpty: Bool {
        current.root.size == 0
    }

    /// `versionExists` returns whether or not a version exists.
    public func versionExists(_ version: Int64) -> Bool {
        return versions.contains(version)
    }

    /// `hash` returns the hash of the latest saved version of the tree, as returned
    /// by saveVersion. If no versions have been saved, Hash returns nil.
    public var hash: Hash? {
        lastSaved.root.hash
    }

    /// `workingHash` returns the hash of the current working tree.
    public var workingHash: Hash {
        current.root.hash
    }

    public var description: String {
        "MutableTree: \(ndb)"
    }

    /// `set` sets a key in the working tree. Nil values are not supported.
    @discardableResult
    public mutating func set(key: Key, value: Value) throws -> Bool {
        return try ndb.set(key: key, value: value)
    }

    /// `remove` removes a key from the working tree.
    @discardableResult
    public mutating func remove(key: Key) -> (Value?, Bool) {
        return ndb.remove(key: key)
    }

    // Rollback resets the working tree to the latest saved version, discarding
    // any unsaved modifications.
    public mutating func rollback() {
        ndb.rollback()
    }

    // GetVersioned gets the value at the specified key and version.
    public func getVersioned(_ key: Key, _ version: Int64) throws -> (index: Int64, value: Value?) {
        if let root = try? ndb.root(at: version) {
            return root.get(key)
        }
        return (-1, nil)
    }

    // SaveVersion saves a new tree version to memDB and removes old version,
    // based on the current state of the tree. Returns the hash and new version number.
    // If version is snapshot version, persist version to disk as well
    public func saveVersion() throws -> (Hash, Int64) {
        // TODO: implement
        try ndb.commit()
        return (current.root.hash, version)
    }

    // DeleteVersion deletes a tree version from disk. The version can then no
    // longer be accessed.
    public mutating func deleteLast() throws {
        try ndb.deleteLast()
    }

    // deleteVersionsFrom deletes tree version from disk specified version to latest version. The version can then no
    // longer be accessed.
    private mutating func deleteAll(from version: Int64) throws {
        try ndb.deleteAll(from: version)
    }
}

public extension MutableTree {
    // GetVersionedWithProof gets the value under the key at the specified version
    // if it exists, or returns nil.
    func getVersionedWithProof(_ key: Storage.Key, _ version: Int64) throws -> (Storage.Value?, RangeProof<Storage.Node>) {
        guard let root = try? ndb.root(at: version) else {
            throw IAVLErrors.generic(identifier: "MutableTree().getVersionedRangeWithProof", reason: "Version doesn't exist")
        }
        return try root.getWithProof(key)
    }

    // GetVersionedRangeWithProof gets key/value pairs within the specified range
    // and limit.
    // swiftlint:disable large_tuple
    func getVersionedRangeWithProof(_ start: Storage.Key, _ end: Storage.Key, _ limit: UInt, _ version: Int64) throws -> (
        keys: [Key], values: [Storage.Value], proof: RangeProof<Storage.Node>
    ) {
        guard let root = try? ndb.root(at: version) else {
            throw IAVLErrors.generic(identifier: "MutableTree().getVersionedRangeWithProof", reason: "Version doesn't exist")
        }

        let (k, v, p) = try root.getRangeWithProof(start, end, limit)
        return (k, v, p)
    }
}

/*

 // ErrVersionDoesNotExist is returned if a requested version does not exist.
 var ErrVersionDoesNotExist = fmt.Errorf("version does not exist")

 // MutableTree is a persistent tree which keeps track of versions.
 type MutableTree struct {
     *ImmutableTree                  // The current, working tree.
     lastSaved      *ImmutableTree   // The most recently saved tree.
     orphans        map[string]int64 // Nodes removed by changes to working tree.
     versions       map[int64]bool   // The previous versions of the tree saved in disk or memory.
     ndb            *nodeDB
 }

 // NewMutableTree returns a new tree with the specified cache size and datastore
 // To maintain backwards compatibility, this function will initialize PruningStrategy{keepEvery: 1, keepRecent: 0}
 func NewMutableTree(db dbm.DB, cacheSize int) (*MutableTree, error) {
     // memDB is initialized but should never be written to
     memDB := dbm.NewMemDB()
     return NewMutableTreeWithOpts(db, memDB, cacheSize, nil)
 }

 func validateOptions(opts *Options) error {
     switch {
     case opts == nil:
         return nil
     case opts.KeepEvery < 0:
         return errors.New("keep every cannot be negative")
     case opts.KeepRecent < 0:
         return errors.New("keep recent cannot be negative")
     case opts.KeepRecent == 0 && opts.KeepEvery > 1:
         // We cannot snapshot more than every one version when we don't keep any versions in memory.
         return errors.New("keep recent cannot be zero when keep every is set larger than one")
     }

     return nil
 }

 // NewMutableTreeWithOpts returns a new tree with the specified cache size, datastores and options
 func NewMutableTreeWithOpts(snapDB dbm.DB, recentDB dbm.DB, cacheSize int, opts *Options) (*MutableTree, error) {
     if err := validateOptions(opts); err != nil {
         return nil, err
     }

     ndb := newNodeDB(snapDB, recentDB, cacheSize, opts)
     head := &ImmutableTree{ndb: ndb}

     return &MutableTree{
         ImmutableTree: head,
         lastSaved:     head.clone(),
         orphans:       map[string]int64{},
         versions:      map[int64]bool{},
         ndb:           ndb,
     }, nil
 }

 // IsEmpty returns whether or not the tree has any keys. Only trees that are
 // not empty can be saved.
 func (tree *MutableTree) IsEmpty() bool {
     return tree.ImmutableTree.Size() == 0
 }

 // VersionExists returns whether or not a version exists.
 func (tree *MutableTree) VersionExists(version int64) bool {
     return tree.versions[version]
 }

 // AvailableVersions returns all available versions in ascending order
 func (tree *MutableTree) AvailableVersions() []int {
     res := make([]int, 0, len(tree.versions))
     for i, v := range tree.versions {
         if v {
             res = append(res, int(i))
         }
     }
     sort.Ints(res)
     return res
 }

 // Hash returns the hash of the latest saved version of the tree, as returned
 // by SaveVersion. If no versions have been saved, Hash returns nil.
 func (tree *MutableTree) Hash() []byte {
     if tree.version > 0 {
         return tree.lastSaved.Hash()
     }
     return nil
 }

 // WorkingHash returns the hash of the current working tree.
 func (tree *MutableTree) WorkingHash() []byte {
     return tree.ImmutableTree.Hash()
 }

 // String returns a string representation of the tree.
 func (tree *MutableTree) String() string {
     return tree.ndb.String()
 }

 // Set/Remove will orphan at most tree.Height nodes,
 // balancing the tree after a Set/Remove will orphan at most 3 nodes.
 func (tree *MutableTree) prepareOrphansSlice() []*Node {
     return make([]*Node, 0, tree.Height()+3)
 }

 // Set sets a key in the working tree. Nil values are not supported.
 func (tree *MutableTree) Set(key, value []byte) bool {
     orphaned, updated := tree.set(key, value)
     tree.addOrphans(orphaned)
     return updated
 }

 func (tree *MutableTree) set(key []byte, value []byte) (orphans []*Node, updated bool) {
     if value == nil {
         panic(fmt.Sprintf("Attempt to store nil value at key '%s'", key))
     }

     if tree.ImmutableTree.root == nil {
         tree.ImmutableTree.root = NewNode(key, value, tree.version+1)
         return nil, updated
     }

     orphans = tree.prepareOrphansSlice()
     tree.ImmutableTree.root, updated = tree.recursiveSet(tree.ImmutableTree.root, key, value, &orphans)
     return orphans, updated
 }

 func (tree *MutableTree) recursiveSet(node *Node, key []byte, value []byte, orphans *[]*Node) (
     newSelf *Node, updated bool,
 ) {
     version := tree.version + 1

     if node.isLeaf() {
         switch bytes.Compare(key, node.key) {
         case -1:
             return &Node{
                 key:       node.key,
                 height:    1,
                 size:      2,
                 leftNode:  NewNode(key, value, version),
                 rightNode: node,
                 version:   version,
             }, false
         case 1:
             return &Node{
                 key:       key,
                 height:    1,
                 size:      2,
                 leftNode:  node,
                 rightNode: NewNode(key, value, version),
                 version:   version,
             }, false
         default:
             *orphans = append(*orphans, node)
             return NewNode(key, value, version), true
         }
     } else {
         *orphans = append(*orphans, node)
         node = node.clone(version)

         if bytes.Compare(key, node.key) < 0 {
             node.leftNode, updated = tree.recursiveSet(node.getLeftNode(tree.ImmutableTree), key, value, orphans)
             node.leftHash = nil // leftHash is yet unknown
         } else {
             node.rightNode, updated = tree.recursiveSet(node.getRightNode(tree.ImmutableTree), key, value, orphans)
             node.rightHash = nil // rightHash is yet unknown
         }

         if updated {
             return node, updated
         }
         node.calcHeightAndSize(tree.ImmutableTree)
         newNode := tree.balance(node, orphans)
         return newNode, updated
     }
 }

 // Remove removes a key from the working tree.
 func (tree *MutableTree) Remove(key []byte) ([]byte, bool) {
     val, orphaned, removed := tree.remove(key)
     tree.addOrphans(orphaned)
     return val, removed
 }

 // remove tries to remove a key from the tree and if removed, returns its
 // value, nodes orphaned and 'true'.
 func (tree *MutableTree) remove(key []byte) (value []byte, orphaned []*Node, removed bool) {
     if tree.root == nil {
         return nil, nil, false
     }
     orphaned = tree.prepareOrphansSlice()
     newRootHash, newRoot, _, value := tree.recursiveRemove(tree.root, key, &orphaned)
     if len(orphaned) == 0 {
         return nil, nil, false
     }

     if newRoot == nil && newRootHash != nil {
         tree.root = tree.ndb.GetNode(newRootHash)
     } else {
         tree.root = newRoot
     }
     return value, orphaned, true
 }

 // removes the node corresponding to the passed key and balances the tree.
 // It returns:
 // - the hash of the new node (or nil if the node is the one removed)
 // - the node that replaces the orig. node after remove
 // - new leftmost leaf key for tree after successfully removing 'key' if changed.
 // - the removed value
 // - the orphaned nodes.
 func (tree *MutableTree) recursiveRemove(node *Node, key []byte, orphans *[]*Node) (newHash []byte, newSelf *Node, newKey []byte, newValue []byte) {
     version := tree.version + 1

     if node.isLeaf() {
         if bytes.Equal(key, node.key) {
             *orphans = append(*orphans, node)
             return nil, nil, nil, node.value
         }
         return node.hash, node, nil, nil
     }

     // node.key < key; we go to the left to find the key:
     if bytes.Compare(key, node.key) < 0 {
         newLeftHash, newLeftNode, newKey, value := tree.recursiveRemove(node.getLeftNode(tree.ImmutableTree), key, orphans) //nolint:govet

         if len(*orphans) == 0 {
             return node.hash, node, nil, value
         }
         *orphans = append(*orphans, node)
         if newLeftHash == nil && newLeftNode == nil { // left node held value, was removed
             return node.rightHash, node.rightNode, node.key, value
         }

         newNode := node.clone(version)
         newNode.leftHash, newNode.leftNode = newLeftHash, newLeftNode
         newNode.calcHeightAndSize(tree.ImmutableTree)
         newNode = tree.balance(newNode, orphans)
         return newNode.hash, newNode, newKey, value
     }
     // node.key >= key; either found or look to the right:
     newRightHash, newRightNode, newKey, value := tree.recursiveRemove(node.getRightNode(tree.ImmutableTree), key, orphans)

     if len(*orphans) == 0 {
         return node.hash, node, nil, value
     }
     *orphans = append(*orphans, node)
     if newRightHash == nil && newRightNode == nil { // right node held value, was removed
         return node.leftHash, node.leftNode, nil, value
     }

     newNode := node.clone(version)
     newNode.rightHash, newNode.rightNode = newRightHash, newRightNode
     if newKey != nil {
         newNode.key = newKey
     }
     newNode.calcHeightAndSize(tree.ImmutableTree)
     newNode = tree.balance(newNode, orphans)
     return newNode.hash, newNode, nil, value
 }

 // Load the latest versioned tree from disk.
 func (tree *MutableTree) Load() (int64, error) {
     return tree.LoadVersion(int64(0))
 }

 // LazyLoadVersion attempts to lazy load only the specified target version
 // without loading previous roots/versions. Lazy loading should be used in cases
 // where only reads are expected. Any writes to a lazy loaded tree may result in
 // unexpected behavior. If the targetVersion is non-positive, the latest version
 // will be loaded by default. If the latest version is non-positive, this method
 // performs a no-op. Otherwise, if the root does not exist, an error will be
 // returned.
 func (tree *MutableTree) LazyLoadVersion(targetVersion int64) (int64, error) {
     latestVersion := tree.ndb.getLatestVersion()
     if latestVersion < targetVersion {
         return latestVersion, fmt.Errorf("wanted to load target %d but only found up to %d", targetVersion, latestVersion)
     }

     // no versions have been saved if the latest version is non-positive
     if latestVersion <= 0 {
         return 0, nil
     }

     // default to the latest version if the targeted version is non-positive
     if targetVersion <= 0 {
         targetVersion = latestVersion
     }

     rootHash, err := tree.ndb.getRoot(targetVersion)
     if err != nil {
         return 0, err
     }
     if rootHash == nil {
         return latestVersion, ErrVersionDoesNotExist
     }

     tree.versions[targetVersion] = true

     iTree := &ImmutableTree{
         ndb:     tree.ndb,
         version: targetVersion,
         root:    tree.ndb.GetNode(rootHash),
     }

     tree.orphans = map[string]int64{}
     tree.ImmutableTree = iTree
     tree.lastSaved = iTree.clone()

     return targetVersion, nil
 }

 // Returns the version number of the latest version found
 func (tree *MutableTree) LoadVersion(targetVersion int64) (int64, error) {
     roots, err := tree.ndb.getRoots()
     if err != nil {
         return 0, err
     }

     if len(roots) == 0 {
         return 0, nil
     }

     latestVersion := int64(0)

     var latestRoot []byte
     for version, r := range roots {
         tree.versions[version] = true
         if version > latestVersion && (targetVersion == 0 || version <= targetVersion) {
             latestVersion = version
             latestRoot = r
         }
     }

     if !(targetVersion == 0 || latestVersion == targetVersion) {
         return latestVersion, fmt.Errorf("wanted to load target %v but only found up to %v",
             targetVersion, latestVersion)
     }

     t := &ImmutableTree{
         ndb:     tree.ndb,
         version: latestVersion,
     }

     if len(latestRoot) != 0 {
         t.root = tree.ndb.GetNode(latestRoot)
     }

     tree.orphans = map[string]int64{}
     tree.ImmutableTree = t
     tree.lastSaved = t.clone()

     return latestVersion, nil
 }

 // LoadVersionOverwrite returns the version number of targetVersion.
 // Higher versions' data will be deleted.
 func (tree *MutableTree) LoadVersionForOverwriting(targetVersion int64) (int64, error) {
     latestVersion, err := tree.LoadVersion(targetVersion)
     if err != nil {
         return latestVersion, err
     }
     tree.deleteVersionsFrom(targetVersion + 1) // nolint:errcheck
     return targetVersion, nil
 }

 // GetImmutable loads an ImmutableTree at a given version for querying
 func (tree *MutableTree) GetImmutable(version int64) (*ImmutableTree, error) {
     rootHash, err := tree.ndb.getRoot(version)
     if err != nil {
         return nil, err
     }
     if rootHash == nil {
         return nil, ErrVersionDoesNotExist
     } else if len(rootHash) == 0 {
         return &ImmutableTree{
             ndb:     tree.ndb,
             version: version,
         }, nil
     }
     return &ImmutableTree{
         root:    tree.ndb.GetNode(rootHash),
         ndb:     tree.ndb,
         version: version,
     }, nil
 }

 // Rollback resets the working tree to the latest saved version, discarding
 // any unsaved modifications.
 func (tree *MutableTree) Rollback() {
     if tree.version > 0 {
         tree.ImmutableTree = tree.lastSaved.clone()
     } else {
         tree.ImmutableTree = &ImmutableTree{ndb: tree.ndb, version: 0}
     }
     tree.orphans = map[string]int64{}
 }

 // GetVersioned gets the value at the specified key and version.
 func (tree *MutableTree) GetVersioned(key []byte, version int64) (
     index int64, value []byte,
 ) {
     if tree.versions[version] {
         t, err := tree.GetImmutable(version)
         if err != nil {
             return -1, nil
         }
         return t.Get(key)
     }
     return -1, nil
 }

 // SaveVersion saves a new tree version to memDB and removes old version,
 // based on the current state of the tree. Returns the hash and new version number.
 // If version is snapshot version, persist version to disk as well
 func (tree *MutableTree) SaveVersion() ([]byte, int64, error) {
     version := tree.version + 1

     if tree.versions[version] {
         //version already exists, throw an error if attempting to overwrite
         // Same hash means idempotent.  Return success.
         existingHash, err := tree.ndb.getRoot(version)
         if err != nil {
             return nil, version, err
         }
         var newHash = tree.WorkingHash()
         if bytes.Equal(existingHash, newHash) {
             tree.version = version
             tree.ImmutableTree = tree.ImmutableTree.clone()
             tree.lastSaved = tree.ImmutableTree.clone()
             tree.orphans = map[string]int64{}
             return existingHash, version, nil
         }
         return nil, version, fmt.Errorf("version %d was already saved to different hash %X (existing hash %X)",
             version, newHash, existingHash)
     }
     tree.versions[version] = true

     if tree.root == nil {
         // There can still be orphans, for example if the root is the node being
         // removed.
         debug("SAVE EMPTY TREE %v\n", version)
         tree.ndb.SaveOrphans(version, tree.orphans)
         err := tree.ndb.SaveEmptyRoot(version)
         if err != nil {
             panic(err)
         }
     } else {
         debug("SAVE TREE %v\n", version)
         // Save the current tree.
         tree.ndb.SaveTree(tree.root, version)
         tree.ndb.SaveOrphans(version, tree.orphans)
         err := tree.ndb.SaveRoot(tree.root, version)
         if err != nil {
             panic(err)
         }
     }
     err := tree.ndb.Commit()
     if err != nil {
         return nil, version, err
     }

     // Prune nodeDB and delete any pruned versions from tree.versions
     prunedVersions, err := tree.ndb.PruneRecentVersions()
     if err != nil {
         return nil, version, err
     }
     for _, pVer := range prunedVersions {
         delete(tree.versions, pVer)
     }

     err = tree.ndb.Commit()
     if err != nil {
         return nil, version, err
     }

     tree.version = version
     tree.versions[version] = true

     // Set new working tree.
     tree.ImmutableTree = tree.ImmutableTree.clone()
     tree.lastSaved = tree.ImmutableTree.clone()
     tree.orphans = map[string]int64{}

     return tree.Hash(), version, nil
 }

 // DeleteVersion deletes a tree version from disk. The version can then no
 // longer be accessed.
 func (tree *MutableTree) DeleteVersion(version int64) error {
     debug("DELETE VERSION: %d\n", version)
     if version == 0 {
         return errors.New("version must be greater than 0")
     }
     if version == tree.version {
         return errors.Errorf("cannot delete latest saved version (%d)", version)
     }
     if _, ok := tree.versions[version]; !ok {
         return errors.Wrap(ErrVersionDoesNotExist, "")
     }

     err := tree.ndb.DeleteVersion(version, true)
     if err != nil {
         return err
     }

     err = tree.ndb.Commit()
     if err != nil {
         return err
     }

     delete(tree.versions, version)

     return nil
 }

 // deleteVersionsFrom deletes tree version from disk specified version to latest version. The version can then no
 // longer be accessed.
 func (tree *MutableTree) deleteVersionsFrom(version int64) error {
     if version <= 0 {
         return errors.New("version must be greater than 0")
     }
     newLatestVersion := version - 1
     lastestVersion := tree.ndb.getLatestVersion()
     for ; version <= lastestVersion; version++ {
         if version == tree.version {
             return errors.Errorf("cannot delete latest saved version (%d)", version)
         }
         err := tree.ndb.DeleteVersion(version, false)
         if err != nil {
             return err
         }
         delete(tree.versions, version)
     }
     err := tree.ndb.Commit()
     if err != nil {
         return err
     }
     tree.ndb.resetLatestVersion(newLatestVersion)
     return nil
 }

 // Rotate right and return the new node and orphan.
 func (tree *MutableTree) rotateRight(node *Node) (*Node, *Node) {
     version := tree.version + 1

     // TODO: optimize balance & rotate.
     node = node.clone(version)
     orphaned := node.getLeftNode(tree.ImmutableTree)
     newNode := orphaned.clone(version)

     newNoderHash, newNoderCached := newNode.rightHash, newNode.rightNode
     newNode.rightHash, newNode.rightNode = node.hash, node
     node.leftHash, node.leftNode = newNoderHash, newNoderCached

     node.calcHeightAndSize(tree.ImmutableTree)
     newNode.calcHeightAndSize(tree.ImmutableTree)

     return newNode, orphaned
 }

 // Rotate left and return the new node and orphan.
 func (tree *MutableTree) rotateLeft(node *Node) (*Node, *Node) {
     version := tree.version + 1

     // TODO: optimize balance & rotate.
     node = node.clone(version)
     orphaned := node.getRightNode(tree.ImmutableTree)
     newNode := orphaned.clone(version)

     newNodelHash, newNodelCached := newNode.leftHash, newNode.leftNode
     newNode.leftHash, newNode.leftNode = node.hash, node
     node.rightHash, node.rightNode = newNodelHash, newNodelCached

     node.calcHeightAndSize(tree.ImmutableTree)
     newNode.calcHeightAndSize(tree.ImmutableTree)

     return newNode, orphaned
 }

 // NOTE: assumes that node can be modified
 // TODO: optimize balance & rotate
 func (tree *MutableTree) balance(node *Node, orphans *[]*Node) (newSelf *Node) {
     if node.persisted {
         panic("Unexpected balance() call on persisted node")
     }
     balance := node.calcBalance(tree.ImmutableTree)

     if balance > 1 {
         if node.getLeftNode(tree.ImmutableTree).calcBalance(tree.ImmutableTree) >= 0 {
             // Left Left Case
             newNode, orphaned := tree.rotateRight(node)
             *orphans = append(*orphans, orphaned)
             return newNode
         }
         // Left Right Case
         var leftOrphaned *Node

         left := node.getLeftNode(tree.ImmutableTree)
         node.leftHash = nil
         node.leftNode, leftOrphaned = tree.rotateLeft(left)
         newNode, rightOrphaned := tree.rotateRight(node)
         *orphans = append(*orphans, left, leftOrphaned, rightOrphaned)
         return newNode
     }
     if balance < -1 {
         if node.getRightNode(tree.ImmutableTree).calcBalance(tree.ImmutableTree) <= 0 {
             // Right Right Case
             newNode, orphaned := tree.rotateLeft(node)
             *orphans = append(*orphans, orphaned)
             return newNode
         }
         // Right Left Case
         var rightOrphaned *Node

         right := node.getRightNode(tree.ImmutableTree)
         node.rightHash = nil
         node.rightNode, rightOrphaned = tree.rotateRight(right)
         newNode, leftOrphaned := tree.rotateLeft(node)

         *orphans = append(*orphans, right, leftOrphaned, rightOrphaned)
         return newNode
     }
     // Nothing changed
     return node
 }

 func (tree *MutableTree) addOrphans(orphans []*Node) {
     for _, node := range orphans {
         if !node.saved {
             // We don't need to orphan nodes that were never saved.
             continue
         }
         if len(node.hash) == 0 {
             panic("Expected to find node hash, but was empty")
         }
         tree.orphans[string(node.hash)] = node.version
     }
 }

 */
