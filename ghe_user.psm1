#
# ghe_user.psm1 : GheClient Exported Functions
# 

Function Get-GheUsers
{
<#
	.SYNOPSIS
		Get GitHub Enterprise Server's user list

	.DESCRIPTION
		This function uses the ssh protocol to connect to the GitHub Appliance and
		extract the complete GitHub apppliance's user list with the ghe-user-csv command.
		https://help.github.com/enterprise/admin/articles/command-line-utilities/#ghe-user-csv

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

	.PARAMETER CsvExportFile
		Full file path of the comma separated file used to export the GitHub's user list.

	.OUTPUTS
		[GheUserCollection]
		GheUserCollection is a [System.Collections.Hashtable] specialization containing [GheUser]
		objects indexed by login.

	.EXAMPLE
		$Params = @{
			ServerUri =  "http://github.mycompany.com/"
			AdminToken = "636e3227468e4e09f397e3ecb26860eed9fbeaff"
			SshKeyPath = join-path $env:HOMEPATH ".ssh/github.mycompany.com_rsa"
		}
		$ghe_users = Get-GheUsers @Params

	.EXAMPLE
		$Params = @{
			ServerUri =  "http://github.mycompany.com/"
			AdminToken = "636e3227468e4e09f397e3ecb26860eed9fbeaff"
			SshKeyPath = join-path $env:HOMEPATH ".ssh/github.mycompany.com_rsa"
		}
		$ghe_client = Get-GheClient @Params
		$ghe_users = $ghe_client | Get-GheUsers

	.NOTES
		Before using this script, create a SSH key and upload it onto GitHub instance.
		https://help.github.com/articles/creating-a-personal-access-token-for-the-command-line/
		https://help.github.com/enterprise/admin/guides/installation/administrative-shell-ssh-access/

	.LINK
		Get-GheClient
		Compare-GheUsers
		Sync-GheUsers
		Get-GheLDAPUsers
		Sync-GheLDAPUsers

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

		$GheGHubUsers = [GheUserCollection]::Get($GheClient)

		if($CsvExportFile)
			{ $GheGHubUsers.ExportToCsv($CsvExportFile) }

		return $GheGHubUsers
	}
	End
	{
		Write-Verbose "$($MyInvocation.MyCommand.Name):: Function ended"
	}
}

