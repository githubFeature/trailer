
import CoreData

final class GroupingCriterion {

	let apiServerId: NSManagedObjectID?
	let repoGroup: String?

	init(apiServerId: NSManagedObjectID?) {
		self.apiServerId = apiServerId
		self.repoGroup = nil
	}

	init(repoGroup: String) {
		self.apiServerId = nil
		self.repoGroup = repoGroup
	}

	var label: String {
		if let r = repoGroup {
			return r
		} else if let aid = apiServerId, let a = existingObject(with: aid) as? ApiServer {
			return a.label ?? "<none>"
		} else {
			return "<none>"
		}
	}

	var relatedServerFailed: Bool {
		if let aid = apiServerId, let a = existingObject(with: aid) as? ApiServer, !a.lastSyncSucceeded {
			return true
		}
		if let group = repoGroup {
			for repo in Repo.repos(for: group, in: DataManager.main) {
				if !repo.apiServer.lastSyncSucceeded {
					return true
				}
			}
		}
		return false
	}

	func isRelated(to i: ListableItem) -> Bool {
		if let aid = apiServerId {
			if i.apiServer.objectID != aid {
				return false
			}
		} else if let r = repoGroup {
			if let l = i.repo.groupLabel {
				return r == l
			} else {
				return false
			}
		}
		return true
	}

	func addCriterion(to predicate: NSPredicate, in moc: NSManagedObjectContext) -> NSPredicate {

		if let a = apiServerId, let server = try! moc.existingObject(with: a) as? ApiServer {
			let np = NSPredicate(format: "apiServer == %@", server)
			return NSCompoundPredicate(andPredicateWithSubpredicates: [np, predicate])
		} else if let r = repoGroup {
			let np = NSPredicate(format: "repo.groupLabel == %@", r)
			return NSCompoundPredicate(andPredicateWithSubpredicates: [np, predicate])
		} else {
			return predicate
		}
	}
}
