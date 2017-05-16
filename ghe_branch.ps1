#
# ghe_branch.ps1 : GheBranches Implementation Classes
# 

class GheBranch 
{
	[String] $Owner
	[String] $Repository
	[String] $Name
	[Boolean] $Protected
	[System.DateTime] $CommitterDate
	[String] $CommitterLogin
	[String] $CommitterEmail
	[String] $Sha

	# Default constructor to allow construction with a hashtable
	GheBranch() {}
	
	# Copy constructors
	GheBranch([GheBranch] $Branch)
	{
		[GheBranch].GetProperties() | % {
			$name = $_.Name
			$value = $Branch.psobject.properties[$name].Value
			$this.psobject.properties[$name].Value = $value
		}
	}
}

class GheBranchCollection
{
	Hidden [GheClient] $_Client
	Hidden [GheGHubUserCollection] $_Users
	[Octokit.RepositoriesClient] $RepoClient
	[Octokit.Repository] $RepoObject
	[System.Collections.ArrayList] $Values
	
	# Default constructor
	GheBranchCollection(
		[GheClient] $GheClient,
		[String] $OrgaName,
		[String] $RepoName) : base()
	{
		$this._Client = $GheClient
		$this.RepoClient = [Octokit.RepositoriesClient]::new($GheClient.ApiConnection)
		$this.RepoObject = $this.RepoClient.Get($OrgaName, $RepoName).Result
		$this.Values = [System.Collections.ArrayList]::new()

		# Fill the collection with GitHub repository branches information
		[Octokit.RepositoryCommitsClient] $cmit_clt = $this.RepoClient.Commit
		ForEach($brch_obj in $this.RepoClient.GetAllBranches($this.RepoObject.Id).Result)
		{
			$cmit_obj = $cmit_clt.Get($this.RepoObject.Id, $brch_obj.Commit.sha).Result
			[GheBranch] $brch_ghe = @{
				"Owner" = $OrgaName;
				"Repository" = $RepoName;
				"Name" = $brch_obj.Name;
				"Protected" = $brch_obj.Protection.Enabled;
				"CommitterDate" = $cmit_obj.Commit.Committer.Date.DateTime; # Warning UTC format, should be converted
				"CommitterLogin" = $cmit_obj.Committer.Login;
				"CommitterEmail" = $cmit_obj.Commit.Committer.Email;
				"Sha" = $brch_obj.Commit.Sha;
			}
			$this.Values.Add($brch_ghe)
		}
	}

	# Copy constructor (Does not copy Values content)
	GheBranchCollection(
		[GheBranchCollection] $BranchColl) : base()
	{ 
		$this._Client = $BranchColl._Client
		$this._Users = $BranchColl._Users
		$this.RepoClient = $BranchColl.RepoClient
		$this.RepoObject = $BranchColl.RepoObject
		$this.Values = [System.Collections.ArrayList]::new()
	}

	[void] ExportToCsv([String]$ExportFilePath)
		{ $this.ExportToCsv($ExportFilePath, $null, $null) }

	[void] ExportToCsv([String]$ExportFilePath, [String[]]$SortOrder, [String[]]$SelectFields)
	{
		$Collection = $this.Values 
		if($SortOrder)
			{ $Collection = $Collection | Sort-Object $sortorder }
		if($SelectFields)
			{ $Collection = $Collection.ForEach({ $_ | Select-Object -property $SelectFields }) }

		# Export user list into csv File
		$Collection | Export-Csv -Path $ExportFilePath -Encoding UTF8 -NoTypeInformation -Force
	}
}

enum GheBranchDiffStatus
{
	# Protected branch name and expiration date are not checked
	Protected
	BadName	
	NotExpired
	NoTarget
	CompareErr
	NotMerged 
	Expired
}

class GheBranchDiff : GheBranch
{
	# Private Fields
	Hidden [System.DateTime] $_TargetDate

	# Exported Field
	[GheBranchDiffStatus] $DiffStatus
	[String] $TargetName
	[String] $TargetDate
	[String] $TargetSha
	
	GheBranchDiff(
		[GheBranch] $Branch,
		[GheBranchDiffStatus] $DiffStatus) : base($Branch)
	{
		$this.DiffStatus = $DiffStatus
	}

	GheBranchDiff(
		[GheBranch] $Branch,
		[GheBranchDiffStatus] $DiffStatus,
		[String] $TargetName) : base($Branch)
	{
		$this.DiffStatus = $DiffStatus
		$this.TargetName = $TargetName
	}

	GheBranchDiff(
		[GheBranch] $Branch,
		[GheBranchDiffStatus] $DiffStatus,
		[String] $TargetName,
		[Octokit.GitHubCommit] $TargetCommit) : base($Branch)
	{
		$this._TargetDate = $TargetCommit.Commit.Committer.Date.Date

		$this.DiffStatus = $DiffStatus
		$this.TargetName = $TargetName
		$this.TargetDate = $this._TargetDate.ToString()
		$this.TargetSha = $TargetCommit.Sha
	}
}