Function Compare-GheUsers
{
<#
	.SYNOPSIS
		Compare GitHub Enterprise Server's user list with the given user list.

	.DESCRIPTION
		The given list used to compare against the current appliance user list may be a
		GheUserColl	previously optained with this api and eventually modified for specific
		purpose, or	an external csv file (CsvImportFile) with the right format.
		The returned value is a collection of [GheUserDiff] containing the match found in each
		[GheUserCollection]. Matching is made by login or email address if the login match
		failed.
		To get difference result, call $GheCompare.Analyze([String[]] $IgnoreLogins) where 
		$IgnoreLogins is the list of login that must be ignored in the comparison.

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

	.PARAMETER GheUserColl
		GheUserColl object previously created with this api.

	.PARAMETER CsvImportFile
		Full file path of the comma separated file used to import the GitHub's user list used
		to compare.

	.OUTPUTS
		[GheUserCompare]
		GheUserCompare is a [System.Collections.Hashtable] specialization containing [GheUserDiff]
		indexed by login.

	.EXAMPLE
		$Params = @{
			ServerUri =  "http://github.mycompany.com/"
			AdminToken = "636e3227468e4e09f397e3ecb26860eed9fbeaff"
			SshKeyPath = join-path $env:HOMEPATH ".ssh/github.mycompany.com_rsa"
		}
		$ghe_users = Get-GheUsers @Params
		$ghe_usrcmp = Compare-GheUsers @Params -GheUserColl $ghe_users

	.EXAMPLE
		$Params = @{
			ServerUri =  "http://github.mycompany.com/"
			AdminToken = "636e3227468e4e09f397e3ecb26860eed9fbeaff"
			SshKeyPath = join-path $env:HOMEPATH ".ssh/github.mycompany.com_rsa"
		}
		$ghe_client = Get-GheClient @Params
		$ghe_users = $ghe_client | Get-GheUsers
		$ghe_usrcmp = $ghe_client | Compare-GheUsers -GheUserColl $ghe_users

	.NOTES
		Before using this script, create a SSH key and upload it onto GitHub instance.
		https://help.github.com/articles/creating-a-personal-access-token-for-the-command-line/
		https://help.github.com/enterprise/admin/guides/installation/administrative-shell-ssh-access/

	.LINK
		Get-GheClient
		Get-GheUsers
		Sync-GheUsers
		Get-GheLDAPUsers
		Sync-GheLDAPUsers
#>
    [CmdletBinding()]

	Param(
		[Parameter(Mandatory=$true, ParameterSetName = "Coll_Connect")]
		[Parameter(Mandatory=$true, ParameterSetName = "Impt_Connect")]
		[ValidateNotNullOrEmpty()]
		[String] $ServerUri,

		[Parameter(Mandatory=$true, ParameterSetName = "Coll_Connect")]
		[Parameter(Mandatory=$true, ParameterSetName = "Impt_Connect")]
		[ValidateNotNullOrEmpty()]
		[String] $AdminToken,

		[Parameter(Mandatory=$true, ParameterSetName = "Coll_Connect")]
		[Parameter(Mandatory=$true, ParameterSetName = "Impt_Connect")]
		[ValidateNotNullOrEmpty()]
		[String] $SshKeyPath,

		[Parameter(Mandatory=$false, ParameterSetName = "Coll_Connect")]
		[Parameter(Mandatory=$false, ParameterSetName = "Impt_Connect")]
		[UInt16] $SshHostPort = 122,

		[Parameter(Mandatory=$true, ParameterSetName = "Coll_Session", ValueFromPipeline=$true)]
		[Parameter(Mandatory=$true, ParameterSetName = "Impt_Session", ValueFromPipeline=$true)]
		[ValidateNotNullOrEmpty()]
		[GheClient] $GheClient,

		[Parameter(Mandatory=$true, ParameterSetName = "Coll_Connect")]
		[Parameter(Mandatory=$true, ParameterSetName = "Coll_Session")]
		[ValidateNotNullOrEmpty()]
		[GheUserCollection] $GheUserColl,

		[Parameter(Mandatory=$true, ParameterSetName = "Impt_Connect")]
		[Parameter(Mandatory=$true, ParameterSetName = "Impt_Session")]
		[ValidateNotNullOrEmpty()]
		[String] $CsvImportFile
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
		if(($PSCmdlet.ParameterSetName -eq "Coll_Connect") -or
			($PSCmdlet.ParameterSetName -eq "Impt_Connect"))
			{ $GheClient = [GheClient]::new($ServerUri, $AdminToken, $SshHostPort, $SshKeyPath)	}

		if(($PSCmdlet.ParameterSetName -eq "Impt_Connect") -or
			($PSCmdlet.ParameterSetName -eq "Impt_Session"))
			{ $GheUserColl = [GheUserCollection]::new($CsvImportFile) }

		$GheGHubColl = [GheUserCollection]::Get($GheClient)
		$GheCompare = [GheUserCompare]::new($GheGHubColl, $GheUserColl)

		return $GheCompare
	}
	End
	{
		Write-Verbose "$($MyInvocation.MyCommand.Name):: Function ended"
	}
}

