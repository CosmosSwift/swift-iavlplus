// ===----------------------------------------------------------------------===
//
//  This source file is part of the CosmosSwift open source project.
//
//  IAVLErrors.swift last updated 02/06/2020
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
public enum IAVLErrors: Error, CustomStringConvertible, LocalizedError {
    case notImplemented(function: String)
    case invalidNodeKeyPrefix(prefix: String)
    case missingKey(key: Data)
    case generic(identifier: String, reason: String)

    public var reason: String {
        switch self {
        case let .notImplemented(function):
            return "Function \(function) is not implemented"
        case let .missingKey(key):
            return "Missing key: \(key)"
        case let .invalidNodeKeyPrefix(prefix):
            return "Invalid NodeKey prefix: \(prefix)"
        case let .generic(identifier, reason):
            return "missing '\(identifier). \(reason)"
        }
    }

    public var description: String {
        return "IAVLPlus error: \(self.reason)"
    }

    public var errorDescription: String? {
        return description
    }
}
