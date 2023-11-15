##########################################################################################
#
# Name:        check_certs.ps1
# Date:        2023-11-15
# Author:      stefan.petronijevic@atomia.com
# Version:     1.1.0
# Parameters:  Without parameters, default values 15 and 30 are used for warning and
#              critical, respectively. Custom values can be used.
#              
#              .\check_certs.ps1 10 20
#                  10 - value for WARNING
#                  20 - value for CRITICAL
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
    [int]$CriticalThreshold = 15, # Default value if not specified
    [int]$WarningThreshold = 30   # Default value if not specified
)

# Initialize the exit code - 0 means no certificates are near expiration
$exitCode = 0

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
        $exitCode = 2 # Set exit code for critical
    } elseif ($daysUntilExpiration -le $WarningThreshold) {
        Write-Host "WARNING: Certificate $($cert.Subject) will expire in $daysUntilExpiration days!"
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