Function Sync-GheUsers
{
<#
	.SYNOPSIS
		Synchronize GitHub's user list with the given user list.

	.DESCRIPTION
		The function synchronize a GitHub Enterprise's user list with the given [GheUserCollection].
		The given [GheUserCollection] must have been created with a Get-GheUser function and may
		have eventually been modified for specific purpose.

	.PARAMETER GheUserColl
		GheUserColl object previously created with this api. (pipeline value)

	.PARAMETER UsersIgnored
		List of GitHub local user's login who must be ignored during the comparaison and the synchronization.
		Usually technical GitHub accounts, without any equivallence in the LDAP directory.

	.PARAMETER SyncAction
		String flag enumeration of actions allowed during the Synchronization :
		"Enable, Disable, Create, Rename" or "None".
		Default value is "Enable, Disable, Create, Rename".

	.PARAMETER CsvExportFile
		Full file path of the comma separated file used to export the comparison [GheUserCompare]
		between the	GitHub's user list and the given [GheUserCollection] after the synchronization
		is done.

	.EXAMPLE
		$Params = @{
			ServerUri =  "http://github.mycompany.com/"
			AdminToken = "636e3227468e4e09f397e3ecb26860eed9fbeaff"
			SshKeyPath = join-path $env:HOMEPATH ".ssh/github.mycompany.com_rsa"
		}
		$ghe_users = Get-GheLDAPUsers @Params -SuspendedRegEx "^(?!.*OU=users).*$"
		$ghe_users | Sync-GheUsers -SyncAction "Disable, Rename" -Verbose

	.EXAMPLE
		$Params = @{
			ServerUri =  "http://github.mycompany.com/"
			AdminToken = "636e3227468e4e09f397e3ecb26860eed9fbeaff"
			SshKeyPath = join-path $env:HOMEPATH ".ssh/github.mycompany.com_rsa"
		}
		$ghe_client = Get-GheClient @Params
		$ghe_client | Sync-GheUsers -SuspendedRegEx "^(?!.*OU=users).*$" -Verbose

	.NOTES
		Before using this script, create a SSH key and upload it onto GitHub instance.
		https://help.github.com/enterprise/admin/guides/user-management/using-ldap/
		https://help.github.com/articles/creating-a-personal-access-token-for-the-command-line/
		https://help.github.com/enterprise/admin/guides/installation/administrative-shell-ssh-access/

		The function compares both list and analyses differences, if a synchronization is needed, 
		it will try to synchronize user status and create new users (depending on SyncAction flag) :
		- User not found in given GheUserCollection are suspended in GitHub.
		- User found in given GheUserCollection is created in GitHub, if he does not already exist.
		- User found in given GheUserCollection are actived in GitHub, if he already exists.
		When the synchronization is done, the function runs a final analysis.
		All results messages are sent to the designed output (verbose, warning and errors), if you want to have
		full information, use the -verbose flags.

	.LINK
		Get-GheClient
		Get-GheUsers
		Compare-GheUsers
		Get-GheLDAPUsers
		Sync-GheLDAPUsers
#>

    [CmdletBinding()]
	Param(
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)]
		[ValidateNotNullOrEmpty()]
		[GheUserCollection] $GheUserColl,

		[Parameter(Mandatory=$false)]
		[String[]] $UsersIgnored,

		[Parameter(Mandatory=$false)]
		[String] $SyncAction = "Enable, Disable, Create, Rename",

		[Parameter(Mandatory=$false)]
		[ValidateNotNullOrEmpty()]
		[String] $CsvExportFile
	)
	begin
	{
		Function DumpAnalysis(
			[HashTable] $GheAnalysis,
			[String] $Title)
		{
			# Print Analysis Results
			if(!$PSCmdlet.MyInvocation.BoundParameters["Verbose"]) { return }

			$output_txt = "{0} Information" -f $Title
			Write-Verbose ("#" * 100)
			Write-Verbose $output_txt.PadLeft((100 + $output_txt.Length) / 2, " ")
			Write-Verbose ("#" * 100)
			@("Ignored", "ToEnable", "ToDisable") | % {
				$status = $_.Replace("To", "To ").ToUpper()
				$GheAnalysis[$_] | % {
					Write-Verbose ("[$status] {0} ({1}) {2}" -f $_.login, $_.email, $_.suspension_status) }
			}
			$GheAnalysis["ToRename"] | % {
				Write-Verbose ("[TO RENAME] {0} ({1}) {2} ({3})" -f $_.login, $_.email, $_.trg_login, $_.trg_suspension_status) }
			$GheAnalysis["ToCreate"] | % {
				Write-Verbose ("[TO CREATE] {0} ({1}) {2}" -f $_.trg_login, $_.trg_email, $_.trg_suspension_status) }

			$output_txt = "{0} Results" -f $Title
			Write-Verbose ("#" * 100)
			Write-Verbose $output_txt.PadLeft((100 + $output_txt.Length) / 2, " ")
			Write-Verbose ("#" * 100)
			@("Ignored", "Enabled", "Disabled") | % {
				Write-Verbose ("[STATUS] {0:N0} $_" -f $GheAnalysis[$_].Count) }
			[Enum]::GetNames([GheSyncAction]) | ? { $_ -notin @("None") } | % {
				Write-Verbose ("[STATUS] {0:N0} should be {1}d" -f $GheAnalysis["To$_"].Count, $_)}
			Write-Verbose ("-" * 40)
			$sum_cnt = 0; $GheAnalysis.Values | % { $sum_cnt += $_.Count }
			Write-Verbose ("[STATUS] {0:N0} Total" -f $sum_cnt)
			Write-Verbose ("[STATUS] {0:N0} Evaluated Users" -f $GheCompare.Values.Count)
		}

		Write-Debug "PsBoundParameters:"
		$PSBoundParameters.GetEnumerator() | % { Write-Debug $_ }

		if($PSBoundParameters['Debug']) { $DebugPreference = 'Continue' }
		Write-Debug "DebugPreference: $DebugPreference"

		Write-Verbose "$($MyInvocation.MyCommand.Name):: Function started"
	}
	Process
	{
		# Compare Github user list against LDAP user list
		$GheGHubColl = [GheUserCollection]::Get($GheUserColl._Client)
		$GheCompare = [GheUserCompare]::new($GheGHubColl, $GheUserColl)

		# Do an initial analysis and dump the Result
		$GheAnalysis = $GheCompare.Analyze($UsersIgnored)
		DumpAnalysis $GheAnalysis "Initial Analysis"

		# Synchronize and dump Synchronization Errors
		[GheSyncAction] $SyncActionEnum = [GheSyncAction]($SyncAction)
		$err_cnt = 0; [Enum]::GetValues([GheSyncAction]) | % {
			if($SyncActionEnum -band $_)
				{ $err_cnt += $GheAnalysis["To$_"].Count }
		}
		if($err_cnt -gt 0)
		{
			$GheSynch = $GheCompare.Synch($GheAnalysis, $SyncActionEnum)
			$err_cnt = 0; $GheSynch.Values | % { $err_cnt += $_.Count }

			if($err_cnt -gt 0)
			{
				$output_txt = "Synchronization Warnings"
				Write-Warning ("#" * 100)
				Write-Warning $output_txt.PadLeft((100 + $output_txt.Length) / 2, " ")
				Write-Warning ("#" * 100)
				$GheSynch["Enable"] | % {
					Write-Warning ("[NOT ENABLED] {0} ({1}) {2}" -f $_.login, $_.email, $_.suspension_status) }
				$GheSynch["Disable"] | % {
					Write-Warning ("[NOT DISABLED] {0} ({1}) {2}" -f $_.login, $_.email, $_.suspension_status) }
				$GheSynch["Rename"] | % {
					Write-Warning ("[NOT RENAMED] {0} ({1}) {2}" -f $_.login, $_.email, $_.trg_login) }
				$GheSynch["RenameStatus"] | % {
					Write-Warning ("[RENAMED BAD STATUS] {0} ({1}) {2}" -f $_.login, $_.email, $_.trg_suspension_status) }
				$GheSynch["Create"] | % {
					Write-Warning ("[NOT CREATED] {0} ({1}) {2}" -f $_.trg_login, $_.trg_email, $_.trg_suspension_status) }
				$GheSynch["CreateStatus"] | % {
					Write-Warning ("[CREATED BAD STATUS] {0} ({1}) {2}" -f $_.login, $_.email, $_.trg_suspension_status) }
			}

			# Do an final analysis and dump the Result
			$GheAnalysis = $GheCompare.Analyze($UsersIgnored)
			DumpAnalysis $GheAnalysis "Final Analysis"
		}

		# Export Comparison Results
		$GheCompare.ExportToCsv($CsvExportFile)
	}
	End
	{
		Write-Verbose "$($MyInvocation.MyCommand.Name):: Function ended"
	}
}

