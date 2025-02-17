# if module SqlServer is installed
if (Get-Module -ListAvailable SqlServer) {
    # Import Module SqlServer
    Import-Module -Name SqlServer
} else {
    # if module SqlServer NOT insatlled, Download Module using Current User scope
    Install-Module -Name SqlServer -Scope CurrentUser -Force
    Import-Module -Name SqlServer
}

# SQL Variables
$SqlServer = ""
$SqlDBName = ""
$SchemaName = ""
$TableName = ""

# Email parameters
$smtpServer = ""
$fromEmail = ""
$toEmail = ""
$subject = ""

# Log location
$logFile = ""

# Write-Log appends log service messages to file
function Write-Log {
    param(
        [string]$message
    )
    $currentTime = Get-Date
    $logMessage = "$currentTime : $message"
    Add-Content $logFile $logMessage -Force
}

# Send-Email sends email notification
function Send-Email {
    param(
        [string]$body
    )
    $smtpParams = @{
        From       = $fromEmail
        To         = $toEmail
        Subject    = $subject
        Body       = $body
        SmtpServer = $smtpServer
    }
    Send-MailMessage @smtpParams
}

# Read-Table reads and returns data from a SQL database of machines and services to monitor
function Read-Table {
    # Table data saved to variable
    $tableData = Read-SqlTableData -ServerInstance $SqlServer -DatabaseName $SqlDBName -SchemaName $SchemaName -TableName "$TableName"
    return $tableData
}

# Update-EmailFlag runs a sql command to update email flag value
function Update-EmailFlag {
    param(
        [string]$computerName,
        [string]$serviceName,
        [int]$emailFlag
    )
    Invoke-Sqlcmd -ServerInstance $SqlServer -Encrypt Optional -Query "
        UPDATE $SqlDBName.$SchemaName.$TableName
        SET EmailFlag = $emailFlag
        WHERE ComputerName = '$computerName' AND ServiceName = '$serviceName'"
}

# Update-EmailDate runs sql command to update email date value in sql table
function Update-EmailDate {
    param(
        [string]$computerName,
        [string]$serviceName
    )
    Invoke-Sqlcmd -ServerInstance $SqlServer -Encrypt Optional -Query "
        UPDATE $SqlDBName.$SchemaName.$TableName
        SET EmailDate = GETDATE()
        WHERE ComputerName = '$computerName' AND ServiceName = '$serviceName'"
}

# Update-RestartDate runs sql command to update restart date value in sql table
function Update-RestartDate {
    param(
        [string]$computerName,
        [string]$serviceName
    )
    Invoke-Sqlcmd -ServerInstance $SqlServer -Encrypt Optional -Query "
        UPDATE $SqlDBName.$SchemaName.$TableName
        SET RestartDate = GETDATE()
        WHERE ComputerName = '$computerName' AND ServiceName = '$serviceName'"
}

# Check-Timespan returns true if current time is greater than last email attempt
function Check-TimeSpan {
    param(
        [DateTime]$emailDate,
        [int]$notiFreqHrs
    )
    # Save current date
    $currentDate = Get-Date
    # Save timespan
    $timeSpan = New-TimeSpan -Start $emailDate -End $currentDate
    # Create timespan bool
    $timeBool = ($timeSpan.Hours -ge $notiFreqHrs)

    # if current date greater than sent email date
    # AND notification frequency timeframe is greater than timespan of last email sent
    # return true to send email notification
    if ($timeBool) {
        return $true
    }
    # Dont email
    return $false
}

# Send-NotificationCheck will send an email notification if no notification has been sent
function Send-NotificationCheck {
    param(
        [string]$computerName,
        [string]$serviceName,
        [string]$message,
        [bool]$emailFlag,
        [DateTime]$emailDate,
        [int]$notiFreqHrs
        )
    # Grab time span
    $timeSpan = Check-TimeSpan -emailDate $emailDate -notiFreqHrs $notiFreqHrs
    # if email has already been sent
    if ($timeSpan -eq $false) {
        # Do nothing...
        Write-Host("$computerName : $serviceName : Notification already sent.")
        Update-EmailFlag -computerName $computerName -serviceName $serviceName -emailFlag 0
    # if email has NOT been sent
    } else {
        # Send email notification and update sql email flag to true
        Send-Email -body $message
        Update-EmailDate -computerName $computerName -serviceName $serviceName
        Update-EmailFlag -computerName $computerName -serviceName $serviceName -emailFlag 1
    }
}

# Check-ServiceStatusAndRestart checks service status and restarts service if Auto-Restart is true
function Check-ServiceStatusAndRestart {
    param(
        [string]$computerName,
        [string]$serviceName,
        [int]$restartFlag,
        [int]$emailFlag,
        [DateTime]$emailDate,
        [int]$notiFreqHrs,
        [int]$disabled
    )
    Write-Host("$computerName : Status Check : $serviceName")
    $service = Get-Service -ComputerName $computerName -Name $serviceName
    # if service is NOT running AND restart is true
    if ($service.Status -eq "Stopped" -and $restartFlag -eq $true) {
        # Restart the service
        $service | Start-Service
        $message = "$computerName : $serviceName : Encountered an error and the service has been re-started."
        Write-Host($message)        
        Send-NotificationCheck -computerName $computerName -serviceName $serviceName -message $message -emailFlag $emailFlag -emailDate $emailDate -notiFreqHrs $notiFreqHrs
        Update-RestartDate -computerName $computerName -serviceName $serviceName
        Write-Log -message $message
    # if service is NOT running AND restart is false
    } elseif ($service.Status -eq "Stopped" -and $restartFlag -eq $false -and $disabled -eq $false) {
        $message = "$computerName : $serviceName : Encountered an error and the service must be manually restarted"
        Write-Host($message)
        Send-NotificationCheck -computerName $computerName -serviceName $serviceName -message $message -emailFlag $emailFlag -emailDate $emailDate -notiFreqHrs $notiFreqHrs
        Write-Log -message $message
    # if service IS running
    } elseif ($service.Status -eq "Running") {
        # If service should NOT be running, stop the service
        if ($disabled -eq $true) {
            $service | Stop-Service
            $message = "$computerName : $serviceName : Is disabled and found running. Service has been stopped."
            Write-Host($message)        
            Send-NotificationCheck -computerName $computerName -serviceName $serviceName -message $message -emailFlag $emailFlag -emailDate $emailDate -notiFreqHrs $notiFreqHrs
            Update-RestartDate -computerName $computerName -serviceName $serviceName
            Write-Log -message $message
        } else {
            #Write-Host("$computerName : Service Running")
            Update-EmailFlag -computerName $computerName -serviceName $serviceName -emailFlag 0
        }
    }
}

# Main script block
try {
    $tableData = Read-Table
    foreach ($computer in $tableData) {
        if (Test-Connection -ComputerName $computer.ComputerName -Count 1 -Quiet) {
            $compParams = @{
                computerName = $computer.ComputerName
                serviceName = $computer.ServiceName
                restartFlag = $computer.RestartFlag
                emailFlag = $computer.EmailFlag
                emailDate = $computer.EmailDate
                notiFreqHrs = $computer.NotiFreqHrs
                disabled = $computer.Disabled
            }
            Check-ServiceStatusAndRestart @compParams
        } else {
            $message = "Unable to reach $computer.ComputerName"
            Write-Host $message
            Send-Email -body $message
            Write-Log -message $message
        }
    }
}
catch {
    $errorMessage = "Error occurred: $_"
    Write-Host $errorMessage
    Send-Email -body $errorMessage
    Write-Log -message $errorMessage
}
