//
//  Copyright © 2021 Essential Developer. All rights reserved.
//

import CoreData

public final class CoreDataFeedStore: FeedStore {
	private static let modelName = "FeedStore"
	private static let model = NSManagedObjectModel(name: modelName, in: Bundle(for: CoreDataFeedStore.self))

	private let container: NSPersistentContainer
	private let context: NSManagedObjectContext

	struct ModelNotFound: Error {
		let modelName: String
	}

	public init(storeURL: URL) throws {
		guard let model = CoreDataFeedStore.model else {
			throw ModelNotFound(modelName: CoreDataFeedStore.modelName)
		}

		container = try NSPersistentContainer.load(
			name: CoreDataFeedStore.modelName,
			model: model,
			url: storeURL
		)
		context = container.newBackgroundContext()
	}

	public func retrieve(completion: @escaping RetrievalCompletion) {
		perform { context in
			do {
				if let cache = try ManagedCache.find(in: context) {
					completion(.found(feed: cache.localFeed, timestamp: cache.timestamp))
				} else {
					completion(.empty)
				}
			} catch {
				completion(.failure(error))
			}
		}
	}

	public func insert(_ feed: [LocalFeedImage], timestamp: Date, completion: @escaping InsertionCompletion) {
		perform { context in
			do {
				let cache = try ManagedCache.newUniqueItem(in: context)
				cache.timestamp = timestamp
				cache.feed = ManagedFeedImage.images(with: feed, in: context)
				try context.save()
				completion(nil)
			} catch {
				context.rollback()
				completion(error)
			}
		}
	}

	public func deleteCachedFeed(completion: @escaping DeletionCompletion) {
		perform { context in
			do {
				try ManagedCache.find(in: context).map(context.delete)
				completion(nil)
			} catch {
				completion(error)
			}
		}
	}

	private func perform(_ action: @escaping (NSManagedObjectContext) -> Void) {
		let context = self.context
		context.perform { action(context) }
	}
}

@objc(ManagedCache)
private class ManagedCache: NSManagedObject {
	@NSManaged var timestamp: Date

	@NSManaged var feed: NSOrderedSet

	static func newUniqueItem(in context: NSManagedObjectContext) throws -> ManagedCache {
		try ManagedCache.find(in: context).map(context.delete)
		return ManagedCache(context: context)
	}

	var localFeed: [LocalFeedImage] {
		feed.compactMap { ($0 as? ManagedFeedImage)?.local }
	}

	static func find(in context: NSManagedObjectContext) throws -> Self? {
		let request = NSFetchRequest<Self>(entityName: Self.entity().name!)
		request.returnsObjectsAsFaults = false
		return try context.fetch(request).first
	}
}

@objc(ManagedFeedImage)
private class ManagedFeedImage: NSManagedObject {
	@NSManaged var id: UUID
	@NSManaged var imageDescription: String?
	@NSManaged var location: String?
	@NSManaged var url: URL

	@NSManaged var cache: ManagedCache

	var local: LocalFeedImage {
		LocalFeedImage(id: id, description: imageDescription, location: location, url: url)
	}

	static func images(with feed: [LocalFeedImage], in context: NSManagedObjectContext) -> NSOrderedSet {
		NSOrderedSet(array: feed.map { local in
			let managed = ManagedFeedImage(context: context)
			managed.id = local.id
			managed.imageDescription = local.description
			managed.location = local.location
			managed.url = local.url
			return managed
		})
	}
}
