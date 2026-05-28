import XCTest
import Core
import Domain
@testable import FeatureHome

final class HomeViewModelFilterTests: XCTestCase {
    private let mixedCharacters = [
        Character(id: 1, name: "Rick Sanchez", status: .alive, species: "Human", gender: "Male", image: "rick.jpg"),
        Character(id: 2, name: "Morty Smith", status: .alive, species: "Human", gender: "Male", image: "morty.jpg"),
        Character(id: 3, name: "Adjudicator Rick", status: .dead, species: "Human", gender: "Male", image: "adjudicator.jpg"),
        Character(id: 4, name: "Antenna Morty", status: .unknown, species: "Human", gender: "Male", image: "antenna.jpg")
    ]

    override func tearDown() {
        //harness:criterion=c-unit-test-service-locator-teardown
        ServiceLocator.shared.unregisterAll()
        super.tearDown()
    }

    func testCharacterStatusTypeAllCasesExposeEveryFilterOption() {
        //harness:criterion=c-character-status-type-case-iterable
        let cases = CharacterStatusType.allCases

        XCTAssertEqual(cases.count, 4)
        XCTAssertTrue(cases.contains(.all))
        XCTAssertTrue(cases.contains(.alive))
        XCTAssertTrue(cases.contains(.dead))
        XCTAssertTrue(cases.contains(.unknown))
    }

    @MainActor
    func testSelectedFilterDefaultsToAllBeforeFetch() {
        //harness:criterion=c-homeviewmodel-selected-filter-default-all
        registerRepository(returning: [])

        let viewModel = HomeViewModel()

        XCTAssertEqual(viewModel.selectedFilter, .all)
    }

    @MainActor
    func testFilterAll() async throws {
        //harness:criterion=c-homeviewmodel-filtered-characters-all-passthrough
        let viewModel = makeViewModel(returning: mixedCharacters)

        viewModel.fetchCharacters()
        try await waitForSuccess(in: viewModel)
        viewModel.selectedFilter = .all

        XCTAssertEqual(viewModel.filteredCharacters, mixedCharacters)
    }

    @MainActor
    func testFilterAlive() async throws {
        //harness:criterion=c-homeviewmodel-filtered-characters-alive
        let viewModel = makeViewModel(returning: mixedCharacters)

        viewModel.fetchCharacters()
        try await waitForSuccess(in: viewModel)
        viewModel.selectedFilter = .alive

        XCTAssertEqual(viewModel.filteredCharacters, mixedCharacters.filter { $0.status == .alive })
        XCTAssertTrue(viewModel.filteredCharacters.allSatisfy { $0.status == .alive })
    }

    @MainActor
    func testFilterDead() async throws {
        //harness:criterion=c-homeviewmodel-filtered-characters-dead
        let viewModel = makeViewModel(returning: mixedCharacters)

        viewModel.fetchCharacters()
        try await waitForSuccess(in: viewModel)
        viewModel.selectedFilter = .dead

        XCTAssertEqual(viewModel.filteredCharacters, mixedCharacters.filter { $0.status == .dead })
        XCTAssertTrue(viewModel.filteredCharacters.allSatisfy { $0.status == .dead })
    }

    @MainActor
    func testFilterUnknown() async throws {
        //harness:criterion=c-homeviewmodel-filtered-characters-unknown
        let viewModel = makeViewModel(returning: mixedCharacters)

        viewModel.fetchCharacters()
        try await waitForSuccess(in: viewModel)
        viewModel.selectedFilter = .unknown

        XCTAssertEqual(viewModel.filteredCharacters, mixedCharacters.filter { $0.status == .unknown })
        XCTAssertTrue(viewModel.filteredCharacters.allSatisfy { $0.status == .unknown })
    }

    @MainActor
    func testFilterEmptyState() async throws {
        //harness:criterion=c-homeviewmodel-filtered-characters-empty-state
        let aliveCharacters = mixedCharacters.filter { $0.status == .alive }
        let viewModel = makeViewModel(returning: aliveCharacters)

        viewModel.fetchCharacters()
        try await waitForSuccess(in: viewModel)
        viewModel.selectedFilter = .dead

        XCTAssertTrue(viewModel.filteredCharacters.isEmpty)
    }

