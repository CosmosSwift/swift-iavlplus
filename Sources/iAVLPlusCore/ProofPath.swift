// ===----------------------------------------------------------------------===
//
//  This source file is part of the CosmosSwift open source project.
//
//  ProofPath.swift last updated 02/06/2020
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

public struct PathWithLeaf<Node: NodeProtocol>: CustomStringConvertible, Codable {
    public typealias Hash = Node.Hasher.Hash

    let path: PathToLeaf<Node>
    let proofLeaf: ProofLeafNode<Node>

    private enum CodingKeys: String, CodingKey {
        case path
        case proofLeaf = "leaf"
    }

    public var description: String {
        "" // TODO: implement properly
    }

    /// `verify` checks that the leaf node's hash + the inner nodes merkle-izes to
    /// the given root. If it returns an error, it means the leafHash or the
    /// PathToLeaf is incorrect.
    public func verify(_ root: Node) throws -> Bool {
        return path.verify(proofLeaf.hash(), root)
    }

    public func computeRootHash() -> Hash {
        return path.computeRootHash(proofLeaf.hash())
    }
}

/// PathToLeaf represents an inner path to a leaf node.
/// Note that the nodes are ordered such that the last one is closest
/// to the root of the tree.
public typealias PathToLeaf<Node: NodeProtocol> = [ProofInnerNode<Node>]

extension Array where Element: ProofInnerNodeProtocol {
    /// `verify` checks that the leaf node's hash + the inner nodes merkle-izes to
    /// the given root. If it returns an error, it means the leafHash or the
    /// PathToLeaf is incorrect.
    public func verify(_ leafHash: Element.Hash, _ root: Element.Node) -> Bool {
        return computeRootHash(leafHash) == root.hash
    }

    /// `computeRootHash` computes the root hash assuming some leaf hash.
    /// Does not verify the root hash.
    public func computeRootHash(_ leafHash: Element.Hash) -> Element.Hash {
        var hash = leafHash
        for node in reversed() {
            hash = node.hash(hash)
        }
        return hash
    }

    public var isLeftmost: Bool {
        for node in self where node.side == .left {
            return false
        }
        return true
    }

    public var isRightmost: Bool {
        for node in self where node.side == .right {
            return false
        }
        return true
    }

    // contrarily to the go version this doesn't mutate the PathToLeaf
    public func hasCommonRoot(_ with: Self) -> Bool {
        if count == 0 || count != with.count {
            return false
        }
        let ptl0 = last!
        let ptl1 = with.last!

        return ptl0.side == ptl1.side && ptl0.sideHash == ptl1.sideHash
    }

    public var index: Int64 {
        var idx: Int64 = 0
        for (i, node) in enumerated() {
            if node.side == .right {
                continue
            } else if node.side == .left {
                if i < count - 1 {
                    idx += node.size - self.self[i + 1].size
                } else {
                    idx += node.size - 1
                }
            } else {
                return -1
            }
        }
        return idx
    }
}

/// PathToLeaf represents an inner path to a leaf node.
/// Note that the nodes are ordered such that the last one is closest
/// to the root of the tree.
public struct PathToLeaf1<Node: NodeProtocol>: Codable {
    public typealias Hash = Node.Hasher.Hash

    fileprivate var array: [ProofInnerNode<Node>]

    public init(_ array: [ProofInnerNode<Node>] = []) {
        self.array = array
    }

    /// `verify` checks that the leaf node's hash + the inner nodes merkle-izes to
    /// the given root. If it returns an error, it means the leafHash or the
    /// PathToLeaf is incorrect.
    public func verify(_ leafHash: Hash, _ root: Node) -> Bool {
        return computeRootHash(leafHash) == root.hash
    }

    /// `computeRootHash` computes the root hash assuming some leaf hash.
    /// Does not verify the root hash.
    public func computeRootHash(_ leafHash: Hash) -> Hash {
        var hash = leafHash
        for node in array.reversed() {
            hash = node.hash(hash)
        }
        return hash
    }

    public var isLeftmost: Bool {
        for node in array where node.side == .left {
            return false
        }
        return true
    }

    public var isRightmost: Bool {
        for node in array where node.side == .right {
            return false
        }
        return true
    }

    // MARK: Array like functions

    public var count: Int {
        array.count
    }

    public subscript(_ index: Int) -> ProofInnerNode<Node> {
        array[index]
    }

    public func dropLast() -> PathToLeaf1 {
        return PathToLeaf1<Node>(array.dropLast())
    }

    public var last: ProofInnerNode<Node>? {
        array.last
    }

    public mutating func append(_ element: ProofInnerNode<Node>) {
        array.append(element)
    }

    // seems only to be used by below isLeftAdjacent, which in itself doesn't seem to be used.
    public func dropRoot() throws -> PathToLeaf1 {
        // return array.dropLast()
        throw IAVLErrors.notImplemented(function: "PathToLeaf().isLeftAdjacent(_ to: PathToLeaf)")
    }

    // contrarily to the go version this doesn't mutate the PathToLeaf
    public func hasCommonRoot(_ with: Self) -> Bool {
        if array.count == 0 || array.count != with.array.count {
            return false
        }
        let ptl0 = array.last!
        let ptl1 = with.array.last!

        return ptl0.side == ptl1.side && ptl0.sideHash == ptl1.sideHash
    }

    // TODO: The go code for this seems wrong, as it will drop all common parts and the first non common item
    //       Check where this is called if ever in the Tendermint code base
    //       if called, then confirm correctness, if not called remove altogether
    public func isLeftAdjacent(_: PathToLeaf1) throws -> Bool {
        //    for pl.hasCommonRoot(pl2) {
        //        pl, pl2 = pl.dropRoot(), pl2.dropRoot()
        //    }
        //    pl, pl2 = pl.dropRoot(), pl2.dropRoot()
        //
        //    return pl.isRightmost() && pl2.isLeftmost()
        throw IAVLErrors.notImplemented(function: "PathToLeaf().isLeftAdjacent(_ to: PathToLeaf)")
    }

    public var index: Int64 {
        var idx: Int64 = 0
        for (i, node) in array.enumerated() {
            if node.side == .right {
                continue
            } else if node.side == .left {
                if i < array.count - 1 {
                    idx += node.size - array[i + 1].size
                } else {
                    idx += node.size - 1
                }
            } else {
                return -1
            }
        }
        return idx
    }
}
