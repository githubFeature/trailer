//
//  API.m
//  Trailer
//
//  Created by Paul Tsochantaris on 20/09/2013.
//  Copyright (c) 2013 HouseTrip. All rights reserved.
//

@interface API ()
{
	AFHTTPClient *client;
	NSDateFormatter *dateFormatter;
}
@end

@implementation API

- (id)init
{
    self = [super init];
    if (self) {
		dateFormatter = [[NSDateFormatter alloc] initWithDateFormat:@"YYYY-MM-DDTHH:MM:SSZ" allowNaturalLanguage:NO];

		[[AFHTTPRequestOperationLogger sharedLogger] startLogging];

		client = [AFHTTPClient clientWithBaseURL:[NSURL URLWithString:@"https://api.github.com"]];
		[client setDefaultHeader:@"User-Agent" value:@"Trailer"];
		[client setDefaultHeader:@"Content-Type" value:@"application/x-www-form-urlencoded"];
		[client setDefaultHeader:@"Authorization" value:[@"token " stringByAppendingString:self.authToken]];
    }
    return self;
}

-(NSString*)authToken
{
	return [[NSUserDefaults standardUserDefaults] stringForKey:GITHUB_TOKEN_KEY];
}

-(void)error:(NSString*)errorString
{
	NSLog(@"Failed to fetch %@",errorString);
}

-(void)fetchCommentsForCurrentPullRequestsAndCallback:(void (^)(BOOL))callback
{
	NSManagedObjectContext *moc = [AppDelegate shared].managedObjectContext;
	NSMutableArray *prs1 = [[DataItem newOrUpdatedItemsOfType:@"PullRequest" inMoc:moc] mutableCopy];
	[self _fetchCommentsForPullRequests:prs1 forIssues:YES andCallback:^(BOOL success) {
		if(success)
		{
			NSMutableArray *prs2 = [[DataItem newOrUpdatedItemsOfType:@"PullRequest" inMoc:moc] mutableCopy];
			[self _fetchCommentsForPullRequests:prs2 forIssues:NO andCallback:^(BOOL success) {
				if(callback) callback(success);
			}];
		}
		else
		{
			if(callback) callback(NO);
		}
	}];
}

-(void)_fetchCommentsForPullRequests:(NSMutableArray *)prs forIssues:(BOOL)issues andCallback:(void(^)(BOOL success))callback
{
	if(!prs.count)
	{
		if(callback) callback(YES);
		return;
	}
	PullRequest *p = [prs objectAtIndex:0];
	[prs removeObjectAtIndex:0];
	NSString *link;
	if(issues)
	{
		link = p.issueCommentLink;
	}
	else
	{
		link = p.reviewCommentLink;
	}
	[self getPagedDataInPath:link
					  params:nil
			 perPageCallback:^(id data, BOOL lastPage) {
				 NSArray *pageOfComments = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
				 for(NSDictionary *info in pageOfComments)
				 {
					 [PRComment commentWithInfo:info moc:[AppDelegate shared].managedObjectContext];
				 }
			 } finalCallback:^(BOOL success) {
				 if(success)
				 {
					 [self _fetchCommentsForPullRequests:prs forIssues:issues andCallback:callback];
				 }
				 else
				 {
					 if(callback) callback(NO);
				 }
			 }];
}

-(void)fetchRepositoriesAndCallback:(void(^)(BOOL success))callback
{
	[self syncOrgsAndCallback:^(BOOL success) {
		if(!success)
		{
			[self error:@"orgs"];
			callback(NO);
		}
		else
		{
			NSArray *orgs = [Org allItemsOfType:@"Org" inMoc:[AppDelegate shared].managedObjectContext];
			__block NSInteger count=orgs.count;
			__block BOOL ok = YES;
			for(Org *r in orgs)
			{
				[self syncReposForOrg:r.login andCallback:^(BOOL success) {
					count--;
					if(ok) ok = success;
					if(count==0)
					{
						[self syncReposForUserAndCallback:^(BOOL success) {
							if(ok) ok = success;
							if(callback)
							{
								callback(ok);
							}
						}];
					}
				}];
			}
		}
	}];
}

-(void)fetchPullRequestsForActiveReposAndCallback:(void(^)(BOOL success))callback
{
	NSManagedObjectContext *moc = [AppDelegate shared].managedObjectContext;
	[DataItem unTouchItemsOfType:@"PullRequest" inMoc:moc];
	NSMutableArray *activeRepos = [[Repo activeReposInMoc:moc] mutableCopy];
	[self _fetchPullRequestsForRepos:activeRepos andCallback:^(BOOL success) {
		if(success)
		{
			[self fetchCommentsForCurrentPullRequestsAndCallback:^(BOOL success) {
				[DataItem nukeUntouchedItemsOfType:@"PullRequest" inMoc:moc];
				if(callback) callback(success);
			}];
		}
		else if(callback) callback(NO);
	}];
}