    @MainActor
    func testFetchCharactersCalledOnce() async throws {
        //harness:criterion=c-homeviewmodel-fetch-characters-unchanged
        let repository = registerRepository(returning: mixedCharacters)
        let viewModel = HomeViewModel()
        viewModel.selectedFilter = .dead

        viewModel.fetchCharacters()
        try await waitForSuccess(in: viewModel)

        XCTAssertEqual(repository.fetchCallCount, 1)
        XCTAssertEqual(viewModel.state, .success(mixedCharacters))
        XCTAssertEqual(viewModel.filteredCharacters, mixedCharacters.filter { $0.status == .dead })
    }

    @MainActor
    func testDidSelectRoutesUnmodifiedCharacter() async throws {
        //harness:criterion=c-homeviewmodel-did-select-routes-unmodified-character
        let viewModel = makeViewModel(returning: mixedCharacters)
        var routedCharacter: Character?
        viewModel.onDetailRequested = { routedCharacter = $0 }

        viewModel.fetchCharacters()
        try await waitForSuccess(in: viewModel)
        viewModel.selectedFilter = .alive
        let selectedCharacter = try XCTUnwrap(viewModel.filteredCharacters.first)
        viewModel.didSelect(character: selectedCharacter)

        XCTAssertEqual(routedCharacter, selectedCharacter)
        XCTAssertEqual(routedCharacter, mixedCharacters.first)
    }

    @MainActor
    func testNoRefetchOnFilterChange() async throws {
        //harness:criterion=c-homeview-no-refetch-on-filter-change
        let repository = registerRepository(returning: mixedCharacters)
        let viewModel = HomeViewModel()

        viewModel.fetchCharacters()
        try await waitForSuccess(in: viewModel)
        viewModel.selectedFilter = .alive
        viewModel.selectedFilter = .dead
        viewModel.selectedFilter = .unknown
        viewModel.selectedFilter = .all

        XCTAssertEqual(repository.fetchCallCount, 1)
    }

    @MainActor
    func testLoadingAndFailureStatesRemainSafeForFiltering() {
        //harness:criterion=c-homeview-loading-state-unaffected,c-homeview-failure-state-unaffected
        registerRepository(returning: mixedCharacters)
        let viewModel = HomeViewModel()

        viewModel.state = .loading
        viewModel.selectedFilter = .dead
        XCTAssertEqual(viewModel.state, .loading)
        XCTAssertTrue(viewModel.filteredCharacters.isEmpty)

        viewModel.state = .failure("Something went wrong")
        viewModel.selectedFilter = .alive
        XCTAssertEqual(viewModel.state, .failure("Something went wrong"))
        XCTAssertTrue(viewModel.filteredCharacters.isEmpty)
    }

    @MainActor
    private func makeViewModel(returning characters: [Character]) -> HomeViewModel {
        registerRepository(returning: characters)
        return HomeViewModel()
    }

    @discardableResult
    private func registerRepository(returning characters: [Character]) -> SpyCharacterRepository {
        let repository = SpyCharacterRepository(characters: characters)
        ServiceLocator.shared.register(repository as CharacterRepositoryProtocol)
        return repository
    }

    @MainActor
    private func waitForSuccess(in viewModel: HomeViewModel) async throws {
        for _ in 0..<50 {
            if case .success = viewModel.state {
                return
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTFail("Expected HomeViewModel.state to become .success, got \(viewModel.state)")
    }
}

private final class SpyCharacterRepository: CharacterRepositoryProtocol, @unchecked Sendable {
    private let characters: [Character]
    private let lock = NSLock()
    private var storedFetchCallCount = 0

    var fetchCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return storedFetchCallCount
    }

    init(characters: [Character]) {
        self.characters = characters
    }

    func fetchCharacters() async throws -> [Character] {
        lock.lock()
        storedFetchCallCount += 1
        lock.unlock()
        return characters
    }
}
