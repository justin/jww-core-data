import Foundation
import SwiftData
import CoreData
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import JWWCore
import os
import _JWWDataInternal

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
public enum JWWFetchedResultsControllerError: Error {
    case indexPathOutOfBounds
}

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
public enum JWWFetchedResultsChangeType: String, CaseIterable, Hashable {
    case inserted
    case updated
    case deleted
}

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
@MainActor
public protocol JWWFetchedResultsControllerDelegate: AnyObject {
    func controllerWillChangeContent(_ controller: JWWFetchedResultsController<some PersistentModel>)

    func controller(_ controller: JWWFetchedResultsController<some PersistentModel>, didChange anObject: some PersistentModel, at indexPath: IndexPath?, for type: JWWFetchedResultsChangeType, newIndexPath: IndexPath?)

    func controllerDidChangeContent(_ controller: JWWFetchedResultsController<some PersistentModel>)
}

public extension JWWFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: JWWFetchedResultsController<some PersistentModel>) { }

    func controller(_ controller: JWWFetchedResultsController<some PersistentModel>, didChange anObject: some PersistentModel, at indexPath: IndexPath?, for type: JWWFetchedResultsChangeType, newIndexPath: IndexPath?) { }

    func controllerDidChangeContent(_ controller: JWWFetchedResultsController<some PersistentModel>) { }
}

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
@MainActor
public final class JWWFetchedResultsController<T: PersistentModel> {
    public nonisolated(unsafe) unowned(unsafe) var delegate: (any JWWFetchedResultsControllerDelegate)?
    public private(set) var fetchedModels: [T]?
    public nonisolated let modelContainer: ModelContainer

    private let modelContext: ModelContext
    private let fetchDescriptor: FetchDescriptor<T>
    internal let notificationCenter: NotificationCenter = .default

    /// The task that is used to monitor the database for changes.
    private var notificationsTask: Task<Void, Never>?

    // MARK: Initialization
    // ====================================
    // Initialization
    // ====================================

    public init(fetchRequest: FetchDescriptor<T>, modelContainer: ModelContainer, delegate: JWWFetchedResultsControllerDelegate? = nil) {
        self.fetchDescriptor = fetchRequest
        self.modelContainer = modelContainer
        self.modelContext = ModelContext(modelContainer)
        self.delegate = delegate
    }

    deinit {
        Task { [notificationsTask] in
            notificationsTask?.cancel()
        }
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

        notificationsTask = Task { [notificationCenter] in
            await subscribeToModelChanges(notificationCenter: notificationCenter)
        }
    }

    public func object(at indexPath: IndexPath) throws (JWWFetchedResultsControllerError) -> T {
        guard let models = fetchedModels, indexPath.section == 0, indexPath.item <= models.endIndex else {
            throw JWWFetchedResultsControllerError.indexPathOutOfBounds
        }

        return models[indexPath.item]
    }

    public func indexPath(forObject object: T) -> IndexPath? {
        guard let models = fetchedModels, let item = models.firstIndex(of: object) else {
            return nil
        }

        return IndexPath(item: item, section: 0)
    }

    // MARK: Private / Convenience
    // ====================================
    // Private / Convenience
    // ====================================

    private func subscribeToModelChanges(notificationCenter: NotificationCenter) async {
        for await userInfo in notificationCenter.notifications(named: ModelContext.didSave)
            .compactMap(\.userInfo)
            .map({ userInfo in
                let categories = [JWWFetchedResultsChangeType.inserted, JWWFetchedResultsChangeType.deleted, JWWFetchedResultsChangeType.updated]
                let result: [JWWFetchedResultsChangeType: [PersistentIdentifier]] = [:]
                return categories.reduce(into: result) { result, category in
                    // Only insert the category into the result if it has values.
                    if let ids = userInfo[category.rawValue] as? [PersistentIdentifier], !ids.isEmpty {
                        result[category] = ids
                    }
                }
            })
            .filter({ !$0.isEmpty }) { // Skip any empty dictionaries since there's nothing worth doing.
            Logger.package.debug("Reloading widget timelines because of \(userInfo)")
            await processHistory()
        }
    }

    private func processHistory() async {
        var historyDescriptor = HistoryDescriptor<DefaultHistoryTransaction>()

        if let token = mostRecentHistoryToken {
            historyDescriptor.predicate = #Predicate { transaction in
                (transaction.token > token)
            }
        }

        let context = ModelContext(modelContainer)
        var results: Set<T> = []
        var transactions: [DefaultHistoryTransaction] = []
        do {
            transactions = try modelContext.fetchHistory(historyDescriptor)

            if !transactions.isEmpty {
                Logger.package.info("Processing \(transactions.count) history transactions.")
            }

            for transaction in transactions {
                for change in transaction.changes {
                    let modelID = change.changedPersistentIdentifier
                    let fetchDescriptor = FetchDescriptor<T>(predicate: #Predicate { thing in
                        thing.persistentModelID == modelID
                    })
                    let fetchResults = try? context.fetch(fetchDescriptor)
                    guard let matchedThing = fetchResults?.first else {
                        continue
                    }

                    switch change {
                    case .insert(_ as DefaultHistoryInsert<T>):
                        results.insert(matchedThing)
                    case .update(_ as DefaultHistoryUpdate<T>):
                        results.update(with: matchedThing)
                    case .delete(_ as DefaultHistoryDelete<T>):
                        results.remove(matchedThing)
                    default: break
                    }
                }

            }

            Logger.package.debug("Processed results are: \(String(describing: results))")

            // Update the history token using the last transaction. The last transaction has the latest token.
           if let newLastPersistentHistoryToken = transactions.last?.token {
               Logger.package.debug("History returned new token: \(String(describing: newLastPersistentHistoryToken), privacy: .public)")

               mostRecentHistoryToken = newLastPersistentHistoryToken
           }
        } catch {
            Logger.package.error("Error while fetching history \(error, privacy: .public)")
        }
    }

    // Track the last history token processed for a store, and write its value to file.
    // The historyQueue reads the token when executing operations, and updates it after processing is complete.
    private var mostRecentHistoryToken: DefaultHistoryToken? {
        get {
            guard let data = try? Data(contentsOf: historyTokenURL) else {
                return nil
            }

            return try? JSONDecoder().decode(DefaultHistoryToken.self, from: data)
        }

        set {
            guard let token = newValue, let data = try? JSONEncoder().encode(token) else {
                return
            }

            do {
                try data.write(to: historyTokenURL)
            } catch {
                let message = "Could not write token data"
                Logger.package.error("\(message): \(error, privacy: .public)")
            }
        }
    }

    private lazy var historyTokenURL: URL = {
        guard let configuration = modelContainer.configurations.first(where: { $0.schema == modelContainer.schema })
        else {
            fatalError("Could not find configuration for the persistent store")
        }

        let url = configuration.url
        if !FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
            } catch {
                let message = "Could not create persistent container URL"
                Logger.package.error("\(message): \(error, privacy: .public)")
            }
        }

        let tokenName = "\(configuration.name).json"
        return url.deletingLastPathComponent().appendingPathComponent(tokenName, isDirectory: false)
    }()
}
