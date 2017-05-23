#
# ghe_branch.psm1 : GheBranches Exported Functions
# 

Function Get-GheBranches
{
<#
	.SYNOPSIS 
		Get GitHub's branches for requested repository

	.DESCRIPTION
		Get the list of all branches for the requested repository.
		The Function returns a GheBranchCollection with a "Value" property containing the array
		list of branches.
		Each GheBranch object contained in the collection have following properties :
			[String] Owner (aka Organization)
			[String] Repository
			[String] Name (Branch name)
			[Boolean] Protected
			[System.DateTime] CommitterDate
			[String] CommitterLogin
			[String] CommitterEmail
			[String] Sha

	.PARAMETER ServerUri
		Full GitHub Enterprise Server URI, including protocol (http or https)

	.PARAMETER AdminToken
		GitHub Enterprise Administrator token

	.PARAMETER SshKeyPath
		SSH RSA private key path used to connect to GitHub Enterprise server with SSH

	.PARAMETER SshHostPort
		SSH port used to connect to GitHub Enterprise server (default is 122)

	.PARAMETER GheClient
		GheClient object previously created with Get-GheClient (pipeline value)
	
	.PARAMETER Organization
		Name of the Owner or the Organization owning the repository (url syntax).

	.PARAMETER Repository
		Repository name (url syntax)
	
	.PARAMETER CsvExportFile
		Full file path of the comma separated file used to export the GitHub's branch list.

	.OUTPUTS
		[GheBranchCollection]

	.EXAMPLE
		$Params = @{
			ServerUri =  "http://github.mycompany.com/"
			AdminToken = "636e3227468e4e09f397e3ecb26860eed9fbeaff"
			SshKeyPath = join-path $env:HOMEPATH ".ssh/github.mycompany.com_rsa"
			Organization = "MyOrganization"
			Repository = "MyRepository"
		}
		$ghe_branches = Get-GheBranches @Params
		$ghe_branches.Values | Out-GridView

	.EXAMPLE
		$Params = @{
			ServerUri =  "http://github.mycompany.com/"
			AdminToken = "636e3227468e4e09f397e3ecb26860eed9fbeaff"
			SshKeyPath = join-path $env:HOMEPATH ".ssh/github.mycompany.com_rsa"
		}
		$ghe_client = Get-GheClient @Params
		$ghe_branches = $ghe_client | Get-GheBranches -Organization "MyOrganization" -Repository "MyRepository"


	.NOTES
		Before using this script, create a SSH key and upload it onto GitHub instance.
		https://help.github.com/articles/creating-a-personal-access-token-for-the-command-line/
		https://help.github.com/enterprise/admin/guides/installation/administrative-shell-ssh-access/

	.LINK
		Get-GheClient
#>
    [CmdletBinding()]
	Param(
		[Parameter(Mandatory=$true, ParameterSetName = "Connect")]
		[ValidateNotNullOrEmpty()]
		[String] $ServerUri,

		[Parameter(Mandatory=$true, ParameterSetName = "Connect")]
		[ValidateNotNullOrEmpty()]
		[String] $AdminToken,

		[Parameter(Mandatory=$true, ParameterSetName = "Connect")]
		[ValidateNotNullOrEmpty()]
		[String] $SshKeyPath,
		
		[Parameter(Mandatory=$false, ParameterSetName = "Connect")]
		[UInt16] $SshHostPort = 122,

		[Parameter(Mandatory=$true, ParameterSetName = "Session", ValueFromPipeline=$true)]
		[ValidateNotNullOrEmpty()]
		[GheClient] $GheClient,

		[Parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		[String] $Organization,

		[Parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		[String] $Repository,

		[Parameter(Mandatory=$false)]
		[ValidateNotNullOrEmpty()]
		[String] $CsvExportFile
	)
	Begin
	{
		Write-Debug "PsBoundParameters:"
		$PSBoundParameters.GetEnumerator() | % { Write-Debug $_ }
    
		if($PSBoundParameters['Debug']) { $DebugPreference = 'Continue' }
		Write-Debug "DebugPreference: $DebugPreference"

		Write-Verbose "$($MyInvocation.MyCommand.Name):: Function started"
	}
	Process 
	{
		if ($PSCmdlet.ParameterSetName -eq "Connect")
			{ $GheClient = [GheClient]::new($ServerUri, $AdminToken, $SshHostPort, $SshKeyPath)	}

		$GheBranches = [GheBranchCollection]::new($GheClient, $Organization, $Repository)
		if($CsvExportFile)
			{ $GheBranches.ExportToCsv($CsvExportFile) }

		return $GheBranches
	}
	End
	{
		Write-Verbose "$($MyInvocation.MyCommand.Name):: Function ended"
	}
}

Function Sync-GheBranches
{
<#
	.SYNOPSIS 
		Sync GitHub's branches for requested repository

	.DESCRIPTION
		Send an email to each GitHub's user who own bad named or expired branches to request action
		like renaming or deletion.
		This function does not delete any existing branch, it just send a mail to the last branch's
		commiter.

	.PARAMETER ServerUri
		Full GitHub Enterprise Server URI, including protocol (http or https)

	.PARAMETER AdminToken
		GitHub Enterprise Administrator token

	.PARAMETER SshKeyPath
		SSH RSA private key path used to connect to GitHub Enterprise server with SSH

	.PARAMETER SshHostPort
		SSH port used to connect to GitHub Enterprise server (default is 122)

	.PARAMETER GheClient
		GheClient object previously created with Get-GheClient (pipeline value)
	
	.PARAMETER Organization
		Name of the Owner or the Organization owning the repository (url syntax).

	.PARAMETER Repository
		Repository name (url syntax)
	
	.PARAMETER ExpirationDays
		Age in days where the branch is assumed to be expired (30 days by default)

	.PARAMETER BranchNameMap
		Array of tuples used for branch name check and target branch merging resolution.
		Each tuples in the array should have a string regex used on the developper branch's name and
		an output format string to deduce the target branch's name.

	.PARAMETER CsvExportFile
		Full file path of the comma separated file used to export the GitHub's branch list.

	.OUTPUTS
		[System.Collections.ArrayList]
		Array list containing all send email commands executed.
    
	.EXAMPLE
		$Params = @{
			ServerUri =  "http://github.mycompany.com/"
			AdminToken = "636e3227468e4e09f397e3ecb26860eed9fbeaff"
			SshKeyPath = join-path $env:HOMEPATH ".ssh/github.mycompany.com_rsa"
			Organization = "MyOrganization"
			Repository = "MyRepository"
			ExpirationDays = 60
		}
		$ghe_cmds = Sync-GheBranches @Params
		$ghe_cmds | Out-GridView

	.EXAMPLE
		$Params = @{
			ServerUri =  "http://github.mycompany.com/"
			AdminToken = "636e3227468e4e09f397e3ecb26860eed9fbeaff"
			SshKeyPath = join-path $env:HOMEPATH ".ssh/github.mycompany.com_rsa"
			Organization = "MyOrganization"
			Repository = "MyRepository"
		}
		$ghe_branches = Get-GheBranches @Params
		$ghe_cmds = $ghe_branches | Sync-GheBranches -ExpirationDays 60
		$ghe_cmds | Out-GridView

	.EXAMPLE
		# This sample describe the BranchNameMap usage
		# All branches named with feature/<nb> or bugfix/<nb> must be merged in a release/<nb> branch
		# where <nb> is the release number.
		# All branches named integration must be merged into the master branch
		$Params = @{
			ServerUri =  "http://github.mycompany.com/"
			AdminToken = "636e3227468e4e09f397e3ecb26860eed9fbeaff"
			SshKeyPath = join-path $env:HOMEPATH ".ssh/github.mycompany.com_rsa"
			Organization = "MyOrganization"
			Repository = "MyRepository"
			ExpirationDays = 60
			BranchNameMap = @(
				@([RegEx]::new("^(feature|bugfix)\/(\d*)\/.*$"), "release/{2}"),
				@([RegEx]::new("^integration\/.*$"), "master")
			)
		}
		$ghe_cmds = Sync-GheBranches @Params
		$ghe_cmds | Out-GridView

	.NOTES
		Email settings must be correctly configured on your Github appliance. (Check management
		console).
		Before using this script, create a SSH key and upload it onto GitHub instance.
		https://help.github.com/articles/creating-a-personal-access-token-for-the-command-line/
		https://help.github.com/enterprise/admin/guides/installation/administrative-shell-ssh-access/

	.LINK
		Get-GheClient
		Get-GheBranches
#>

    [CmdletBinding()]
	Param(
		[Parameter(Mandatory=$true, ParameterSetName = "Connect")]
		[ValidateNotNullOrEmpty()]
		[String] $ServerUri,

		[Parameter(Mandatory=$true, ParameterSetName = "Connect")]
		[ValidateNotNullOrEmpty()]
		[String] $AdminToken,

		[Parameter(Mandatory=$true, ParameterSetName = "Connect")]
		[ValidateNotNullOrEmpty()]
		[String] $SshKeyPath,
		
		[Parameter(Mandatory=$false, ParameterSetName = "Connect")]
		[UInt16] $SshHostPort = 122,

		[Parameter(Mandatory=$true, ParameterSetName = "Session", ValueFromPipeline=$true)]
		[ValidateNotNullOrEmpty()]
		[GheClient] $GheClient,

		[Parameter(Mandatory=$true, ParameterSetName = "Connect")]
		[Parameter(Mandatory=$true, ParameterSetName = "Session")]
		[ValidateNotNullOrEmpty()]
		[String] $Organization,

		[Parameter(Mandatory=$true, ParameterSetName = "Connect")]
		[Parameter(Mandatory=$true, ParameterSetName = "Session")]
		[ValidateNotNullOrEmpty()]
		[String] $Repository,

		[Parameter(Mandatory=$true, ParameterSetName = "Branches", ValueFromPipeline=$true)]
		[ValidateNotNullOrEmpty()]
		[GheBranchCollection] $GheBranchColl,

		[Parameter(Mandatory=$false)]
		[UInt16] $ExpirationDays = 30,

		[Parameter(Mandatory=$false)]
		[System.Object[]] $BranchNameMap = $null,

		[Parameter(Mandatory=$false)]
		[ValidateNotNullOrEmpty()]
		[String] $CsvExportFile
	)
	Begin
	{
		Write-Debug "PsBoundParameters:"
		$PSBoundParameters.GetEnumerator() | % { Write-Debug $_ }
    
		if($PSBoundParameters['Debug']) { $DebugPreference = 'Continue' }
		Write-Debug "DebugPreference: $DebugPreference"

		Write-Verbose "$($MyInvocation.MyCommand.Name):: Function started"
	}
	Process
	{
		if ($PSCmdlet.ParameterSetName -eq "Branches")
			{ $GheClient = $GheBranchColl._Client }
		else
		{
			if ($PSCmdlet.ParameterSetName -eq "Connect")
				{ $GheClient = [GheClient]::new($ServerUri, $AdminToken, $SshHostPort, $SshKeyPath)	}

			$GheBranchColl = [GheBranchCollection]::new($GheClient, $Organization, $Repository)
		}

		# Compare Github branch against given expiration date
		$ExpirationDate = [System.DateTimeOffset]::Now.AddDays(-$ExpirationDays).DateTime
		$GheBranchComp = [GheBranchCompare]::new($GheBranchColl, $ExpirationDate, $BranchNameMap)
		if($CsvExportFile)
			{ $GheBranchComp.ExportToCsv($CsvExportFile) }

		# Create mail base template from GitHub Enterprise configuration
		$GheConfig = [GheConfig]::Get($this._Client, "^smtp|ldap|core\..*$")
		$MailTemplate =  @{
			"From" = [System.Net.Mail.MailAddress]::new($GheConfig["smtp.noreply-address"]);
			"Sender" = [System.Net.Mail.MailAddress]::new($GheConfig["smtp.support-address"]);
			"Subject" = "[$Organization/$Repository] GitHub branch audit"
		}
		
		# Prepare email spamming ... :-)
		[GheMailMsg] $MailAdmin = $MailTemplate
		$MailAdmin.Body = @(
			"Dear Administrators,",
			"",
			"You received this email, because one or more unidentified user's branch have some issues.",
			"Please follow given explanation to correct them :",
			"{0}",
			"Thank you for your collaboration,",
			"",
			"Best Regards",
			"GitHub Administrator"
		) -join "`n"

		[GheMailMsg] $MailUsers = $MailTemplate
		$MailUsers.Body = @(
			"Dear user",
			"",
			"You received this email, because one or more branch you worked on have some issues.",
			"Please follow given explanation to correct them :",
			"{0}",
			"Thank you for your collaboration,",
			"",
			"Best Regards",
			"GitHub Administrator"
		) -join "`n"

		$MailContent = @{
			"BadName" =
				"`n[BAD BRANCH NAME]`n" +
				"The following branch list, does not follow our naming convention.`n" +
				"Please rename them or remove them :`n";
			"NotMerged" =
				"`n[EXPIRED BRANCHES NOT MERGED]`n" +
				"The content of following branch list, has not been merged in the target branch.`n" +
				"Please merge the content if needed, and remove the branch.`n";
			"Expired" =
				"`n[EXPIRED BRANCHES]`n" +
				"The content of following branches, has not been modified since 30 days.`n" + 
				"Please remove expired branches or request for a branch protection for those you want to keep.`n";
		}

		$GheMailColl = $GheBranchComp.CreateMailCollection($MailAdmin, $MailUsers, $MailContent)

		# Send messages
		$GheCmdsColl = $GheClient.SendMail($GheMailColl)

		# Dump results
		if($PSCmdlet.MyInvocation.BoundParameters["Verbose"])
		{
			$output_txt = "Sent messages Dump"
			Write-Verbose ("#" * 100)
			Write-Verbose $output_txt.PadLeft((100 + $output_txt.Length) / 2, " ")
			Write-Verbose ("#" * 100)
			$GheCmdsColl | ForEach-Object { $_.Query, $_.Response , ("-" * 100)} | Out-String

			$output_txt = "Results For $Organization/$Repository"
			Write-Verbose ("#" * 100)
			Write-Verbose $output_txt.PadLeft((100 + $output_txt.Length) / 2, " ")
			Write-Verbose ("#" * 100)
			$brch_count = 0
			ForEach($grp in $GheBranchComp.Values | Group DiffStatus)
			{
				Write-Verbose ("[STATUS] {0:N0} {1}" -f $grp.Count, $grp.Name)
				$brch_count += $grp.Count
			}
			Write-Verbose ("[STATUS] {0:N0} Total" -f $brch_count)
			Write-Verbose ("[STATUS] {0:N0} Evaluated branches" -f $GheBranchColl.Values.Count)
		}
	}
	End
	{
		Write-Verbose "$($MyInvocation.MyCommand.Name):: Function ended"
	}
}

