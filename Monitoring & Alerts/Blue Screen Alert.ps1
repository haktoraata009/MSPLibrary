#Requires -Version 5.1

<#
.SYNOPSIS
    Scans the Event Viewer for Blue Screen of Death (BSOD) events and generates an alert if any are detected within the specified time frame. Optionally, the results can be saved to a custom field.
.DESCRIPTION
    Scans the Event Viewer for Blue Screen of Death (BSOD) events and generates an alert if any are detected within the specified time frame. Optionally, the results can be saved to a custom field.
.EXAMPLE
    -MinutesAgo 60 -MaxEvents 25 -MultilineCustomField "Multiline" -WYSIWYGCustomField "WYSIWYG"

    Checking for BSOD Event Log entries.

    No BSOD Events detected in the past '60' minutes.

    ### All BSOD Events Detected ###
    Date      : 11/26/2025 2:40 PM
    EventID   : 1001
    Reason    : DRIVER_IRQL_NOT_LESS_OR_EQUAL
    Dumpfile  : C:\Windows\Minidump\112625-3187-01.dmp
    Link      : https://learn.microsoft.com/windows-hardware/drivers/debugger/bug-check-0xd1--driver-irql-not-less-or-equal
    ErrorCode : 0x000000d1

    Date      : 11/19/2025 9:47 AM
    EventID   : 1001
    Reason    : DRIVER_IRQL_NOT_LESS_OR_EQUAL
    Dumpfile  : C:\Windows\Minidump\111925-3312-01.dmp
    Link      : https://learn.microsoft.com/windows-hardware/drivers/debugger/bug-check-0xd1--driver-irql-not-less-or-equal
    ErrorCode : 0x000000d1

    Attempting to save the results to the custom field 'Multiline'.
    Success.
    Attempting to save the results to the custom field 'WYSIWYG'.
    Success.

.EXAMPLE
    -MinutesAgo 320 -MaxEvents 25 -MultilineCustomField "Multiline" -WYSIWYGCustomField "WYSIWYG"

    Checking for BSOD Event Log entries.

    [Alert] One or more BSODs were detected in the past '320' minutes.

    ### BSOD Events in the Past 320 Minutes ###
    Date      : 11/26/2025 2:40 PM
    EventID   : 1001
    Reason    : DRIVER_IRQL_NOT_LESS_OR_EQUAL
    Dumpfile  : C:\Windows\Minidump\112625-3187-01.dmp
    Link      : https://learn.microsoft.com/windows-hardware/drivers/debugger/bug-check-0xd1--driver-irql-not-less-or-equal
    ErrorCode : 0x000000d1

    Attempting to save the results to the custom field 'Multiline'.
    Success.
    Attempting to save the results to the custom field 'WYSIWYG'.
    Success.

.PARAMETER MinutesAgo
    Outputs an alert message if a BSOD was detected in the past x minutes. Must be between 1 and 10,080 minutes (inclusive).

.PARAMETER MaxEvents
    Specifies the maximum number of events to return. Must be between 1 and 1,000 events (inclusive).

.PARAMETER MultilineCustomField
    The name of a multiline custom field to save BSOD events.

.PARAMETER WYSIWYGCustomField
    The name of a WYSIWYG custom field to save BSOD events.

.PARAMETER SaveFullHistory
    When saving the results to a custom field, save the full history (within the maximum event cap) instead of only the events that triggered the alert.

.NOTES
    Minimum OS Architecture Supported: Windows 10, Windows Server 2016
    Version: 2.0
    Release Notes: Removed dependency, capped the number of events returned, only alert when within a specified threshold, and added custom field output.
#>

[CmdletBinding()]
param (
    [Parameter()]
    [Int]$MinutesAgo = 60,
    [Parameter()]
    [Int]$MaxEvents = 25,
    [Parameter()]
    [String]$MultilineCustomField,
    [Parameter()]
    [String]$WYSIWYGCustomField,
    [Parameter()]
    [Switch]$SaveFullHistory = [System.Convert]::ToBoolean($env:saveFullHistory)
)

