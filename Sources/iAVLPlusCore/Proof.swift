// ===----------------------------------------------------------------------===
//
//  This source file is part of the CosmosSwift open source project.
//
//  Proof.swift last updated 02/06/2020
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

public struct ProofLeafNode<Node: NodeProtocol>: Codable {
    public typealias Hash = Node.Hasher.Hash
    public typealias Hasher = Node.Hasher

    let key: Node.Key
    let valueHash: Hash
    let version: Int64

    private enum CodingKeys: String, CodingKey {
        case key
        case valueHash = "value"
        case version
    }

    public func hash() -> Hash {
        Hasher.hashLeaf(key: key, valueHash: valueHash, version: version)
    }
}

public protocol ProofInnerNodeProtocol {
    associatedtype Node: NodeProtocol
    typealias Hash = Node.Hasher.Hash

    var size: Int64 { get }
    var side: Side { get }
    var sideHash: Hash { get }

    func hash(_ childHash: Hash) -> Hash
}

public enum Side: String, Codable {
    case left
    case right
}

public struct ProofInnerNode<Node: NodeProtocol>: ProofInnerNodeProtocol, Codable {
    public typealias Hash = Node.Hasher.Hash
    public typealias Hasher = Node.Hasher

    public let height: Int8
    public let size: Int64
    public let version: Int64
    public let side: Side
    public let sideHash: Hash

    public init(_ height: Int8, _ size: Int64, _ version: Int64, _ side: Side, _ sideHash: Hash) {
        self.height = height
        self.size = size
        self.version = version
        self.side = side
        self.sideHash = sideHash
    }

    public func hash(_ childHash: Hash) -> Hash {
        Hasher.hashInner(height: height, size: size, leftHash: side == .left ? sideHash : childHash, rightHash: side == .right ? sideHash : childHash, version: version)
    }
}
