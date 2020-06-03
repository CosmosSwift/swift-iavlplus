// ===----------------------------------------------------------------------===
//
//  This source file is part of the CosmosSwift open source project.
//
//  HasherProtocol.swift last updated 02/06/2020
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

public protocol HasherProtocol {
    associatedtype Hash: Hashable, DataProtocol, Codable, InitialisableProtocol
    associatedtype Coder: CoderProtocol

    static func hash<Data: DataProtocol>(_ value: Data) -> Hash

    static func hashLeaf<Key: DataProtocol>(key: Key, valueHash: Hash, version: Int64) -> Hash
    static func hashInner(height: Int8, size: Int64, leftHash: Hash, rightHash: Hash, version: Int64) -> Hash
} // 32 bytes

public extension HasherProtocol {
    static func hashLeaf<Key: DataProtocol>(key: Key, valueHash: Hash, version: Int64) -> Hash {
        // amino encoding of: Int8(0), VarInt(1), VarInt(version)
        //           Data(key), Data(hash(value))
        // then take the hash of that
        var d = Data()
        Coder.encode(&d, int8: 0)
        Coder.encode(&d, int64: 1)
        Coder.encode(&d, int64: version)
        Coder.encode(&d, bytes: key)
        Coder.encode(&d, bytes: valueHash)
        return Self.hash(d)
    }

    static func hashInner(height: Int8, size: Int64, leftHash: Hash, rightHash: Hash, version: Int64) -> Hash {
        // amino encoding of: Int8(height), VarInt(size), VarInt(version)
        //           Data(leftHash), Data(rightHash))
        // then take the hash of that
        var d = Data()
        Coder.encode(&d, int8: height)
        Coder.encode(&d, int64: size)
        Coder.encode(&d, int64: version)
        Coder.encode(&d, bytes: leftHash)
        Coder.encode(&d, bytes: rightHash)
        return Self.hash(d)
    }
}
