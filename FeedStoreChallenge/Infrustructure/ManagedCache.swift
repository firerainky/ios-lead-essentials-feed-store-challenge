//
//  ManagedCache.swift
//  FeedStoreChallenge
//
//  Created by Zheng Kanyan on 2021/6/11.
//  Copyright © 2021 Essential Developer. All rights reserved.
//

import CoreData

@objc(ManagedCache)
internal class ManagedCache: NSManagedObject {
	@NSManaged var timestamp: Date

	@NSManaged var feed: NSOrderedSet
}

extension ManagedCache {
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
