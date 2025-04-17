import Foundation
import SwiftData
import CoreData
import JWWCore
import os

private extension Logger {
    /// Logger for logging related to SwiftData and CoreData.
    static let package = Logger(subsystem: .default, category: .init(rawValue: "package"))
}

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
public protocol JWWFetchedResultsControllerDelegate: AnyObject {
    func controllerWillChangeContent(_ controller: JWWFetchedResultsController<some PersistentModel>)
    func controllerDidChangeContent(_ controller: JWWFetchedResultsController<some PersistentModel>)
}

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
@Observable
@MainActor
public final class JWWFetchedResultsController<T: PersistentModel> {
    public unowned(unsafe) var delegate: (any JWWFetchedResultsControllerDelegate)?
    public private(set) var fetchedModels: [T]?

    private let container: ModelContainer
    private let modelContext: ModelContext
    private let fetchDescriptor: FetchDescriptor<T>
    private let databaseMonitor: JWWDatabaseMonitor
    internal let notificationCenter: NotificationCenter = .default

    /// The task that is used to monitor the database for changes.
    private var notificationsTask: Task<Void, Never>?

    // MARK: Initialization
    // ====================================
    // Initialization
    // ====================================

    public init(fetchRequest: FetchDescriptor<T>, container: ModelContainer, delegate: JWWFetchedResultsControllerDelegate? = nil) {
        self.container = container
        self.modelContext = container.mainContext
        self.fetchDescriptor = fetchRequest
        self.databaseMonitor = JWWDatabaseMonitor(modelContainer: container)
        self.delegate = delegate
    }

    deinit {
        print("DEINIT")
        //notificationsTask?.cancel()
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

        notificationsTask = Task { [databaseMonitor, notificationCenter] in
            await databaseMonitor.subscribeToModelChanges(notificationCenter: notificationCenter)
        }
    }
}

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, *)
@ModelActor
private actor JWWDatabaseMonitor {
    private let persistentHistoryTokenName: String = "asdf"

    func subscribeToModelChanges(notificationCenter: NotificationCenter) async {
        for await userInfo in notificationCenter.notifications(named: ModelContext.didSave)
            .compactMap(\.userInfo)
            .map({ userInfo in
                let categories = ["inserted", "deleted", "updated"]
                let result: [String: [PersistentIdentifier]] = [:]
                return categories.reduce(into: result) { result, category in
                    // Only insert the category into the result if it has values.
                    if let ids = userInfo[category] as? [PersistentIdentifier], !ids.isEmpty {
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
        guard let token = mostRecentHistoryToken else {
            return
        }
        var historyDescriptor = HistoryDescriptor<DefaultHistoryTransaction>()
        historyDescriptor.predicate = #Predicate { transaction in
            (transaction.token > token)
        }

        var transactions: [DefaultHistoryTransaction] = []
        do {
            transactions = try modelContext.fetchHistory(historyDescriptor)

            if !transactions.isEmpty {
                Logger.package.info("Processing \(transactions.count) history transactions.")
            }

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
    var mostRecentHistoryToken: DefaultHistoryToken? {
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
        guard let configuration = modelContainer.configurations.first(where: { $0.schema == modelContainer.schema && $0.isStoredInMemoryOnly == false })
        else {
            fatalError()
        }

        let url = configuration.url.appendingPathComponent("Reactions", isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
            } catch {
                let message = "Could not create persistent container URL"
                Logger.package.error("\(message): \(error, privacy: .public)")
            }
        }

        return url.appendingPathComponent(persistentHistoryTokenName, isDirectory: false)
    }()
}
