## Script to sync AD group with other AD group flatening users
##Set-PSDebug -Trace 2

## Copy all users from readonly group recoursively flat to readonly-flat group
function sync-ADGroupMembers-As-is {
  param (
    [string]$SourceGroup,
    [string]$DestinationGroup
  )
  Get-ADGroupMember -Recursive -Identity $SourceGroup -Server $global:ADServer -Credential $global:credentials | ForEach-Object {Add-ADGroupMember -Identity $DestinationGroup -Members $_.distinguishedName -Server $global:ADServer -Credential $global:credentials}
  if($?)
  {  
    Write-Host "$($DestinationGroup) is in sync now with $($SourceGroup)"
  } else {
    Write-Host "Failed to sync $($DestinationGroup) with $($SourceGroup)"
    exit 1
  }
}



function Copy-ADGroupMembers {
  param (
      [string]$SourceGroup,
      [string]$DestinationGroup
  )
  # Get the users from the source group recursively
  $users = Get-ADGroupMember -Identity $SourceGroup -Recursive -Server $global:ADServer -Credential $global:credentials | Where-Object { $_.objectClass -eq "user" }
  # Get the current date minus 10 days
  $startDate = (Get-Date).AddDays(-10)

  # Loop through each user
  foreach ($user in $users) {
    # Check if the user is a member of the destination group recursively
    $isMember = Get-ADGroupMember -Identity $DestinationGroup -Recursive -Server $global:ADServer -Credential $global:credentials | Where-Object { $_.SamAccountName -eq $user.SamAccountName }

    # Check if the user is not a member of the destination group
    if (-not $isMember) {
      # Check if the user was created at least 10 days ago
      $userObject = Get-ADUser -Identity $user.SamAccountName -Properties whenCreated -Server $global:ADServer -Credential $global:credentials
      $createdDate = $userObject.whenCreated

      if ($createdDate -lt $startDate) {
        # Add the user to the destination group
        Add-ADGroupMember -Identity $DestinationGroup -Members $user.SamAccountName -Server $global:ADServer -Credential $global:credentials 
        Write-Host "User $($user.SamAccountName) has been copied to $($DestinationGroup) ."
      }
    }
  }
  if($?)
  {
    Write-Host "$($DestinationGroup) is in sync now with $($SourceGroup)"
  } else {
    Write-Host "Failed to sync $($DestinationGroup) with $($SourceGroup)"
    exit 1
  }
}


function Remove-leftMembers {
  param (
      [string]$SourceGroup,
      [string]$DestinationGroup
  )
  # Get the users from the destination group recursively
  $users = Get-ADGroupMember -Identity $DestinationGroup -Recursive -Server $global:ADServer -Credential $global:credentials | Where-Object { $_.objectClass -eq "user" }
  $removal_candidates = @()
  # Loop through each user
  foreach ($user in $users) {
    # Check if the user is a member of the source group recursively
    $isMember = Get-ADGroupMember -Identity $SourceGroup -Recursive  -Server $global:ADServer -Credential $global:credentials| Where-Object { $_.SamAccountName -eq $user.SamAccountName }
   
    # Check if the user is not a member of the estination group
    if (-not $isMember) {
      # Removal candidates
      $removal_candidates += $user.SamAccountName 
    }
  }
  if ( $removal_candidates.Count -lt $global:MaxLeavingUsersAmount ) {
     foreach ($user in $removal_candidates) {
       Remove-ADGroupMember -Identity $DestinationGroup -Members $user -Confirm:$false -Server $global:ADServer -Credential $global:credentials
       if($?)
       {
          Write-Host "$($user) - is removed from $($DestinationGroup)" 
       }else {
          Write-Host "Failed to remove user $($user) from $($DestinationGroup)"
          exit 3
       }   
     }
  }
  else {
    Write-Host "$($removal_candidates.Count) users are going to be deleted from $($DestinationGroup) - Something is wrong!"
    Write-Host "Too many users left at once. Limit: $global:MaxLeavingUsersAmount users." 
    Write-Host "Need to check it! It may be reorg."
    Write-Host "Nothing was changed. See MAX_LEAVING_USERS_AMOUNT Ci/CD variable in the project settings."
    Write-Host "Users are going to be removed: $($removal_candidates)"
    exit 2
  }
}

## Compare members * group recoursively with *-flat group
function compare-ADGroupsMembers {
  param (
    [string]$SourceGroup,
    [string]$DestinationGroup
  )
  $SG = Get-ADGroupMember -Recursive -Identity $SourceGroup -Server $global:ADServer -Credential $global:credentials
  $DG = Get-ADGroupMember -Recursive -Identity $DestinationGroup -Server $global:ADServer -Credential $global:credentials
  Write-Host "$($SourceGroup) compared to $($DestinationGroup)"
  Compare-Object ($SG) ($DG) -Property "SamAccountName" -IncludeEqual | Sort-Object SamAccountName
}

## Get password from ENV Vars secure it and put to Creds variable for service user 
$global:Username = "DOMAIN\service_user"
$global:Password = $SERVICE_USER_PASS
$global:ADServer = "domain.company.com"
$global:MaxLeavingUsersAmount = $MAX_LEAVING_USERS_AMOUNT

# Define the names of the source and destination groups
# Create a PSCredential object with the global username and password
$securePassword = ConvertTo-SecureString -String $global:Password -AsPlainText -Force
$global:credentials = New-Object System.Management.Automation.PSCredential ($global:Username, $securePassword)

# Simple copy users for readonly and developers
sync-ADGroupMembers-As-is -SourceGroup "readonly" -DestinationGroup "readonly-flat"
sync-ADGroupMembers-As-is -SourceGroup "developers" -DestinationGroup "developers-flat"

# Only users created after 10 days in AD 
Copy-ADGroupMembers -SourceGroup "operations" -DestinationGroup "operations-flat"
Copy-ADGroupMembers -SourceGroup "admins" -DestinationGroup "admins-flat"

## Remove members that left of moved to another area - to remove access
Remove-leftMembers -SourceGroup "readonly" -DestinationGroup "readonly-flat"
Remove-leftMembers -SourceGroup "developers" -DestinationGroup "developers-flat"
Remove-leftMembers -SourceGroup "operations" -DestinationGroup "operations-flat"
Remove-leftMembers -SourceGroup "admins" -DestinationGroup "admins-flat"

# Compare * with *-flat for all 4 groups
compare-ADGroupsMembers -SourceGroup "readonly" -DestinationGroup "readonly-flat"
compare-ADGroupsMembers -SourceGroup "developers" -DestinationGroup "developers-flat"
compare-ADGroupsMembers -SourceGroup "operations" -DestinationGroup "operations-flat"
compare-ADGroupsMembers -SourceGroup "admins" -DestinationGroup "admins-flat"



