x Get all directories with pom and common version
Go into each directory iteratively
Function that can be called with a directory name so we can retry failures ---

	Stash changes
	Checkout develop
	Pull
	Checkout updatingCommon branch
	Update version in pom
	MCI
	If fail
		checkout develop
		delete updatingCommonBranch
		Add to list of failed
	If succeed
		add to list of succeeded

Print list of failures
Print list of succeded
For each success
	Do you want to create PR?
	Yes?
		Push branch
		See if we can get current PR template?
		Create PR into develop
		Open PR URL
		Add PR URL to file
	No?
		Go onto next success

Print URLs
		
Features - maybe check in proton directory


	

	
		

