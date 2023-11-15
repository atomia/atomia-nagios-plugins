param(
    [int]$CriticalThreshold = 15, # Default value if not specified
    [int]$WarningThreshold = 30   # Default value if not specified
)

# Check if warning threshold is less than critical threshold and swap if necessary
if ($WarningThreshold -lt $CriticalThreshold) {
    $temp = $WarningThreshold
    $WarningThreshold = $CriticalThreshold
    $CriticalThreshold = $temp
}

# Specify the certificate store to check
$storeLocation = "Cert:\LocalMachine\My"

# Get all certificates from the specified store
$certificates = Get-ChildItem -Path $storeLocation

# Current date for comparison
$currentDate = Get-Date

foreach ($cert in $certificates) {
    # Get certificate expiration date
    $expirationDate = $cert.NotAfter

    # Calculate days until expiration
    $daysUntilExpiration = ($expirationDate - $currentDate).Days

    # Check if the certificate is close to expiration
    if ($daysUntilExpiration -le $CriticalThreshold) {
        Write-Host "CRITICAL: Certificate $($cert.Subject) will expire in $daysUntilExpiration days!"
    } elseif ($daysUntilExpiration -le $WarningThreshold) {
        Write-Host "WARNING: Certificate $($cert.Subject) will expire in $daysUntilExpiration days!"
    }
}