Function Get-GheLDAPUsers
{
<#
	.SYNOPSIS 
		Get LDAP's user list used by GitHub Enterprise Server to allow server access.

	.DESCRIPTION
		The function uses the GitHub Enterprise configuration and the ssh connection to run the 
		required LDAP query.

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

	.PARAMETER SuspendedRegEx
		RegEx used to check against LDAP DN if the user is Suspended.

	.PARAMETER CsvExportFile
		Full file path of the comma separated file used to export the LDAP's user list.
    
	.OUTPUTS
		[GheLDAPUserCollection]
		GheUserCollection is a [System.Collections.Hashtable] specialization containing [GheUser]
		indexed by login.

	.EXAMPLE
		$Params = @{
			ServerUri =  "http://github.mycompany.com/"
			AdminToken = "636e3227468e4e09f397e3ecb26860eed9fbeaff"
			SshKeyPath = join-path $env:HOMEPATH ".ssh/github.mycompany.com_rsa"
		}
		$ghe_users = Get-GheLDAPUsers @Params -SuspendedRegEx "^(?!.*OU=users).*$"

	.EXAMPLE
		$Params = @{
			ServerUri =  "http://github.mycompany.com/"
			AdminToken = "636e3227468e4e09f397e3ecb26860eed9fbeaff"
			SshKeyPath = join-path $env:HOMEPATH ".ssh/github.mycompany.com_rsa"
		}
		$ghe_client = Get-GheClient @Params
		$ghe_users = $ghe_client | Get-GheLDAPUsers -SuspendedRegEx "^(?!.*OU=users).*$"

	.NOTES
		Before using this script, create a SSH key and upload it onto GitHub instance.
		https://help.github.com/articles/creating-a-personal-access-token-for-the-command-line/
		https://help.github.com/enterprise/admin/guides/installation/administrative-shell-ssh-access/

		SuspendedRegEx can be inclusive or exclusive, for instance :
			# When suspended users are removed from the LDAP group named "users"
			$SuspendedRegEx = "^(?!.*OU=users).*$"
			# When suspended users are added to LDAP group named "disabled"
			$SuspendedRegEx = "^.*OU=disabled.*$"

	.LINK
		Get-GheClient
		Get-GheUsers
		Compare-GheUsers
		Sync-GheUsers
		Sync-GheLDAPUsers
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

		[Parameter(Mandatory=$false)]
		[ValidateNotNullOrEmpty()]
		[String] $SuspendedRegEx,

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
		if($PSCmdlet.ParameterSetName -eq "Connect")
			{ $GheClient = [GheClient]::new($ServerUri, $AdminToken, $SshHostPort, $SshKeyPath)	}

		$GheLDAPUsers = [GheLDAPUserCollection]::new($GheClient, $SuspendedRegEx)
		if($GheLDAPUsers.Values.Count -eq 0)
			{ Write-Error "GheLDAPUserCollection is empty, check your LDAP configuration into your GitHub instance`r`n" }

		if($CsvExportFile)
			{ $GheLDAPUsers.ExportToCsv($CsvExportFile) }

		return $GheLDAPUsers
	}
	End
	{
		Write-Verbose "$($MyInvocation.MyCommand.Name):: Function ended"
	}
}

