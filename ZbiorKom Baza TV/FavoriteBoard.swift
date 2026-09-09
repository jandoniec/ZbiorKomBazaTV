//
//  FavoriteBoard.swift
//  ZbiorKom Baza TV
//
//  Created by Jan Doniec on 09/09/2026.
//


import Foundation

struct FavoriteBoard: Codable, Identifiable, Equatable {
    let id: UUID
    let groupID: String
    let groupName: String
    let platformCode: String?

    init(
        id: UUID = UUID(),
        groupID: String,
        groupName: String,
        platformCode: String?
    ) {
        self.id = id
        self.groupID = groupID
        self.groupName = groupName
        self.platformCode = platformCode
    }

    var title: String {
        groupName
    }

    var subtitle: String {
        if let platformCode {
            return "Słupek \(platformCode)"
        }

        return "Wszystkie słupki"
    }
}