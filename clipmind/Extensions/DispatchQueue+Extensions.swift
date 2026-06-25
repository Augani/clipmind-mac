//
//  DispatchQueue+Extensions.swift
//  clipmind
//
//  Extensions for DispatchQueue
//

import Foundation

extension DispatchTimeInterval {
    static func hours(_ hours: Int) -> DispatchTimeInterval {
        return .seconds(hours * 3600)
    }
}