class GheBranchCompare : GheBranchCollection
{
	GheBranchCompare(
		[GheBranchCollection] $SourceColl,
		[System.DateTime] $ExpirationDate,
		[System.Object[]] $BranchNameMap
		) : base($SourceColl)
	{
		# Analyze the branch Collection
		[Octokit.RepositoryCommitsClient] $cmit_clt = $this.RepoClient.Commit
		ForEach($brch_obj in $SourceColl.Values)
		{
			# Check if the branch is protected
			if($brch_obj.Protected)
			{
				$this.Values.Add([GheBranchDiff]::new($brch_obj,
					[GheBranchDiffStatus]::Protected))
				continue
			}

			# Check if the branch does follow the naming convention with the
			# regex list and compute the target branch name
			$trgt_name = ""
			$brch_fnd = $null
			ForEach($regex_map in $BranchNameMap)
			{
				$regex_res = $regex_map[0].Match($brch_obj.Name)
				$brch_fnd = $regex_res.Success
				if($brch_fnd)
				{
					$trgt_name = $regex_map[1] -f ( $regex_res.Groups | % {$_.Value} )
					break
				}
			}
			if($brch_fnd -eq $false)
			{
				$this.Values.Add([GheBranchDiff]::new($brch_obj,
					[GheBranchDiffStatus]::BadName))
				continue
			}

			# Check if the branch is not expired yet
			$cmit_obj = $cmit_clt.Get($this.RepoObject.Id, $brch_obj.Sha).Result
			if($brch_obj.CommitterDate -gt $ExpirationDate)
			{
				$this.Values.Add([GheBranchDiff]::new($brch_obj,
					[GheBranchDiffStatus]::NotExpired))
				continue
			}

			# If there is no BranchNameMap, we do not have any solution to compare
			# source branch to target branch, so we are finished.
			if(!$BranchNameMap)
			{
				$this.Values.Add([GheBranchDiff]::new($brch_obj,
					[GheBranchDiffStatus]::Expired))
				continue
			}

			# Find the target branch with the branch name
			[Octokit.Branch] $trgt_obj = 
				$this.RepoClient.GetBranch($this.RepoObject.Id, $trgt_name).Result
			if(!$trgt_obj)
			{
				$this.Values.Add([GheBranchDiff]::new($brch_obj,
					[GheBranchDiffStatus]::NoTarget, $trgt_name))
				continue
			}

			# Check if the source branch has been merged into the target
			[Octokit.CompareResult]	$comp_obj =
				$cmit_clt.Compare($this.RepoObject.Id, $trgt_obj.Commit.Sha, $brch_obj.Sha).Result
			if(!$comp_obj)
			{
				$this.Values.Add([GheBranchDiff]::new($brch_obj,
					[GheBranchDiffStatus]::CompareErr, $trgt_name))
			}
			elseif($comp_obj.AheadBy -gt 0)
			{
				$this.Values.Add([GheBranchDiff]::new($brch_obj,
					[GheBranchDiffStatus]::NotMerged,
					$trgt_name, $comp_obj.BaseCommit))
			}
			else
			{
				$this.Values.Add([GheBranchDiff]::new($brch_obj,
					[GheBranchDiffStatus]::Expired,
					$trgt_name, $comp_obj.BaseCommit))
			}
		}
	}

	# $Branches are [System.Object[]] instead than GheBranchCollection by design as a
	# specific GheBranchCollection range can be used instead than the full collection.
	[GheMailMsg] CreateMailMsg(
		[System.Net.Mail.MailMessage] $MailTemplate,
		[Hashtable] $MailContent,
		[System.Object[]] $Branches)
	{
		# Create the mail content depending on required chapters
		$mail_txt = ""
		$mail_obj = $null
		ForEach($grp_brch in $Branches | Group DiffStatus)
		{
			$chap_txt = $MailContent[$grp_brch.Name]
			if($chap_txt)
			{
				$mail_txt += $chap_txt
				$mail_txt += $grp_brch.Group.ForEach(
					{ "{0}/{1}/{2}/branches/all?utf8=?&query={3}" -f $ServerUri, $_.Owner, $_.Repository, $_.Name }
				) -join "`n"
				$mail_txt += "`n"
			}
		}
		# If there is a mail content, create the mail
		if($mail_txt)
		{
			$mail_obj = [GheMailMsg]::new($MailTemplate)
			$mail_obj.Body = $mail_obj.Body -f $mail_txt
		}
		return $mail_obj
	}

	[GheMailMsgCollection] CreateMailCollection(
		[System.Net.Mail.MailMessage] $MailAdmin,
		[System.Net.Mail.MailMessage] $MailUsers,
		[Hashtable] $MailContent)
	{
		# Get the user collection if it does not already exist
		if(!$this._Users)
			{ $this._Users = [GheGHubUserCollection]::new($this._Client) }

		# Create message for all concerned and identified users
		$mail_coll = [GheMailMsgCollection]::new()
		$brch_coll = $this.Values | Sort CommitterLogin, CommitterEmail, DiffStatus, Name
		$brch_pool = [GheBranchCollection]::new($this)
		ForEach($grp_usr in ($brch_coll  | Group CommitterLogin))
		{
			# If the CommitterLogin cannot be found in the GitHub Users, or if the user is disabled
			# store branches into Administrator mail pool
			$usr_obj = $this._Users[$grp_usr.Name]
			if(($usr_obj -eq $null) -or
				($usr_obj.suspension_status -ne [GheUserStatus]::active))
			{
				$brch_pool.Values.AddRange($grp_usr.Group)
				continue
			}
			# Create the mail message with Committer branches
			$mail_obj = $this.CreateMailMsg($MailUsers, $MailContent, $grp_usr.Group)
			if($mail_obj)
			{
				$mail_obj.To.Add($usr_obj.email)
				$mail_coll.Add($mail_obj)
			}
		}

		# Create message for administrators
		$mail_obj = $this.CreateMailMsg($MailAdmin, $MailContent, $brch_pool.Values)
		if($mail_obj)
		{
			$this._Users.Values | where-object {
				($_.role -eq "admin") -and
				($_.suspension_status -eq [GheUserStatus]::active)
			} | ForEach-Object {$mail_obj.To.Add($_.email)}
			$mail_coll.Add($mail_obj)
		}
		return $mail_coll
	}

	[void] ExportToCsv([String] $ExportFilePath)
		{ ([GheBranchCollection]$this).ExportToCsv($ExportFilePath, @("DiffStatus", "Name"), $null) }
}