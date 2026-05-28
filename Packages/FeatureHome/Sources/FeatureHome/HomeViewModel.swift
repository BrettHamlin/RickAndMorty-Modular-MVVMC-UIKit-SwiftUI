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
    private var allCharacters: [Character]?
    
    public init() {}
    
    public func fetchCharacters() {
        allCharacters = nil
        state = .loading
        Task {
            do {
                let result = try await repository.fetchCharacters()
                if result.isEmpty {
                    allCharacters = nil
                    state = .failure("Karakter listesi boş geldi.")
                } else {
                    allCharacters = result
                    applySelectedFilter()
                }
            } catch {
                allCharacters = nil
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
        guard let allCharacters else { return }
        
        switch selectedFilter {
        case .all:
            state = .success(allCharacters)
        case .alive:
            state = .success(allCharacters.filter { $0.status == .alive })
        case .dead:
            state = .success(allCharacters.filter { $0.status == .dead })
        case .unknown:
            state = .success(allCharacters.filter { $0.status == .unknown })
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
