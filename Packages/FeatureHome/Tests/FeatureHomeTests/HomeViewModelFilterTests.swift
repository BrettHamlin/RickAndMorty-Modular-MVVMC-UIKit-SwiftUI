import XCTest
import Core
import Domain
@testable import FeatureHome

final class HomeViewModelFilterTests: XCTestCase {
    override func tearDown() {
        ServiceLocator.shared.unregisterAll()
        super.tearDown()
    }

    // harness:criterion=c-character-status-filter-enum-cases,c-character-status-filter-display-label-all,c-character-status-filter-display-label-alive,c-character-status-filter-display-label-dead,c-character-status-filter-display-label-unknown
    func testCharacterStatusFilterCasesAndDisplayLabels() {
        XCTAssertEqual(CharacterStatusFilter.allCases.count, 4)
        XCTAssertTrue(CharacterStatusFilter.allCases.contains(.all))
        XCTAssertTrue(CharacterStatusFilter.allCases.contains(.alive))
        XCTAssertTrue(CharacterStatusFilter.allCases.contains(.dead))
        XCTAssertTrue(CharacterStatusFilter.allCases.contains(.unknown))

        XCTAssertFalse(CharacterStatusFilter.all.displayLabel.isEmpty)
        XCTAssertFalse(CharacterStatusFilter.alive.displayLabel.isEmpty)
        XCTAssertFalse(CharacterStatusFilter.dead.displayLabel.isEmpty)
        XCTAssertFalse(CharacterStatusFilter.unknown.displayLabel.isEmpty)
        XCTAssertEqual(CharacterStatusFilter.unknown.displayLabel, "Unknown")
        XCTAssertNotEqual(CharacterStatusFilter.unknown.displayLabel, CharacterStatusType.unknown.rawValue)
    }

    // harness:criterion=c-homeviewmodel-selected-filter-default
    @MainActor
    func testSelectedFilterDefaultsToAll() {
        let viewModel = makeViewModel(characters: fixtureCharacters()).viewModel

        XCTAssertEqual(viewModel.selectedFilter, .all)
    }

    // harness:criterion=c-homeviewmodel-filtered-characters-all,c-homeviewmodel-filtered-characters-alive,c-homeviewmodel-filtered-characters-dead,c-homeviewmodel-filtered-characters-unknown
    @MainActor
    func testFilteredCharactersMatchSelectedStatus() async throws {
        let characters = fixtureCharacters()
        let viewModel = makeViewModel(characters: characters).viewModel
        viewModel.fetchCharacters()
        _ = try await waitForLoadedCharacters(in: viewModel)

        viewModel.selectedFilter = .all
        XCTAssertEqual(viewModel.filteredCharacters.map(\.id), characters.map(\.id))

        viewModel.selectedFilter = .alive
        XCTAssertEqual(viewModel.filteredCharacters.map(\.id), [1, 2])
        XCTAssertTrue(viewModel.filteredCharacters.allSatisfy { $0.status == .alive })

        viewModel.selectedFilter = .dead
        XCTAssertEqual(viewModel.filteredCharacters.map(\.id), [47])
        XCTAssertTrue(viewModel.filteredCharacters.allSatisfy { $0.status == .dead })

        viewModel.selectedFilter = .unknown
        XCTAssertEqual(viewModel.filteredCharacters.map(\.id), [331])
        XCTAssertTrue(viewModel.filteredCharacters.allSatisfy { $0.status == .unknown })
    }

    // harness:criterion=c-homeviewmodel-filtered-characters-empty-result
    @MainActor
    func testFilteredCharactersReturnsEmptyArrayWhenNoLoadedCharacterMatches() async throws {
        let viewModel = makeViewModel(characters: [fixtureCharacters()[0]]).viewModel
        viewModel.fetchCharacters()
        _ = try await waitForLoadedCharacters(in: viewModel)

        viewModel.selectedFilter = .dead

        XCTAssertTrue(viewModel.filteredCharacters.isEmpty)
    }

