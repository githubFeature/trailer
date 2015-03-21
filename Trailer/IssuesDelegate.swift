
class IssuesDelegate: NSObject, NSTableViewDelegate, NSTableViewDataSource {

	private var issueIds: [NSObject]

	override init() {
		issueIds = [NSObject]()
		super.init()
		reloadData(nil)
	}

	func reloadData(filter: String?) {

		issueIds.removeAll(keepCapacity: false)

		let f = Issue.requestForIssuesWithFilter(filter)
		let allIssues = mainObjectContext.executeFetchRequest(f, error: nil) as [Issue]

		if let firstIssue = allIssues.first {
			var lastSection = firstIssue.sectionIndex!.integerValue
			issueIds.append(PullRequestSection.allTitles[lastSection])

			for issue in allIssues {
				let i = issue.sectionIndex!.integerValue
				if lastSection < i {
					issueIds.append(PullRequestSection.allTitles[i])
					lastSection = i
				}
				issueIds.append(issue.objectID)
			}
		}
	}

	func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
		let object = issueIds[row]
		if object.isKindOfClass(NSManagedObjectID) {
			return nil
		} else {
			let title = object as String
			let showButton = (title == PullRequestSection.Merged.name() || title == PullRequestSection.Closed.name())
			return SectionHeader(title: title, showRemoveAllButton: showButton)
		}
	}

	func tableView(tv: NSTableView, heightOfRow row: Int) -> CGFloat {
		let prView = tableView(tv, viewForTableColumn: nil, row: row)
		return prView!.frame.size.height
	}

	func numberOfRowsInTableView(tableView: NSTableView) -> Int {
		return issueIds.count
	}

	func issueAtRow(row: Int) -> Issue? {
		let object = issueIds[row]
		if object.isKindOfClass(NSManagedObjectID) {
			return mainObjectContext.existingObjectWithID(object as NSManagedObjectID, error: nil) as? Issue
		} else {
			return nil
		}
	}
}