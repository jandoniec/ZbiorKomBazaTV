//
//  GTFSDownloader.swift
//  ZbiorKom Baza
//
//  Created by Jan Doniec on 08/09/2026.
//


import Foundation
import Combine

@MainActor
final class GTFSDownloader: ObservableObject {
    @Published var isDownloading = false
    @Published var status = "Ładowanie danych..."
    @Published var groups: [GTFSGroup] = []
    @Published var selectedGroupID: String?
    @Published var selectedPlatformID: String?
    @Published var departures: [GTFSDeparture] = []
    @Published var now = Date()
    @Published var loadedKinds: [GTFSKind] = []

    @Published private(set) var favoriteGroupIDs: Set<String> = []
    @Published private(set) var favoriteBoards: [FavoriteBoard] = []

    private let favoriteBoardsKey = "favoriteBoards"
    private let service = GTFSService()
    private var refreshTask: Task<Void, Never>?

    private let favoritesKey = "favoriteGroupIDs"
    private let selectedGroupKey = "favoriteGroup"
    private let selectedPlatformKey = "selectedPlatform"

    init() {
        favoriteGroupIDs = Set(
            UserDefaults.standard.stringArray(forKey: favoritesKey) ?? []
        )

        selectedGroupID = UserDefaults.standard.string(forKey: selectedGroupKey)
        selectedPlatformID = UserDefaults.standard.string(forKey: selectedPlatformKey)
        if let data = UserDefaults.standard.data(forKey: favoriteBoardsKey),
           let saved = try? JSONDecoder().decode([FavoriteBoard].self, from: data) {
            favoriteBoards = saved
        }
    }

    // MARK: - Favorite boards

    var isCurrentBoardFavorite: Bool {
        guard let selectedGroupID else { return false }

        return favoriteBoards.contains {
            $0.groupID == selectedGroupID
            && $0.platformCode == selectedPlatformID
        }
    }

    func toggleCurrentBoardFavorite() {
        guard let group = selectedGroup else { return }

        if let index = favoriteBoards.firstIndex(where: {
            $0.groupID == group.id
            && $0.platformCode == selectedPlatformID
        }) {
            favoriteBoards.remove(at: index)
        } else {
            favoriteBoards.append(
                FavoriteBoard(
                    groupID: group.id,
                    groupName: group.name,
                    platformCode: selectedPlatformID
                )
            )
        }

        saveFavoriteBoards()
    }

    func selectFavoriteBoard(_ favorite: FavoriteBoard) {
        guard groups.contains(where: { $0.id == favorite.groupID }) else {
            return
        }

        selectedGroupID = favorite.groupID
        selectedPlatformID = favorite.platformCode

        UserDefaults.standard.set(
            favorite.groupID,
            forKey: "favoriteGroup"
        )

        if let platformCode = favorite.platformCode {
            UserDefaults.standard.set(
                platformCode,
                forKey: "selectedPlatform"
            )
        } else {
            UserDefaults.standard.removeObject(forKey: "selectedPlatform")
        }

        refreshDepartures()
    }

    private func saveFavoriteBoards() {
        guard let data = try? JSONEncoder().encode(favoriteBoards) else {
            return
        }

        UserDefaults.standard.set(data, forKey: favoriteBoardsKey)
    }
    
    
    // MARK: - Selection

    var selectedGroup: GTFSGroup? {
        groups.first { $0.id == selectedGroupID }
    }

    var selectedPlatforms: [String] {
        guard let group = selectedGroup else { return [] }

        return Array(
            Set(
                group.stops
                    .map { WidgetPlatform.number(from: $0.code) }
                    .filter { !$0.isEmpty }
            )
        )
        .sorted()
    }

    func selectGroup(_ id: String) {
        guard selectedGroupID != id else { return }

        selectedGroupID = id
        selectedPlatformID = nil

        UserDefaults.standard.set(id, forKey: selectedGroupKey)
        UserDefaults.standard.removeObject(forKey: selectedPlatformKey)

        refreshDepartures()
    }

    func selectPlatform(_ id: String?) {
        selectedPlatformID = id

        if let id {
            UserDefaults.standard.set(id, forKey: selectedPlatformKey)
        } else {
            UserDefaults.standard.removeObject(forKey: selectedPlatformKey)
        }

        refreshDepartures()
    }

    // MARK: - Favorites

    func isFavorite(_ id: String) -> Bool {
        favoriteGroupIDs.contains(id)
    }

    func toggleFavorite(_ id: String) {
        if favoriteGroupIDs.contains(id) {
            favoriteGroupIDs.remove(id)
        } else {
            favoriteGroupIDs.insert(id)
        }

        UserDefaults.standard.set(
            favoriteGroupIDs.sorted(),
            forKey: favoritesKey
        )
    }

    // MARK: - Loading

    func start() async {
        guard !isDownloading else { return }

        isDownloading = true
        status = "Wczytywanie zapisanych rozkładów..."

        let errors = await service.loadCached()
        await publishData()

        if !errors.isEmpty {
            status = errors.joined(separator: "\n")
        } else if !loadedKinds.isEmpty {
            status = "Wczytano zapisane rozkłady."
        }

        isDownloading = false

        if loadedKinds.count < GTFSKind.allCases.count {
            await downloadMissing()
        }
    }

    func downloadAll() async {
        guard !isDownloading else { return }

        isDownloading = true
        var errors: [String] = []

        for kind in GTFSKind.allCases {
            status = "Pobieranie: \(kind.title)..."

            do {
                try await service.download(kind)
                await publishData()
            } catch {
                errors.append("\(kind.title): \(error.localizedDescription)")
            }
        }

        isDownloading = false

        status = errors.isEmpty
            ? "Rozkłady autobusów i tramwajów są aktualne."
            : "Nie udało się pobrać części danych:\n"
                + errors.joined(separator: "\n")
    }

    private func downloadMissing() async {
        guard !isDownloading else { return }

        isDownloading = true
        var errors: [String] = []

        for kind in GTFSKind.allCases where !loadedKinds.contains(kind) {
            status = "Pobieranie: \(kind.title)..."

            do {
                try await service.download(kind)
                await publishData()
            } catch {
                errors.append("\(kind.title): \(error.localizedDescription)")
            }
        }

        isDownloading = false

        status = errors.isEmpty
            ? "Dane gotowe."
            : errors.joined(separator: "\n")
    }

    private func publishData() async {
        groups = await service.groups()
        loadedKinds = await service.availableKinds()

        if !groups.contains(where: { $0.id == selectedGroupID }) {
            selectedGroupID = groups.first?.id
            selectedPlatformID = nil
        }

        if let selectedPlatformID,
           !selectedPlatforms.contains(selectedPlatformID) {
            self.selectedPlatformID = nil
        }

        refreshDepartures()
    }

    // MARK: - Departures

    func refreshDepartures() {
        refreshTask?.cancel()
        now = Date()

        guard let group = selectedGroup else {
            departures = []
            return
        }

        let groupID = group.id
        let platformID = selectedPlatformID

        let selectedStops = group.stops.filter { stop in
            guard let platformID else { return true }

            return WidgetPlatform.number(from: stop.code) == platformID
        }

        let requestedAt = now

        refreshTask = Task { [weak self] in
            guard let self else { return }

            let result = await service.departures(
                for: selectedStops,
                now: requestedAt,
                limit: 24
            )

            guard !Task.isCancelled,
                  self.selectedGroupID == groupID,
                  self.selectedPlatformID == platformID else {
                return
            }

            self.departures = result
        }
    }
}
