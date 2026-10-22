# Define the path to the registry key
$registryPath = "HKCU:\software\policies\microsoft\office\16.0\outlook\cached mode"

# Define the value name, type, and data
$valueName = "syncwindowsetting"
$valueType = "DWORD"
$valueData = 6

# Check if the registry path exists, if not, create it
if (-not (Test-Path $registryPath)) {
    New-Item -Path $registryPath -Force
}

# Set the registry value
Set-ItemProperty -Path $registryPath -Name $valueName -Value $valueData -Type $valueType
