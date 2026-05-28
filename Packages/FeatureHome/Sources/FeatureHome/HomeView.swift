//
//  HomeView.swift
//  FeatureHome
//
//  Created by rico on 22.01.2026.
//

import SwiftUI
import Domain
import Core

public struct HomeView: View {
    
    @ObservedObject var viewModel: HomeViewModel
    
    public init(viewModel: HomeViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack {
            Picker("Status", selection: $viewModel.selectedFilter) {
                ForEach(CharacterStatusType.allCases, id: \.self) { status in
                    Text(status.filterTitle)
                        .tag(status)
                }
            }
            .pickerStyle(.segmented)
            .padding([.horizontal, .top])
            .accessibilityIdentifier("filter_picker")

            switch viewModel.state {
            case .loading:
                Spacer()
                ProgressView("Loading...")
                    .scaleEffect(1.7)
                    .accessibilityIdentifier("loading_indicator")
                Spacer()
            case .success:
                List(viewModel.filteredCharacters) { character in
                    Button {
                        viewModel.didSelect(character: character)
                    } label: {
                        HStack {
                            AsyncImage(url: URL(string: character.image)) { img in
                                img.resizable()
                            } placeholder: {
                                Color.gray.opacity(0.3)
                            }
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                            
                            Text(character.name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.gray)
                        }
                    }
                    .accessibilityIdentifier("row_\(character.name)")
                }
                .listStyle(.plain)
                .accessibilityIdentifier("character_list")
            case .failure(let error):
                Spacer()
                Text(error).foregroundStyle(.red)
                Spacer()
            }
        }
        .task {
            viewModel.fetchCharacters()
        }
    }
}

#Preview {
    let mockRepo = MockCharacterRepository()
    ServiceLocator.shared.register(mockRepo as CharacterRepositoryProtocol)
    let vm = HomeViewModel()
    return HomeView(viewModel: vm)
}

fileprivate class MockCharacterRepository: CharacterRepositoryProtocol, @unchecked Sendable {
    func fetchCharacters() async throws -> [Domain.Character] {
        return [
            Character(id: 1, name: "Rick Sanchez", status: .alive, species: "Human", gender: "Male", image: "https://rickandmortyapi.com/api/character/avatar/1.jpeg"),
            Character(id: 2, name: "Morty Smith", status: .alive, species: "Human", gender: "Male", image: "https://rickandmortyapi.com/api/character/avatar/2.jpeg")
        ]
    }
}
