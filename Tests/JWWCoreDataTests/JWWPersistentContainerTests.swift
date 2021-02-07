import XCTest
import Combine
import CoreData
@testable import JWWCoreData

/// Tests to validate our `PersistentContainer` type.
final class JWWPersistentContainerTests: XCTestCase {
    /// Test container
    private var sut: TestDatabaseContainer!

    private var subscriptions: Set<AnyCancellable> = []

    override func setUpWithError() throws {
        try super.setUpWithError()

        sut = TestDatabaseContainer()

        let loadingEx = expectation(description: "loading persistent store")

        sut.loadPersistentStores()
            .sink(receiveCompletion: { (completion) in
                switch completion {
                case .finished:
                    loadingEx.fulfill()
                case .failure(let error):
                    XCTFail("Error initialized data store: \(error)")
                }
            },
            receiveValue: { _ in })
            .store(in: &subscriptions)

        wait(for: [loadingEx], timeout: 1.0)
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()

        sut = nil
        subscriptions.removeAll()
    }

    /// Validate our main context is properly named.
    func testMainContextNaming() throws {
        let expectedName = "UI / Main thread context"

        let result = sut.mainObjectContext.name

        XCTAssertEqual(result, expectedName)
    }

    /// Validate a new background context is properly named.
    func testBackgroundContextNaming() throws {
        let expectedName = "Persistent Container Background Context"

        let result = try XCTUnwrap(sut.newBackgroundContext().name)

        XCTAssertEqual(result, expectedName)
    }
}

private final class TestDatabaseContainer: JWWPersistentContainer {
    init() {
        super.init(name: "Test Database", bundle: .module)
    }
}
