// ===----------------------------------------------------------------------===
//
//  This source file is part of the CosmosSwift open source project.
//
//  LazyBox.swift last updated 02/06/2020
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

private enum LazyValue<Input, Value> {
    case notYetComputed((Input) -> Value)
    case computed(Value)
}

public final class LazyBox<Input, Result> {
    public init(computation: @escaping (Input) -> Result) {
        _value = .notYetComputed(computation)
    }

    private var _value: LazyValue<Input, Result>

    /// All reads and writes of `_value` must
    /// happen on this queue.
    private let queue = DispatchQueue(label: "LazyBox._value")

    public func value(input: Input) -> Result {
        var returnValue: Result?
        queue.sync {
            switch self._value {
            case let .notYetComputed(computation):
                let result = computation(input)
                self._value = .computed(result)
                returnValue = result
            case let .computed(result):
                returnValue = result
            }
        }
        assert(returnValue != nil)
        return returnValue!
    }
}
