//
//  File.swift
//  HomeViewModel
//
//  Created by rico on 22.01.2026.
//

import Foundation
import Core
import Domain
import SwiftUI

@MainActor
public final class HomeViewModel: ObservableObject {

    @Published public var state: HomeViewState = .loading
    @Published public var selectedFilter: CharacterStatusFilter = .all {
        didSet {
            applySelectedFilter()
        }
    }

    public var onDetailRequested: ((Character) -> Void)?

    @Inject private var repository: CharacterRepositoryProtocol
    private var allCharacters: [Character] = []
    private var hasFetchedCharacters = false
    private var isFetchingCharacters = false
    private var fetchGeneration = 0

    public init() {}

    public func fetchCharacters() {
        guard !isFetchingCharacters else { return }

        fetchGeneration += 1
        let currentGeneration = fetchGeneration
        allCharacters = []
        hasFetchedCharacters = false
        isFetchingCharacters = true
        state = .loading
        Task {
            do {
                let result = try await repository.fetchCharacters()
                guard currentGeneration == fetchGeneration else { return }
                isFetchingCharacters = false
                guard !result.isEmpty else {
                    state = .failure("Karakter listesi boş geldi.")
                    return
                }
                allCharacters = result
                hasFetchedCharacters = true
                applySelectedFilter()
            } catch {
                guard currentGeneration == fetchGeneration else { return }
                isFetchingCharacters = false
                state = .failure(error.localizedDescription)
            }
        }
    }

    // View'daki butona basılınca bu çalışır
    public func didSelect(character: Character) {
        // Coordinator'a "Patron, detay istendi" diye haber verir
        onDetailRequested?(character)
    }

    private func applySelectedFilter() {
        guard hasFetchedCharacters else { return }

        state = .success(selectedFilter.characters(from: allCharacters))
    }
}

public enum CharacterStatusFilter: CaseIterable, Hashable, Identifiable, Sendable {
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

    fileprivate func characters(from characters: [Character]) -> [Character] {
        switch self {
        case .all:
            return characters
        case .alive:
            return characters.filter { $0.status == .alive }
        case .dead:
            return characters.filter { $0.status == .dead }
        case .unknown:
            return characters.filter { $0.status == .unknown }
        }
    }
}

extension CharacterStatusType {
    var color: Color {
        switch self {
        case .alive:
            return .green
        case .dead:
            return .red
        case .unknown:
            return .gray
        }
    }

    var iconName: String {
        switch self {
        case .alive: return "heart.fill"
        case .dead: return "heart.slash.fill"
        case .unknown: return "questionmark.circle"
        }
    }
}
