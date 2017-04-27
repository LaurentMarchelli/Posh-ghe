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
	
	# Contructor used to normalize GheUser properties
	GheUser(
		[String] $login,
		[String] $email,
		[GheUserStatus] $status)
	{
		$this.login = $login.Replace(".", "-").Replace("_", "-")
		if($email)
			{ $this.email = [System.Net.Mail.MailAddress]::new($email.ToString().ToLower()) }
		$this.suspension_status = $status
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
}

Class GheUserCollection : System.Collections.Hashtable
{
	Hidden [GheClient ]$_client

	GheUserCollection([GheClient] $GheClient) : base()
	{
		# The tricky way to set the class property without adding a key / value
		# pair to the [hashtable].
		$this.GetType().GetProperty("_client").SetValue($this, $GheClient)
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
	Hidden [GheUser] $_source
	Hidden [GheUser] $_target

	GheUserDiff(
		[GheUser] $UserSource,
		[GheUser] $UserTarget) : base($UserSource)
	{
		$this._source = $UserSource
		$this._target = $UserTarget

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

Class GheUserCompare : GheUserCollection
{
	GheUserCompare(
		[GheUserCollection] $SourceColl,
		[GheUserCollection] $TargetColl) : base($SourceColl._client)
	{
		# Create compare collection with $SourceColl collection content
		$SourceColl.Keys | ForEach-Object {
			$trg_obj = $TargetColl[$_]
			$this.Add($_, [GheUserDiff]::new($SourceColl[$_], $trg_obj))
			if($trg_obj)
				{ $TargetColl.Remove($_) }
		}
		# Update compare collection with object remainnig into $TargetColl
		$TargetColl.Keys | ForEach-Object {
			$this.Add($_, [GheUserDiff]::new($null, $TargetColl[$_]))
		}
	}

	[HashTable] Analyse([String[]] $IgnoreLogins)
	{
		# Create a group hastable keyed by source suspension_status and target suspension_status
		$exclude = [System.Collections.ArrayList]::new()
		if(!$IgnoreLogins)
			{ $include = $this.Values }
		else
		{
			$include = [System.Collections.ArrayList]::new()
			$this.Values | % {
				if($_.login -in  $IgnoreLogins)
					{ $exclude.Add($_) }
				else
					{ $include.Add($_) }
			}
		}
		$grp_lst = $include | Group-Object -AsHashTable -AsString -Property suspension_status, trg_suspension_status

		# Complete the hashtable with values not found in the Values list
		$empty = @()
		$lst_stat = [Enum]::GetNames([GheUserStatus]) 
		$lst_stat| % {
			$src_obj = $_
			$lst_stat | % {
				$key_obj = "{0}, {1}" -f $src_obj, $_
				if($grp_lst[$key_obj] -eq $null)
					{ $grp_lst.Add($key_obj, $empty) }
			}
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
		return @{
			"Ignored" = $exclude;
			"Enabled" = $grp_lst["active, active"];
			"Disabled" = $grp_lst["suspended, null"] + $grp_lst["suspended, suspended"];
			"ToEnabled" = $grp_lst["suspended, active"];
			"ToDisable" = $grp_lst["active, null"] + $grp_lst["active, suspended"];
			"ToCreate" = $grp_lst["null, suspended"] + $grp_lst["null, active"]
		}
	}

	# Synchronize in the GitHub Server, the source collection with target collection
	# information
	[HashTable] Synch(
		[HashTable] $Analysis,
		[Boolean] $CreateNewUser)
	{
		$synch_err = @{
			"Enable" = [System.Collections.ArrayList]::new();
			"Disable" = [System.Collections.ArrayList]::new();
			"Create" = [System.Collections.ArrayList]::new();
			"SuspendNew" = [System.Collections.ArrayList]::new();
		}
		$user_admin = [Octokit.UserAdministrationClient]::new($this._client.ApiConnection)
		$Analysis["ToEnabled"] | % {
			if($user_admin.Unsuspend($_.login).Result)
				{ $_.suspension_status = $_._source.suspension_status = [GheUserStatus]::active }
			else
				{ $synch_err["Enable"].Add($_) }
		}
		$Analysis["ToDisable"] | % {
			if($user_admin.Suspend($_.login).Result)
				{ $_.suspension_status = $_._source.suspension_status = [GheUserStatus]::suspended }
			else
				{ $synch_err["Disable"].Add($_) }
		}
		if(!$CreateNewUser)
			{ return $synch_err }

		$Analysis["ToCreate"] | % {
			if($user_admin.Create([Octokit.NewUser]::new($_.trg_login, $_.trg_email)).Result)
			{
				$_.login = $_.trg_login
				$_.email = $_.trg_email
				$_.suspension_status = [GheUserStatus]::active
				$_._source = [GheUser]::($_)
				if($_.trg_suspension_status -eq [GheUserStatus]::suspended)
				{
					if($user_admin.Suspend($_.login).Result)
						{ $_.suspension_status = $_._source.suspension_status = [GheUserStatus]::suspended }
					else
						{ $synch_err["SuspendNew"].Add($_) }
				}
			}
			else
				{ $synch_err["Create"].Add($_) }
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
