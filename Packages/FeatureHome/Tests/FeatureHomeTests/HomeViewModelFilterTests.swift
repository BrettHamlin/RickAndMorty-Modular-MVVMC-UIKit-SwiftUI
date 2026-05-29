import Combine
import XCTest
import Core
import Domain
@testable import FeatureHome

@MainActor
final class HomeViewModelFilterTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []

    override func setUp() {
        super.setUp()
        ServiceLocator.shared.unregisterAll()
        cancellables = []
    }

    override func tearDown() {
        cancellables = []
        ServiceLocator.shared.unregisterAll()
        super.tearDown()
    }

    // harness:criterion=c-viewmodel-default-filter-all
    func testSelectedFilterDefaultsToAll() {
        registerRepository(characters: mixedStatusCharacters)

        let viewModel = HomeViewModel()

        XCTAssertEqual(viewModel.selectedFilter, .all)
    }

    // harness:criterion=c-viewmodel-selected-filter-published
    func testSelectedFilterPublishesEverySupportedFilterValue() {
        registerRepository(characters: mixedStatusCharacters)
        let viewModel = HomeViewModel()
        var observedFilters: [CharacterStatusFilter] = []

        viewModel.$selectedFilter
            .dropFirst()
            .sink { observedFilters.append($0) }
            .store(in: &cancellables)

        viewModel.selectedFilter = .alive
        viewModel.selectedFilter = .dead
        viewModel.selectedFilter = .unknown
        viewModel.selectedFilter = .all

        XCTAssertEqual(observedFilters, [.alive, .dead, .unknown, .all])
    }

    // harness:criterion=c-filter-alive-yields-alive-only,c-filter-tests-cover-all-statuses
    func testAliveFilterDisplaysOnlyAliveCharacters() async throws {
        registerRepository(characters: mixedStatusCharacters)
        let viewModel = HomeViewModel()

        await viewModel.fetchCharacters()
        viewModel.selectedFilter = .alive
        let displayedCharacters = try displayedCharacters(from: viewModel)

        XCTAssertFalse(displayedCharacters.isEmpty)
        XCTAssertTrue(displayedCharacters.allSatisfy { $0.status == .alive })
    }

    // harness:criterion=c-filter-dead-yields-dead-only,c-filter-tests-cover-all-statuses
    func testDeadFilterDisplaysOnlyDeadCharacters() async throws {
        registerRepository(characters: mixedStatusCharacters)
        let viewModel = HomeViewModel()

        await viewModel.fetchCharacters()
        viewModel.selectedFilter = .dead
        let displayedCharacters = try displayedCharacters(from: viewModel)

        XCTAssertFalse(displayedCharacters.isEmpty)
        XCTAssertTrue(displayedCharacters.allSatisfy { $0.status == .dead })
    }

    // harness:criterion=c-filter-unknown-yields-unknown-only,c-filter-tests-cover-all-statuses
    func testUnknownFilterDisplaysOnlyUnknownCharacters() async throws {
        registerRepository(characters: mixedStatusCharacters)
        let viewModel = HomeViewModel()

        await viewModel.fetchCharacters()
        viewModel.selectedFilter = .unknown
        let displayedCharacters = try displayedCharacters(from: viewModel)

        XCTAssertFalse(displayedCharacters.isEmpty)
        XCTAssertTrue(displayedCharacters.allSatisfy { $0.status == .unknown })
    }

    // harness:criterion=c-viewmodel-all-characters-cache,c-filter-switch-no-fetch,c-filter-all-yields-full-list
    func testSwitchingFiltersUsesCachedCharactersWithoutRefetching() async throws {
        let repository = registerRepository(characters: mixedStatusCharacters)
        let viewModel = HomeViewModel()

        await viewModel.fetchCharacters()
        viewModel.selectedFilter = .alive
        viewModel.selectedFilter = .dead
        viewModel.selectedFilter = .unknown
        viewModel.selectedFilter = .all
        let displayedCharacters = try displayedCharacters(from: viewModel)

        XCTAssertEqual(repository.fetchCallCount, 1)
        XCTAssertEqual(displayedCharacters.count, mixedStatusCharacters.count)
    }

    // harness:criterion=c-filter-empty-result
    func testFilterWithNoMatchingCachedCharactersPublishesEmptySuccess() async throws {
        registerRepository(characters: [
            character(id: 10, name: "Only Alive Rick", status: .alive),
            character(id: 11, name: "Only Alive Morty", status: .alive)
        ])
        let viewModel = HomeViewModel()

        await viewModel.fetchCharacters()
        viewModel.selectedFilter = .dead
        let displayedCharacters = try displayedCharacters(from: viewModel)

        XCTAssertTrue(displayedCharacters.isEmpty)
    }

    // harness:criterion=c-did-select-fires-detail-filtered-row,c-did-select-unchanged-signature
    func testDidSelectFilteredCharacterRequestsDetailForTheSameCharacter() async throws {
        registerRepository(characters: mixedStatusCharacters)
        let viewModel = HomeViewModel()
        var requestedCharacters: [Character] = []

        await viewModel.fetchCharacters()
        viewModel.selectedFilter = .alive
        let selectedCharacter = try XCTUnwrap(displayedCharacters(from: viewModel).first)
        viewModel.onDetailRequested = { requestedCharacters.append($0) }

        viewModel.didSelect(character: selectedCharacter)

        XCTAssertEqual(requestedCharacters.count, 1)
        XCTAssertEqual(requestedCharacters.first?.id, selectedCharacter.id)
        XCTAssertEqual(requestedCharacters.first?.name, selectedCharacter.name)
    }

    // harness:criterion=c-loading-state-preserved
    func testLoadingStateIsPreservedWhileFetchIsInFlightForStatusFilters() async {
        for filter in [CharacterStatusFilter.alive, .dead, .unknown] {
            ServiceLocator.shared.unregisterAll()
            let fetchStarted = expectation(description: "fetch started for \(filter.rawValue)")
            let repository = SuspendingCharacterRepository {
                fetchStarted.fulfill()
            }
            ServiceLocator.shared.register(repository as CharacterRepositoryProtocol)
            let viewModel = HomeViewModel()
            viewModel.selectedFilter = filter

            let fetchTask = Task {
                await viewModel.fetchCharacters()
            }
            await fulfillment(of: [fetchStarted], timeout: 1.0)

            assertLoading(viewModel.state)
            repository.resume(returning: mixedStatusCharacters)
            await fetchTask.value
        }
    }

    // harness:criterion=c-failure-state-preserved
    func testFailureStateIsPreservedForEveryFilterValueWhenFetchThrows() async {
        let repository = registerRepository(error: TestError.fetchFailed)
        let viewModel = HomeViewModel()

        for filter in [CharacterStatusFilter.all, .alive, .dead, .unknown] {
            viewModel.selectedFilter = filter

            await viewModel.fetchCharacters()

            assertFailure(viewModel.state)
        }

        XCTAssertEqual(repository.fetchCallCount, 4)
    }

    // harness:criterion=c-filter-tests-use-service-locator-mock,c-package-test-target-added,c-feature-home-tests-compiles
    func testServiceLocatorMockCanBeReplacedBetweenViewModels() async throws {
        let firstRepository = registerRepository(characters: [character(id: 20, name: "Alive One", status: .alive)])
        let firstViewModel = HomeViewModel()
        await firstViewModel.fetchCharacters()
        XCTAssertEqual(try displayedCharacters(from: firstViewModel).map(\.name), ["Alive One"])
        XCTAssertEqual(firstRepository.fetchCallCount, 1)

        ServiceLocator.shared.unregisterAll()

        let secondRepository = registerRepository(characters: [character(id: 21, name: "Dead One", status: .dead)])
        let secondViewModel = HomeViewModel()
        await secondViewModel.fetchCharacters()
        XCTAssertEqual(try displayedCharacters(from: secondViewModel).map(\.name), ["Dead One"])
        XCTAssertEqual(secondRepository.fetchCallCount, 1)
    }

    @discardableResult
    private func registerRepository(characters: [Character]) -> MockCharacterRepository {
        let repository = MockCharacterRepository(result: .success(characters))
        ServiceLocator.shared.register(repository as CharacterRepositoryProtocol)
        return repository
    }

    @discardableResult
    private func registerRepository(error: Error) -> MockCharacterRepository {
        let repository = MockCharacterRepository(result: .failure(error))
        ServiceLocator.shared.register(repository as CharacterRepositoryProtocol)
        return repository
    }

    private var mixedStatusCharacters: [Character] {
        [
            character(id: 1, name: "Rick Sanchez", status: .alive),
            character(id: 2, name: "Morty Smith", status: .alive),
            character(id: 3, name: "Squanchy", status: .dead),
            character(id: 4, name: "Birdperson", status: .unknown)
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

    private func displayedCharacters(
        from viewModel: HomeViewModel,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> [Character] {
        switch viewModel.state {
        case .success(let characters):
            return characters
        case .loading:
            XCTFail("Expected success state, got loading", file: file, line: line)
            return []
        case .failure(let message):
            XCTFail("Expected success state, got failure: \(message)", file: file, line: line)
            return []
        }
    }

    private func assertLoading(_ state: HomeViewState, file: StaticString = #filePath, line: UInt = #line) {
        guard case .loading = state else {
            XCTFail("Expected loading state", file: file, line: line)
            return
        }
    }

    private func assertFailure(_ state: HomeViewState, file: StaticString = #filePath, line: UInt = #line) {
        guard case .failure = state else {
            XCTFail("Expected failure state", file: file, line: line)
            return
        }
    }
}

private final class MockCharacterRepository: CharacterRepositoryProtocol, @unchecked Sendable {
    enum Result {
        case success([Character])
        case failure(Error)
    }

    private let lock = NSLock()
    private let result: Result
    private var _fetchCallCount = 0

    var fetchCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _fetchCallCount
    }

    init(result: Result) {
        self.result = result
    }

    func fetchCharacters() async throws -> [Character] {
        lock.lock()
        _fetchCallCount += 1
        lock.unlock()

        switch result {
        case .success(let characters):
            return characters
        case .failure(let error):
            throw error
        }
    }
}

private final class SuspendingCharacterRepository: CharacterRepositoryProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private let onSuspended: () -> Void
    private var continuation: CheckedContinuation<[Character], Error>?

    init(onSuspended: @escaping () -> Void) {
        self.onSuspended = onSuspended
    }

    func fetchCharacters() async throws -> [Character] {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            self.continuation = continuation
            lock.unlock()
            onSuspended()
        }
    }

    func resume(returning characters: [Character]) {
        lock.lock()
        let continuation = continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(returning: characters)
    }
}

private enum TestError: Error {
    case fetchFailed
}
