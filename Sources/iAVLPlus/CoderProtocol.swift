// ===----------------------------------------------------------------------===
//
//  This source file is part of the CosmosSwift open source project.
//
//  CoderProtocol.swift last updated 02/06/2020
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

/// The protocol Coder describes the primitives required to serialize structures.
/// A Coder accumulates bytes into a buffer which can then be pushed to storage.
/// The reference implementation uses Amino.

public protocol CoderProtocol {
    // encoding
    static func encode(_ to: inout Data, int64: Int64) // varint
    static func encode(_ to: inout Data, int8: Int8)
    static func encode<Bytes: DataProtocol>(_ to: inout Data, bytes: Bytes)
//
//    static func size(int64: Int64) -> Int // varint
//    static func size(int8: Int8) -> Int
//    static func size<Data: DataProtocol>(bytes: Data) -> Int
//
    static func decode<T: Decodable>(_ type: T.Type, from: Data) throws -> T

    static func encode<T: Encodable>(_ object: T) throws -> Data
}

public extension CoderProtocol {}

// needs Amino for calculating hashes and storing nodes is comparatively simple.
// It uses the Int8, Varint and Bytes encoding primitives.
