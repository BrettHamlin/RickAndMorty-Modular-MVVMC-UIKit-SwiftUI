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

    public var displayLabel: String {
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

    var status: CharacterStatusType? {
        switch self {
        case .all:
            return nil
        case .alive:
            return .alive
        case .dead:
            return .dead
        case .unknown:
            return .unknown
        }
    }
}
