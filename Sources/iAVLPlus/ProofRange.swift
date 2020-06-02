// ===----------------------------------------------------------------------===
//
//  This source file is part of the CosmosSwift open source project.
//
//  ProofRange.swift last updated 02/06/2020
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

public struct RangeProof<Node: NodeProtocol>: CustomStringConvertible, Codable {
    public var description: String {
        """
        RangeProof
                leftPath: \(leftPath)
                innerNodes: \(innerNodes)
                leaves: \(leaves)
        """
    }

    public typealias Hash = Node.Hasher.Hash
    public typealias Hasher = Node.Hasher
    public typealias Key = Node.Key
    public typealias Value = Node.Value

    public var leftPath: PathToLeaf<Node>
    public var innerNodes: [PathToLeaf<Node>]
    public var leaves: [ProofLeafNode<Node>]

    private let hashCalc = LazyBox<RangeProof<Node>, (Hash?, Bool)> { rp in
        (try? RangeProof<Node>.computeRootHash(rp.leftPath, rp.leaves, rp.innerNodes)) ?? (nil, false)
    }

    // cache
    public var rootHash: Hash! { // valid iff rootVerified is true
        hashCalc.value(input: self).0
    }

    // public var rootVerified: Bool = false
    public var treeEnd: Bool { // valid iff rootVerified is true
        hashCalc.value(input: self).1
    }

    // Keys returns all the keys in the RangeProof.  NOTE: The keys here may
    // include more keys than provided by tree.GetRangeWithProof or
    // MutableTree.GetVersionedRangeWithProof.  The keys returned there are only
    // in the provided [startKey,endKey){limit} range.  The keys returned here may
    // include extra keys, such as:
    // - the key before startKey if startKey is provided and doesn't exist;
    // - the key after a queried key with tree.GetWithProof, when the key is absent.
    public var keys: [Key] {
        leaves.map { $0.key }
    }

    // The index of the first leaf (of the whole tree).
    // Returns -1 if the proof is nil.
    public var leftIndex: Int64 {
        leftPath.index
    }

    public init(leftPath: PathToLeaf<Node>, innerNodes: [PathToLeaf<Node>] = [], leaves: [ProofLeafNode<Node>]) {
        self.leftPath = leftPath
        self.innerNodes = innerNodes
        self.leaves = leaves
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        leftPath = try container.decode(PathToLeaf<Node>.self, forKey: .leftPath)
        innerNodes = try container.decode([PathToLeaf<Node>].self, forKey: .innerNodes)
        leaves = try container.decode([ProofLeafNode<Node>].self, forKey: .leaves)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(leftPath, forKey: .leftPath)
        try container.encode(innerNodes, forKey: .innerNodes)
        try container.encode(leaves, forKey: .leaves)
    }

    private enum CodingKeys: CodingKey {
        case leftPath
        case innerNodes
        case leaves
    }

//    public init(bytes: Data) throws {
//        // TODO: implement
//    }

    // Also see LeftIndex().
    // Verify that a key has some value.
    public func verifyItem(_ rootHash: Hash, _ key: Key, _ value: Value) throws {
        if self.rootHash != rootHash {
            throw IAVLErrors.generic(identifier: "RangeProof().verifyItem", reason: "root hash \(String(describing: self.rootHash)) is different than expected hash \(rootHash)")
        }

        guard let pln = leaves.first(where: { key == $0.key }) else {
            throw IAVLErrors.generic(identifier: "RangeProof().verifyItem", reason: "leaf key not found in proof")
        }
        if pln.valueHash != Hasher.hash(value) {
            throw IAVLErrors.generic(identifier: "RangeProof().verifyItem", reason: "leaf value hash not the same")
        }
    }

    // Verify that proof is valid absence proof for key.
    public func verifyAbsence(_ rootHash: Hash, _ key: Key) throws {
        if self.rootHash != rootHash {
            throw IAVLErrors.generic(identifier: "RangeProof().verifyAbsence", reason: "root hash \(String(describing: self.rootHash)) is different than expected hash \(rootHash)")
        }

        if key < leaves[0].key {
            if leftPath.isLeftmost {
                return // proof ok
            }
            throw IAVLErrors.generic(identifier: "RangeProof().verifyAbsence", reason: "absence not proved by left path")
        } else if key == leaves[0].key {
            throw IAVLErrors.generic(identifier: "RangeProof().verifyAbsence", reason: "absence disproved via first item #0")
        }

        if leftPath.count == 0 || leftPath.isRightmost {
            return // proof ok
        }

        // See if any of the leaves are greater than key.
        for (i, l) in leaves.dropFirst().enumerated() {
            if key < l.key {
                return // proof ok
            } else if key == l.key {
                throw IAVLErrors.generic(identifier: "RangeProof().verifyAbsence", reason: "absence disproved via item #\(i + 1)")
            }
        }

        // It's still a valid proof if our last leaf is the rightmost child.
        if treeEnd {
            return // proof ok
        }

        if leaves.count < 2 {
            throw IAVLErrors.generic(identifier: "RangeProof().verifyAbsence", reason: "absence not proved by right leaf (need another leaf?)")
        }
        throw IAVLErrors.generic(identifier: "RangeProof().verifyAbsence", reason: "absence not proved by right leaf")
    }

