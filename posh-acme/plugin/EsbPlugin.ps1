function Get-CurrentPluginType { 'dns-01' }

function Add-DnsTxt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory,Position=0)]
        [string]$RecordName,
        [Parameter(Mandatory,Position=1)]
        [string]$TxtValue,
        <#
        Add plugin specific parameters here. Make sure their names are
        unique across all existing plugins. But make sure common ones
        across this plugin are the same.
        #>
        [Parameter(Mandatory)]
        [string]$EsbSubscriptionKey,
        [string]$BasicAuthBase64
    )

    $header = @{
        Authorization = $BasicAuthBase64
        "EsbApi-Subscription-Key" = $EsbSubscriptionKey
        "Content-type" = "application/json"
    }
    
    $first, $second, $rest = $RecordName.Split(".")
    $zone = "$rest".Replace(" ", ".")
    $uri = "https://esb.zeiss.com/public/api/infoblox/record/txt?zone=$zone&name=$($first+"."+$second)&view=Internet"
    $response = (Invoke-WebRequest -Uri $uri -Method Get -Headers $header)
    
    if($response.StatusCode -eq 200){
        $content = $response.Content | ConvertFrom-Json
        Write-Verbose "Record $RecordName with value $TxtValue already exists. Nothing to do."
    } else {
    
        $body = @{
            "name" = $RecordName
            "text" = $TxtValue
            "view" = "Internet"
            "ttl" = 3600
        } | ConvertTo-Json
    
        $response = (Invoke-WebRequest -Uri "https://esb.zeiss.com/public/api/infoblox/record/txt" -Method Post -Headers $header -Body $body)
        if($response.StatusCode -eq 201){
            $content = $response.Content | ConvertFrom-Json
            Write-Verbose "Record $RecordName with value $TxtValue successfully created."
        }
    }

    <#
    .SYNOPSIS
        Add a DNS TXT record to <My DNS Server/Provider>

    .DESCRIPTION
        Description for <My DNS Server/Provider>

    .PARAMETER RecordName
        The fully qualified name of the TXT record.

    .PARAMETER TxtValue
        The value of the TXT record.

    .PARAMETER ExtraParams
        This parameter can be ignored and is only used to prevent errors when splatting with more parameters than this function supports.

    .EXAMPLE
        Add-DnsTxt '_acme-challenge.example.com' 'txt-value'

        Adds a TXT record for the specified site with the specified value.
    #>
}

function Remove-DnsTxt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory,Position=0)]
        [string]$RecordName,
        [Parameter(Mandatory,Position=1)]
        [string]$TxtValue,
        <#
        Add plugin specific parameters here. Make sure their names are
        unique across all existing plugins. But make sure common ones
        across this plugin are the same.
        #>
        [Parameter(Mandatory)]
        [string]$EsbSubscriptionKey,
        [string]$BasicAuthBase64
    )

    $header = @{
        Authorization = $BasicAuthBase64
        "EsbApi-Subscription-Key" = $EsbSubscriptionKey
        "Content-type" = "application/json"
    }

    $first, $second, $rest = $RecordName.Split(".")
    $zone = "$rest".Replace(" ", ".")
    $uri = "https://esb.zeiss.com/public/api/infoblox/record/txt?zone=$zone&name=$($first+"."+$second)&view=Internet"
    $response = (Invoke-WebRequest -Uri $uri -Method Get -Headers $header)

    if($response.StatusCode -eq 200){
        $refs = ($response.Content | ConvertFrom-Json)._ref
        foreach($ref in $refs){
            $uri = "https://esb.zeiss.com/public/api/infoblox/record?reference=$ref"
            $response = (Invoke-WebRequest -Uri $uri -Method Delete -Headers $header)
            if($response.StatusCode -eq 200){
                Write-Verbose "Record $ref successfully deleted."
            }
        }
    }

    <#
    .SYNOPSIS
        Remove a DNS TXT record from <My DNS Server/Provider>

    .DESCRIPTION
        Description for <My DNS Server/Provider>

    .PARAMETER RecordName
        The fully qualified name of the TXT record.

    .PARAMETER TxtValue
        The value of the TXT record.

    .PARAMETER ExtraParams
        This parameter can be ignored and is only used to prevent errors when splatting with more parameters than this function supports.

    .EXAMPLE
        Remove-DnsTxt '_acme-challenge.example.com' 'txt-value'

        Removes a TXT record for the specified site with the specified value.
    #>
}

function Save-DnsTxt {
    [CmdletBinding()]
    param(
        <#
        Add plugin specific parameters here. Make sure their names are
        unique across all existing plugins. But make sure common ones
        across this plugin are the same.
        #>
        [Parameter(ValueFromRemainingArguments)]
        $ExtraParams
    )

    # If necessary, do work here to save or finalize changes performed by
    # Add/Remove functions. It is not uncommon for this function to have
    # no work to do depending on the DNS provider. In that case, just
    # leave the function body empty.

    <#
    .SYNOPSIS
        Commits changes for pending DNS TXT record modifications to <My DNS Server/Provider>

    .DESCRIPTION
        Description for <My DNS Server/Provider>

    .PARAMETER ExtraParams
        This parameter can be ignored and is only used to prevent errors when splatting with more parameters than this function supports.

    .EXAMPLE
        Save-DnsTxt

        Commits changes for pending DNS TXT record modifications.
    #>
}

############################
# Helper Functions
############################

# Add a commented link to API docs if they exist.

# Add additional functions here if necessary.

# Try to follow verb-noun naming guidelines.
# https://msdn.microsoft.com/en-us/library/ms714428