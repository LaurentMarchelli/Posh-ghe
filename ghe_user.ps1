#
# ghe_user.ps1 : GheUser Implementation Classes
# 

enum GheUserStatus
{
	active
	suspended
	null
}

# Base User declaration
class GheUser
{
	[String] $login
	[System.Net.Mail.MailAddress] $email
	[GheUserStatus] $suspension_status

	# Raw login before normalization
	[String] $lograw

	# Contructor used to normalize GheUser properties
	GheUser(
		[String] $Login,
		[String] $Email,
		[GheUserStatus] $Status)
	{
		$this.SetLogin($Login)
		$this.SetEmail($Email)
		$this.suspension_status = $Status
	}

	# Constructor used to create GheUser from csv import object
	GheUser([PSObject] $User)
	{
		if($User -eq $null)
			{ $this.suspension_status = [GheUserStatus]::null }
		else
		{
			# Set Specific properties
			$this.SetLogin($User.login)
			$this.SetEmail($User.email)
			if($User.suspension_status)
				{ $this.suspension_status = [GheUserStatus]($User.suspension_status) }
			else
				{ $this.suspension_status = [GheUserStatus]::null }

			# Add non specific properties
			$exclude =  $this.psobject.properties.ForEach({$_.Name})
			$User.psobject.properties | Where { $_.Name -notin $exclude } | % {
				$this | Add-Member -MemberType $_.MemberType -Name $_.Name -Value $_.Value}
		}
	}

	# Copy constructors
	GheUser([GheUser] $User)
	{
		if($User -eq $null)
			{ $this.suspension_status = [GheUserStatus]::null }
		else
		{
			[GheUser].GetProperties() | % {
				$name = $_.Name
				$value = $User.psobject.properties[$name].Value
				$this.psobject.properties[$name].Value = $value
			}
		}
	}
	[void] SetLogin([String] $Login)
	{
		$this.login = $Login.Replace(".", "-").Replace("_", "-")
		$this.lograw = $Login
	}
	[void] SetEmail([String] $Email)
	{
		if($Email)
			{ $this.email = [System.Net.Mail.MailAddress]::new($Email.ToString().ToLower()) }
		else
			{ $this.email = $null }
	}
}

