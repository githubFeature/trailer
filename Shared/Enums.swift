
enum Section: Int {
	case None, Mine, Participated, Merged, Closed, All
	static let prMenuTitles = ["", "Mine", "Participated", "Recently Merged", "Recently Closed", "All Pull Requests"]
	static let issueMenuTitles = ["", "Mine", "Participated", "Recently Merged", "Recently Closed", "All Issues"]
	static let watchMenuTitles = ["", "Mine", "Participated", "Merged", "Closed", "Other"]
	static let apiTitles = ["", "mine", "participated", "merged", "closed", "other"]
	func prMenuName() -> String {
		return Section.prMenuTitles[rawValue]
	}
	func issuesMenuName() -> String {
		return Section.issueMenuTitles[rawValue]
	}
	func watchMenuName() -> String {
		return Section.watchMenuTitles[rawValue]
	}
	func apiName() -> String {
		return Section.apiTitles[rawValue]
	}
}

func never() -> NSDate {
	return NSDate.distantPast()
}

typealias Completion = ()->Void

func atNextEvent(completion: Completion) {
	NSOperationQueue.mainQueue().addOperationWithBlock(completion)
}

func delay(delay:NSTimeInterval, closure: Completion) {
	let time = dispatch_time(DISPATCH_TIME_NOW, Int64(delay * Double(NSEC_PER_SEC)))
	dispatch_after(time, dispatch_get_main_queue()) {
		atNextEvent(closure)
	}
}
