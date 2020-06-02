// ===----------------------------------------------------------------------===
//
//  This source file is part of the CosmosSwift open source project.
//
//  NodeKey.swift last updated 02/06/2020
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

public enum NodeKey<Hasher: HasherProtocol, Coder: CoderProtocol>: Codable, CustomStringConvertible {
    public typealias Hash = Hasher.Hash
    // All node keys are prefixed with the byte 'n'. This ensures no collision is
    // possible with the other keys, and makes them easier to traverse. They are indexed by the node hash.
    case node(_ hash: Hash) // n<hash>

    // Orphans are keyed in the database by their expected lifetime.
    // The first number represents the *last* version at which the orphan needs
    // to exist, while the second number represents the *earliest* version at
    // which it is expected to exist - which starts out by being the version
    // of the node being orphaned.
    case orphan(_ lastVersion: Int64, _ firstVersion: Int64, _ hash: Hash) // o<last-version><first-version><hash>

    // Root nodes are indexed separately by their version
    case root(_ version: Int64) // r<version>

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let prefix = try container.decode(String.self, forKey: .prefix)

        switch prefix {
        case "n":
            let d = try container.decode(Data.self, forKey: .data)
            let h = Hasher.hash(d)
            self = .node(h)
        case "o":
            let d = try container.decode(Data.self, forKey: .data)
            let l = d[0 ..< 8].withUnsafeBytes {
                $0.load(as: Int64.self).bigEndian
            }
            let f = d[8 ..< 16].withUnsafeBytes {
                $0.load(as: Int64.self).bigEndian
            }
            let h = Hasher.hash(d[16 ..< 48])
            self = .orphan(l, f, h)
        case "r":
            let d = try container.decode(Data.self, forKey: .data)
            let h = d[0 ..< 8].withUnsafeBytes {
                $0.load(as: Int64.self).bigEndian
            }
            self = .root(h)
        default:
            throw IAVLErrors.invalidNodeKeyPrefix(prefix: prefix)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.prefix, forKey: .prefix)
        try container.encode(data(), forKey: .data)
    }

    public func data() throws -> Data {
        var d = Data()
        switch self {
        case let .node(h):
            Coder.encode(&d, bytes: h)
        case let .orphan(l, f, h):
            Coder.encode(&d, int64: l.bigEndian)
            Coder.encode(&d, int64: f.bigEndian)
            Coder.encode(&d, bytes: h)
        case let .root(v):
            Coder.encode(&d, int64: v.bigEndian)
        }
        return d
    }

    private enum CodingKeys: CodingKey {
        case prefix
        case data
    }

    public var description: String {
        switch self {
        case let .node(h):
            return "n-\(h)"
        case let .orphan(l, f, h):
            return "o-\(l)-\(f)-\(h)"
        case let .root(v):
            return "r-\(v)"
        }
    }

    public var prefix: String {
        switch self {
        case .node:
            return "n"
        case .orphan:
            return "o"
        case .root:
            return "r"
        }
    }
}
