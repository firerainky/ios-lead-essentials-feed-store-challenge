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
					var feed = [LocalFeedImage]()
					cache.feed.forEach { img in
						let image = img as! ManagedFeedImage
						let local = LocalFeedImage(id: image.id, description: image.imageDescription, location: image.location, url: image.url)
						feed.append(local)
					}
					let result = RetrieveCachedFeedResult.found(feed: feed, timestamp: cache.timestamp)
					completion(result)
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
				if let cache = try ManagedCache.find(in: context) {
					context.delete(cache)
				}
				let managedCache = ManagedCache(context: context)
				managedCache.timestamp = timestamp
				managedCache.feed = NSOrderedSet(array: feed.map { local in
					let managed = ManagedFeedImage(context: context)
					managed.id = local.id
					managed.imageDescription = local.description
					managed.location = local.location
					managed.url = local.url
					return managed
				})
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
				if let cache = try ManagedCache.find(in: context) {
					context.delete(cache)
				}
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
}