    // Verify that proof is valid.
    public func verify(_ rootHash: Hash) -> Bool {
        rootHash == self.rootHash
    }

//    // ComputeRootHash computes the root hash with leaves.
//    // Returns nil if error or proof is nil.
//    // Does not verify the root hash.
//    mutating public func computeRootHash() throws -> Hash {
//        (self.rootHash, self.treeEnd) = try self._computeRootHash() // TODO: when throws, the roothash will not be returned. is that a problem?
//        return self.rootHash
//    }

    private static func computeRootHash(_ leftPath: PathToLeaf<Node>, _ leaves: [ProofLeafNode<Node>], _ innersq: [PathToLeaf<Node>]) throws -> (rootHash: Hash, treeEnd: Bool) {
        guard leaves.count > 0 else {
            throw IAVLErrors.generic(identifier: "ProofRange()._computeRootHash()", reason: "No leaves")
        }
        guard innersq.count + 1 == leaves.count else {
            throw IAVLErrors.generic(identifier: "ProofRange()._computeRootHash()", reason: "InnerNodes vs Leaves length mismatch, leaves should be 1 more.")
        }

        // Start from the left path and prove each leaf.
        // shared across recursive calls
        var leaves = leaves
        var innersq = innersq

        // rightmost: is the root a rightmost child of the tree?
        // treeEnd: true iff the last leaf is the last item of the tree.
        // Returns the (possibly intermediate, possibly root) hash.
        // swiftlint:disable large_tuple
        func COMPUTEHASH(_ path: inout PathToLeaf<Node>, _ rightMost: Bool) throws -> (Hash, Bool, Bool) {
            // Pop next leaf.
            let nleaf = leaves.first! // leaves is always at least one element when COMPUTEHASH is called
            leaves = Array(leaves.dropFirst())

            let hash = PathWithLeaf(path: path, proofLeaf: nleaf).computeRootHash()

            // If we don't have any leaves left, we're done.
            if leaves.count == 0 {
                return (hash, rightMost && path.isRightmost, true)
            }
            while path.count > 0 {
                // Drop the leaf-most (last-most) inner nodes from path
                // until we encounter one with a left hash.
                // We assume that the left side is already verified.
                // rpath: rest of path
                // lpath: last path item

                let lpath = path.last! // path always has at least one element
                path = path.dropLast()

                if lpath.side == .right {
                    let rightHash = lpath.sideHash
                    // Pop next inners, a PathToLeaf (e.g. []ProofInnerNode).
                    var inners = innersq.first! // innersq has always one more than leaves
                    innersq = Array(innersq.dropFirst())

                    // Recursively verify inners against remaining leaves.
                    guard let (derivedRoot, treeEnd, done) = try? COMPUTEHASH(&inners, rightMost && path.isRightmost) else {
                        throw IAVLErrors.generic(identifier: "ProofRange()._computeRootHash()", reason: "root COMPUTEHASH call")
                    }

                    if derivedRoot == rightHash {
                        throw IAVLErrors.generic(identifier: "ProofRange()._computeRootHash()", reason: "intermediate root hash \(rightHash)doesn't match, got \(derivedRoot)")
                    }

                    if done {
                        return (hash, treeEnd, true)
                    }

                } else {
                    continue
                }
            }

            // We're not done yet (leaves left over). No error, not done either.
            // Technically if rightmost, we know there's an error "left over leaves
            // -- malformed proof", but we return that at the top level, below.
            return (hash, false, false)
        }

        // Verify!
        var path = leftPath
        guard let (rootHash, treeEnd, done) = try? COMPUTEHASH(&path, true) else {
            throw IAVLErrors.generic(identifier: "ProofRange()._computeRootHash()", reason: "root COMPUTEHASH call")
        }
        guard done else {
            throw IAVLErrors.generic(identifier: "ProofRange()._computeRootHash()", reason: "left over leaves -- malformed proof")
        }
        // Ok!
        return (rootHash, treeEnd)
    }
}

