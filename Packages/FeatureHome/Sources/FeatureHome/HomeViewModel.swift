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
            publishFilteredCharactersIfAvailable()
        }
    }
    
    public var onDetailRequested: ((Character) -> Void)?
    
    @Inject private var repository: CharacterRepositoryProtocol
    private var fetchedCharacters: [Character]?
    
    public init() {}
    
    public func fetchCharacters() {
        state = .loading
        fetchedCharacters = nil
        Task {
            do {
                let result = try await repository.fetchCharacters()
                if result.isEmpty {
                    state = .failure("Karakter listesi boş geldi.")
                } else {
                    fetchedCharacters = result
                    publishFilteredCharactersIfAvailable()
                }
            } catch {
                state = .failure(error.localizedDescription)
            }
        }
    }
    
    // View'daki butona basılınca bu çalışır
    public func didSelect(character: Character) {
        // Coordinator'a "Patron, detay istendi" diye haber verir
        onDetailRequested?(character)
    }

    private func publishFilteredCharactersIfAvailable() {
        guard let fetchedCharacters else { return }
        state = .success(fetchedCharacters.filter(selectedFilter.includes))
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
