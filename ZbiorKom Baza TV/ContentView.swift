//
//  ContentView.swift
//  ZbiorKom Baza TV
//
//  Created by Jan Doniec on 09/09/2026.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var model = GTFSDownloader()
    @State private var showingSettings = false
    @State private var searchText = ""

    private let amber = Color(red: 1.0, green: 0.48, blue: 0.04)
    private let silver = Color(red: 0.72, green: 0.74, blue: 0.75)

    var body: some View {
        ZStack {
            if showingSettings {
                settingsView
            } else {
                boardView
            }
        }
        .task {
            await model.start()
        }
        .task {
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(60))
                } catch {
                    break
                }

                model.refreshDepartures()
            }
        }
    }

    // MARK: - Board

    // MARK: - Board

    private var boardView: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            GeometryReader { geometry in
                let scale = max(0.7, geometry.size.width / 1920)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(model.selectedGroup?.name ?? "Wybierz przystanek")
                                .font(.system(size: 54 * scale, weight: .medium))
                                .foregroundStyle(.white)
                                .lineLimit(1)

                            Text("Autobusy i tramwaje")
                                .font(.system(size: 24 * scale))
                                .foregroundStyle(.white.opacity(0.7))
                        }

                        Spacer()

                        Button {
                            showingSettings = true
                        } label: {
                            Label("Ustawienia", systemImage: "gearshape")
                        }
                        .font(.system(size: 24 * scale))
                    }
                    .padding(.bottom, 32 * scale)

                    HStack {
                        Text("Linia")
                            .frame(width: 130 * scale, alignment: .leading)

                        Text("Przystanek docelowy")
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("Odjazd")
                            .frame(width: 200 * scale, alignment: .trailing)
                    }
                    .font(.system(size: 24 * scale))
                    .foregroundStyle(.white.opacity(0.9))

                    Rectangle()
                        .fill(Color.white.opacity(0.4))
                        .frame(height: 1)
                        .padding(.vertical, 16 * scale)

                    ForEach(model.departures.prefix(8)) { departure in
                        HStack(spacing: 16 * scale) {
                            Text(departure.line)
                                .frame(width: 130 * scale, alignment: .leading)

                            Text(departure.destination)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .lineLimit(1)

                            Text(
                                countdown(
                                    to: departure.date,
                                    now: context.date
                                )
                            )
                            .frame(width: 200 * scale, alignment: .trailing)
                        }
                        .font(.system(
                            size: 40 * scale,
                            weight: .medium,
                            design: .monospaced
                        ))
                        .foregroundStyle(amber)
                        .padding(.vertical, 12 * scale)
                    }

                    Spacer(minLength: 0)

                    HStack {
                        Text("GODZINA")

                        Spacer()

                        Text(clock(context.date))
                    }
                    .font(.system(
                        size: 24 * scale,
                        design: .monospaced
                    ))
                    .foregroundStyle(amber)
                }
                .padding(48 * scale)
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.height,
                    alignment: .topLeading
                )
                .background(Color.black)
            }
        }
        .background(Color.black.ignoresSafeArea())
    }
    private var silverStrip: some View {
        Rectangle()
            .fill(silver)
            .frame(height: 20)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Settings

    private var settingsView: some View {
        NavigationStack {
            Form {
                // MARK: Favorite boards

                if !model.favoriteBoards.isEmpty {
                    Section("Ulubione tablice") {
                        ForEach(model.favoriteBoards) { favorite in
                            Button {
                                model.selectFavoriteBoard(favorite)
                                showingSettings = false
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(favorite.title)
                                            .font(.headline)

                                        Text(favorite.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    if model.selectedGroupID == favorite.groupID
                                        && model.selectedPlatformID == favorite.platformCode {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                }

                // MARK: Stop selection

                Section("Przystanek") {
                    NavigationLink {
                        stopSelectionView
                    } label: {
                        HStack {
                            Text("Wybrany przystanek")

                            Spacer()

                            Text(model.selectedGroup?.name ?? "Wybierz")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if model.selectedGroup != nil {
                        Picker(
                            "Słupek",
                            selection: Binding(
                                get: { model.selectedPlatformID },
                                set: { model.selectPlatform($0) }
                            )
                        ) {
                            Text("Wszystkie słupki")
                                .tag(String?.none)

                            ForEach(model.selectedPlatforms, id: \.self) { platform in
                                Text(platform)
                                    .tag(Optional(platform))
                            }
                        }

                        Button {
                            model.toggleCurrentBoardFavorite()
                        } label: {
                            Label(
                                model.isCurrentBoardFavorite
                                    ? "Usuń tablicę z ulubionych"
                                    : "Dodaj tablicę do ulubionych",
                                systemImage: model.isCurrentBoardFavorite
                                    ? "star.fill"
                                    : "star"
                            )
                        }
                    }
                }

                // MARK: Data

                Section("Dane") {
                    Button("Odśwież odjazdy") {
                        model.refreshDepartures()
                    }

                    Button {
                        Task {
                            await model.downloadAll()
                        }
                    } label: {
                        Label(
                            "Pobierz aktualne rozkłady",
                            systemImage: "arrow.down.circle"
                        )
                    }
                    .disabled(model.isDownloading)

                    if model.isDownloading {
                        ProgressView()
                    }

                    Text(model.status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button("Wróć do tablicy") {
                        showingSettings = false
                    }
                }
            }
            .navigationTitle("Ustawienia")
        }
    }

    // MARK: - Stop selection

    private var stopSelectionView: some View {
        VStack(spacing: 0) {
            TextField("Szukaj przystanku", text: $searchText)
                .padding(.horizontal, 60)
                .padding(.top, 30)

            List(filteredGroups) { group in
                Button {
                    model.selectGroup(group.id)
                    showingSettings = false
                } label: {
                    HStack {
                        Text(group.name)

                        Spacer()

                        if model.selectedGroupID == group.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }
        .navigationTitle("Wybierz przystanek")
    }

    private var filteredGroups: [GTFSGroup] {
        let query = GTFSService.normalized(searchText)
        let words = query.split(whereSeparator: \.isWhitespace)

        return model.groups.filter { group in
            guard !words.isEmpty else { return true }

            let name = GTFSService.normalized(group.name)
            return words.allSatisfy { name.contains($0) }
        }
    }

    // MARK: - Helpers

    private func countdown(to date: Date, now: Date) -> String {
        let seconds = date.timeIntervalSince(now)

        if seconds <= 0 {
            return ">>>>"
        }

        let minutes = Int(ceil(seconds / 60))
        return "\(minutes) min"
    }

    private func clock(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pl_PL")
        formatter.timeZone = TimeZone(identifier: "Europe/Warsaw")
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}