begin {
    if ($env:multilineCustomFieldName) { $MultilineCustomField = $env:multilineCustomFieldName }
    if ($env:wysiwygCustomFieldName) { $WYSIWYGCustomField = $env:wysiwygCustomFieldName }

    #region Input Validation
    if ($env:minutesAgo) {
        try {
            $ErrorActionPreference = "Stop"
            $MinutesAgo = $env:minutesAgo
            $ErrorActionPreference = "Continue"
        } catch {
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] The provided 'Minutes Ago' value is invalid. It must be between 1 and 10080 minutes (inclusive)."
            $ErrorActionPreference = "Continue"
            exit 1
        }
    }

    if ($env:maxEvents) {
        try {
            $ErrorActionPreference = "Stop"
            $MaxEvents = $env:maxEvents
            $ErrorActionPreference = "Continue"
        } catch {
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] The provided 'Max Events' value is invalid. It must be between 1 and 1000 events (inclusive)."
            $ErrorActionPreference = "Continue"
            exit 1
        }
    }

    # Validate the operating system build version to ensure compatibility
    if ([System.Environment]::OSVersion.Version.Build -lt 10240) {
        Write-Host -Object "`n[Warning] The minimum OS version supported by this script is Windows 10 (10240) or Windows Server 2016 (14393)."
        Write-Host -Object "[Warning] OS build '$([System.Environment]::OSVersion.Version.Build)' detected. This could lead to errors or unexpected results.`n"
    }

    # Validate the 'Minutes Ago' parameter to ensure it is within the allowed range
    if ($MinutesAgo -le 0 -or $MinutesAgo -gt 10080) {
        Write-Host -Object "[Error] The provided 'Minutes Ago' value '$MinutesAgo' is invalid. It must be between 1 and 10080 minutes (inclusive)."
        exit 1
    }

    # Validate the 'Max Events' parameter to ensure it is within the allowed range
    if ($MaxEvents -le 0 -or $MaxEvents -gt 1000) {
        Write-Host -Object "[Error] The provided 'Max Events' value is invalid. It must be between 1 and 1000 events (inclusive)."
        exit 1
    }

    # Validate the Multiline custom field name if provided
    if ($MultilineCustomField) {
        # Ensure the field name is not just whitespace
        if ([string]::IsNullOrWhiteSpace($MultilineCustomField)) {
            Write-Host "[Error] The 'Multiline Custom Field Name' parameter contains only spaces. Please provide a valid field name or leave it blank."
            exit 1
        }

        # Trim leading and trailing whitespace from the field name
        $MultilineCustomField = $MultilineCustomField.Trim()

        # Ensure the field name contains only alphanumeric characters
        if ($MultilineCustomField -match "[^0-9A-Z]") {
            Write-Host -Object "[Error] The 'Multiline Custom Field Name' of '$MultilineCustomField' contains invalid characters."
            Write-Host -Object "[Error] Please provide a valid multiline custom field name to save the results, or leave it blank."
            Write-Host -Object "[Error] https://ninjarmm.zendesk.com/hc/articles/360060920631-Custom-Field-Setup"
            exit 1
        }
    }

    # Validate the WYSIWYG custom field name if provided
    if ($WYSIWYGCustomField) {
        # Ensure the field name is not just whitespace
        if ([string]::IsNullOrWhiteSpace($WYSIWYGCustomField)) {
            Write-Host "[Error] The 'WYSIWYG Custom Field Name' parameter contains only spaces. Please provide a valid field name or leave it blank."
            exit 1
        }

        # Trim leading and trailing whitespace from the field name
        $WYSIWYGCustomField = $WYSIWYGCustomField.Trim()

        # Ensure the field name contains only alphanumeric characters
        if ($WYSIWYGCustomField -match "[^0-9A-Z]") {
            Write-Host -Object "[Error] The 'WYSIWYG Custom Field Name' of '$WYSIWYGCustomField' contains invalid characters."
            Write-Host -Object "[Error] Please provide a valid WYSIWYG custom field name to save the results, or leave it blank."
            Write-Host -Object "[Error] https://ninjarmm.zendesk.com/hc/en-us/articles/360060920631-Custom-Field-Setup"
            exit 1
        }
    }

    # Ensure the WYSIWYG and Multiline custom fields are not the same
    if ($WYSIWYGCustomField -and $MultilineCustomField -and $WYSIWYGCustomField -eq $MultilineCustomField) {
        Write-Host -Object "[Error] You provided the same custom field name '$WYSIWYGCustomField' for both custom fields."
        exit 1
    }

    if ($SaveFullHistory -and !$MultilineCustomField -and !$WYSIWYGCustomField) {
        Write-Host -Object "[Warning] 'Save Full History' was specified, but no custom field name was given to save to. This option will be ignored."
    }

    #endregion

    #region BugCheck HashTable
    # Every bugcheck code with accompanying reason and url slug.
    $BugCheckCodes = @{
        "0x00000001" = @{ Name = "APC_INDEX_MISMATCH"; Slug = "bug-check-0x1--apc-index-mismatch" }
        "0x00000002" = @{ Name = "DEVICE_QUEUE_NOT_BUSY"; Slug = "bug-check-0x2--device-queue-not-busy" }
        "0x00000003" = @{ Name = "INVALID_AFFINITY_SET"; Slug = "bug-check-0x3--invalid-affinity-set" }
        "0x00000004" = @{ Name = "INVALID_DATA_ACCESS_TRAP"; Slug = "bug-check-0x4--invalid-data-access-trap" }
        "0x00000005" = @{ Name = "INVALID_PROCESS_ATTACH_ATTEMPT"; Slug = "bug-check-0x5--invalid-process-attach-attempt" }
        "0x00000006" = @{ Name = "INVALID_PROCESS_DETACH_ATTEMPT"; Slug = "bug-check-0x6--invalid-process-detach-attempt" }
        "0x00000007" = @{ Name = "INVALID_SOFTWARE_INTERRUPT"; Slug = "bug-check-0x7--invalid-software-interrupt" }
        "0x00000008" = @{ Name = "IRQL_NOT_DISPATCH_LEVEL"; Slug = "bug-check-0x8--irql-not-dispatch-level" }
        "0x00000009" = @{ Name = "IRQL_NOT_GREATER_OR_EQUAL"; Slug = "bug-check-0x9--irql-not-greater-or-equal" }
        "0x0000000A" = @{ Name = "IRQL_NOT_LESS_OR_EQUAL"; Slug = "bug-check-0xa--irql-not-less-or-equal" }
        "0x0000000B" = @{ Name = "NO_EXCEPTION_HANDLING_SUPPORT"; Slug = "bug-check-0xb--no-exception-handling-support" }
        "0x0000000C" = @{ Name = "MAXIMUM_WAIT_OBJECTS_EXCEEDED"; Slug = "bug-check-0xc--maximum-wait-objects-exceeded" }
        "0x0000000D" = @{ Name = "MUTEX_LEVEL_NUMBER_VIOLATION"; Slug = "bug-check-0xd--mutex-level-number-violation" }
        "0x0000000E" = @{ Name = "NO_USER_MODE_CONTEXT"; Slug = "bug-check-0xe--no-user-mode-context" }
        "0x0000000F" = @{ Name = "SPIN_LOCK_ALREADY_OWNED"; Slug = "bug-check-0xf--spin-lock-already-owned" }
        "0x00000010" = @{ Name = "SPIN_LOCK_NOT_OWNED"; Slug = "bug-check-0x10--spin-lock-not-owned" }
        "0x00000011" = @{ Name = "THREAD_NOT_MUTEX_OWNER"; Slug = "bug-check-0x11--thread-not-mutex-owner" }
        "0x00000012" = @{ Name = "TRAP_CAUSE_UNKNOWN"; Slug = "bug-check-0x12--trap-cause-unknown" }
        "0x00000013" = @{ Name = "EMPTY_THREAD_REAPER_LIST"; Slug = "bug-check-0x13--empty-thread-reaper-list" }
        "0x00000014" = @{ Name = "CREATE_DELETE_LOCK_NOT_LOCKED"; Slug = "bug-check-0x14--create-delete-lock-not-locked" }
        "0x00000015" = @{ Name = "LAST_CHANCE_CALLED_FROM_KMODE"; Slug = "bug-check-0x15--last-chance-called-from-kmode" }
        "0x00000016" = @{ Name = "CID_HANDLE_CREATION"; Slug = "bug-check-0x16--cid-handle-creation" }
        "0x00000017" = @{ Name = "CID_HANDLE_DELETION"; Slug = "bug-check-0x17--cid-handle-deletion" }
        "0x00000018" = @{ Name = "REFERENCE_BY_POINTER"; Slug = "bug-check-0x18--reference-by-pointer" }
        "0x00000019" = @{ Name = "BAD_POOL_HEADER"; Slug = "bug-check-0x19--bad-pool-header" }
        "0x0000001A" = @{ Name = "MEMORY_MANAGEMENT"; Slug = "bug-check-0x1a--memory-management" }
        "0x0000001B" = @{ Name = "PFN_SHARE_COUNT"; Slug = "bug-check-0x1b--pfn-share-count" }
        "0x0000001C" = @{ Name = "PFN_REFERENCE_COUNT"; Slug = "bug-check-0x1c--pfn-reference-count" }
        "0x0000001D" = @{ Name = "NO_SPIN_LOCK_AVAILABLE"; Slug = "bug-check-0x1d--no-spin-lock-available" }
        "0x0000001E" = @{ Name = "KMODE_EXCEPTION_NOT_HANDLED"; Slug = "bug-check-0x1e--kmode-exception-not-handled" }
        "0x0000001F" = @{ Name = "SHARED_RESOURCE_CONV_ERROR"; Slug = "bug-check-0x1f--shared-resource-conv-error" }
        "0x00000020" = @{ Name = "KERNEL_APC_PENDING_DURING_EXIT"; Slug = "bug-check-0x20--kernel-apc-pending-during-exit" }
        "0x00000021" = @{ Name = "QUOTA_UNDERFLOW"; Slug = "bug-check-0x21--quota-underflow" }
        "0x00000022" = @{ Name = "FILE_SYSTEM"; Slug = "bug-check-0x22--file-system" }
        "0x00000023" = @{ Name = "FAT_FILE_SYSTEM"; Slug = "bug-check-0x23--fat-file-system" }
        "0x00000024" = @{ Name = "NTFS_FILE_SYSTEM"; Slug = "bug-check-0x24--ntfs-file-system" }
        "0x00000025" = @{ Name = "NPFS_FILE_SYSTEM"; Slug = "bug-check-0x25--npfs-file-system" }
        "0x00000026" = @{ Name = "CDFS_FILE_SYSTEM"; Slug = "bug-check-0x26--cdfs-file-system" }
        "0x00000027" = @{ Name = "RDR_FILE_SYSTEM"; Slug = "bug-check-0x27--rdr-file-system" }
        "0x00000028" = @{ Name = "CORRUPT_ACCESS_TOKEN"; Slug = "bug-check-0x28--corrupt-access-token" }
        "0x00000029" = @{ Name = "SECURITY_SYSTEM"; Slug = "bug-check-0x29--security-system" }
        "0x0000002A" = @{ Name = "INCONSISTENT_IRP"; Slug = "bug-check-0x2a--inconsistent-irp" }
        "0x0000002B" = @{ Name = "PANIC_STACK_SWITCH"; Slug = "bug-check-0x2b--panic-stack-switch" }
        "0x0000002C" = @{ Name = "PORT_DRIVER_INTERNAL"; Slug = "bug-check-0x2c--port-driver-internal" }
        "0x0000002D" = @{ Name = "SCSI_DISK_DRIVER_INTERNAL"; Slug = "bug-check-0x2d--scsi-disk-driver-internal" }
        "0x0000002E" = @{ Name = "DATA_BUS_ERROR"; Slug = "bug-check-0x2e--data-bus-error" }
        "0x0000002F" = @{ Name = "INSTRUCTION_BUS_ERROR"; Slug = "bug-check-0x2f--instruction-bus-error" }
        "0x00000030" = @{ Name = "SET_OF_INVALID_CONTEXT"; Slug = "bug-check-0x30--set-of-invalid-context" }
        "0x00000031" = @{ Name = "PHASE0_INITIALIZATION_FAILED"; Slug = "bug-check-0x31--phase0-initialization-failed" }
        "0x00000032" = @{ Name = "PHASE1_INITIALIZATION_FAILED"; Slug = "bug-check-0x32--phase1-initialization-failed" }
        "0x00000033" = @{ Name = "UNEXPECTED_INITIALIZATION_CALL"; Slug = "bug-check-0x33--unexpected-initialization-call" }
        "0x00000034" = @{ Name = "CACHE_MANAGER"; Slug = "bug-check-0x34--cache-manager" }
        "0x00000035" = @{ Name = "NO_MORE_IRP_STACK_LOCATIONS"; Slug = "bug-check-0x35--no-more-irp-stack-locations" }
        "0x00000036" = @{ Name = "DEVICE_REFERENCE_COUNT_NOT_ZERO"; Slug = "bug-check-0x36--device-reference-count-not-zero" }
        "0x00000037" = @{ Name = "FLOPPY_INTERNAL_ERROR"; Slug = "bug-check-0x37--floppy-internal-error" }
        "0x00000038" = @{ Name = "SERIAL_DRIVER_INTERNAL"; Slug = "bug-check-0x38--serial-driver-internal" }
        "0x00000039" = @{ Name = "SYSTEM_EXIT_OWNED_MUTEX"; Slug = "bug-check-0x39--system-exit-owned-mutex" }
        "0x0000003A" = @{ Name = "SYSTEM_UNWIND_PREVIOUS_USER"; Slug = "bug-check-0x3a--system-unwind-previous-user" }
        "0x0000003B" = @{ Name = "SYSTEM_SERVICE_EXCEPTION"; Slug = "bug-check-0x3b--system-service-exception" }
        "0x0000003C" = @{ Name = "INTERRUPT_UNWIND_ATTEMPTED"; Slug = "bug-check-0x3c--interrupt-unwind-attempted" }
        "0x0000003D" = @{ Name = "INTERRUPT_EXCEPTION_NOT_HANDLED"; Slug = "bug-check-0x3d--interrupt-exception-not-handled" }
        "0x0000003E" = @{ Name = "MULTIPROCESSOR_CONFIGURATION_NOT_SUPPORTED"; Slug = "bug-check-0x3e--multiprocessor-configuration-not-supported" }
        "0x0000003F" = @{ Name = "NO_MORE_SYSTEM_PTES"; Slug = "bug-check-0x3f--no-more-system-ptes" }
        "0x00000040" = @{ Name = "TARGET_MDL_TOO_SMALL"; Slug = "bug-check-0x40--target-mdl-too-small" }
        "0x00000041" = @{ Name = "MUST_SUCCEED_POOL_EMPTY"; Slug = "bug-check-0x41--must-succeed-pool-empty" }
        "0x00000042" = @{ Name = "ATDISK_DRIVER_INTERNAL"; Slug = "bug-check-0x42--atdisk-driver-internal" }
        "0x00000043" = @{ Name = "NO_SUCH_PARTITION"; Slug = "bug-check-0x43--no-such-partition" }
        "0x00000044" = @{ Name = "MULTIPLE_IRP_COMPLETE_REQUESTS"; Slug = "bug-check-0x44--multiple-irp-complete-requests" }
        "0x00000045" = @{ Name = "INSUFFICIENT_SYSTEM_MAP_REGS"; Slug = "bug-check-0x45--insufficient-system-map-regs" }
        "0x00000046" = @{ Name = "DEREF_UNKNOWN_LOGON_SESSION"; Slug = "bug-check-0x46--deref-unknown-logon-session" }
        "0x00000047" = @{ Name = "REF_UNKNOWN_LOGON_SESSION"; Slug = "bug-check-0x47--ref-unknown-logon-session" }
        "0x00000048" = @{ Name = "CANCEL_STATE_IN_COMPLETED_IRP"; Slug = "bug-check-0x48--cancel-state-in-completed-irp" }
        "0x00000049" = @{ Name = "PAGE_FAULT_WITH_INTERRUPTS_OFF"; Slug = "bug-check-0x49--page-fault-with-interrupts-off" }
        "0x0000004A" = @{ Name = "IRQL_GT_ZERO_AT_SYSTEM_SERVICE"; Slug = "bug-check-0x4a--irql-gt-zero-at-system-service" }
        "0x0000004B" = @{ Name = "STREAMS_INTERNAL_ERROR"; Slug = "bug-check-0x4b--streams-internal-error" }
        "0x0000004C" = @{ Name = "FATAL_UNHANDLED_HARD_ERROR"; Slug = "bug-check-0x4c--fatal-unhandled-hard-error" }
        "0x0000004D" = @{ Name = "NO_PAGES_AVAILABLE"; Slug = "bug-check-0x4d--no-pages-available" }
        "0x0000004E" = @{ Name = "PFN_LIST_CORRUPT"; Slug = "bug-check-0x4e--pfn-list-corrupt" }
        "0x0000004F" = @{ Name = "NDIS_INTERNAL_ERROR"; Slug = "bug-check-0x4f--ndis-internal-error" }
        "0x00000050" = @{ Name = "PAGE_FAULT_IN_NONPAGED_AREA"; Slug = "bug-check-0x50--page-fault-in-nonpaged-area" }
        "0x00000051" = @{ Name = "REGISTRY_ERROR"; Slug = "bug-check-0x51--registry-error" }
        "0x00000052" = @{ Name = "MAILSLOT_FILE_SYSTEM"; Slug = "bug-check-0x52--mailslot-file-system" }
        "0x00000053" = @{ Name = "NO_BOOT_DEVICE"; Slug = "bug-check-0x53--no-boot-device" }
        "0x00000054" = @{ Name = "LM_SERVER_INTERNAL_ERROR"; Slug = "bug-check-0x54--lm-server-internal-error" }
        "0x00000055" = @{ Name = "DATA_COHERENCY_EXCEPTION"; Slug = "bug-check-0x55--data-coherency-exception" }
        "0x00000056" = @{ Name = "INSTRUCTION_COHERENCY_EXCEPTION"; Slug = "bug-check-0x56--instruction-coherency-exception" }
        "0x00000057" = @{ Name = "XNS_INTERNAL_ERROR"; Slug = "bug-check-0x57--xns-internal-error" }
        "0x00000058" = @{ Name = "FTDISK_INTERNAL_ERROR"; Slug = "bug-check-0x58--ftdisk-internal-error" }
        "0x00000059" = @{ Name = "PINBALL_FILE_SYSTEM"; Slug = "bug-check-0x59--pinball-file-system" }
        "0x0000005A" = @{ Name = "CRITICAL_SERVICE_FAILED"; Slug = "bug-check-0x5a--critical-service-failed" }
        "0x0000005B" = @{ Name = "SET_ENV_VAR_FAILED"; Slug = "bug-check-0x5b--set-env-var-failed" }
        "0x0000005C" = @{ Name = "HAL_INITIALIZATION_FAILED"; Slug = "bug-check-0x5c--hal-initialization-failed" }
        "0x0000005D" = @{ Name = "UNSUPPORTED_PROCESSOR"; Slug = "bug-check-0x5d--unsupported-processor" }
        "0x0000005E" = @{ Name = "OBJECT_INITIALIZATION_FAILED"; Slug = "bug-check-0x5e--object-initialization-failed" }
        "0x0000005F" = @{ Name = "SECURITY_INITIALIZATION_FAILED"; Slug = "bug-check-0x5f--security-initialization-failed" }
        "0x00000060" = @{ Name = "PROCESS_INITIALIZATION_FAILED"; Slug = "bug-check-0x60--process-initialization-failed" }
        "0x00000061" = @{ Name = "HAL1_INITIALIZATION_FAILED"; Slug = "bug-check-0x61--hal1-initialization-failed" }
        "0x00000062" = @{ Name = "OBJECT1_INITIALIZATION_FAILED"; Slug = "bug-check-0x62--object1-initialization-failed" }
        "0x00000063" = @{ Name = "SECURITY1_INITIALIZATION_FAILED"; Slug = "bug-check-0x63--security1-initialization-failed" }
        "0x00000064" = @{ Name = "SYMBOLIC_INITIALIZATION_FAILED"; Slug = "bug-check-0x64--symbolic-initialization-failed" }
        "0x00000065" = @{ Name = "MEMORY1_INITIALIZATION_FAILED"; Slug = "bug-check-0x65--memory1-initialization-failed" }
        "0x00000066" = @{ Name = "CACHE_INITIALIZATION_FAILED"; Slug = "bug-check-0x66--cache-initialization-failed" }
        "0x00000067" = @{ Name = "CONFIG_INITIALIZATION_FAILED"; Slug = "bug-check-0x67--config-initialization-failed" }
        "0x00000068" = @{ Name = "FILE_INITIALIZATION_FAILED"; Slug = "bug-check-0x68--file-initialization-failed" }
        "0x00000069" = @{ Name = "IO1_INITIALIZATION_FAILED"; Slug = "bug-check-0x69--io1-initialization-failed" }
        "0x0000006A" = @{ Name = "LPC_INITIALIZATION_FAILED"; Slug = "bug-check-0x6a--lpc-initialization-failed" }
        "0x0000006B" = @{ Name = "PROCESS1_INITIALIZATION_FAILED"; Slug = "bug-check-0x6b--process1-initialization-failed" }
        "0x0000006C" = @{ Name = "REFMON_INITIALIZATION_FAILED"; Slug = "bug-check-0x6c--refmon-initialization-failed" }
        "0x0000006D" = @{ Name = "SESSION1_INITIALIZATION_FAILED"; Slug = "bug-check-0x6d--session1-initialization-failed" }
        "0x0000006E" = @{ Name = "SESSION2_INITIALIZATION_FAILED"; Slug = "bug-check-0x6e--session2-initialization-failed" }
        "0x0000006F" = @{ Name = "SESSION3_INITIALIZATION_FAILED"; Slug = "bug-check-0x6f--session3-initialization-failed" }
        "0x00000070" = @{ Name = "SESSION4_INITIALIZATION_FAILED"; Slug = "bug-check-0x70--session4-initialization-failed" }
        "0x00000071" = @{ Name = "SESSION5_INITIALIZATION_FAILED"; Slug = "bug-check-0x71--session5-initialization-failed" }
        "0x00000072" = @{ Name = "ASSIGN_DRIVE_LETTERS_FAILED"; Slug = "bug-check-0x72--assign-drive-letters-failed" }
        "0x00000073" = @{ Name = "CONFIG_LIST_FAILED"; Slug = "bug-check-0x73--config-list-failed" }
        "0x00000074" = @{ Name = "BAD_SYSTEM_CONFIG_INFO"; Slug = "bug-check-0x74--bad-system-config-info" }
        "0x00000075" = @{ Name = "CANNOT_WRITE_CONFIGURATION"; Slug = "bug-check-0x75--cannot-write-configuration" }
        "0x00000076" = @{ Name = "PROCESS_HAS_LOCKED_PAGES"; Slug = "bug-check-0x76--process-has-locked-pages" }
        "0x00000077" = @{ Name = "KERNEL_STACK_INPAGE_ERROR"; Slug = "bug-check-0x77--kernel-stack-inpage-error" }
        "0x00000078" = @{ Name = "PHASE0_EXCEPTION"; Slug = "bug-check-0x78--phase0-exception" }
        "0x00000079" = @{ Name = "MISMATCHED_HAL"; Slug = "bug-check-0x79--mismatched-hal" }
        "0x0000007A" = @{ Name = "KERNEL_DATA_INPAGE_ERROR"; Slug = "bug-check-0x7a--kernel-data-inpage-error" }
        "0x0000007B" = @{ Name = "INACCESSIBLE_BOOT_DEVICE"; Slug = "bug-check-0x7b--inaccessible-boot-device" }
        "0x0000007C" = @{ Name = "BUGCODE_NDIS_DRIVER"; Slug = "bug-check-0x7c--bugcode-ndis-driver" }
        "0x0000007D" = @{ Name = "INSTALL_MORE_MEMORY"; Slug = "bug-check-0x7d--install-more-memory" }
        "0x0000007E" = @{ Name = "SYSTEM_THREAD_EXCEPTION_NOT_HANDLED"; Slug = "bug-check-0x7e--system-thread-exception-not-handled" }
        "0x0000007F" = @{ Name = "UNEXPECTED_KERNEL_MODE_TRAP"; Slug = "bug-check-0x7f--unexpected-kernel-mode-trap" }
        "0x00000080" = @{ Name = "NMI_HARDWARE_FAILURE"; Slug = "bug-check-0x80--nmi-hardware-failure" }
        "0x00000081" = @{ Name = "SPIN_LOCK_INIT_FAILURE"; Slug = "bug-check-0x81--spin-lock-init-failure" }
        "0x00000082" = @{ Name = "DFS_FILE_SYSTEM"; Slug = "bug-check-0x82--dfs-file-system" }
        "0x00000085" = @{ Name = "SETUP_FAILURE"; Slug = "bug-check-0x85--setup-failure" }
        "0x0000008B" = @{ Name = "MBR_CHECKSUM_MISMATCH"; Slug = "bug-check-0x8b--mbr-checksum-mismatch" }
        "0x0000008E" = @{ Name = "KERNEL_MODE_EXCEPTION_NOT_HANDLED"; Slug = "bug-check-0x8e--kernel-mode-exception-not-handled" }
        "0x0000008F" = @{ Name = "PP0_INITIALIZATION_FAILED"; Slug = "bug-check-0x8f--pp0-initialization-failed" }
        "0x00000090" = @{ Name = "PP1_INITIALIZATION_FAILED"; Slug = "bug-check-0x90--pp1-initialization-failed" }
        "0x00000092" = @{ Name = "UP_DRIVER_ON_MP_SYSTEM"; Slug = "bug-check-0x92--up-driver-on-mp-system" }
        "0x00000093" = @{ Name = "INVALID_KERNEL_HANDLE"; Slug = "bug-check-0x93--invalid-kernel-handle" }
        "0x00000094" = @{ Name = "KERNEL_STACK_LOCKED_AT_EXIT"; Slug = "bug-check-0x94--kernel-stack-locked-at-exit" }
        "0x00000096" = @{ Name = "INVALID_WORK_QUEUE_ITEM"; Slug = "bug-check-0x96--invalid-work-queue-item" }
        "0x00000097" = @{ Name = "BOUND_IMAGE_UNSUPPORTED"; Slug = "bug-check-0x97--bound-image-unsupported" }
        "0x00000098" = @{ Name = "END_OF_NT_EVALUATION_PERIOD"; Slug = "bug-check-0x98--end-of-nt-evaluation-period" }
        "0x00000099" = @{ Name = "INVALID_REGION_OR_SEGMENT"; Slug = "bug-check-0x99--invalid-region-or-segment" }
        "0x0000009A" = @{ Name = "SYSTEM_LICENSE_VIOLATION"; Slug = "bug-check-0x9a--system-license-violation" }
        "0x0000009B" = @{ Name = "UDFS_FILE_SYSTEM"; Slug = "bug-check-0x9b--udfs-file-system" }
        "0x0000009C" = @{ Name = "MACHINE_CHECK_EXCEPTION"; Slug = "bug-check-0x9c--machine-check-exception" }
        "0x0000009E" = @{ Name = "USER_MODE_HEALTH_MONITOR"; Slug = "bug-check-0x9e--user-mode-health-monitor" }
        "0x0000009F" = @{ Name = "DRIVER_POWER_STATE_FAILURE"; Slug = "bug-check-0x9f--driver-power-state-failure" }
        "0x000000A0" = @{ Name = "INTERNAL_POWER_ERROR"; Slug = "bug-check-0xa0--internal-power-error" }
        "0x000000A1" = @{ Name = "PCI_BUS_DRIVER_INTERNAL"; Slug = "bug-check-0xa1--pci-bus-driver-internal" }
        "0x000000A2" = @{ Name = "MEMORY_IMAGE_CORRUPT"; Slug = "bug-check-0xa2--memory-image-corrupt" }
        "0x000000A3" = @{ Name = "ACPI_DRIVER_INTERNAL"; Slug = "bug-check-0xa3--acpi-driver-internal" }
        "0x000000A4" = @{ Name = "CNSS_FILE_SYSTEM_FILTER"; Slug = "bug-check-0xa4--cnss-file-system-filter" }
        "0x000000A5" = @{ Name = "ACPI_BIOS_ERROR"; Slug = "bug-check-0xa5--acpi-bios-error" }
        "0x000000A7" = @{ Name = "BAD_EXHANDLE"; Slug = "bug-check-0xa7--bad-exhandle" }
        "0x000000AC" = @{ Name = "HAL_MEMORY_ALLOCATION"; Slug = "bug-check-0xac--hal-memory-allocation" }
        "0x000000AD" = @{ Name = "VIDEO_DRIVER_DEBUG_REPORT_REQUEST"; Slug = "bug-check-0xad--video-driver-debug-report-request" }
        "0x000000B1" = @{ Name = "BGI_DETECTED_VIOLATION"; Slug = "bug-check-0xb1--bgi-detected-violation" }
        "0x000000B4" = @{ Name = "VIDEO_DRIVER_INIT_FAILURE"; Slug = "bug-check-0xb4--video-driver-init-failure" }
        "0x000000B8" = @{ Name = "ATTEMPTED_SWITCH_FROM_DPC"; Slug = "bug-check-0xb8--attempted-switch-from-dpc" }
        "0x000000B9" = @{ Name = "CHIPSET_DETECTED_ERROR"; Slug = "bug-check-0xb9--chipset-detected-error" }
        "0x000000BA" = @{ Name = "SESSION_HAS_VALID_VIEWS_ON_EXIT"; Slug = "bug-check-0xba--session-has-valid-views-on-exit" }
        "0x000000BB" = @{ Name = "NETWORK_BOOT_INITIALIZATION_FAILED"; Slug = "bug-check-0xbb--network-boot-initialization-failed" }
        "0x000000BC" = @{ Name = "NETWORK_BOOT_DUPLICATE_ADDRESS"; Slug = "bug-check-0xbc--network-boot-duplicate-address" }
        "0x000000BD" = @{ Name = "INVALID_HIBERNATED_STATE"; Slug = "bug-check-0xbd--invalid-hibernated-state" }
        "0x000000BE" = @{ Name = "ATTEMPTED_WRITE_TO_READONLY_MEMORY"; Slug = "bug-check-0xbe--attempted-write-to-readonly-memory" }
        "0x000000BF" = @{ Name = "MUTEX_ALREADY_OWNED"; Slug = "bug-check-0xbf--mutex-already-owned" }
        "0x000000C1" = @{ Name = "SPECIAL_POOL_DETECTED_MEMORY_CORRUPTION"; Slug = "bug-check-0xc1--special-pool-detected-memory-corruption" }
        "0x000000C2" = @{ Name = "BAD_POOL_CALLER"; Slug = "bug-check-0xc2--bad-pool-caller" }
        "0x000000C4" = @{ Name = "DRIVER_VERIFIER_DETECTED_VIOLATION"; Slug = "bug-check-0xc4--driver-verifier-detected-violation" }
        "0x000000C5" = @{ Name = "DRIVER_CORRUPTED_EXPOOL"; Slug = "bug-check-0xc5--driver-corrupted-expool" }
        "0x000000C6" = @{ Name = "DRIVER_CAUGHT_MODIFYING_FREED_POOL"; Slug = "bug-check-0xc6--driver-caught-modifying-freed-pool" }
        "0x000000C7" = @{ Name = "TIMER_OR_DPC_INVALID"; Slug = "bug-check-0xc7--timer-or-dpc-invalid" }
        "0x000000C8" = @{ Name = "IRQL_UNEXPECTED_VALUE"; Slug = "bug-check-0xc8--irql-unexpected-value" }
        "0x000000C9" = @{ Name = "DRIVER_VERIFIER_IOMANAGER_VIOLATION"; Slug = "bug-check-0xc9--driver-verifier-iomanager-violation" }
        "0x000000CA" = @{ Name = "PNP_DETECTED_FATAL_ERROR"; Slug = "bug-check-0xca--pnp-detected-fatal-error" }
        "0x000000CB" = @{ Name = "DRIVER_LEFT_LOCKED_PAGES_IN_PROCESS"; Slug = "bug-check-0xcb--driver-left-locked-pages-in-process" }
        "0x000000CC" = @{ Name = "PAGE_FAULT_IN_FREED_SPECIAL_POOL"; Slug = "bug-check-0xcc--page-fault-in-freed-special-pool" }
        "0x000000CD" = @{ Name = "PAGE_FAULT_BEYOND_END_OF_ALLOCATION"; Slug = "bug-check-0xcd--page-fault-beyond-end-of-allocation" }
        "0x000000CE" = @{ Name = "DRIVER_UNLOADED_WITHOUT_CANCELLING_PENDING_OPERATIONS"; Slug = "bug-check-0xce--driver-unloaded-without-cancelling-pending-operations" }
        "0x000000CF" = @{ Name = "TERMINAL_SERVER_DRIVER_MADE_INCORRECT_MEMORY_REFERENCE"; Slug = "bug-check-0xcf--terminal-server-driver-made-incorrect-memory-reference" }
        "0x000000D0" = @{ Name = "DRIVER_CORRUPTED_MMPOOL"; Slug = "bug-check-0xd0--driver-corrupted-mmpool" }
        "0x000000D1" = @{ Name = "DRIVER_IRQL_NOT_LESS_OR_EQUAL"; Slug = "bug-check-0xd1--driver-irql-not-less-or-equal" }
        "0x000000D2" = @{ Name = "BUGCODE_ID_DRIVER"; Slug = "bug-check-0xd2--bugcode-id-driver" }
        "0x000000D3" = @{ Name = "DRIVER_PORTION_MUST_BE_NONPAGED"; Slug = "bug-check-0xd3--driver-portion-must-be-nonpaged" }
        "0x000000D4" = @{ Name = "SYSTEM_SCAN_AT_RAISED_IRQL_CAUGHT_IMPROPER_DRIVER_UNLOAD"; Slug = "bug-check-0xd4--system-scan-at-raised-irql-caught-improper-driver-unlo" }
        "0x000000D5" = @{ Name = "DRIVER_PAGE_FAULT_IN_FREED_SPECIAL_POOL"; Slug = "bug-check-0xd5--driver-page-fault-in-freed-special-pool" }
        "0x000000D6" = @{ Name = "DRIVER_PAGE_FAULT_BEYOND_END_OF_ALLOCATION"; Slug = "bug-check-0xd6--driver-page-fault-beyond-end-of-allocation" }
        "0x000000D7" = @{ Name = "DRIVER_UNMAPPING_INVALID_VIEW"; Slug = "bug-check-0xd7--driver-unmapping-invalid-view" }
        "0x000000D8" = @{ Name = "DRIVER_USED_EXCESSIVE_PTES"; Slug = "bug-check-0xd8--driver-used-excessive-ptes" }
        "0x000000D9" = @{ Name = "LOCKED_PAGES_TRACKER_CORRUPTION"; Slug = "bug-check-0xd9--locked-pages-tracker-corruption" }
        "0x000000DA" = @{ Name = "SYSTEM_PTE_MISUSE"; Slug = "bug-check-0xda--system-pte-misuse" }
        "0x000000DB" = @{ Name = "DRIVER_CORRUPTED_SYSPTES"; Slug = "bug-check-0xdb--driver-corrupted-sysptes" }
        "0x000000DC" = @{ Name = "DRIVER_INVALID_STACK_ACCESS"; Slug = "bug-check-0xdc--driver-invalid-stack-access" }
        "0x000000DE" = @{ Name = "POOL_CORRUPTION_IN_FILE_AREA"; Slug = "bug-check-0xde--pool-corruption-in-file-area" }
        "0x000000DF" = @{ Name = "IMPERSONATING_WORKER_THREAD"; Slug = "bug-check-0xdf--impersonating-worker-thread" }
        "0x000000E0" = @{ Name = "ACPI_BIOS_FATAL_ERROR"; Slug = "bug-check-0xe0--acpi-bios-fatal-error" }
        "0x000000E1" = @{ Name = "WORKER_THREAD_RETURNED_AT_BAD_IRQL"; Slug = "bug-check-0xe1--worker-thread-returned-at-bad-irql" }
        "0x000000E2" = @{ Name = "MANUALLY_INITIATED_CRASH"; Slug = "bug-check-0xe2--manually-initiated-crash" }
        "0x000000E3" = @{ Name = "RESOURCE_NOT_OWNED"; Slug = "bug-check-0xe3--resource-not-owned" }
        "0x000000E4" = @{ Name = "WORKER_INVALID"; Slug = "bug-check-0xe4--worker-invalid" }
        "0x000000E6" = @{ Name = "DRIVER_VERIFIER_DMA_VIOLATION"; Slug = "bug-check-0xe6--driver-verifier-dma-violation" }
        "0x000000E7" = @{ Name = "INVALID_FLOATING_POINT_STATE"; Slug = "bug-check-0xe7--invalid-floating-point-state" }
        "0x000000E8" = @{ Name = "INVALID_CANCEL_OF_FILE_OPEN"; Slug = "bug-check-0xe8--invalid-cancel-of-file-open" }
        "0x000000E9" = @{ Name = "ACTIVE_EX_WORKER_THREAD_TERMINATION"; Slug = "bug-check-0xe9--active-ex-worker-thread-termination" }
        "0x000000EA" = @{ Name = "THREAD_STUCK_IN_DEVICE_DRIVER"; Slug = "bug-check-0xea--thread-stuck-in-device-driver" }
        "0x000000EB" = @{ Name = "DIRTY_MAPPED_PAGES_CONGESTION"; Slug = "bug-check-0xeb--dirty-mapped-pages-congestion" }
        "0x000000EC" = @{ Name = "SESSION_HAS_VALID_SPECIAL_POOL_ON_EXIT"; Slug = "bug-check-0xec--session-has-valid-special-pool-on-exit" }
        "0x000000ED" = @{ Name = "UNMOUNTABLE_BOOT_VOLUME"; Slug = "bug-check-0xed--unmountable-boot-volume" }
        "0x000000EF" = @{ Name = "CRITICAL_PROCESS_DIED"; Slug = "bug-check-0xef--critical-process-died" }
        "0x000000F0" = @{ Name = "STORAGE_MINIPORT_ERROR"; Slug = "bug-check-0xf0--storage-miniport-error" }
        "0x000000F1" = @{ Name = "SCSI_VERIFIER_DETECTED_VIOLATION"; Slug = "bug-check-0xf1--scsi-verifier-detected-violation" }
        "0x000000F2" = @{ Name = "HARDWARE_INTERRUPT_STORM"; Slug = "bug-check-0xf2--hardware-interrupt-storm" }
        "0x000000F3" = @{ Name = "DISORDERLY_SHUTDOWN"; Slug = "bug-check-0xf3--disorderly-shutdown" }
        "0x000000F4" = @{ Name = "CRITICAL_OBJECT_TERMINATION"; Slug = "bug-check-0xf4--critical-object-termination" }
        "0x000000F5" = @{ Name = "FLTMGR_FILE_SYSTEM"; Slug = "bug-check-0xf5--fltmgr-file-system" }
        "0x000000F6" = @{ Name = "PCI_VERIFIER_DETECTED_VIOLATION"; Slug = "bug-check-0xf6--pci-verifier-detected-violation" }
        "0x000000F7" = @{ Name = "DRIVER_OVERRAN_STACK_BUFFER"; Slug = "bug-check-0xf7--driver-overran-stack-buffer" }
        "0x000000F8" = @{ Name = "RAMDISK_BOOT_INITIALIZATION_FAILED"; Slug = "bug-check-0xf8--ramdisk-boot-initialization-failed" }
        "0x000000F9" = @{ Name = "DRIVER_RETURNED_STATUS_REPARSE_FOR_VOLUME_OPEN"; Slug = "bug-check-0xf9--driver-returned-status-reparse-for-volume-open" }
        "0x000000FA" = @{ Name = "HTTP_DRIVER_CORRUPTED"; Slug = "bug-check-0xfa---http-driver-corrupted" }
        "0x000000FC" = @{ Name = "ATTEMPTED_EXECUTE_OF_NOEXECUTE_MEMORY"; Slug = "bug-check-0xfc---attempted-execute-of-noexecute-memory" }
        "0x000000FD" = @{ Name = "DIRTY_NOWRITE_PAGES_CONGESTION"; Slug = "bug-check-0xfd---dirty-nowrite-pages-congestion" }
        "0x000000FE" = @{ Name = "BUGCODE_USB_DRIVER"; Slug = "bug-check-0xfe--bugcode-usb-driver" }
        "0x000000FF" = @{ Name = "RESERVE_QUEUE_OVERFLOW"; Slug = "bug-check-0xff---reserve-queue-overflow" }
        "0x00000100" = @{ Name = "LOADER_BLOCK_MISMATCH"; Slug = "bug-check-0x100---loader-block-mismatch" }
        "0x00000101" = @{ Name = "CLOCK_WATCHDOG_TIMEOUT"; Slug = "bug-check-0x101---clock-watchdog-timeout" }
        "0x00000102" = @{ Name = "DPC_WATCHDOG_TIMEOUT"; Slug = "bug-check-0x102--dpc-watchdog-timeout" }
        "0x00000103" = @{ Name = "MUP_FILE_SYSTEM"; Slug = "bug-check-0x103---mup-file-system" }
        "0x00000104" = @{ Name = "AGP_INVALID_ACCESS"; Slug = "bug-check-0x104---agp-invalid-access" }
        "0x00000105" = @{ Name = "AGP_GART_CORRUPTION"; Slug = "bug-check-0x105---agp-gart-corruption" }
        "0x00000106" = @{ Name = "AGP_ILLEGALLY_REPROGRAMMED"; Slug = "bug-check-0x106---agp-illegally-reprogrammed" }
        "0x00000108" = @{ Name = "THIRD_PARTY_FILE_SYSTEM_FAILURE"; Slug = "bug-check-0x108--third-party-file-system-failure" }
        "0x00000109" = @{ Name = "CRITICAL_STRUCTURE_CORRUPTION"; Slug = "bug-check-0x109---critical-structure-corruption" }
        "0x0000010A" = @{ Name = "APP_TAGGING_INITIALIZATION_FAILED"; Slug = "bug-check-0x10a---app-tagging-initialization-failed" }
        "0x0000010C" = @{ Name = "FSRTL_EXTRA_CREATE_PARAMETER_VIOLATION"; Slug = "bug-check-0x10c---fsrtl-extra-create-parameter-violation" }
        "0x0000010D" = @{ Name = "WDF_VIOLATION"; Slug = "bug-check-0x10d---wdf-violation" }
        "0x0000010E" = @{ Name = "VIDEO_MEMORY_MANAGEMENT_INTERNAL"; Slug = "bug-check-0x10e---video-memory-management-internal" }
        "0x0000010F" = @{ Name = "RESOURCE_MANAGER_EXCEPTION_NOT_HANDLED"; Slug = "bug-check-0x10f---resource-manager-exception-not-handled" }
        "0x00000111" = @{ Name = "RECURSIVE_NMI"; Slug = "bug-check-0x111---recursive-nmi" }
        "0x00000112" = @{ Name = "MSRPC_STATE_VIOLATION"; Slug = "bug-check-0x112---msrpc-state-violation" }
        "0x00000113" = @{ Name = "VIDEO_DXGKRNL_FATAL_ERROR"; Slug = "bug-check-0x113---video-dxgkrnl-fatal-error" }
        "0x00000114" = @{ Name = "VIDEO_SHADOW_DRIVER_FATAL_ERROR"; Slug = "bug-check-0x114---video-shadow-driver-fatal-error" }
        "0x00000115" = @{ Name = "AGP_INTERNAL"; Slug = "bug-check-0x115---agp-internal" }
        "0x00000116" = @{ Name = "VIDEO_TDR_FAILURE"; Slug = "bug-check-0x116---video-tdr-failure" }
        "0x00000117" = @{ Name = "VIDEO_TDR_TIMEOUT_DETECTED"; Slug = "bug-check-0x117---video-tdr-timeout-detected" }
        "0x00000119" = @{ Name = "VIDEO_SCHEDULER_INTERNAL_ERROR"; Slug = "bug-check-0x119---video-scheduler-internal-error" }
        "0x0000011A" = @{ Name = "EM_INITIALIZATION_FAILURE"; Slug = "bug-check-0x11a---em-initialization-failure" }
        "0x0000011B" = @{ Name = "DRIVER_RETURNED_HOLDING_CANCEL_LOCK"; Slug = "bug-check-0x11b---driver-returned-holding-cancel-lock" }
        "0x0000011C" = @{ Name = "ATTEMPTED_WRITE_TO_CM_PROTECTED_STORAGE"; Slug = "bug-check-0x11c--attempted-write-to-cm-protected-storage" }
        "0x0000011D" = @{ Name = "EVENT_TRACING_FATAL_ERROR"; Slug = "bug-check-0x11d---event-tracing-fatal-error" }
        "0x0000011E" = @{ Name = "TOO_MANY_RECURSIVE_FAULTS"; Slug = "bug-check-0x11e--too-many-recursive-faults" }
        "0x0000011F" = @{ Name = "INVALID_DRIVER_HANDLE"; Slug = "bug-check-0x11f--invalid-driver-handle" }
        "0x00000120" = @{ Name = "BITLOCKER_FATAL_ERROR"; Slug = "bug-check-0x120--bitlocker-fatal-error-" }
        "0x00000121" = @{ Name = "DRIVER_VIOLATION"; Slug = "bug-check-0x121---driver-violation" }
        "0x00000122" = @{ Name = "WHEA_INTERNAL_ERROR"; Slug = "bug-check-0x122---whea-internal-error" }
        "0x00000123" = @{ Name = "CRYPTO_SELF_TEST_FAILURE"; Slug = "bug-check-0x123--crypto-self-test-failure-" }
        "0x00000124" = @{ Name = "WHEA_UNCORRECTABLE_ERROR"; Slug = "bug-check-0x124---whea-uncorrectable-error" }
        "0x00000125" = @{ Name = "NMR_INVALID_STATE"; Slug = "bug-check-0x125--nmr-invalid-state" }
        "0x00000126" = @{ Name = "NETIO_INVALID_POOL_CALLER"; Slug = "bug-check-0x126--netio-invalid-pool-caller" }
        "0x00000127" = @{ Name = "PAGE_NOT_ZERO"; Slug = "bug-check-0x127---page-not-zero" }
        "0x00000128" = @{ Name = "WORKER_THREAD_RETURNED_WITH_BAD_IO_PRIORITY"; Slug = "bug-check-0x128--worker-thread-returned-with-bad-io-priority" }
        "0x00000129" = @{ Name = "WORKER_THREAD_RETURNED_WITH_BAD_PAGING_IO_PRIORITY"; Slug = "bug-check-0x129--worker-thread-returned-with-bad-paging-io-priority" }
        "0x0000012A" = @{ Name = "MUI_NO_VALID_SYSTEM_LANGUAGE"; Slug = "bug-check-0x12a--mui-no-valid-system-language" }
        "0x0000012B" = @{ Name = "FAULTY_HARDWARE_CORRUPTED_PAGE"; Slug = "bug-check-0x12b---faulty-hardware-corrupted-page" }
        "0x0000012C" = @{ Name = "EXFAT_FILE_SYSTEM"; Slug = "bug-check-0x12c---exfat-file-system" }
        "0x0000012D" = @{ Name = "VOLSNAP_OVERLAPPED_TABLE_ACCESS"; Slug = "bug-check-0x12d--volsnap-overlapped-table-access" }
        "0x0000012E" = @{ Name = "INVALID_MDL_RANGE"; Slug = "bug-check-0x12e--invalid-mdl-range" }
        "0x0000012F" = @{ Name = "VHD_BOOT_INITIALIZATION_FAILED"; Slug = "bug-check-0x12f--vhd-boot-initialization-failed" }
        "0x00000130" = @{ Name = "DYNAMIC_ADD_PROCESSOR_MISMATCH"; Slug = "bug-check-0x130--dynamic-add-processor-mismatch" }
        "0x00000131" = @{ Name = "INVALID_EXTENDED_PROCESSOR_STATE"; Slug = "bug-check-0x131--invalid-extended-processor-state" }
        "0x00000132" = @{ Name = "RESOURCE_OWNER_POINTER_INVALID"; Slug = "bug-check-0x132--resource-owner-pointer-invalid" }
        "0x00000133" = @{ Name = "DPC_WATCHDOG_VIOLATION"; Slug = "bug-check-0x133-dpc-watchdog-violation" }
        "0x00000134" = @{ Name = "DRIVE_EXTENDER"; Slug = "bug-check-0x134--drive-extender" }
        "0x00000135" = @{ Name = "REGISTRY_FILTER_DRIVER_EXCEPTION"; Slug = "bug-check-0x135--registry-filter-driver-exception" }
        "0x00000136" = @{ Name = "VHD_BOOT_HOST_VOLUME_NOT_ENOUGH_SPACE"; Slug = "bug-check-0x136--vhd-boot-host-volume-not-enough-space" }
        "0x00000137" = @{ Name = "WIN32K_HANDLE_MANAGER"; Slug = "bug-check-0x137--win32k-handle-manager" }
        "0x00000138" = @{ Name = "GPIO_CONTROLLER_DRIVER_ERROR"; Slug = "bug-check-0x138-gpio-controller-driver-error" }
        "0x00000139" = @{ Name = "KERNEL_SECURITY_CHECK_FAILURE"; Slug = "bug-check-0x139--kernel-security-check-failure" }
        "0x0000013A" = @{ Name = "KERNEL_MODE_HEAP_CORRUPTION"; Slug = "bug-check-0x13a--kernel-mode-heap-corruption" }
        "0x0000013B" = @{ Name = "PASSIVE_INTERRUPT_ERROR"; Slug = "bug-check-0x13b--passive-interrupt-error" }
        "0x0000013C" = @{ Name = "INVALID_IO_BOOST_STATE"; Slug = "bug-check-0x13c--invalid-io-boost-state" }
        "0x0000013D" = @{ Name = "CRITICAL_INITIALIZATION_FAILURE"; Slug = "bug-check-0x13d--critical-initialization-failure" }
        "0x00000140" = @{ Name = "STORAGE_DEVICE_ABNORMALITY_DETECTED"; Slug = "bug-check-0x140--storage-device-abnormality-detected" }
        "0x00000143" = @{ Name = "PROCESSOR_DRIVER_INTERNAL"; Slug = "bug-check-0x143--processor-driver-internal" }
        "0x00000144" = @{ Name = "BUGCODE_USB3_DRIVER"; Slug = "bug-check-0x144--bugcode-usb3-driver" }
        "0x00000145" = @{ Name = "SECURE_BOOT_VIOLATION"; Slug = "bug-check-0x145--secure-boot-violation-" }
        "0x00000147" = @{ Name = "ABNORMAL_RESET_DETECTED"; Slug = "bug-check-0x147--abnormal-reset-detected" }
        "0x00000149" = @{ Name = "REFS_FILE_SYSTEM"; Slug = "bug-check-0x149--refs-file-system" }
        "0x0000014A" = @{ Name = "KERNEL_WMI_INTERNAL"; Slug = "bug-check-0x14a--kernel-wmi-internal" }
        "0x0000014B" = @{ Name = "SOC_SUBSYSTEM_FAILURE"; Slug = "bug-check-0x14b--soc-subsystem-failure" }
        "0x0000014C" = @{ Name = "FATAL_ABNORMAL_RESET_ERROR"; Slug = "bug-check-0x14c--fatal-abnormal-reset-error" }
        "0x0000014D" = @{ Name = "EXCEPTION_SCOPE_INVALID"; Slug = "bug-check-0x14d--exception-scope-invalid" }
        "0x0000014E" = @{ Name = "SOC_CRITICAL_DEVICE_REMOVED"; Slug = "bug-check-0x14e--soc-critical-device-removed" }
        "0x0000014F" = @{ Name = "PDC_WATCHDOG_TIMEOUT"; Slug = "bug-check-0x14f--pdc-watchdog-timeout" }
        "0x00000150" = @{ Name = "TCPIP_AOAC_NIC_ACTIVE_REFERENCE_LEAK"; Slug = "bug-check-0x150--tcpip-aoac-nic-active-reference-leak" }
        "0x00000151" = @{ Name = "UNSUPPORTED_INSTRUCTION_MODE"; Slug = "bug-check-0x151--unsupported-instruction-mode" }
        "0x00000152" = @{ Name = "INVALID_PUSH_LOCK_FLAGS"; Slug = "bug-check-0x152--invalid-push-lock-flags" }
        "0x00000153" = @{ Name = "KERNEL_LOCK_ENTRY_LEAKED_ON_THREAD_TERMINATION"; Slug = "bug-check-0x153--kernel-lock-entry-leaked-on-thread-termination" }
        "0x00000154" = @{ Name = "UNEXPECTED_STORE_EXCEPTION"; Slug = "bug-check-0x154--unexpected-store-exception" }
        "0x00000155" = @{ Name = "OS_DATA_TAMPERING"; Slug = "bug-check-0x155--os-data-tampering" }
        "0x00000157" = @{ Name = "KERNEL_THREAD_PRIORITY_FLOOR_VIOLATION"; Slug = "bug-check-0x157--kernel-thread-priority-floor-violation" }
        "0x00000158" = @{ Name = "ILLEGAL_IOMMU_PAGE_FAULT"; Slug = "bug-check-0x158--illegal-iommu-page-fault" }
        "0x00000159" = @{ Name = "HAL_ILLEGAL_IOMMU_PAGE_FAULT"; Slug = "bug-check-0x159--hal-illegal-iommu-page-fault" }
        "0x0000015A" = @{ Name = "SDBUS_INTERNAL_ERROR"; Slug = "bug-check-0x15a--sdbus-internal-error" }
        "0x0000015B" = @{ Name = "WORKER_THREAD_RETURNED_WITH_SYSTEM_PAGE_PRIORITY_ACTIVE"; Slug = "bug-check-0x15b--worker-thread-returned-with-system-page-priority-active" }
        "0x00000160" = @{ Name = "WIN32K_ATOMIC_CHECK_FAILURE"; Slug = "bug-check-0x160--win32k-atomic-check-failure" }
        "0x00000162" = @{ Name = "KERNEL_AUTO_BOOST_INVALID_LOCK_RELEASE"; Slug = "bug-check-0x162--kernel-auto-boost-invalid-lock-release" }
        "0x00000163" = @{ Name = "WORKER_THREAD_TEST_CONDITION"; Slug = "bug-check-0x163--worker-thread-test-condition" }
        "0x00000164" = @{ Name = "WIN32K_CRITICAL_FAILURE"; Slug = "bug-check-0x164--win32k-critical-failure" }
        "0x0000016C" = @{ Name = "INVALID_RUNDOWN_PROTECTION_FLAGS"; Slug = "bug-check-0x16c--invalid-rundown-protection-flags" }
        "0x0000016D" = @{ Name = "INVALID_SLOT_ALLOCATOR_FLAGS"; Slug = "bug-check-0x16d--invalid-slot-allocator-flags" }
        "0x0000016E" = @{ Name = "ERESOURCE_INVALID_RELEASE"; Slug = "bug-check-0x16e--eresource-invalid-release" }
        "0x00000170" = @{ Name = "CLUSTER_CSV_CLUSSVC_DISCONNECT_WATCHDOG"; Slug = "bug-check-0x170--cluster-csv-clussvc-disconnect-watchdog" }
        "0x00000171" = @{ Name = "CRYPTO_LIBRARY_INTERNAL_ERROR"; Slug = "bug-check-0x171--crypto-library-internal-error" }
        "0x00000173" = @{ Name = "COREMSGCALL_INTERNAL_ERROR"; Slug = "bug-check-0x173--coremsgcall-internal-error" }
        "0x00000174" = @{ Name = "COREMSG_INTERNAL_ERROR"; Slug = "bug-check-0x174--coremsg-internal-error" }
        "0x00000178" = @{ Name = "ELAM_DRIVER_DETECTED_FATAL_ERROR"; Slug = "bug-check-0x178--elam-driver-detected-fatal-error" }
        "0x0000017B" = @{ Name = "PROFILER_CONFIGURATION_ILLEGAL"; Slug = "bug-check-0x17b--profiler-configuration-illegal" }
        "0x0000017E" = @{ Name = "MICROCODE_REVISION_MISMATCH"; Slug = "bug-check-0x17e--microcode-revision-mismatch" }
        "0x00000187" = @{ Name = "VIDEO_DWMINIT_TIMEOUT_FALLBACK_BDD"; Slug = "bug-check-0x187--video-dwminit-timeout-fallback-bdd" }
        "0x00000189" = @{ Name = "BAD_OBJECT_HEADER"; Slug = "bug-check-0x189--bad-object-header" }
        "0x0000018B" = @{ Name = "SECURE_KERNEL_ERROR"; Slug = "bug-check-0x18b--secure-kernel-error" }
        "0x0000018C" = @{ Name = "HYPERGUARD_VIOLATION"; Slug = "bug-check-0x18c--hyperguard-violation" }
        "0x0000018D" = @{ Name = "SECURE_FAULT_UNHANDLED"; Slug = "bug-check-0x18d--secure-fault-unhandled" }
        "0x0000018E" = @{ Name = "KERNEL_PARTITION_REFERENCE_VIOLATION"; Slug = "bug-check-0x18e--kernel-partition-reference-violation" }
        "0x00000191" = @{ Name = "PF_DETECTED_CORRUPTION"; Slug = "bug-check-0x191--pf-detected-corruption" }
        "0x00000192" = @{ Name = "KERNEL_AUTO_BOOST_LOCK_ACQUISITION_WITH_RAISED_IRQL"; Slug = "bug-check-0x192--kernel-auto-boost-lock-acquisition-with-raised-irql" }
        "0x00000196" = @{ Name = "LOADER_ROLLBACK_DETECTED"; Slug = "bug-check-0x196--loader-rollback-detected" }
        "0x00000197" = @{ Name = "WIN32K_SECURITY_FAILURE"; Slug = "bug-check-0x197--win32k-security-failure" }
        "0x00000199" = @{ Name = "KERNEL_STORAGE_SLOT_IN_USE"; Slug = "bug-check-0x199--kernel-storage-slot-in-use" }
        "0x0000019A" = @{ Name = "WORKER_THREAD_RETURNED_WHILE_ATTACHED_TO_SILO"; Slug = "bug-check-0x19a--worker-thread-returned-while-attached-to-silo" }
        "0x0000019B" = @{ Name = "TTM_FATAL_ERROR"; Slug = "bug-check-0x19b--ttm-fatal-error" }
        "0x0000019C" = @{ Name = "WIN32K_POWER_WATCHDOG_TIMEOUT"; Slug = "bug-check-0x19c--win32k-power-watchdog-timeout" }
        "0x000001A0" = @{ Name = "TTM_WATCHDOG_TIMEOUT"; Slug = "bug-check-0x1a0--ttm-watchdog-timeout" }
        "0x000001A2" = @{ Name = "WIN32K_CALLOUT_WATCHDOG_BUGCHECK"; Slug = "bug-check-0x1a2--win32k-callout-watchdog-bugcheck" }
        "0x000001AA" = @{ Name = "EXCEPTION_ON_INVALID_STACK"; Slug = "bug-check-0x1aa-exception-on-invalid-stack" }
        "0x000001AB" = @{ Name = "UNWIND_ON_INVALID_STACK"; Slug = "bug-check-0x1ab-unwind-on-invalid-stack" }
        "0x000001C6" = @{ Name = "FAST_ERESOURCE_PRECONDITION_VIOLATION"; Slug = "bug-check-0x1c6--fast-eresource-precondition-violation" }
        "0x000001C7" = @{ Name = "STORE_DATA_STRUCTURE_CORRUPTION"; Slug = "bug-check-0x1c7--store-data-structure-corruption" }
        "0x000001C8" = @{ Name = "MANUALLY_INITIATED_POWER_BUTTON_HOLD"; Slug = "bug-check-0x1c8--manually-initiated-power-button-hold" }
        "0x000001CA" = @{ Name = "SYNTHETIC_WATCHDOG_TIMEOUT"; Slug = "bug-check-0x1ca--synthetic-watchdog-timeout" }
        "0x000001CB" = @{ Name = "INVALID_SILO_DETACH"; Slug = "bug-check-0x1cb--invalid-silo-detach" }
        "0x000001CD" = @{ Name = "INVALID_CALLBACK_STACK_ADDRESS"; Slug = "bug-check-0x1cd--invalid-callback-stack-address" }
        "0x000001CE" = @{ Name = "INVALID_KERNEL_STACK_ADDRESS"; Slug = "bug-check-0x1ce--invalid-kernel-stack-address" }
        "0x000001CF" = @{ Name = "HARDWARE_WATCHDOG_TIMEOUT"; Slug = "bug-check-0x1cf--hardware-watchdog-timeout" }
        "0x000001D0" = @{ Name = "CPI_FIRMWARE_WATCHDOG_TIMEOUT"; Slug = "bug-check-0x1d0--acpi-firmware-watchdog-timeout" }
        "0x000001D2" = @{ Name = "WORKER_THREAD_INVALID_STATE"; Slug = "bug-check-0x1d2--worker-thread-invalid-state" }
        "0x000001D3" = @{ Name = "WFP_INVALID_OPERATION"; Slug = "bug-check-0x1d3--wfp-invalid-operation" }
        "0x000001D5" = @{ Name = "DRIVER_PNP_WATCHDOG"; Slug = "bug-check-0x1d5--driver-pnp-watchdog" }
        "0x000001D6" = @{ Name = "WORKER_THREAD_RETURNED_WITH_NON_DEFAULT_WORKLOAD_CLASS"; Slug = "bug-check-0x1d6--worker-thread-returned-with-non-default-workload-class" }
        "0x000001D7" = @{ Name = "EFS_FATAL_ERROR"; Slug = "bug-check-0x1d7--efs-fatal-error" }
        "0x000001D8" = @{ Name = "UCMUCSI_FAILURE"; Slug = "bug-check-0x1d8--ucmucsi-failure" }
        "0x000001D9" = @{ Name = "HAL_IOMMU_INTERNAL_ERROR"; Slug = "bug-check-0x1d9--hal-iommu-internal-error" }
        "0x000001DA" = @{ Name = "HAL_BLOCKED_PROCESSOR_INTERNAL_ERROR"; Slug = "bug-check-0x1da--hal-blocked-processor-internal-error" }
        "0x000001DB" = @{ Name = "IPI_WATCHDOG_TIMEOUT"; Slug = "bug-check-0x1db--ipi-watchdog-timeout" }
        "0x000001DC" = @{ Name = "DMA_COMMON_BUFFER_VECTOR_ERROR"; Slug = "bug-check-0x1dc--dma-common-buffer-vector-error" }
        "0x000001DD" = @{ Name = "BUGCODE_MBBADAPTER_DRIVER"; Slug = "bug-check-0x1dd--bugcode-mbbadapter-driver" }
        "0x000001DE" = @{ Name = "BUGCODE_WIFIADAPTER_DRIVER"; Slug = "bug-check-0x1de--bugcode-wifiadapter-driver" }
        "0x000001DF" = @{ Name = "PROCESSOR_START_TIMEOUT"; Slug = "bug-check-0x1df--processor-start-timeout" }
        "0x000001E4" = @{ Name = "VIDEO_DXGKRNL_SYSMM_FATAL_ERROR"; Slug = "bug-check-0x1e4--video-dxgkrnl-sysmm-fatal-error" }
        "0x000001E9" = @{ Name = "ILLEGAL_ATS_INITIALIZATION"; Slug = "bug-check-0x1e9--illegal-ats-initialization" }
        "0x000001EA" = @{ Name = "SECURE_PCI_CONFIG_SPACE_ACCESS_VIOLATION"; Slug = "bug-check-0x1ea--secure-pci-config-space-access-violation" }
        "0x000001EB" = @{ Name = "DAM_WATCHDOG_TIMEOUT"; Slug = "bug-check-0x1eb--dam-watchdog-timeout" }
        "0x000001ED" = @{ Name = "HANDLE_ERROR_ON_CRITICAL_THREAD"; Slug = "bug-check-0x1ed--handle-error-on-critical-thread" }
        "0x000001F1" = @{ Name = "KASAN_ENLIGHTENMENT_VIOLATION"; Slug = "bug-check-0x1f1--kasan-enlightement-violation" }
        "0x000001F2" = @{ Name = "KASAN_ILLEGAL_ACCESS"; Slug = "bug-check-0x1f2--kasan-illegal-access" }
        "0x00000356" = @{ Name = "XBOX_ERACTRL_CS_TIMEOUT"; Slug = "bug-check-0x356--xbox-eractrl-cs-timeout" }
        "0x00000BFE" = @{ Name = "BC_BLUETOOTH_VERIFIER_FAULT"; Slug = "bug-check-0xbfe--bc-bluetooth-verifier-fault" }
        "0x00000BFF" = @{ Name = "BC_BTHMINI_VERIFIER_FAULT"; Slug = "bug-check-0xbff--bc-bthmini-verifier-fault" }
        "0x00020001" = @{ Name = "HYPERVISOR_ERROR"; Slug = "bug-check-0x20001--hypervisor-error" }
        "0x1000007E" = @{ Name = "SYSTEM_THREAD_EXCEPTION_NOT_HANDLED_M"; Slug = "bug-check-0x1000007e--system-thread-exception-not-handled-m" }
        "0x1000007F" = @{ Name = "UNEXPECTED_KERNEL_MODE_TRAP_M"; Slug = "bug-check-0x1000007f--unexpected-kernel-mode-trap-m" }
        "0x1000008E" = @{ Name = "KERNEL_MODE_EXCEPTION_NOT_HANDLED_M"; Slug = "bug-check-0x1000008e--kernel-mode-exception-not-handled-m" }
        "0x100000EA" = @{ Name = "THREAD_STUCK_IN_DEVICE_DRIVER_M"; Slug = "bug-check-0x100000ea--thread-stuck-in-device-driver-m" }
        "0x4000008A" = @{ Name = "THREAD_TERMINATE_HELD_MUTEX"; Slug = "bug-check-0x4000008a--thread-terminate-held-mutex" }
        "0xC0000218" = @{ Name = "STATUS_CANNOT_LOAD_REGISTRY_FILE"; Slug = "bug-check-0xc0000218--status-cannot-load-registry-file" }
        "0xC000021A" = @{ Name = "WINLOGON_FATAL_ERROR"; Slug = "bug-check-0xc000021a--winlogin-fatal-error" }
        "0xC0000221" = @{ Name = "STATUS_IMAGE_CHECKSUM_MISMATCH"; Slug = "bug-check-0xc0000221--status-image-checksum-mismatch" }
        "0xDEADDEAD" = @{ Name = "MANUALLY_INITIATED_CRASH1"; Slug = "bug-check-0xdeaddead--manually-initiated-crash1" }
    }
    #endregion

    function Test-IsElevated {
        [CmdletBinding()]
        param ()

        # Get the current Windows identity of the user running the script
        $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()

        # Create a WindowsPrincipal object based on the current identity
        $p = New-Object System.Security.Principal.WindowsPrincipal($id)

        # Check if the current user is in the Administrator role
        # The function returns $True if the user has administrative privileges, $False otherwise
        # 544 is the value for the Built In Administrators role
        # Reference: https://learn.microsoft.com/en-us/dotnet/api/system.security.principal.windowsbuiltinrole
        $p.IsInRole([System.Security.Principal.WindowsBuiltInRole]'544')
    }

    if (!$ExitCode) {
        $ExitCode = 0
    }
}
process {
    # Attempt to determine if the current session is running with Administrator privileges.
    try {
        $IsElevated = Test-IsElevated -ErrorAction Stop
    } catch {
        # Log an error if the elevation check fails and exit with an error code.
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Unable to determine if the account '$env:Username' is running this script in an elevated session."
        exit 1
    }

    # Exit if the script is not running in an elevated session.
    if (!$IsElevated) {
        Write-Host -Object "[Error] The user '$env:USERNAME' is not running this script in an elevated session. Please run this script as System or in an elevated session."
        exit 1
    }

    #region Retrieve Events

    # Calculate the cutoff date and time for filtering events based on the 'MinutesAgo' parameter.
    try {
        $DateCutOff = (Get-Date -ErrorAction Stop).AddMinutes(-$MinutesAgo)
    } catch {
        # Log an error if the cutoff calculation fails and exit with an error code.
        Write-Host -Object "[Error] $($_.Exception.Message)"
        Write-Host -Object "[Error] Failed to calculate the cutoff for the alert."
        exit 1
    }

    # Inform the user that the script is checking for BSOD events in the Event Log.
    Write-Host -Object "Checking for BSOD Event Log entries."

    # Define the XML query to retrieve BSOD events from the System Event Log.
    $BSODXml = "<QueryList><Query Id=`"0`" Path=`"System`"><Select Path=`"System`">*[System[Provider[@Name='Microsoft-Windows-WER-SystemErrorReporting']]]</Select></Query></QueryList>"

    # Retrieve BSOD events using the defined XML query and limit the results to the specified maximum number of events.
    $BSODEvents = Get-WinEvent -FilterXml $BSODXml -MaxEvents $MaxEvents -ErrorAction SilentlyContinue
    $BSODCount = $BSODEvents | Measure-Object | Select-Object -ExpandProperty Count

    #endregion

    #region Format Events
    # Initialize a list to store BSOD event details.
    $BSODs = New-Object -TypeName System.Collections.Generic.List[object]
    foreach ($FoundEvent in $BSODEvents) {
        try {
            # Convert the event to XML format for easier parsing.
            [XML]$EventXML = $FoundEvent.ToXML()
            $NameSpace = New-Object -TypeName System.Xml.XmlNamespaceManager($EventXML.NameTable) -ErrorAction Stop
            $NameSpace.AddNamespace("e", $EventXML.DocumentElement.NamespaceURI)
        } catch {
            # Log an error if the event conversion fails and continue processing other events.
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to convert event from '$($FoundEvent.TimeCreated)' with ID $($FoundEvent.Id) in the '$($FoundEvent.LogName)' log into XML."
            $ExitCode = 1
            continue
        }

        # Extract details such as dump file, error code, reason, and slug from the event.
        $DumpFile = $EventXML.SelectSingleNode("//e:Data[@Name='param2']", $NameSpace) | Select-Object -ExpandProperty "#text"
        $ErrorCode = ($EventXML.SelectSingleNode("//e:Data[@Name='param1']", $NameSpace) | Select-Object -ExpandProperty "#text").Split() | Select-Object -First 1
        $ReasonCode = ($BugCheckCodes.GetEnumerator() | Where-Object { $_.Name -eq $ErrorCode }).Value.Name
        $Slug = ($BugCheckCodes.GetEnumerator() | Where-Object { $_.Name -eq $ErrorCode }).Value.Slug

        # Add the extracted details to the list of BSODs.
        $BSODs.Add(
            [PSCustomObject]@{
                Date      = $FoundEvent.TimeCreated
                EventID   = $FoundEvent.Id
                Reason    = $ReasonCode
                Dumpfile  = $DumpFile
                Link      = "https://learn.microsoft.com/windows-hardware/drivers/debugger/$Slug"
                ErrorCode = $ErrorCode
                Message   = $FoundEvent.Message
            }
        )
    }

    # Filter BSODs to include only those that occurred within the cutoff time.
    $BSODsWithinCutoff = $BSODs | Where-Object { $_.Date -gt $DateCutOff }
    $BSODsCount = $BSODs | Measure-Object | Select-Object -ExpandProperty Count
    $BSODsWithinCutoffCount = $BSODsWithinCutoff | Measure-Object | Select-Object -ExpandProperty Count

    #endregion
    #region Activity Log Output

    # Log the results based on whether BSODs were detected within the cutoff time.
    if ($BSODsWithinCutoff) {
        Write-Host -Object "`n[Alert] One or more BSODs were detected in the past '$MinutesAgo' minutes."
        Write-Host -Object "`n### BSOD Events in the Past $MinutesAgo Minutes ###"
        ($BSODsWithinCutoff | Select-Object -Property @{ Name = "Date"; Expression = {
                "$($_.Date.ToShortDateString()) $($_.Date.ToShortTimeString())" }
        }, EventID, Reason, Dumpfile, Link, ErrorCode | Format-List | Out-String).Trim()
    } elseif ($BSODsCount -gt 0) {
        Write-Host -Object "`nNo BSOD Events detected in the past '$MinutesAgo' minutes."
        Write-Host -Object "`n### All BSOD Events Detected ###"
        ($BSODs | Select-Object -Property @{ Name = "Date"; Expression = {
                "$($_.Date.ToShortDateString()) $($_.Date.ToShortTimeString())" }
        }, EventID, Reason, Dumpfile, Link, ErrorCode | Format-List | Out-String).Trim()
    } else {
        Write-Host -Object "No BSOD Events were found on this device."
    }

    # Update custom fields if specified.
    if ($MultilineCustomField -or $WYSIWYGCustomField) {
        Write-Host -Object ""
    }
    #endregion

    #region Custom Field Output
    # Update the multiline custom field with BSOD details.
    if ($MultilineCustomField) {
        Write-Host -Object "Attempting to save the results to the custom field '$MultilineCustomField'."

        if ($BSODsCount -eq 0 -or ($BSODsWithinCutoffCount -eq 0 -and !$SaveFullHistory)) {
            $MultilineValue = "No BSOD Events were found on this device."
        } elseif ($SaveFullHistory) {
            $MultilineValue = ($BSODs | Select-Object -Property @{ Name = "Date"; Expression = {
                        "$($_.Date.ToShortDateString()) $($_.Date.ToShortTimeString())" }
                }, EventID, Reason, Dumpfile, Link, ErrorCode | Format-List | Out-String).Trim()
        } elseif ($BSODsWithinCutoff) {
            $MultilineValue = ($BSODsWithinCutoff | Select-Object -Property @{ Name = "Date"; Expression = {
                        "$($_.Date.ToShortDateString()) $($_.Date.ToShortTimeString())" }
                }, EventID, Reason, Dumpfile, Link, ErrorCode | Format-List | Out-String).Trim()
        }

        try {
            $MultilineCharacters = ($MultilineValue | Out-String).Length
            if ($MultilineCharacters -gt 9500) {
                Write-Host -Object "The current character count is '$MultilineCharacters'."
                Write-Host -Object "[Warning] Trimming the multiline output to accommodate the 9,500 character limit."

                # Truncate the output if it exceeds the limit.
                $i = 0
                [array]$NewList = $MultilineValue -split "`r?`n"
                $TrimStart = Get-Date
                do {
                    $MultilineValue = New-Object -TypeName System.Collections.Generic.List[String]
                    $MultilineValue.Add("This list has been truncated to accommodate the 9,500 character limit.`n")

                    # Calculate the batch size for trimming
                    $ExceededAmount = $MultilineCharacters - 9500
                    if ($ExceededAmount -le 0) {
                        $BatchSize = 1
                    } else {
                        $BatchSize = [math]::Ceiling($ExceededAmount / 500)
                    }

                    # Reverse the event log array so that the last entry is at the top.
                    [array]::Reverse($NewList)

                    # Remove excess event log entries
                    for ($BatchNumber = 0 ; $BatchNumber -lt $BatchSize ; $BatchNumber++) {
                        # Delete rows until the character count is reduced.
                        $NewList[$i] = $null
                        $i++
                    }

                    # Reverse the array back to its original order.
                    [array]::Reverse($NewList)

                    $MultilineValue.Add(($NewList | Out-String).Trim())

                    # Check the character count again; repeat if still too long.
                    $MultilineCharacters = ($MultilineValue | Out-String).Length
                    $ElapsedTime = (Get-Date) - $TrimStart
                    if ($ElapsedTime.TotalMinutes -ge 5) {
                        Write-Host -Object "The current character count is '$MultilineCharacters'."
                        throw "5 minute timeout reached. Unable to trim the output to comply with the character limit."
                    }
                }while ($MultilineCharacters -ge 9500)
            }

            Set-NinjaProperty -Name $MultilineCustomField -Value $MultilineValue -ErrorAction Stop
            Write-Host -Object "Success."
        } catch {
            # Log an error if updating the custom field fails.
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to update the custom field '$MultilineCustomField'."
            $ExitCode = 1
        }
    }

    # Update the WYSIWYG custom field with BSOD details in HTML format.
    if ($WYSIWYGCustomField) {
        try {
            Write-Host -Object "Attempting to save the results to the custom field '$WYSIWYGCustomField'."

            $WYSIWYGValue = New-Object -TypeName System.Collections.Generic.List[String]
            $WYSIWYGValue.Add("<div>")


            if ($BSODsCount -eq 0 -or ($BSODsWithinCutoffCount -eq 0 -and !$SaveFullHistory)) {
                $WYSIWYGTable = "<p>No BSOD Events were found on this device.</p>"
            } elseif ($SaveFullHistory) {
                $WYSIWYGTable = $BSODs | Select-Object -Property @{ Name = "Date"; Expression = {
                        "$($_.Date.ToShortDateString()) $($_.Date.ToShortTimeString())" }
                }, EventID, Reason, Dumpfile, ErrorCode | ConvertTo-Html -Fragment -ErrorAction Stop
            } else {
                $WYSIWYGTable = $BSODsWithinCutoff | Select-Object -Property @{ Name = "Date"; Expression = {
                        "$($_.Date.ToShortDateString()) $($_.Date.ToShortTimeString())" }
                }, EventID, Reason, Dumpfile, ErrorCode | ConvertTo-Html -Fragment -ErrorAction Stop
            }

            $WYSIWYGTable = $WYSIWYGTable -replace "<th>", "<th><b>" -replace "</th>", "</b></th>"

            $BSODReasons = $BSODs | Select-Object -Property Reason, Link -Unique

            foreach ($BSODReason in $BSODReasons) {
                $WYSIWYGTable = $WYSIWYGTable -replace [Regex]::Escape($BSODReason.Reason), "<a href='$($BSODReason.Link)' target='_blank'>$($BSODReason.Reason)&nbsp;<i class='fas fa-arrow-up-right-from-square' style='color: #337ab7;'></i></a>"
            }

            $WYSIWYGValue.Add("<div class='card flex-grow-1'>
        <div class='card-title-box'>
            <div class='card-title'><i class='fa-solid fa-triangle-exclamation'></i>&nbsp;&nbsp;BSOD Events</div>
        </div>
        <div class='card-body container-fluid' style='white-space: nowrap'>
            $WYSIWYGTable
        </div>
    </div>")

            $WYSIWYGValue.Add("</div>")

            $HTMLCharacters = ($WYSIWYGValue | Out-String).Length
            if ($HTMLCharacters -gt 195000) {
                Write-Host -Object "The current character count is '$HTMLCharacters'."
                Write-Host -Object "[Warning] Trimming the html output to accommodate the 195,000 character limit."

                # Truncate the output if it exceeds the limit.
                $i = 0
                [array]$NewWYSIWYGTable = $WYSIWYGTable
                $TrimStart = Get-Date
                do {
                    $WYSIWYGValue = New-Object -TypeName System.Collections.Generic.List[String]
                    $WYSIWYGValue.Add("<div>")
                    $WYSIWYGValue.Add("<h1>This information has been truncated to fit within the character limit of 195,000.</h1>")

                    # Calculate the batch size for trimming
                    $ExceededAmount = $HTMLCharacters - 195000
                    if ($ExceededAmount -le 0) {
                        $BatchSize = 1
                    } else {
                        $BatchSize = [math]::Ceiling($ExceededAmount / 500)
                    }

                    # Reverse the event log array so that the last entry is at the top.
                    [array]::Reverse($NewWYSIWYGTable)

                    # Remove excess event log entries
                    for ($BatchNumber = 0 ; $BatchNumber -lt $BatchSize ; $BatchNumber++) {
                        # Delete rows until the character count is reduced.
                        if ($NewWYSIWYGTable[$i] -match '<tr><td>' -or $NewWYSIWYGTable[$i] -match '<tr class=') {
                            $NewWYSIWYGTable[$i] = $null
                        }
                        $i++
                    }

                    # Reverse the array back to its original order.
                    [array]::Reverse($NewWYSIWYGTable)

                    $WYSIWYGValue.Add("<div class='card flex-grow-1'>
    <div class='card-title-box'>
        <div class='card-title'><i class='fa-solid fa-triangle-exclamation'></i>&nbsp;&nbsp;BSOD Events</div>
    </div>
    <div class='card-body container-fluid' style='white-space: nowrap'>
        $NewWYSIWYGTable
    </div>
</div>")

                    $WYSIWYGValue.Add("</div>")

                    # Check the character count again; repeat if still too long.
                    $HTMLCharacters = ($WYSIWYGValue | Out-String).Length
                    $ElapsedTime = (Get-Date) - $TrimStart
                    if ($ElapsedTime.TotalMinutes -ge 5) {
                        Write-Host -Object "The current character count is '$HTMLCharacters'."
                        throw "5 minute timeout reached. Unable to trim the output to comply with the character limit."
                    }
                }while ($HTMLCharacters -ge 195000)
            }

            Set-NinjaProperty -Name $WYSIWYGCustomField -Value $WYSIWYGValue -ErrorAction Stop
            Write-Host -Object "Success."
        } catch {
            # Log an error if updating the custom field fails.
            Write-Host -Object "[Error] $($_.Exception.Message)"
            Write-Host -Object "[Error] Failed to update the custom field '$WYSIWYGCustomField'."
            $ExitCode = 1
        }
    }
    #endregion

    exit $ExitCode
}
end {
    
    
    
}