//
//  DesktopBoardView.swift
//  ZbiorKom Baza
//
//  Created by Jan Doniec on 08/09/2026.
//


import SwiftUI

struct DesktopBoardView: View {
    @ObservedObject var model: GTFSDownloader

    private let amber = Color(
        red: 1.0,
        green: 0.48,
        blue: 0.04
    )

    private let silver = Color(
        red: 0.72,
        green: 0.74,
        blue: 0.75
    )

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    silverStrip

                    VStack(alignment: .leading, spacing: 0) {
                        Text(model.selectedGroup?.name ?? "Wybierz przystanek")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .padding(.bottom, 14)

                        HStack {
                            Text("Linia")
                                .frame(width: 65, alignment: .leading)

                            Text("Przystanek docelowy")
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text("Odjazd")
                                .frame(width: 100, alignment: .trailing)
                        }
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.9))

                        Rectangle()
                            .fill(Color.white.opacity(0.4))
                            .frame(height: 1)
                            .padding(.vertical, 8)

                        ForEach(model.departures.prefix(8)) { departure in
                            HStack(spacing: 8) {
                                Text(departure.line)
                                    .frame(width: 65, alignment: .leading)

                                Text(departure.destination)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .lineLimit(1)

                                Text(
                                    countdown(
                                        to: departure.date,
                                        now: context.date
                                    )
                                )
                                .frame(width: 100, alignment: .trailing)
                            }
                            .font(.system(
                                size: 22,
                                weight: .medium,
                                design: .monospaced
                            ))
                            .foregroundStyle(amber)
                            .padding(.vertical, 5)
                        }

                        Spacer(minLength: 0)

                        HStack {
                            Text("GODZINA")

                            Spacer()

                            Text(clock(context.date))
                        }
                        .font(.system(
                            size: 12,
                            design: .monospaced
                        ))
                        .foregroundStyle(amber)
                    }
                    .padding(20)
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: .topLeading
                    )
                    .background(Color.black)

                    silverStrip
                }
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.height
                )
            }
        }
        .frame(minWidth: 650, minHeight: 350)
    }

    private var silverStrip: some View {
        Rectangle()
            .fill(silver)
            .frame(height: 20)
            .frame(maxWidth: .infinity)
    }

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
