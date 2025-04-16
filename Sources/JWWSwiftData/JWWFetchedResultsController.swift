import Foundation
import SwiftData
import JWWCore
import os

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
public protocol JWWFetchedResultsControllerDelegate: AnyObject {
    func controllerWillChangeContent(_ controller: JWWFetchedResultsController<some PersistentModel>)
    func controllerDidChangeContent(_ controller: JWWFetchedResultsController<some PersistentModel>)
    
}

@available(macOS 14, iOS 17, tvOS 17, watchOS 10, *)
@Observable
@MainActor
public final class JWWFetchedResultsController<T: PersistentModel> {
    public unowned(unsafe) var delegate: (any JWWFetchedResultsControllerDelegate)?
    public private(set) var fetchedModels: [T]?

    private let modelContext: ModelContext
    private let fetchDescriptor: FetchDescriptor<T>

    // MARK: Initialization
    // ====================================
    // Initialization
    // ====================================

    public init(fetchRequest: FetchDescriptor<T>, context: ModelContext) {
        self.modelContext = context
        self.fetchDescriptor = fetchRequest
    }

    deinit {
        print("DEINIT")
    }

    // MARK: Public API
    // ====================================
    // Public API
    // ====================================

    public func fetch() async throws {
        let results  = try modelContext.fetch(fetchDescriptor)

        if let delegate {
            delegate.controllerWillChangeContent(self)
        }

        fetchedModels = results

        if let delegate {
            delegate.controllerDidChangeContent(self)
        }
    }
}
