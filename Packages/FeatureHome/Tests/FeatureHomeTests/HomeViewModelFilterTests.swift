import Combine
import XCTest
import Core
import Domain
@testable import FeatureHome

final class HomeViewModelFilterTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []

    override func tearDown() {
        cancellables.removeAll()
        ServiceLocator.shared.unregisterAll()
        super.tearDown()
    }

    //harness:criterion=c-filter-type-all-four-cases,c-package-test-target-added
    func testCharacterStatusFilterHasExactlyTheSupportedCases() {
        XCTAssertEqual(CharacterStatusFilter.allCases.count, 4)

        let filters: [CharacterStatusFilter] = [.all, .alive, .dead, .unknown]
        XCTAssertEqual(Set(CharacterStatusFilter.allCases), Set(filters))

        for filter in filters {
            switch filter {
            case .all, .alive, .dead, .unknown:
                break
            }
        }
    }

    //harness:criterion=c-viewmodel-selected-filter-default-all
    @MainActor
    func testSelectedFilterDefaultsToAll() {
        registerRepository(with: mixedStatusCharacters())

        let viewModel = HomeViewModel()

        XCTAssertEqual(viewModel.selectedFilter, .all)
    }

    //harness:criterion=c-viewmodel-published-selected-filter
    @MainActor
    func testSelectedFilterPublishesChanges() {
        registerRepository(with: mixedStatusCharacters())
        let viewModel = HomeViewModel()
        let expectation = expectation(description: "selected filter publishes the new value")
        var receivedFilters: [CharacterStatusFilter] = []

        viewModel.$selectedFilter
            .dropFirst()
            .sink { filter in
                receivedFilters.append(filter)
                if filter == .alive {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        viewModel.selectedFilter = .alive

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(receivedFilters, [.alive])
    }

    //harness:criterion=c-viewmodel-stores-full-list
    @MainActor
    func testChangingFilterBackToAllUsesCachedFullListWithoutRefetching() async {
        let repository = registerRepository(with: mixedStatusCharacters())
        let viewModel = HomeViewModel()

        viewModel.fetchCharacters()
        _ = await successCharacters(in: viewModel)

        viewModel.selectedFilter = .alive
        _ = await successCharacters(in: viewModel)
        viewModel.selectedFilter = .all
        let characters = await successCharacters(in: viewModel)

        XCTAssertEqual(characters.count, 4)
        XCTAssertEqual(repository.fetchCallCount, 1)
    }

    //harness:criterion=c-filter-all-shows-every-character
    @MainActor
    func testAllFilterShowsEveryReturnedCharacter() async {
        registerRepository(with: mixedStatusCharacters())
        let viewModel = HomeViewModel()

        viewModel.fetchCharacters()
        _ = await successCharacters(in: viewModel)
        viewModel.selectedFilter = .all
        let characters = await successCharacters(in: viewModel)

        XCTAssertEqual(characters.map(\.id), [1, 2, 3, 4])
        XCTAssertEqual(Set(characters.map(\.status)), [.alive, .dead, .unknown])
    }

    //harness:criterion=c-filter-alive-shows-only-alive,c-filter-alive-excludes-dead-and-unknown
    @MainActor
    func testAliveFilterShowsOnlyAliveCharacters() async {
        registerRepository(with: mixedStatusCharacters())
        let viewModel = HomeViewModel()

        viewModel.fetchCharacters()
        _ = await successCharacters(in: viewModel)
        viewModel.selectedFilter = .alive
        let characters = await successCharacters(in: viewModel)

        XCTAssertEqual(characters.count, 2)
        XCTAssertEqual(characters.map(\.id), [1, 2])
        XCTAssertTrue(characters.allSatisfy { $0.status == .alive })
        XCTAssertTrue(characters.filter { $0.status == .dead || $0.status == .unknown }.isEmpty)
    }

    //harness:criterion=c-filter-dead-shows-only-dead,c-filter-dead-excludes-alive-and-unknown
    @MainActor
    func testDeadFilterShowsOnlyDeadCharacters() async {
        registerRepository(with: mixedStatusCharacters())
        let viewModel = HomeViewModel()

        viewModel.fetchCharacters()
        _ = await successCharacters(in: viewModel)
        viewModel.selectedFilter = .dead
        let characters = await successCharacters(in: viewModel)

        XCTAssertEqual(characters.count, 1)
        XCTAssertEqual(characters.map(\.id), [3])
        XCTAssertTrue(characters.allSatisfy { $0.status == .dead })
        XCTAssertTrue(characters.filter { $0.status == .alive || $0.status == .unknown }.isEmpty)
    }

    //harness:criterion=c-filter-unknown-shows-only-unknown,c-filter-unknown-excludes-alive-and-dead
    @MainActor
    func testUnknownFilterShowsOnlyUnknownCharacters() async {
        registerRepository(with: mixedStatusCharacters())
        let viewModel = HomeViewModel()

        viewModel.fetchCharacters()
        _ = await successCharacters(in: viewModel)
        viewModel.selectedFilter = .unknown
        let characters = await successCharacters(in: viewModel)

        XCTAssertEqual(characters.count, 1)
        XCTAssertEqual(characters.map(\.id), [4])
        XCTAssertTrue(characters.allSatisfy { $0.status == .unknown })
        XCTAssertTrue(characters.filter { $0.status == .alive || $0.status == .dead }.isEmpty)
    }

    //harness:criterion=c-filter-empty-result-no-crash
    @MainActor
    func testFilterWithNoMatchesEmitsEmptySuccessState() async {
        registerRepository(with: [
            character(id: 10, name: "Rick Sanchez", status: .alive),
            character(id: 11, name: "Morty Smith", status: .alive)
        ])
        let viewModel = HomeViewModel()

        viewModel.fetchCharacters()
        _ = await successCharacters(in: viewModel)
        viewModel.selectedFilter = .dead
        let characters = await successCharacters(in: viewModel)

        switch viewModel.state {
        case .success:
            XCTAssertTrue(characters.isEmpty)
        case .loading:
            XCTFail("Expected an empty success state, got loading")
        case .failure(let message):
            XCTFail("Expected an empty success state, got failure: \(message)")
        }
    }

    //harness:criterion=c-filter-change-no-refetch
    @MainActor
    func testChangingFiltersDoesNotFetchAgain() async {
        let repository = registerRepository(with: mixedStatusCharacters())
        let viewModel = HomeViewModel()

        viewModel.fetchCharacters()
        _ = await successCharacters(in: viewModel)

        viewModel.selectedFilter = .alive
        viewModel.selectedFilter = .dead
        viewModel.selectedFilter = .unknown
        viewModel.selectedFilter = .all

        XCTAssertEqual(repository.fetchCallCount, 1)
    }

    //harness:criterion=c-did-select-fires-on-detail-requested
    @MainActor
    func testDidSelectInvokesDetailCallbackForCurrentFilter() {
        registerRepository(with: mixedStatusCharacters())
        let selectedCharacter = character(id: 42, name: "Pickle Rick", status: .alive)

        assertDidSelectInvokesDetailCallbackOnce(
            selectedFilter: .all,
            character: selectedCharacter
        )
        assertDidSelectInvokesDetailCallbackOnce(
            selectedFilter: .alive,
            character: selectedCharacter
        )
    }

    @MainActor
    private func assertDidSelectInvokesDetailCallbackOnce(
        selectedFilter: CharacterStatusFilter,
        character: Character,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let viewModel = HomeViewModel()
        viewModel.selectedFilter = selectedFilter
        var receivedCharacters: [Character] = []
        viewModel.onDetailRequested = { receivedCharacters.append($0) }

        viewModel.didSelect(character: character)

        XCTAssertEqual(receivedCharacters.count, 1, file: file, line: line)
        XCTAssertEqual(receivedCharacters.first?.id, character.id, file: file, line: line)
        XCTAssertEqual(receivedCharacters.first?.name, character.name, file: file, line: line)
        XCTAssertEqual(receivedCharacters.first?.status, character.status, file: file, line: line)
    }

    //harness:criterion=c-did-select-after-filter-correct-character
    @MainActor
    func testDidSelectAfterFilteringPassesTheFilteredCharacterToDetailCallback() async {
        registerRepository(with: mixedStatusCharacters())
        let viewModel = HomeViewModel()

        viewModel.fetchCharacters()
        _ = await successCharacters(in: viewModel)
        viewModel.selectedFilter = .alive
        let aliveCharacter = await successCharacters(in: viewModel).first!

        var receivedCharacter: Character?
        viewModel.onDetailRequested = { receivedCharacter = $0 }
        viewModel.didSelect(character: aliveCharacter)

        XCTAssertEqual(receivedCharacter?.id, aliveCharacter.id)
        XCTAssertEqual(receivedCharacter?.name, aliveCharacter.name)
        XCTAssertEqual(receivedCharacter?.status, aliveCharacter.status)
    }

    @discardableResult
    private func registerRepository(with characters: [Character]) -> FakeCharacterRepository {
        let repository = FakeCharacterRepository(characters: characters)
        ServiceLocator.shared.register(repository as CharacterRepositoryProtocol)
        return repository
    }

    private func mixedStatusCharacters() -> [Character] {
        [
            character(id: 1, name: "Rick Sanchez", status: .alive),
            character(id: 2, name: "Morty Smith", status: .alive),
            character(id: 3, name: "Birdperson", status: .dead),
            character(id: 4, name: "Dr. Wong", status: .unknown)
        ]
    }

    private func character(id: Int, name: String, status: CharacterStatusType) -> Character {
        Character(
            id: id,
            name: name,
            status: status,
            species: "Human",
            gender: "Unknown",
            image: "https://example.com/\(id).png"
        )
    }

    @MainActor
    private func successCharacters(
        in viewModel: HomeViewModel,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async -> [Character] {
        for _ in 0..<100 {
            switch viewModel.state {
            case .success(let characters):
                return characters
            case .failure(let message):
                XCTFail("Expected success state, got failure: \(message)", file: file, line: line)
                return []
            case .loading:
                try? await Task.sleep(nanoseconds: 10_000_000)
            }
        }

        XCTFail("Timed out waiting for success state", file: file, line: line)
        return []
    }
}

private final class FakeCharacterRepository: CharacterRepositoryProtocol, @unchecked Sendable {
    private let characters: [Character]
    private let lock = NSLock()
    private var _fetchCallCount = 0

    var fetchCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _fetchCallCount
    }

    init(characters: [Character]) {
        self.characters = characters
    }

    func fetchCharacters() async throws -> [Character] {
        incrementFetchCallCount()
        return characters
    }

    private func incrementFetchCallCount() {
        lock.lock()
        defer { lock.unlock() }
        _fetchCallCount += 1
    }
}
