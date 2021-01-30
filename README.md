# DNS-Server-Cache-to-PS-Objects

Read the DNS Server's records in memory via WMI and returns a Powershell object. Several DNS record types are merged into the single output object format as many of them have commonalities.  The idea is similar to Get-DnsServerResourceRecord from Win 2012 but in this case you get more records that just the zones that you control, you get everything the DNS Server has cached in it's memory.  Powershell v2+ is required.  This is an "object out" companion script to my DNS to SQL via Powershell project.

![Output_example](https://github.com/donhess321/DNS-Server-Cache-to-PS-Objects/blob/main/Output_example.png)
