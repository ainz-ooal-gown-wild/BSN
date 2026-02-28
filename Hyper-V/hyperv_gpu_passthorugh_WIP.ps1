#$VM='Main-Win10Pro'
$VM='Ubuntu24.04-AI1'
Set-VM $VM -GuestControlledCacheTypes $true
$Location='PCIROOT(0)#PCI(0101)#PCI(0000)#PCI(0000)#PCI(0000)'
Write-Host "VM, Location und Cache gesetzt"

# Alternativ durch automatischen Algorithmus tauschen
Set-VM $VM -LowMemoryMappedIoSpace 512MB
Set-VM $VM -HighMemoryMappedIoSpace 1GB
Write-Host "MMIO einstellen erfolgreich"
#GPU beim Host dismounten
Dismount-VMHostAssignableDevice -force -LocationPath $Location
#GPU in VM mounten
Add-VMAssignableDevice -LocationPath $Location -VMName VMName

Write-Host "Skript ausgeführt"