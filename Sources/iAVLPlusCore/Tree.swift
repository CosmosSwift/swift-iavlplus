// ===----------------------------------------------------------------------===
//
//  This source file is part of the CosmosSwift open source project.
//
//  Tree.swift last updated 02/06/2020
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

public protocol Tree {
    associatedtype Hash

    var size: Int { get }
    var height: Int8 { get }
    func has(key: Data) -> Bool
    // swiftlint:disable large_tuple
    func proof(key: Data) -> (value: Data, proof: Data, exists: Bool) // TODO: make it return an index

    // swiftlint:disable large_tuple
    func get(key: Data) -> (index: Int, value: Data, exists: Bool)
    func get(index: Int) -> (key: Data, value: Data)

    func set(key: Data, value: Data) -> Bool

    func remove(key: Data) -> (value: Data, remove: Bool)

    func hashWithCount() -> (hash: Data, count: Int)

    func hash() -> Hash

    func save() -> Hash

    func load(_ hash: Hash)

    func copy() -> Self

    func iterate(_ fx: (Data, Data) -> Bool) -> Bool
    func iterate(start: Data, end: Data, ascending: Bool, _ fx: (Data, Data) -> Bool) -> Bool
}