Class GheUserCollection : System.Collections.Hashtable
{
	Hidden [GheClient] $_Client
	Hidden [HashTable] $_Params
	Hidden [GheCommandCollection] $_Command

	GheUserCollection([GheClient] $GheClient) : base()
		{ $this._create($GheClient) }

	GheUserCollection([String] $ImportFilePath) : base()
	{
		$this._create($null)
		$this.ImportFromCsv($ImportFilePath)
	}

	[void] _create([GheClient] $GheClient)
	{
		# The tricky way to set the class property without adding a key / value
		# pair to the [hashtable].
		[GheUserCollection].GetProperty("_Client").SetValue($this, $GheClient)
		[GheUserCollection].GetProperty("_Params").SetValue($this, [HashTable]::new())
	}

	[void] ConvertFromCsv([PSObject[]] $UserRecords)
	{
		ConvertFrom-Csv -InputObject $UserRecords | % {
			$user = [GheUser]::new($_)
			$this[$user.login] = $user
		}
	}

	[void] ImportFromCsv([String] $ImportFilePath)
	{
		$fileimport = Get-Content -Path $ImportFilePath -Encoding UTF8
		$this.ConvertFromCsv($fileimport)
	}

	[void] ExportToCsv([String] $ExportFilePath)
		{ $this.ExportToCsv($ExportFilePath, @("login"), $null) }

	[void] ExportToCsv(
		[String] $ExportFilePath,
		[String[]]$SortOrder, 
		[String[]]$SelectFields)
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

class GheUserDiff : GheUser
{
	Hidden [GheUser] $_Source
	Hidden [GheUser] $_Target

	GheUserDiff(
		[GheUser] $UserSource,
		[GheUser] $UserTarget) : base($UserSource)
	{
		$this._Source = $UserSource
		$this._Target = $UserTarget

		# Add target specific properties
		if($UserTarget -eq $null)
			{ $UserTarget = [GheUser]::new($null) }

		$exclude =  $this.psobject.properties.ForEach({$_.Name})
		$UserTarget.psobject.properties | Where { $_.Name -in $exclude } | % {
			$Name = "trg_" + $_.Name
			$this | Add-Member -MemberType NoteProperty -Name $Name -Value $_.Value
		}
	}
}

[Flags()] enum GheSyncAction
{
	None = 0
	Enable = 1
	Disable = 2
	Create = 4
	Rename = 8
}

Class GheUserCompare : GheUserCollection
{
	Hidden [GheUserCollection] $_Source
	Hidden [GheUserCollection] $_Target

	GheUserCompare(
		[GheUserCollection] $SourceColl,
		[GheUserCollection] $TargetColl) : base($SourceColl._Client)
	{
		# The tricky way to set the class property without adding a key / value
		# pair to the [hashtable].
		[GheUserCompare].GetProperty("_Source").SetValue($this, $SourceColl)
		[GheUserCompare].GetProperty("_Target").SetValue($this, $TargetColl)

		# Copy Extended parameters from target
		$TargetColl._Params.Keys | % {
			$this._Params[$_] = $TargetColl._Params[$_]
		}
		
		# Create target login hashtable and email hashtable to identify login
		# modification
		$TargetLogn = @{}
		$TargetMail = @{}
		$TargetColl.Values | % {
			$TargetLogn[$_.login] = $_
			if($_.email)
				{ $TargetMail[$_.email] = $_ }
		}

		# Create compare collection with $SourceColl collection content
		$SourceColl.Values | % {
			# Try to find the user with his login
			$trg_obj = $TargetLogn[$_.login]

			# If login changed, try to find the user with his email
			if(($trg_obj -eq $null) -and ($_.email -ne $null))
				{ $trg_obj = $TargetMail[$_.email] }

			# If the user is found, remove it from target hash tables
			$this.Add($_.login, [GheUserDiff]::new($_, $trg_obj))
			if($trg_obj)
			{
				$TargetLogn.Remove($trg_obj.login)
				if($trg_obj.email)
					{ $TargetMail.Remove($trg_obj.email) }
			}
		}
		# Update compare collection with object remainnig into $TargetLogn
		$TargetLogn.Values | % {
			$this.Add($_.login, [GheUserDiff]::new($null, $_))
		}
	}

	[HashTable] Analyze([String[]] $IgnoreLogins)
	{
		# Create a status and action hashtable
		$ret_val = @{
			"Ignored" = [System.Collections.ArrayList]::new();
			"Enabled" = [System.Collections.ArrayList]::new();
			"Disabled" = [System.Collections.ArrayList]::new();
			"ToEnable" = [System.Collections.ArrayList]::new();
			"ToDisable" = [System.Collections.ArrayList]::new();
			"ToRename" = [System.Collections.ArrayList]::new();
			"ToCreate" = [System.Collections.ArrayList]::new();
		}

		#   "Source, Target"
		#----------------------------------------
		#   "active, active"       : Enabled
		#   "active, suspended"    : ToDisable
		#   "active, null"         : ToDisable
		#   "suspended, active"    : ToEnable
		#   "suspended, suspended" : Disabled
		#   "suspended, null"      : Disabled
		#   "null, active"         : ToCreate
		#   "null, suspended"      : ToCreate
		#   "null, null"           : Unexpected value

		$this.Values | % {
			if(($IgnoreLogins -ne $null) -and ($_.login -in  $IgnoreLogins))
				{ $ret_val["Ignored"].Add($_) }
			elseif($_.login -eq $null)
				{ $ret_val["ToCreate"].Add($_) }
			elseif($_.trg_login -eq $null)
			{
				if($_.suspension_status -eq [GheUserStatus]::active)
					{ $ret_val["ToDisable"].Add($_) }
				else
					{ $ret_val["Disabled"].Add($_) }
			}
			elseif($_.trg_login -ne $_.login)
				{ $ret_val["ToRename"].Add($_) }
			elseif($_.trg_suspension_status -eq  $_.suspension_status)
			{
				if($_.trg_suspension_status -eq [GheUserStatus]::active)
					{ $ret_val["Enabled"].Add($_) }
				else
					{ $ret_val["Disabled"].Add($_) }
			}
			elseif($_.trg_suspension_status -eq [GheUserStatus]::active)
				{ $ret_val["ToEnable"].Add($_) }
			else
				{ $ret_val["ToDisable"].Add($_) }
		}
		return $ret_val
	}

	# Synchronize in the GitHub Server, the source collection with target collection
	# information
	[HashTable] Synch(
		[HashTable] $Analysis,
		[GheSyncAction] $SyncAction)
	{
		$synch_err = @{
			"Enable" = [System.Collections.ArrayList]::new();
			"Disable" = [System.Collections.ArrayList]::new();
			"Rename" = [System.Collections.ArrayList]::new();
			"RenameStatus" = [System.Collections.ArrayList]::new();
			"Create" = [System.Collections.ArrayList]::new();
			"CreateStatus" = [System.Collections.ArrayList]::new();
		}
		$user_admin = [Octokit.UserAdministrationClient]::new($this._Client.ApiConnection)
		if($SyncAction -band [GheSyncAction]::Enable)
		{
			$Analysis["ToEnable"] | % {
				if($user_admin.Unsuspend($_.login).Result)
					{ $_.suspension_status = $_._Source.suspension_status = [GheUserStatus]::active }
				else
					{ $synch_err["Enable"].Add($_) }
			}
		}
		if($SyncAction -band [GheSyncAction]::Disable)
		{
			$Analysis["ToDisable"] | % {
				if($user_admin.Suspend($_.login).Result)
					{ $_.suspension_status = $_._Source.suspension_status = [GheUserStatus]::suspended }
				else
					{ $synch_err["Disable"].Add($_) }
			}
		}
		if($SyncAction -band [GheSyncAction]::Rename)
		{
			$config = [GheConfig]::Get($this._Client, "^smtp|ldap|core\..*$")
			$prof_logn = $config["ldap.profile.uid"]
			$prof_name = $config["ldap.profile.name"]
			$mail_lst = [System.Collections.Generic.List[System.Net.Mail.MailMessage]]::new()

			$Analysis["ToRename"] | %  {
				# Synchronize the status first to avoid error due to server delay when renaming.
				if($_.trg_suspension_status -ne $_.suspension_status)
				{
					if(($_.trg_suspension_status -eq [GheUserStatus]::active) -and
						($user_admin.Unsuspend($_.login).Result))
						{ $_.suspension_status = $_._Source.suspension_status = [GheUserStatus]::active }
					elseif(($_.trg_suspension_status -eq [GheUserStatus]::suspended) -and
						($user_admin.Suspend($_.login).Result))
						{ $_.suspension_status = $_._Source.suspension_status = [GheUserStatus]::suspended }
					else
						{ $synch_err["RenameStatus"].Add($_) }
				}
				# Now try to rename the user
				if($user_admin.Rename($_.login, [Octokit.UserRename]::new($_.trg_login)).Result)
				{
					# Prepare Notification email
					$mail_tmpl = $this._Params["Mail.Rename"]
					if($mail_tmpl)
					{
						[GheMailMsg] $mail_obj = $mail_tmpl
						$mail_obj.To.Add($_.email)
						$mail_obj.Body = ($mail_obj.Body -f
							$_.login, $_.lograw,
							$_.trg_login, $_.trg_lograw)
						$mail_lst.Add($mail_obj)
					}
					$_.login = $_._Source.login = $_.trg_login
				}
				else
				{
					# Keep the worse error only, to have correct statistics.
					$synch_err["RenameStatus"].Remove($_)
					$synch_err["Rename"].Add($_)
				}
			}
			# Send Notification Emails and store result into hidden member
			[GheUserCompare].GetProperty("_Command").SetValue(
				$this, $this._Client.SendMail($mail_lst))
		}
		if($SyncAction -band [GheSyncAction]::Create)
		{
			$synch_ok = [System.Collections.ArrayList]::new();
			$Analysis["ToCreate"] | % {
				if($user_admin.Create([Octokit.NewUser]::new($_.trg_login, $_.trg_email)).Result)
				{
					$_.login = $_.trg_login
					$_.email = $_.trg_email
					$_.suspension_status = [GheUserStatus]::active
					$_._Source = [GheUser]::($_)
					$synch_ok.Add($_)
				}
				else
					{ $synch_err["Create"].Add($_) }
			}
			$synch_ok | % {
				if($_.trg_suspension_status -eq [GheUserStatus]::suspended)
				{
					if($user_admin.Suspend($_.login).Result)
						{ $_.suspension_status = $_._Source.suspension_status = [GheUserStatus]::suspended }
					else
						{ $synch_err["CreateStatus"].Add($_) }
				}
			}
		}
		return $synch_err
	}

	[void] ExportToCsv([String] $ExportFilePath)
	{ 
		$this.ExportToCsv($ExportFilePath, @("suspension_status", "trg_suspension_status", "login"), @(
			"suspension_status"
			"login",
			"email",
			"trg_suspension_status",
			"trg_login",
			"trg_email"
			)
		)
	}
}