Function Sync-GheLDAPUsers
{
<#
	.SYNOPSIS 
		Synchronize GitHub's user list with LDAP's user list

	.DESCRIPTION
		The function synchronize a GitHub Enterprise's user list when your server is configured 
		to use LDAP authentication, but not LDAP synchronization.

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
    
	.PARAMETER SuspendedRegEx
		RegEx used to check against LDAP DN if the user is Suspended.

	.PARAMETER UsersIgnored
		List of GitHub local user's login who must be ignored during the comparaison and the synchronization.

	.PARAMETER SyncAction
		String flag enumeration of actions allowed during the Synchronization : "Enable, Disable, Create, Rename"
		or "None". Default value is "Enable, Disable, Create, Rename".

	.PARAMETER CsvExportFile
		Full file path of the comma separated file used to export the comparison between the
		GitHub's user list and the LDAP's user list after the synchronization is done.

	.EXAMPLE
		$Params = @{
			ServerUri =  "http://github.mycompany.com/"
			AdminToken = "636e3227468e4e09f397e3ecb26860eed9fbeaff"
			SshKeyPath = join-path $env:HOMEPATH ".ssh/github.mycompany.com_rsa"
			SyncAction = "Disable, Rename"
		}
		Sync-GheLDAPUsers @Params -SuspendedRegEx "^(?!.*OU=users).*$" -Verbose

	.EXAMPLE
		$Params = @{
			ServerUri =  "http://github.mycompany.com/"
			AdminToken = "636e3227468e4e09f397e3ecb26860eed9fbeaff"
			SshKeyPath = join-path $env:HOMEPATH ".ssh/github.mycompany.com_rsa"
		}
		$ghe_client = Get-GheClient @Params
		$ghe_client | Sync-GheLDAPUsers -SuspendedRegEx "^(?!.*OU=users).*$" -Verbose

	.NOTES
		Before using this script, create a SSH key and upload it onto GitHub instance.
		https://help.github.com/enterprise/admin/guides/user-management/using-ldap/
		https://help.github.com/articles/creating-a-personal-access-token-for-the-command-line/
		https://help.github.com/enterprise/admin/guides/installation/administrative-shell-ssh-access/

		The function compares both list and analyses differences, if a synchronization is needed, 
		it will try to synchronize user status and create new users (depending on SyncAction flag) :
		- User not found in LDAP are suspended in GitHub.
		- User found in LDAP is created in GitHub, if he does not already exist.
		- User found in LDAP are actived in GitHub, if he already exists.
		When the synchronization is done, the function runs a final analysis.
		All results messages are sent to the designed output (verbose, warning and errors), if you want to have
		full information, use the -verbose flags.

		SuspendedRegEx can be inclusive or exclusive, for instance :
			# When suspended users are removed from the LDAP group named "users"
			$SuspendedRegEx = "^(?!.*OU=users).*$"
			# When suspended users are added to LDAP group named "disabled"
			$SuspendedRegEx = "^.*OU=disabled.*$"

	.LINK
		Get-GheClient
		Get-GheUsers
		Compare-GheUsers
		Sync-GheUsers
		Get-GheLDAPUsers
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

		[Parameter(Mandatory=$false)]
		[String] $SuspendedRegEx,

		[Parameter(Mandatory=$false)]
		[String[]] $UsersIgnored,

		[Parameter(Mandatory=$false)]
		[String] $SyncAction = "Enable, Disable, Create, Rename",

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

		# Get LDAP user list
		$GheLDAPColl = [GheLDAPUserCollection]::new($GheClient, $SuspendedRegEx)
		if($GheLDAPColl.Values.Count -eq 0)
			{ Write-Error "GheLDAPUserCollection is empty, check your LDAP configuration into your GitHub instance`r`n" }
		
		# Use PowerShell Splatting for parameters redirection
		$NewParams = @{}
		$NotParams = @("ServerUri", "AdminToken", "SshHostPort", "SshKeyPath", "GheClient", "SuspendedRegEx")
		$PSCmdlet.MyInvocation.BoundParameters.keys | ? {
			$_ -notin $NotParams } | % {
			$NewParams[$_] = $PSCmdlet.MyInvocation.BoundParameters[$_] }
		$NewParams["GheUserColl"] = $GheLDAPColl

		Sync-GheUsers @NewParams
	}
	End
	{
		Write-Verbose "$($MyInvocation.MyCommand.Name):: Function ended"
	}
}

