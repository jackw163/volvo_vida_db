# Get the computer name
$computerName = $env:COMPUTERNAME

# Define SQL Server instance name using the computer name
$serverInstance = "$computerName\VIDA"  # Assuming the instance name is always "VIDA"


# Define parameters hashtable
$parameters = @{
    ServerInstance = $serverInstance
}

# Define the list of database names
$dbnames = 'basedata', 'carcom' # Edit if you want any other tables

# Loop through each database name
foreach ($dbname in $dbnames) {
    # Skip 'imagerepository' database
    if ($dbname -eq 'imagerepository') {
        Write-Output "Skipping imagerepository database."
        continue
    }

    # Construct SQL query to get table names from the database
    $query = @"
        SELECT TABLE_NAME
        FROM $($dbname).INFORMATION_SCHEMA.TABLES
        WHERE TABLE_TYPE = 'BASE TABLE';
"@

    # Get the list of tables from the database
    try {
        $db_tables = Invoke-Sqlcmd @parameters -Database $dbname -Query $query -ErrorAction Stop
    } catch {
        Write-Error "Failed to retrieve tables from database $dbname. $_"
        continue
    }

    # Create directory for CSV files if it doesn't exist
    $folder = 'csv/' + $dbname + '/'
    if (-not (Test-Path $folder -PathType Container)) {
        try {
            New-Item -Path $folder -ItemType Directory -ErrorAction Stop
        } catch {
            Write-Error "Failed to create directory $folder. $_"
            continue
        }
    }

    # Loop through each table and export its data to a CSV file
    foreach ($table_row in $db_tables) {
        $table = $table_row.TABLE_NAME
        $file_path = Join-Path -Path $folder -ChildPath "$table.csv"

        # Check if CSV file already exists, if yes, skip exporting
        if (Test-Path $file_path -PathType Leaf) {
            Write-Output "CSV file for table $table already exists. Skipping export."
            continue
        }

        # Construct SQL query to select all data from the table
        $query = @"
            SELECT * FROM $($dbname).dbo.$table;
"@

        # Execute SQL query and export data to CSV file
        try {
            $rows = Invoke-Sqlcmd @parameters -Database $dbname -Query $query -ErrorAction Stop
            $rows | Export-Csv -Path $file_path -Encoding UTF8 -NoTypeInformation -Force
            Write-Output "Exported data from table $table to CSV file."
        } catch {
            Write-Error "Failed to export data from table $table. $_"
            continue
        }
    }
}
