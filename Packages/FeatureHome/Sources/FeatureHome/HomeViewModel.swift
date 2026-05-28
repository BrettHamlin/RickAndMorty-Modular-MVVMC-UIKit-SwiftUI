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
    
    public var id: Self { self }
    public var title: String { rawValue }
    
    var matchingStatus: CharacterStatusType? {
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

@MainActor
public final class HomeViewModel: ObservableObject {
    
    @Published public var state: HomeViewState = .loading
    @Published public var selectedFilter: CharacterStatusFilter = .all {
        didSet {
            guard case .success = state else { return }
            publishFilteredCharacters()
        }
    }
    
    public var onDetailRequested: ((Character) -> Void)?
    
    @Inject private var repository: CharacterRepositoryProtocol
    private var allCharacters: [Character] = []
    
    public init() {}
    
    public func fetchCharacters() {
        state = .loading
        Task {
            do {
                let result = try await repository.fetchCharacters()
                if result.isEmpty {
                    allCharacters = []
                    state = .failure("Karakter listesi boş geldi.")
                } else {
                    allCharacters = result
                    publishFilteredCharacters()
                }
            } catch {
                allCharacters = []
                state = .failure(error.localizedDescription)
            }
        }
    }
    
    // View'daki butona basılınca bu çalışır
    public func didSelect(character: Character) {
        // Coordinator'a "Patron, detay istendi" diye haber verir
        onDetailRequested?(character)
    }
    
    private func publishFilteredCharacters() {
        let filteredCharacters: [Character]
        if let status = selectedFilter.matchingStatus {
            filteredCharacters = allCharacters.filter { $0.status == status }
        } else {
            filteredCharacters = allCharacters
        }
        
        state = .success(filteredCharacters)
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
