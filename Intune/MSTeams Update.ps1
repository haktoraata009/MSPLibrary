# Run the detection command
$result = .\teamsbootstrapper.exe -p

# Check if the result contains "success": false
if ($result -match '"success": false') {
    # Run the specified command if the condition is met
    .\teamsbootstrapper.exe -p
} elseif ($result -match '"success": true') {
    # Run the specified command if the condition is met
    .\teamsbootstrapper.exe -u
    } else { return "ERROR"
    }