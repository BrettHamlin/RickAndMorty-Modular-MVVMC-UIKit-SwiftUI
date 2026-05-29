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

public enum CharacterStatusFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case alive = "Alive"
    case dead = "Dead"
    case unknown = "Unknown"
    
    public var id: String { rawValue }
    
    fileprivate func includes(_ character: Character) -> Bool {
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
    
    public init() {}
    
    public func fetchCharacters() async {
        state = .loading
        do {
            let result = try await repository.fetchCharacters()
            if result.isEmpty {
                allCharacters = []
                state = .failure("Karakter listesi boş geldi.")
            } else {
                allCharacters = result
                state = .success(filteredCharacters())
            }
        } catch {
            state = .failure(error.localizedDescription)
        }
    }
    
    // View'daki butona basılınca bu çalışır
    public func didSelect(character: Character) {
        // Coordinator'a "Patron, detay istendi" diye haber verir
        onDetailRequested?(character)
    }
    
    private func applySelectedFilter() {
        guard case .success = state else { return }
        state = .success(filteredCharacters())
    }
    
    private func filteredCharacters() -> [Character] {
        allCharacters.filter(selectedFilter.includes)
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
