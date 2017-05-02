#
# ghe_userghub.ps1 : GheGHubUser Implementation Classes
# 

# Github User
# login,email,role,ssh_keys,org_memberships,repos,suspension_status,last_logged_ip,creation_date
class GheGHubUser : GheUser
{
	# Constructor used to create GheUser from GitHub information
	GheGHubUser([PSObject] $user) : base(
		$user.login, $user.email, $user.suspension_status)
	{
		# Add non specific properties
		$exclude =  $this.psobject.properties.ForEach({$_.Name})
		$user.psobject.properties | Where { $_.Name -notin $exclude } | % {
			$this | Add-Member -MemberType $_.MemberType -Name $_.Name -Value $_.Value}
	}
}

class GheGHubUserCollection : GheUserCollection
{
	GheGHubUserCollection([GheClient] $GheClient) : base($GheClient) 
	{
		# Usage: ghe-user-csv [options]
		#
		# This utility dumps out a list of all the users in the installation in CSV
		# format. This information includes login, email address, permission level
		# (admin or user), how many repositories they have, ssh keys, and the last
		# logged IP address.
		#
		# OPTIONS:
		#   -h, --help         Show this message
		#   -d, --header       Display header row. Defaults to false.
		#   -o, --stdout       Print output to STDOUT. Optional.
		#   -a, --admins       Limit to admin users. Optional.
		#   -u, --users        Limit to non-admin users. Optional.
		#   -s, --suspended    Limit to suspended users. Optional.

		# The tricky way to set the class property without adding a key / value
		# pair to the [hashtable].
		[GheGHubUserCollection].GetProperty("_Command").SetValue(
			$this, [GheCommandCollection]::new())
		$CommandObj = [GheCommand]::new("ghe-user-csv -o -d")
		$this._Command.Add($CommandObj)

		# Run ssh command to get the result
		$GheClient.SendCommand($CommandObj)

		# Convert csv result into Object list
		ConvertFrom-Csv -InputObject $CommandObj.Response.Output | ForEach-Object {
			$user=[GheGHubUser]::new($_)
			$this.Add($user.login, $user)}
	}
}
