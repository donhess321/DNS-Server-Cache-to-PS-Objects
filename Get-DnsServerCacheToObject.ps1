
function Get-DNSServerCacheToObject(
    [parameter(Mandatory=$true,
               Position=0,
               ValueFromPipeline=$false,
               ValueFromPipelineByPropertyName=$true,
               HelpMessage='DNS Server to query')] 
        [string] $sDnsServerFQName,
    [Parameter(Mandatory=$true,
               Position=1,
               ValueFromPipeline=$false,
               ValueFromPipelineByPropertyName=$true,
               HelpMessage='DNS server Timezone offset. +/-00 from GMT')]
        [string] $DnsServerTzOffset=''
    ) {
    <# 
    .Synopsis 
	Get DNS Server cache records to a PS Object.
    
    .DESCRIPTION 
	Get DNS Server cache records to a PS Object. You can get the same information
	using Get-WMI.  The custom object removes some unneccesary stuff, adds a few 
	attributes, and merges multiple record types.
    
    .PARAMETER oSqlConn
	Microsoft SQL server connection object  
    
    .PARAMETER sDnsServerFQName
	DNS server fully qualified hostname
    
    .PARAMETER DnsServerTzOffset
    The timezone offset of DNS server from GMT in the format +/-00

    .EXAMPLE 
	Get-DNSServerCacheToSQL $oSqlConn $sDnsServerFQName
    
    
    .RELATED LINKS 
	NA
    
    .NOTES 
	Note that the DNS cache refreshes certain entries as you are reading it.  
	If you take a long time to read the cache there will be a slightly different 
	timestamps as records are appended to the end of the cache and you read them.  
	You will also have  records flushed from cache as you are using them so 
	DnsServerName will be $null.  There are workarounds noted in the code to 
	account for these issues.
	
	Author:
	Don Hess
	Version History:
	1.0    2016-05-12   Release
    #> 
Begin {
    # Halt on any error
    $ErrorActionPreference = "Stop"
    function DnsCacheRecordFactory([int] $iCount=1) {
    	# Create a DNSCacheRecord object(s)
    	# Input:  Number of objects needed
    	# Returns: Array of blank objects
    	$aReturned = @()
    	for ($i = 0; $i -lt $iCount; $i++) {
    		$oSingle = New-Object -TypeName System.Management.Automation.PSObject
            #Standard DNS attributes
            Add-Member -InputObject $oSingle -MemberType NoteProperty -Name TextRepresentation -Value $null  # String, this is the full answer so it needs to be long
            Add-Member -InputObject $oSingle -MemberType NoteProperty -Name RecordType -Value $null
            Add-Member -InputObject $oSingle -MemberType NoteProperty -Name DomainName -Value $null
            Add-Member -InputObject $oSingle -MemberType NoteProperty -Name OwnerName -Value $null
            Add-Member -InputObject $oSingle -MemberType NoteProperty -Name RecordData -Value $null
            Add-Member -InputObject $oSingle -MemberType NoteProperty -Name TTL -Value $null  # Integer
            Add-Member -InputObject $oSingle -MemberType NoteProperty -Name Timestamp -Value $null  # Datetime, when cached record was processed in this script
            Add-Member -InputObject $oSingle -MemberType NoteProperty -Name GMTTimestamp -Value $null  # Datetime, when cached record was processed in this script
            Add-Member -InputObject $oSingle -MemberType NoteProperty -Name PSComputerName -Value $null  # String, hostname of machine that gathered the data
    		Add-Member -InputObject $oSingle -MemberType NoteProperty -Name GMTOffset_PSComputer -Value (Get-Date -UFormat %Z) # String +/-00 from GMT
            Add-Member -InputObject $oSingle -MemberType NoteProperty -Name DnsServerName -Value $null
            # Additional specific record type attributes.  Just try to set the attributes later on and keep going if they fail
            Add-Member -InputObject $oSingle -MemberType NoteProperty -Name IPAddress -Value $null
            Add-Member -InputObject $oSingle -MemberType NoteProperty -Name MailExchange -Value $null
            Add-Member -InputObject $oSingle -MemberType NoteProperty -Name PTRDomainName -Value $null
            Add-Member -InputObject $oSingle -MemberType NoteProperty -Name Port -Value $null  # Integer
            Add-Member -InputObject $oSingle -MemberType NoteProperty -Name Preference -Value $null  # Integer
            Add-Member -InputObject $oSingle -MemberType NoteProperty -Name PrimaryName -Value $null
            Add-Member -InputObject $oSingle -MemberType NoteProperty -Name SRVDomainName -Value $null
    		$aReturned += $oSingle
    	}
        return ,$aReturned
    } 
    function Convert-DnsResourceRecordToCustomObject( 
    	[Parameter(Mandatory=$true)] [array] $aDnsRRs
        ) {
    	# Convert a DNS Resource Records to a single format  
    	# Input:   Array of DNS resource records from Get-WMI
        # Also:    $regRecType, $dtStartOfRun, $sDnsServerFQName, $sPSComputerTzOffset from outside of this function
    	# Returns: Pipeline of custom DNS resource record objects
    	$aDnsRRs | ForEach-Object {
        	$Matches = $null
    		$oSingle = (DnsCacheRecordFactory)[0] 
            $oSingle.TextRepresentation = $_.TextRepresentation
            $_.__CLASS -match $regRecType | Out-Null
            $oSingle.RecordType = $Matches.RecordType
            $oSingle.DomainName = $_.DomainName
            $oSingle.OwnerName = $_.OwnerName
            $oSingle.RecordData = $_.RecordData
            $oSingle.TTL = $_.TTL
            $oSingle.Timestamp = $dtStartOfRun
            # Next line does NOT account for 30min offset countries!!!
            $oSingle.GMTTimestamp = $oSingle.Timestamp.AddMinutes(([int] $DnsServerTzOffset)*-60) # Need inverse number so we end up at GMT.  
            # DnsServerName will be $null if the cache has expired and been flushed
            if ($null -eq $_.DnsServerName) { 
                $oSingle.DnsServerName = $sDnsServerFQName
            } else {
                $oSingle.DnsServerName = $_.DnsServerName
            }
            if ($null -eq $_.PSComputerName) {
                $oSingle.PSComputerName = $env:COMPUTERNAME
            } else {
                $oSingle.PSComputerName = $_.PSComputerName
            }
            $oSingle.GMTOffset_PSComputer = $sPSComputerTzOffset
            # Record type specific
            try { $oSingle.IPAddress = $_.IPAddress } catch { Out-Null }
            try { $oSingle.MailExchange = $_.MailExchange } catch { Out-Null }
            try { $oSingle.PTRDomainName = $_.PTRDomainName } catch { Out-Null }
            try { $oSingle.Port = $_.Port } catch { Out-Null }
            try { $oSingle.Preference = $_.Preference } catch { Out-Null }
            try { $oSingle.PrimaryName = $_.PrimaryName } catch { Out-Null }
            try { $oSingle.SRVDomainName = $_.SRVDomainName } catch { Out-Null }
            $oSingle
    	}
    } # End Convert-DnsResourceRecordToCustomObject
    $regRecType = [regex] '^MicrosoftDNS_(?<RecordType>\S{1,8})Type$'
    $sPSComputerTzOffset = (Get-Date -UFormat %Z) # String +/-00 from GMT
} # End Begin section
Process {
    if (($null -eq $sDnsServerFQName) -or ($sDnsServerFQName -eq '') -or ($sDnsServerFQName -eq '.')) {
        $oComputer = Get-WmiObject Win32_ComputerSystem
        $sDnsServerFQName = ($oComputer.Name+'.'+$oComputer.Domain)
    }
    $sDnsServerFQName = $sDnsServerFQName.ToLower()
    # Specify the types of text records you want.  https://technet.microsoft.com/en-us/library/dd197491%28v=ws.10%29.aspx
    $aRRTypes = @(
        'MicrosoftDNS_AAAAType',
        'MicrosoftDNS_AType',
        'MicrosoftDNS_CNAMEType',
        'MicrosoftDNS_MXType',
        'MicrosoftDNS_SOAType',
        'MicrosoftDNS_SRVType',
        'MicrosoftDNS_TXTType'
    )
    $aRRTypes | ForEach-Object {
        $sDnsRRType = $_
        $dtStartOfRun = Get-Date
        Write-Debug "$dtStartOfRun  Working on record type $sDnsRRType"
        # DNS class reference:  https://technet.microsoft.com/en-us/library/dd197491%28v=ws.10%29.aspx
        # This will get ALL cached records.  A, MX, PTR, NS, AAAA, etc...
        # Get-WmiObject -ComputerName . -Namespace root\MicrosoftDNS -class MicrosoftDNS_ResourceRecord
        # This will get only A record types.
        #Get-WmiObject -ComputerName . -Namespace root\MicrosoftDNS -class MicrosoftDNS_AType
        Get-WmiObject -ComputerName $sDnsServerFQName -Namespace root\MicrosoftDNS -class $sDnsRRType | ForEach-Object { 
            if ($null -eq $_) {
                return # Break out of current pipeline object (which is none anyway)
            }
            Convert-DnsResourceRecordToCustomObject @($_)
        }
    } # End $aRRTypes | ForEach-Object {
} # End -Process
} # End Get-DNSServerCacheToObject function

function Start-Get-DNSServerCacheToObject() {
    # This contents can go in some other script and passed to the Get-DNSServerCacheToObject function
    $sDnsServerFQName = '.'
    $DnsServerTzOffset = (Get-Date -UFormat %Z) # String +/-00 from GMT
    Get-DNSServerCacheToObject -sDnsServerFQName $sDnsServerFQName -DnsServerTzOffset $DnsServerTzOffset
}

Start-Get-DNSServerCacheToObject




