import Foundation
import Testing
import SwiftData
import JWWSwiftData

/// Tests to verify the functionality of `JWWFetchedResultsController`.
@Suite("JWWFetchedResultsController Tests")
@MainActor
final class JWWFetchedResultsControllerTests {
    private let sut: JWWFetchedResultsController<Person>
    private let container: ModelContainer
    private var delegate: JWWFetchedResultsControllerTestsDelegate?

    init() throws {
        container = JWWSwiftDataTestingStack().testingModelContainer
        sut = JWWFetchedResultsController(fetchRequest: FetchDescriptor<Person>(), context: container.mainContext)
    }

    @Test("init")
    func initController() async {
        #expect(sut.fetchedModels == nil)
        #expect(sut.delegate == nil)
    }

    @Test("Fetching initial data")
    func fetchData() async throws {
        let people = [
            Person(id: UUID(), firstName: "John"),
            Person(id: UUID(), firstName: "Jane"),
            Person(id: UUID(), firstName: "Doe")
        ]

        for person in people {
            container.mainContext.insert(person)
        }
        try container.mainContext.save()

        try await sut.fetch()

        let result = try #require(sut.fetchedModels)
        #expect(result.count == 3, "Expected 3 people, but got \(result.count)")
    }

    @Test("Fetching data with predicate")
    func updateData() async throws {
        delegate = JWWFetchedResultsControllerTestsDelegate()
        sut.delegate = delegate

        let people = [
            Person(id: UUID(), firstName: "John"),
            Person(id: UUID(), firstName: "Jane"),
            Person(id: UUID(), firstName: "Doe")
        ]

        for person in people {
            container.mainContext.insert(person)
        }
        try container.mainContext.save()

        try await sut.fetch()

        let result = try #require(delegate)
        #expect(result.controllerWillChangeContentCalled == true)
        #expect(result.controllerDidChangeContentCalled == true)
    }
}

final class JWWFetchedResultsControllerTestsDelegate: JWWFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: JWWSwiftData.JWWFetchedResultsController<some PersistentModel>) {
        controllerWillChangeContentCalled = true
    }
    
    func controllerDidChangeContent(_ controller: JWWSwiftData.JWWFetchedResultsController<some PersistentModel>) {
        controllerDidChangeContentCalled = true
    }

    private(set) var controllerWillChangeContentCalled: Bool
    private(set) var controllerDidChangeContentCalled: Bool

    init() {
        self.controllerWillChangeContentCalled = false
        self.controllerDidChangeContentCalled = false
    }
}
