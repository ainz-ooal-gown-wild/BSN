function Get-VHDChain {
    [CmdletBinding()]
    param(
        [string]$ComputerName = $env:COMPUTERNAME,
        [string[]]$Name = '*'
    )
    try {
        $VMs = Get-VM -ComputerName $ComputerName -Name $Name -ErrorAction Stop
    }
    catch {
        Write-Warning $_.Exception.Message
    }
    foreach ($vm in $VMs){
        $VHDs = ($vm).harddrives.path
        foreach ($vhd in $VHDs){
            Clear-Variable VHDType -ErrorAction SilentlyContinue
            try {
                $VHDInfo = $vhd | Get-VHD -ComputerName $ComputerName -ErrorAction Stop
            }
            catch {
                $VHDType = 'Error'
                $VHDPath = $vhd
                Write-Verbose $_.Exception.Message
            }
            $i = 1
            $problem = $false
            while (($VHDInfo.parentpath -or $i -eq 1) -and (-not($problem))){
                If ($VHDType -ne 'Error' -and $i -gt 1){
                    try {
                        $VHDInfo = $VHDInfo.ParentPath | Get-VHD -ComputerName $ComputerName -ErrorAction Stop
                    }
                    catch {
                        $VHDType = 'Error'
                        $VHDPath = $VHDInfo.parentpath
                        Write-Verbose $_.Exception.Message
                    }
                }
                if ($VHDType -ne 'Error'){
                    $VHDType = $VHDInfo.VhdType
                    $VHDPath = $VHDInfo.path
                }
                else {
                    $problem = $true
                }
                [pscustomobject]@{
                    Name = $vm.name
                    VHDNumber = $i
                    VHDType = $VHDType
                    VHD = $VHDPath
                }
                $i++
            }
        }
    }
}
################################
$vm = Read-Host("please enter the VMname") #Der VMname wird für die GetChain und Merge Functions verwendet

do {
   #Get-vhdchain -name <virtual machine name>
   Get-vhdchain -name $vm
   
   $response = Read-Host "Is the chain Error-free? If not yet, you got to delete the faulty files. Then proceed by answering 'yes' (yes/no)"
} while ($response -notmatch '^yes$')

$vhds=Get-VM $vm | Select-Object -Property VMId | Get-VHD 
if (Test-Path '.\merge.txt'){Remove-Item -Path '.\merge.txt'}
foreach($vhd in $vhds){
$chain=[ordered]@{}
    while ($vhd.ParentPath){
        $chain.add($vhd.Path,$vhd.ParentPath)
        $vhd=Get-VHD -Path $vhd.ParentPath
        }
$chain.GetEnumerator() | ForEach-Object {
    $line='Merge-VHD -Path "{0}" -Destination "{1}"' -f $_.key, $_.value
    $line | Out-File -FilePath .\merge.txt  -Append
    }    
}

$response = Read-Host "Begin auto-merge of (a)vhdx files, listed in merge.txt? (yes/no)"
if ($response -match '^y(es)?$') {
   if (Test-Path ".\merge.txt") {
       $mergeCommands = Get-Content ".\merge.txt"
       foreach ($command in $mergeCommands) {
           Write-Host "Executing: $command"
           Invoke-Expression $command
       }
   } else {
       Write-Host "Error: merge.txt not found in current directory!"
   }
} else {
   Write-Host "Auto-merging of vhdx-files stopped by user."
}