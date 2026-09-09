//
//  WidgetPlatform.swift
//  ZbiorKom Baza
//
//  Created by Jan Doniec on 08/09/2026.
//


import Foundation

// MARK: - Platform numbers

enum WidgetPlatform {
    static func number(from code: String) -> String {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.suffix(2))
    }
}