extension ImmutableTree {
    // GetRangeWithProof gets key/value pairs within the specified range and limit.
    // keyStart is inclusive and keyEnd is exclusive.
    // If keyStart or keyEnd don't exist, the leaf before keyStart
    // or after keyEnd will also be included, but not be included in values.
    // If keyEnd-1 exists, no later leaves will be included.
    // If keyStart >= keyEnd and both not nil, panics.
    // Limit is never exceeded.
    // swiftlint:disable large_tuple
    public func getRangeWithProof(_ start: Storage.Key?, _ end: Storage.Key?, _ limit: UInt) throws -> (keys: [Storage.Key], value: [Storage.Value], proof: RangeProof<Storage.Node>) {
        var keys: [Storage.Key] = []
        var values: [Storage.Value] = []
        var leaves: [ProofLeafNode<Storage.Node>] = []

        if let s = start, let e = end, s >= e {
            throw IAVLErrors.generic(identifier: "ImmutableTree().getRangeWithProof()", reason: "if keyStart and keyEnd are present, need keyStart < keyEnd.")
        }

        // TODO: ensure all hashes are properly computed

        // Get the first key/value pair proof, which provides us with the left key.
        // Key doesn't exist, but instead we got the prev leaf (or the
        // first or last leaf), which provides proof of absence).
        let (path, left, _) = root.pathToLeaf(start)

        let startOK = start == nil || start! <= left.key
        let endOK = end == nil || left.key < end!

        // If left.key is in range, add it to key/values.
        if startOK && endOK {
            keys.append(left.key)
            values.append(left.value!)
        }
        // Either way, add to proof leaves.
        leaves.append(ProofLeafNode<Storage.Node>(key: left.key, valueHash: Storage.Hasher.hash(left.value!), version: left.version))

        // 1: Special case if limit is 1.
        // 2: Special case if keyEnd is left.key+1.
        let nextKey = next(key: left.key)
        // TODO: Check id nextKey works
        if limit == 1 || nextKey == nil || (end != nil && nextKey! >= end!) {
            return (keys, values, RangeProof<Storage.Node>(leftPath: path, leaves: leaves))
        }

        // Traverse starting from afterLeft, until keyEnd or the next leaf
        // after keyEnd.
        var innersq: [PathToLeaf<Storage.Node>] = []
        var inners = PathToLeaf<Storage.Node>()
        var leafCount = 1
        var pathCount = 0

        // TODO: check coverage of this function in tests as not sure that the above are passed by value

        _ = root.traverseInRange(from: nextKey, to: nil, ascending: true, inclusive: false, depth: 0) { (node, _) -> Bool in
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

                leaves.append(ProofLeafNode(key: node.key, valueHash: Storage.Hasher.hash(v), version: node.version))
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
                    inners.append(ProofInnerNode<Storage.Node>(h, s, node.version, .right, r.hash))
                }
            }
            return false
        }
        return (keys, values, RangeProof<Storage.Node>(leftPath: path, innerNodes: innersq, leaves: leaves))
    }

    // GetWithProof gets the value under the key if it exists, or returns nil.
    // A proof of existence or absence is returned alongside the value.
    public func getWithProof(_ key: Storage.Key) throws -> (value: Storage.Value?, proof: RangeProof<Storage.Node>) {
        let nextKey = next(key: key)

        let (_, values, proof) = try getRangeWithProof(key, nextKey, 2)
        if values.count > 0, proof.leaves[0].key == key {
            return (values[0], proof)
        }

        return (nil, proof) // TODO: not sure what it means to return a nil Value?
    }
}

public extension MutableTree {
    // GetVersionedWithProof gets the value under the key at the specified version
    // if it exists, or returns nil.
    func getVersionedWithProof(_ key: Storage.Key, _ version: Int64) throws -> (Storage.Value?, RangeProof<Storage.Node>) {
        if let b = versions[version], !b {
            throw IAVLErrors.generic(identifier: "MutableTree().getVersionedRangeWithProof", reason: "Version doesn't exist")
        }
        return try getImmutable(version).getWithProof(key)
    }

    // GetVersionedRangeWithProof gets key/value pairs within the specified range
    // and limit.
    // swiftlint:disable large_tuple
    func getVersionedRangeWithProof(_ start: Storage.Key, _ end: Storage.Key, _ limit: UInt, _ version: Int64) throws -> (
        keys: [Key], values: [Storage.Value], proof: RangeProof<Storage.Node>
    ) {
        if let b = versions[version], !b {
            throw IAVLErrors.generic(identifier: "MutableTree().getVersionedRangeWithProof", reason: "Version doesn't exist")
        }

        let (k, v, rp) = try getImmutable(version).getRangeWithProof(start, end, limit)

        return (k, v, rp)
    }
}
