// ===----------------------------------------------------------------------===
//
//  This source file is part of the CosmosSwift open source project.
//
//  ProofIAVLAbsence.swift last updated 02/06/2020
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
import Merkle

public struct AbsenceOp<Node: NodeProtocol>: ProofOperatorProtocol, Codable {
    public var data: Data? // TODO: remove, for now, this is just to conform to the ProofOperatorProtocol, but should not be needed as we should use Codable

    typealias Hash = Node.Hasher.Hash
    public typealias Key = Node.Key

    public let key: Key
    public var proof: RangeProof<Node>

    public func run(_ data: [Data]) throws -> [Data] {
        if data.count != 0 {
            throw CosmosSwiftError.general("expected 0 arg, got \(data.count)")
        }

        // Compute the root hash and assume it is valid.
        // The caller checks the ultimate root later.
        guard let rootHash = proof.rootHash else {
            throw CosmosSwiftError.general("failed to compute rootHash")
        }

        // The go code here "verifies" the hashm but the only effect is to set the rootVerified boolean to true as it compares whether the hash provided above is the same as itself.
        // try self.proof.verify(rootHash)

        // XXX What is the encoding for keys?
        // We should decode the key depending on whether it's a string or hex,
        // maybe based on quotes and 0x prefix?
        try proof.verifyAbsence(rootHash, key)

        return [Data(rootHash)]
    }

    public let type: String = "AbsenceOp"
}
