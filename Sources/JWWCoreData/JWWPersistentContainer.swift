import Foundation
import Combine
import CoreData

/// A container that encapsulates the Core Data stack in your app.
open class JWWPersistentContainer: NSPersistentContainer {
    /// The main thread / UI managed object context.
    public var mainObjectContext: NSManagedObjectContext {
        viewContext
    }

    // MARK: Initialization
    // ====================================
    // Initialization
    // ====================================

    public init(name: String, bundle: Bundle) {
        guard let url = bundle.url(forResource: name, withExtension: "momd") else {
            fatalError("Failed to find model \(name) in bundle.")
        }

        guard let model = NSManagedObjectModel(contentsOf: url) else {
            fatalError("Failed to load momd file \(name) at url \(url).")
        }

        super.init(name: name, managedObjectModel: model)
    }

    // MARK: Subclass Methods
    // ====================================
    // Subclass Methods
    // ====================================

    public override func loadPersistentStores(completionHandler block: @escaping (NSPersistentStoreDescription, Error?) -> Void) {
        let completion = {(storeDescription: NSPersistentStoreDescription, error: Error?) -> Void in
            self.viewContext.name = "UI / Main thread context"
            self.viewContext.automaticallyMergesChangesFromParent = true
            self.viewContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
            block(storeDescription, error)
        }
        super.loadPersistentStores(completionHandler: completion)
    }

    public override func newBackgroundContext() -> NSManagedObjectContext {
        let context = super.newBackgroundContext()
        context.undoManager = nil
        context.name = "Persistent Container Background Context"
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyStoreTrumpMergePolicyType)
        return context
    }

    // MARK: Public Methods
    // ====================================
    // Public Methods
    // ====================================


    /// Returns a publisher that wraps the `loadPersistentStores(completionHandler:)` function.
    ///
    /// - Returns: An `AnyPublisher` wrapping this publisher.
    public func loadPersistentStores() -> AnyPublisher<NSPersistentStoreDescription, Error> {
        Future { [self] promise in
            let count = persistentStoreDescriptions.count
            var index = 0

            loadPersistentStores { (description, error) in
                if let error = error {
                    return promise(.failure(error))
                }

                index += 1

                if index == count {
                    return promise(.success(description))
                }
            }
        }.eraseToAnyPublisher()
    }
}