-(void)_fetchPullRequestsForRepos:(NSMutableArray *)repos andCallback:(void(^)(BOOL success))callback
{
	if(!repos.count)
	{
		if(callback) callback(YES);
		return;
	}
	Repo *r = [repos objectAtIndex:0];
	[repos removeObjectAtIndex:0];
	[self getPagedDataInPath:[NSString stringWithFormat:@"/repos/%@/pulls",r.fullName]
					  params:nil
			 perPageCallback:^(id data, BOOL lastPage) {
				 NSArray *pageOfPRs = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
				 for(NSDictionary *info in pageOfPRs)
				 {
					 [PullRequest pullRequestWithInfo:info moc:[AppDelegate shared].managedObjectContext];
				 }
			 } finalCallback:^(BOOL success) {
				 if(success)
				 {
					 [self _fetchPullRequestsForRepos:repos andCallback:callback];
				 }
				 else
				 {
					 if(callback) callback(NO);
				 }
			 }];
}

-(void)syncReposForUserAndCallback:(void(^)(BOOL success))callback
{
	[self getPagedDataInPath:@"/user/repos"
					  params:nil
			 perPageCallback:^(id data, BOOL lastPage) {
				 NSArray *pageOfRepos = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
				 for(NSDictionary *info in pageOfRepos)
				 {
					 [Repo repoWithInfo:info moc:[AppDelegate shared].managedObjectContext];
				 }
			 } finalCallback:^(BOOL success) {
				 if(callback) callback(success);
			 }];
}

-(void)syncReposForOrg:(NSString*)orgLogin andCallback:(void(^)(BOOL success))callback
{
	[self getPagedDataInPath:[NSString stringWithFormat:@"/orgs/%@/repos",orgLogin]
					  params:nil
			 perPageCallback:^(id data, BOOL lastPage) {
				 NSArray *pageOfRepos = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
				 for(NSDictionary *info in pageOfRepos)
				 {
					 [Repo repoWithInfo:info moc:[AppDelegate shared].managedObjectContext];
				 }
			 } finalCallback:^(BOOL success) {
				 if(callback) callback(success);
			 }];
}

-(void)syncOrgsAndCallback:(void(^)(BOOL success))callback
{
	[self getPagedDataInPath:@"/user/orgs"
					  params:nil
			 perPageCallback:^(id data, BOOL lastPage) {
				 NSArray *pageOfOrgs = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
				 for(NSDictionary *info in pageOfOrgs) [Org orgWithInfo:info moc:[AppDelegate shared].managedObjectContext];
			 } finalCallback:^(BOOL success) {
				 if(callback) callback(success);
			 }];
}

-(void)getPagedDataInPath:(NSString*)path
				   params:(NSDictionary*)params
		  perPageCallback:(void(^)(id data, BOOL lastPage))pageCallback
			finalCallback:(void(^)(BOOL success))finalCallback
{
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		__block NSInteger page = 1;
		__block BOOL keepGoing = YES;
		__block BOOL ok = YES;
		dispatch_semaphore_t s = dispatch_semaphore_create(0);
		NSMutableDictionary *mparams = [params mutableCopy];
		if(!mparams) mparams = [NSMutableDictionary dictionaryWithCapacity:2];
		while(keepGoing)
		{
			mparams[@"page"] = @(page);
			mparams[@"per_page"] = @100;
			[self getDataInPath:path
						 params:mparams
					andCallback:^(id data, BOOL lastPage) {
						if(data)
						{
							if(pageCallback)
							{
								pageCallback(data,lastPage);
							}
							keepGoing = !lastPage;
							page++;
						}
						else
						{
							ok = NO;
							keepGoing = NO;
						}
						dispatch_semaphore_signal(s);
					}];
			dispatch_semaphore_wait(s, DISPATCH_TIME_FOREVER);
		}
		if(finalCallback)
		{
			dispatch_sync(dispatch_get_main_queue(), ^{
				finalCallback(ok);
			});
		}
	});
}

-(void)getDataInPath:(NSString*)path params:(NSDictionary*)params andCallback:(void(^)(id data, BOOL lastPage))callback
{
	NSMutableURLRequest *request = [client requestWithMethod:@"GET" path:path parameters:params];
	AFHTTPRequestOperation *o = [client HTTPRequestOperationWithRequest:request
																success:^(AFHTTPRequestOperation *operation, id responseObject) {
																	NSDictionary *data = [NSJSONSerialization JSONObjectWithData:responseObject options:0 error:nil];
																	NSString *requestsRemaining = [operation.response allHeaderFields][@"X-RateLimit-Remaining"];
																	NSLog(@"Success %@",data);
																	NSLog(@"Remaining requests: %@",requestsRemaining);
																	if(callback) callback(responseObject, [API lastPage:operation.response]);
																} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
																	NSLog(@"Failed: %@",error);
																	if(callback) callback(nil,NO);
																}];
	[client.operationQueue addOperation:o];
}

+(BOOL)lastPage:(NSHTTPURLResponse*)response
{
	NSString *linkHeader = [[response allHeaderFields] objectForKey:@"Link"];
	if(!linkHeader) return YES;
	return ([linkHeader rangeOfString:@"rel=\"next\""].location==NSNotFound);
}

@end