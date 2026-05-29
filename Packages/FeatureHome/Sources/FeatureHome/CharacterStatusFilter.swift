//
//  CharacterStatusFilter.swift
//  FeatureHome
//
//  Created by Codex on 28.05.2026.
//

import Domain

public enum CharacterStatusFilter: CaseIterable, Identifiable, Sendable {
    case all
    case alive
    case dead
    case unknown

    public var id: Self { self }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .alive:
            return "Alive"
        case .dead:
            return "Dead"
        case .unknown:
            return "Unknown"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .all:
            return "status_filter_all"
        case .alive:
            return "status_filter_alive"
        case .dead:
            return "status_filter_dead"
        case .unknown:
            return "status_filter_unknown"
        }
    }

    func includes(_ character: Character) -> Bool {
        switch self {
        case .all:
            return true
        case .alive:
            return character.status == .alive
        case .dead:
            return character.status == .dead
        case .unknown:
            return character.status == .unknown
        }
    }
}
