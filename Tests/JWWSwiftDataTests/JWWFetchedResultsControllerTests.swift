import Foundation
import Testing
import SwiftData
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import JWWSwiftData

/// Tests to verify the functionality of `JWWFetchedResultsController`.
@MainActor
final class JWWFetchedResultsControllerTests {
    private let sut: JWWFetchedResultsController<Person>
    private let container: ModelContainer
    private var delegate: JWWFetchedResultsControllerTestsDelegate?

    init() throws {
        container = JWWSwiftDataTestingStack().testingModelContainer

        var fetchDescriptor = FetchDescriptor<Person>()
        fetchDescriptor.sortBy = [
            SortDescriptor(\.firstName, order: .forward)
        ]

        sut = JWWFetchedResultsController(fetchDescriptor: fetchDescriptor, modelContainer: container)
    }

    deinit {
        try? container.erase()
    }

    @Test("init")
    func initController() async {
        #expect(sut.fetchedModels == nil)
        #expect(sut.delegate == nil)
    }

    @Test("Fetching initial data")
    func fetchInitialData() async throws {
        try insertDefaultObjects()

        try await sut.fetch()

        let result = try #require(sut.fetchedModels)
        #expect(result.count == 3, "Expected 3 people, but got \(result.count)")
    }

    @Test("Initial fetch doesn't call delegate methods")
    func initialFetchDoesntCallDelegate() async throws {
        delegate = JWWFetchedResultsControllerTestsDelegate()
        sut.delegate = delegate
        try insertDefaultObjects()

        try await sut.fetch()

        let result = try #require(delegate)
        #expect(result.controllerWillChangeContentCalled == false, "Delegate methods should not be called after the initial fetch.")
        #expect(result.controllerDidChangeContentCalled == false, "Delegate methods should not be called after the initial fetch.")
        #expect(result.controllerDidChangeObjectCalled == false, "Delegate methods should not be called after the initial fetch.")
    }

    @Test("Updating already fetched data calls delegate methods")
    func updatingDataCallsDelegateMethods() async throws {
        delegate = JWWFetchedResultsControllerTestsDelegate()
        sut.delegate = delegate
        try insertDefaultObjects()
        try await sut.fetch()

        container.mainContext.insert(Person(id: UUID(), firstName: "Steve"))
        try container.mainContext.save()

        let result = try #require(delegate)
        #expect(result.controllerWillChangeContentCalled == true, "Delegate methods should be called after data change.")
        #expect(result.controllerDidChangeContentCalled == true, "Delegate methods should be called after data change.")
        #expect(result.controllerDidChangeObjectCalled == true, "Delegate methods should be called after data change.")
    }

    @Test("object(at:) returns correct object")
    func objectAtIndexPath() async throws {
        try insertDefaultObjects()
        try await sut.fetch()

        let indexPath = IndexPath(item: 1, section: 0)
        let object = try sut.object(at: indexPath)
        #expect(object.firstName == "Jane")
    }

    @Test("indexPath(forObject:) returns correct indexPath")
    func indexPathForObject() async throws {
        try insertDefaultObjects()
        try await sut.fetch()

        let object = try #require(sut.fetchedModels?.last)
        let indexPath = sut.indexPath(forObject: object)
        #expect(indexPath == IndexPath(item: 2, section: 0))
    }

    @Test("object(at:) throws for out-of-bounds indexPath")
    func objectAtIndexPathOutOfBounds() async throws {
        try insertDefaultObjects()
        try await sut.fetch()

        let indexPath = IndexPath(item: 10, section: 0)
        #expect(throws: JWWFetchedResultsControllerError.indexPathOutOfBounds) {
            try self.sut.object(at: indexPath)
        }
    }

    @Test("indexPath(forObject:) returns nil for missing object")
    func indexPathForNonexistentObject() async throws {
        try insertDefaultObjects()
        try await sut.fetch()

        let missing = Person(id: UUID(), firstName: "Ghost")
        let indexPath = sut.indexPath(forObject: missing)
        #expect(indexPath == nil)
    }

    // MARK: Private / Convenience
    // ====================================
    // Private / Convenience
    // ====================================

    /// Inserts default test objects into the container.
    private func insertDefaultObjects() throws {
        let people: [Person] = [
            Person(id: UUID(), firstName: "John"),
            Person(id: UUID(), firstName: "Jane"),
            Person(id: UUID(), firstName: "Doe")
        ]
        for person in people {
            container.mainContext.insert(person)
        }
        try container.mainContext.save()
    }
}

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
private final class JWWFetchedResultsControllerTestsDelegate: JWWFetchedResultsControllerDelegate {
    private(set) var controllerWillChangeContentCalled: Bool
    private(set) var controllerDidChangeContentCalled: Bool
    private(set) var controllerDidChangeObjectCalled: Bool

    init() {
        self.controllerWillChangeContentCalled = false
        self.controllerDidChangeContentCalled = false
        self.controllerDidChangeObjectCalled = false
    }

    func controllerWillChangeContent(_ controller: JWWSwiftData.JWWFetchedResultsController<some PersistentModel>) {
        controllerWillChangeContentCalled = true
    }

    func controllerDidChangeContent(_ controller: JWWSwiftData.JWWFetchedResultsController<some PersistentModel>) {
        controllerDidChangeContentCalled = true
    }

    func controller(_ controller: JWWFetchedResultsController<some PersistentModel>, didChange anObject: some PersistentModel, at indexPath: IndexPath?, for type: JWWFetchedResultsChangeType, newIndexPath: IndexPath?) {
        controllerDidChangeObjectCalled = true
    }
}
