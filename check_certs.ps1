##########################################################################################
#
# Name:        check_certs.ps1
# Date:        2023-11-15
# Author:      stefan.petronijevic@atomia.com
# Version:     1.1.0
# Parameters:  Without parameters, default values 15 and 30 are used for warning and
#              critical, respectively. Custom values can be used.
#              
#              .\check_certs.ps1
#                  -CriticalThreshold 10
#                  -WarningThreshold 20
#                  -storeLocation "Cert:\LocalMachine\Root"
#
# Returns:
#              0 - OK
#              1 - WARNING
#              2 - CRITICAL
#
# Description: Nagios plugin that alerts whenever some certificate from store is due for
#              renewal, and alerts based on the number of days until the expiration.
#
##########################################################################################

param(
    [int]$CriticalThreshold = 15,  # Default value if not specified
    [int]$WarningThreshold = 30,   # Default value if not specified
    [string]$storeLocation = "Cert:\LocalMachine\My"  # Default certificate store location
)

# Initialize the exit code - 0 means no certificates are near expiration
$exitCode = 0

# Check if warning threshold is less than critical threshold and swap if necessary
if ($WarningThreshold -lt $CriticalThreshold) {
    $temp = $WarningThreshold
    $WarningThreshold = $CriticalThreshold
    $CriticalThreshold = $temp
}

# Get all certificates from the specified store
$certificates = Get-ChildItem -Path $storeLocation

# Current date for comparison
$currentDate = Get-Date

foreach ($cert in $certificates) {
    # Get certificate expiration date
    $expirationDate = $cert.NotAfter

    # Calculate days until expiration
    $daysUntilExpiration = ($expirationDate - $currentDate).Days

    # Check if the certificate has expired
    if ($daysUntilExpiration -lt 0) {
        Write-Host "CRITICAL: Certificate $($cert.Subject) expired on $expirationDate!"
        $exitCode = 2 # Set exit code for critical, as expired is a critical issue
    }
    # Check if the certificate is close to expiration
    elseif ($daysUntilExpiration -le $CriticalThreshold) {
        Write-Host "CRITICAL: Certificate $($cert.Subject) will expire in $daysUntilExpiration days, on $expirationDate!"
        $exitCode = 2 # Set exit code for critical
    } elseif ($daysUntilExpiration -le $WarningThreshold) {
        Write-Host "WARNING: Certificate $($cert.Subject) will expire in $daysUntilExpiration days, on $expirationDate!"
        # Only update exit code for warning if a more severe status hasn't been encountered
        if ($exitCode -ne 2) {
            $exitCode = 1
        }
    }
}

# Check exit code and output appropriate message
if ($exitCode -eq 0) {
    Write-Host "INFO: All certificates are OK!"
}

# Exit the script with the determined exit code
exit $exitCode