    // harness:criterion=c-homeviewmodel-didselect-forwards-original-character,c-homeviewmodel-didselect-all-filter-routes-correctly,c-homeviewmodel-didselect-alive-filter-routes-correctly,c-homeviewmodel-didselect-dead-filter-routes-correctly,c-homeviewmodel-didselect-unknown-filter-routes-correctly
    @MainActor
    func testDidSelectForwardsOriginalCharacterForEachActiveFilter() async throws {
        let viewModel = makeViewModel(characters: fixtureCharacters()).viewModel
        viewModel.fetchCharacters()
        _ = try await waitForLoadedCharacters(in: viewModel)

        let targets: [(CharacterStatusFilter, Character)] = [
            (.all, fixtureCharacters()[2]),
            (.alive, fixtureCharacters()[0]),
            (.dead, fixtureCharacters()[2]),
            (.unknown, fixtureCharacters()[3])
        ]

        for (filter, target) in targets {
            var routedCharacter: Character?
            viewModel.selectedFilter = filter
            XCTAssertTrue(viewModel.filteredCharacters.contains { $0.id == target.id })

            viewModel.onDetailRequested = { character in
                routedCharacter = character
            }

            viewModel.didSelect(character: target)

            XCTAssertEqual(routedCharacter?.id, target.id)
            XCTAssertEqual(routedCharacter?.name, target.name)
            XCTAssertEqual(routedCharacter?.status, target.status)
        }
    }

    // harness:criterion=c-homeviewmodel-filter-does-not-affect-repository-contract
    @MainActor
    func testChangingSelectedFilterDoesNotFetchCharactersAgain() async throws {
        let setup = makeViewModel(characters: fixtureCharacters())
        setup.viewModel.fetchCharacters()
        _ = try await waitForLoadedCharacters(in: setup.viewModel)
        XCTAssertEqual(setup.repository.fetchCallCount, 1)

        setup.viewModel.selectedFilter = .alive
        _ = setup.viewModel.filteredCharacters
        setup.viewModel.selectedFilter = .dead
        _ = setup.viewModel.filteredCharacters
        setup.viewModel.selectedFilter = .unknown
        _ = setup.viewModel.filteredCharacters
        setup.viewModel.selectedFilter = .all
        _ = setup.viewModel.filteredCharacters

        XCTAssertEqual(setup.repository.fetchCallCount, 1)
    }

    @MainActor
    private func makeViewModel(
        characters: [Character]
    ) -> (viewModel: HomeViewModel, repository: CountingCharacterRepository) {
        let repository = CountingCharacterRepository(characters: characters)
        ServiceLocator.shared.register(repository as CharacterRepositoryProtocol)
        return (HomeViewModel(), repository)
    }

    @MainActor
    private func waitForLoadedCharacters(
        in viewModel: HomeViewModel,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws -> [Character] {
        for _ in 0..<50 {
            if case .success(let characters) = viewModel.state {
                return characters
            }

            if case .failure(let message) = viewModel.state {
                XCTFail("Expected successful character load, got failure: \(message)", file: file, line: line)
                return []
            }

            try await Task.sleep(nanoseconds: 20_000_000)
        }

        XCTFail("Timed out waiting for loaded characters", file: file, line: line)
        return []
    }

    private func fixtureCharacters() -> [Character] {
        [
            Character(
                id: 1,
                name: "Rick Sanchez",
                status: .alive,
                species: "Human",
                gender: "Male",
                image: "https://rickandmortyapi.com/api/character/avatar/1.jpeg"
            ),
            Character(
                id: 2,
                name: "Morty Smith",
                status: .alive,
                species: "Human",
                gender: "Male",
                image: "https://rickandmortyapi.com/api/character/avatar/2.jpeg"
            ),
            Character(
                id: 47,
                name: "Birdperson",
                status: .dead,
                species: "Bird-Person",
                gender: "Male",
                image: "https://rickandmortyapi.com/api/character/avatar/47.jpeg"
            ),
            Character(
                id: 331,
                name: "Squanchy",
                status: .unknown,
                species: "Cat-Person",
                gender: "Male",
                image: "https://rickandmortyapi.com/api/character/avatar/331.jpeg"
            )
        ]
    }
}

private final class CountingCharacterRepository: CharacterRepositoryProtocol, @unchecked Sendable {
    private let characters: [Character]
    private let lock = NSLock()
    private var fetchCount = 0

    init(characters: [Character]) {
        self.characters = characters
    }

    var fetchCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return fetchCount
    }

    func fetchCharacters() async throws -> [Character] {
        lock.lock()
        fetchCount += 1
        lock.unlock()
        return characters
    }
}
