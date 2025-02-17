# Service Monitoring and Auto-Restart Script

This PowerShell script monitors services on remote computers, restarts stopped services if required, and sends email notifications when issues arise.

Features
- Monitors services listed in a SQL Server database.
- Restarts services if they are stopped and auto-restart is enabled.
- Sends email notifications for service failures or manual restart requirements.
- Logs all activities to a specified log file.

Prerequisites
- PowerShell (latest version recommended)
- SQL Server PowerShell module (`SqlServer`)
- SMTP server for email notifications
- Permissions to query and modify SQL Server databases
- Administrative access to start/stop services on target machines

Installation
1. Ensure the `SqlServer` module is installed:
    ```powershell
    if (Get-Module -ListAvailable SqlServer) {
        Import-Module -Name SqlServer
    } else {
        Install-Module -Name SqlServer -Scope CurrentUser -Force
        Import-Module -Name SqlServer
    }
    ```
2. Configure the following script variables:
    ```powershell
    $SqlServer = "YourSQLServer"
    $SqlDBName = "YourDatabase"
    $SchemaName = "YourSchema"
    $TableName = "YourTable"
    
    $smtpServer = "your.smtp.server"
    $fromEmail = "your-email@example.com"
    $toEmail = "recipient@example.com"
    $subject = "Service Monitoring Alert"
    
    $logFile = "C:\Logs\ServiceMonitor.log"
    ```

Usage
1. Save the script as `ServiceMonitor.ps1`.
2. Run the script using PowerShell:
    ```powershell
    .\ServiceMonitor.ps1
    ```
3. The script will:
    - Retrieve service monitoring data from the SQL Server database.
    - Check the status of each service on remote computers.
    - Restart stopped services if required.
    - Send email notifications when issues are detected.
    - Log activities to the specified log file.

Error Handling
- If an error occurs, the script will send an email with the error message.
- If a target computer is unreachable, a notification will be sent.
- All activities are logged for auditing purposes.

Customization
- Modify the `Check-ServiceStatusAndRestart` function to adjust monitoring conditions.
- Change database queries to match your organization’s data structure.
- Adjust logging and email notification formats as needed.

License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

