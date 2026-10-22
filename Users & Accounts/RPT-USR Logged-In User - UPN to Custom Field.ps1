# NinjaOne script variable 'customFieldName' overrides the default field.
$CustomFieldName = if ($env:customFieldName -and $env:customFieldName -notlike 'null') { $env:customFieldName } else { 'lastLoggedInUser' }

$script:source = @"
using Microsoft.Win32.SafeHandles;
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Security.Principal;
using System.Text;

namespace RunAsUser
{
    internal class NativeHelpers
    {
        [StructLayout(LayoutKind.Sequential)]
        public struct LUID
        {
            public int LowPart;
            public int HighPart;
        }
        [StructLayout(LayoutKind.Sequential)]
        public struct LUID_AND_ATTRIBUTES
        {
            public LUID Luid;
            public PrivilegeAttributes Attributes;
        }
        [StructLayout(LayoutKind.Sequential)]
        public struct PROCESS_INFORMATION
        {
            public IntPtr hProcess;
            public IntPtr hThread;
            public int dwProcessId;
            public int dwThreadId;
        }
        [StructLayout(LayoutKind.Sequential)]
        public struct STARTUPINFO
        {
            public int cb;
            public String lpReserved;
            public String lpDesktop;
            public String lpTitle;
            public uint dwX;
            public uint dwY;
            public uint dwXSize;
            public uint dwYSize;
            public uint dwXCountChars;
            public uint dwYCountChars;
            public uint dwFillAttribute;
            public uint dwFlags;
            public short wShowWindow;
            public short cbReserved2;
            public IntPtr lpReserved2;
            public IntPtr hStdInput;
            public IntPtr hStdOutput;
            public IntPtr hStdError;
        }
        [StructLayout(LayoutKind.Sequential)]
        public struct TOKEN_PRIVILEGES
        {
            public int PrivilegeCount;
            [MarshalAs(UnmanagedType.ByValArray, SizeConst = 1)]
            public LUID_AND_ATTRIBUTES[] Privileges;
        }
        [StructLayout(LayoutKind.Sequential)]
        public struct WTS_SESSION_INFO
        {
            public readonly UInt32 SessionID;
            [MarshalAs(UnmanagedType.LPStr)]
            public readonly String pWinStationName;
            public readonly WTS_CONNECTSTATE_CLASS State;
        }
        public struct SECURITY_ATTRIBUTES
        {
            public Int32 nLength;
            public IntPtr lpSecurityDescriptor;
            public int bInheritHandle;
        }
    }
    internal class NativeMethods
    {
        [DllImport("kernel32", SetLastError = true)]
        public static extern int WaitForSingleObject(
          IntPtr hHandle,
          int dwMilliseconds);
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool CloseHandle(
            IntPtr hSnapshot);
        [DllImport("userenv.dll", SetLastError = true)]
        public static extern bool CreateEnvironmentBlock(
            ref IntPtr lpEnvironment,
            SafeHandle hToken,
            bool bInherit);
        [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        public static extern bool CreateProcessAsUserW(
            SafeHandle hToken,
            String lpApplicationName,
            StringBuilder lpCommandLine,
            IntPtr lpProcessAttributes,
            IntPtr lpThreadAttributes,
            bool bInheritHandle,
            uint dwCreationFlags,
            IntPtr lpEnvironment,
            String lpCurrentDirectory,
            ref NativeHelpers.STARTUPINFO lpStartupInfo,
            out NativeHelpers.PROCESS_INFORMATION lpProcessInformation);
        [DllImport("userenv.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool DestroyEnvironmentBlock(
            IntPtr lpEnvironment);
        [DllImport("advapi32.dll", SetLastError = true)]
        public static extern bool DuplicateTokenEx(
            SafeHandle ExistingTokenHandle,
            uint dwDesiredAccess,
            IntPtr lpThreadAttributes,
            SECURITY_IMPERSONATION_LEVEL ImpersonationLevel,
            TOKEN_TYPE TokenType,
            out SafeNativeHandle DuplicateTokenHandle);
        [DllImport("kernel32")]
        public static extern IntPtr GetCurrentProcess();
        [DllImport("advapi32.dll", SetLastError = true)]
        public static extern bool GetTokenInformation(
            SafeHandle TokenHandle,
            uint TokenInformationClass,
            SafeMemoryBuffer TokenInformation,
            int TokenInformationLength,
            out int ReturnLength);
        [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        public static extern bool LookupPrivilegeName(
            string lpSystemName,
            ref NativeHelpers.LUID lpLuid,
            StringBuilder lpName,
            ref Int32 cchName);
        [DllImport("advapi32.dll", SetLastError = true)]
        public static extern bool OpenProcessToken(
            IntPtr ProcessHandle,
            TokenAccessLevels DesiredAccess,
            out SafeNativeHandle TokenHandle);
        [DllImport("wtsapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern bool WTSEnumerateSessions(
            IntPtr hServer,
            int Reserved,
            int Version,
            ref IntPtr ppSessionInfo,
            ref int pCount);
        [DllImport("wtsapi32.dll")]
        public static extern void WTSFreeMemory(
            IntPtr pMemory);
        [DllImport("kernel32.dll")]
        public static extern uint WTSGetActiveConsoleSessionId();
        [DllImport("Wtsapi32.dll", SetLastError = true)]
        public static extern bool WTSQueryUserToken(
            uint SessionId,
            out SafeNativeHandle phToken);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern IntPtr CreatePipe(
            ref IntPtr hReadPipe,
            ref IntPtr hWritePipe,
            ref NativeHelpers.SECURITY_ATTRIBUTES lpPipeAttributes,
            Int32 nSize);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool SetHandleInformation(
            IntPtr hObject,
            int dwMask,
            int dwFlags);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool ReadFile(
            IntPtr hFile,
            byte[] lpBuffer,
            int nNumberOfBytesToRead,
            ref int lpNumberOfBytesRead,
            IntPtr lpOverlapped/*IntPtr.Zero*/);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool PeekNamedPipe(
            IntPtr handle,
            byte[] buffer,
            uint nBufferSize,
            ref uint bytesRead,
            ref uint bytesAvail,
            ref uint BytesLeftThisMessage);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool DuplicateHandle(IntPtr hSourceProcessHandle,
           ushort hSourceHandle, IntPtr hTargetProcessHandle, out IntPtr lpTargetHandle,
           uint dwDesiredAccess, [MarshalAs(UnmanagedType.Bool)] bool bInheritHandle, uint dwOptions);

    }
    internal class SafeMemoryBuffer : SafeHandleZeroOrMinusOneIsInvalid
    {
        public SafeMemoryBuffer(int cb) : base(true)
        {
            base.SetHandle(Marshal.AllocHGlobal(cb));
        }
        public SafeMemoryBuffer(IntPtr handle) : base(true)
        {
            base.SetHandle(handle);
        }
        protected override bool ReleaseHandle()
        {
            Marshal.FreeHGlobal(handle);
            return true;
        }
    }
    internal class SafeNativeHandle : SafeHandleZeroOrMinusOneIsInvalid
    {
        public SafeNativeHandle() : base(true) { }
        public SafeNativeHandle(IntPtr handle) : base(true) { this.handle = handle; }
        protected override bool ReleaseHandle()
        {
            return NativeMethods.CloseHandle(handle);
        }
    }
    internal enum SECURITY_IMPERSONATION_LEVEL
    {
        SecurityAnonymous = 0,
        SecurityIdentification = 1,
        SecurityImpersonation = 2,
        SecurityDelegation = 3,
    }
    internal enum SW
    {
        SW_HIDE = 0,
        SW_SHOWNORMAL = 1,
        SW_NORMAL = 1,
        SW_SHOWMINIMIZED = 2,
        SW_SHOWMAXIMIZED = 3,
        SW_MAXIMIZE = 3,
        SW_SHOWNOACTIVATE = 4,
        SW_SHOW = 5,
        SW_MINIMIZE = 6,
        SW_SHOWMINNOACTIVE = 7,
        SW_SHOWNA = 8,
        SW_RESTORE = 9,
        SW_SHOWDEFAULT = 10,
        SW_MAX = 10
    }
    internal enum TokenElevationType
    {
        TokenElevationTypeDefault = 1,
        TokenElevationTypeFull,
        TokenElevationTypeLimited,
    }
    internal enum TOKEN_TYPE
    {
        TokenPrimary = 1,
        TokenImpersonation = 2
    }
    internal enum WTS_CONNECTSTATE_CLASS
    {
        WTSActive,
        WTSConnected,
        WTSConnectQuery,
        WTSShadow,
        WTSDisconnected,
        WTSIdle,
        WTSListen,
        WTSReset,
        WTSDown,
        WTSInit
    }
    [Flags]
    public enum PrivilegeAttributes : uint
    {
        Disabled = 0x00000000,
        EnabledByDefault = 0x00000001,
        Enabled = 0x00000002,
        Removed = 0x00000004,
        UsedForAccess = 0x80000000,
    }
    public class Win32Exception : System.ComponentModel.Win32Exception
    {
        private string _msg;
        public Win32Exception(string message) : this(Marshal.GetLastWin32Error(), message) { }
        public Win32Exception(int errorCode, string message) : base(errorCode)
        {
            _msg = String.Format("{0} ({1}, Win32ErrorCode {2} - 0x{2:X8})", message, base.Message, errorCode);
        }
        public override string Message { get { return _msg; } }
        public static explicit operator Win32Exception(string message) { return new Win32Exception(message); }
    }
    public static class ProcessExtensions
    {
        #region Win32 Constants
        private const int CREATE_UNICODE_ENVIRONMENT = 0x00000400;
        private const int CREATE_NO_WINDOW = 0x08000000;
        private const int CREATE_NEW_CONSOLE = 0x00000010;
        private const uint INVALID_SESSION_ID = 0xFFFFFFFF;
        private static readonly IntPtr WTS_CURRENT_SERVER_HANDLE = IntPtr.Zero;
        private const int HANDLE_FLAG_INHERIT = 0x00000001;
        private const int STARTF_USESTDHANDLES = 0x00000100;
        #endregion
        // Gets the user token from the currently active session
        private static SafeNativeHandle GetSessionUserToken(bool elevated)
        {
            var activeSessionId = INVALID_SESSION_ID;
            var pSessionInfo = IntPtr.Zero;
            var sessionCount = 0;
            // Get a handle to the user access token for the current active session.
            if (NativeMethods.WTSEnumerateSessions(WTS_CURRENT_SERVER_HANDLE, 0, 1, ref pSessionInfo, ref sessionCount))
            {
                try
                {
                    var arrayElementSize = Marshal.SizeOf(typeof(NativeHelpers.WTS_SESSION_INFO));
                    var current = pSessionInfo;
                    for (var i = 0; i < sessionCount; i++)
                    {
                        var si = (NativeHelpers.WTS_SESSION_INFO)Marshal.PtrToStructure(
                            current, typeof(NativeHelpers.WTS_SESSION_INFO));
                        current = IntPtr.Add(current, arrayElementSize);
                        if (si.State == WTS_CONNECTSTATE_CLASS.WTSActive)
                        {
                            activeSessionId = si.SessionID;
                            break;
                        }
                    }
                }
                finally
                {
                    NativeMethods.WTSFreeMemory(pSessionInfo);
                }
            }
            // If enumerating did not work, fall back to the old method
            if (activeSessionId == INVALID_SESSION_ID)
            {
                activeSessionId = NativeMethods.WTSGetActiveConsoleSessionId();
            }
            SafeNativeHandle hImpersonationToken;
            if (!NativeMethods.WTSQueryUserToken(activeSessionId, out hImpersonationToken))
            {
                throw new Win32Exception("WTSQueryUserToken failed to get access token.");
            }
            using (hImpersonationToken)
            {
                // First see if the token is the full token or not. If it is a limited token we need to get the
                // linked (full/elevated token) and use that for the CreateProcess task. If it is already the full or
                // default token then we already have the best token possible.
                TokenElevationType elevationType = GetTokenElevationType(hImpersonationToken);
                if (elevationType == TokenElevationType.TokenElevationTypeLimited && elevated == true)
                {
                    using (var linkedToken = GetTokenLinkedToken(hImpersonationToken))
                        return DuplicateTokenAsPrimary(linkedToken);
                }
                else
                {
                    return DuplicateTokenAsPrimary(hImpersonationToken);
                }
            }
        }

        private static IntPtr out_read;
        private static IntPtr out_write;
        private static IntPtr err_read;
        private static IntPtr err_write;
        private static int BUFSIZE = 4096;
        public static string StartProcessAsCurrentUser(string appPath, string cmdLine = null, string workDir = null, bool visible = true, int wait = -1, bool elevated = true, bool redirectOutput = true)
        {
            NativeHelpers.SECURITY_ATTRIBUTES saAttr = new NativeHelpers.SECURITY_ATTRIBUTES();
            saAttr.nLength = Marshal.SizeOf(typeof(NativeHelpers.SECURITY_ATTRIBUTES));
            saAttr.bInheritHandle = 0x1;
            saAttr.lpSecurityDescriptor = IntPtr.Zero;
            if (redirectOutput)
            {
                NativeMethods.CreatePipe(ref out_read, ref out_write, ref saAttr, 0);
                NativeMethods.CreatePipe(ref err_read, ref err_write, ref saAttr, 0);
                NativeMethods.SetHandleInformation(out_read, HANDLE_FLAG_INHERIT, 0);
                NativeMethods.SetHandleInformation(err_read, HANDLE_FLAG_INHERIT, 0);
            }

            var startInfo = new NativeHelpers.STARTUPINFO();
            startInfo.cb = Marshal.SizeOf(startInfo);
            uint dwCreationFlags = CREATE_UNICODE_ENVIRONMENT | (uint)(visible ? CREATE_NEW_CONSOLE : CREATE_NO_WINDOW);
            startInfo.wShowWindow = (short)(visible ? SW.SW_SHOW : SW.SW_HIDE);
            startInfo.hStdOutput = out_write;
            startInfo.hStdError = err_write;
            startInfo.dwFlags |= (uint)STARTF_USESTDHANDLES;

            StringBuilder commandLine = new StringBuilder(cmdLine);
            var procInfo = new NativeHelpers.PROCESS_INFORMATION();

            using (var hUserToken = GetSessionUserToken(elevated))
            {
                IntPtr pEnv = IntPtr.Zero;
                if (!NativeMethods.CreateEnvironmentBlock(ref pEnv, hUserToken, false))
                {
                    throw new Win32Exception("CreateEnvironmentBlock failed.");
                }

                try
                {
                    if (!NativeMethods.CreateProcessAsUserW(hUserToken,
                        appPath, // Application Name
                        commandLine, // Command Line
                        IntPtr.Zero,
                        IntPtr.Zero,
                        redirectOutput,
                        dwCreationFlags,
                        pEnv,
                        workDir, // Working directory
                        ref startInfo,
                        out procInfo))
                    {
                        throw new Win32Exception("CreateProcessAsUser failed.");
                    }
                    try
                    {
                        NativeMethods.WaitForSingleObject(procInfo.hProcess, wait);
                    }
                    finally
                    {
                        NativeMethods.CloseHandle(procInfo.hThread);
                        NativeMethods.CloseHandle(procInfo.hProcess);
                    }
                }
                finally
                {
                    NativeMethods.DestroyEnvironmentBlock(pEnv);
                }
            }
            if (redirectOutput)
            {
                var sb = new StringBuilder();
                byte[] buf = new byte[BUFSIZE];
                int dwRead = 0;
                while (true)
                {
                    if (Readable(out_read))
                    {
                        bool bSuccess = NativeMethods.ReadFile(out_read, buf, BUFSIZE, ref dwRead, IntPtr.Zero);
                        if (!bSuccess || dwRead == 0)
                            break;
                        sb.AppendLine(Encoding.Default.GetString(buf).TrimEnd(new char[] { (char)0 }));
                    }
                    else
                    {
                        break;
                    }
                }

                NativeMethods.CloseHandle(out_read);
                NativeMethods.CloseHandle(err_read);
                NativeMethods.CloseHandle(out_write);
                NativeMethods.CloseHandle(err_write);

                return sb.ToString();
            }
            else
            {
                return procInfo.dwProcessId.ToString();
            }
        }

        private static bool Readable(IntPtr streamHandle)
        {
            byte[] aPeekBuffer = new byte[1];
            uint aPeekedBytes = 0;
            uint aAvailBytes = 0;
            uint aLeftBytes = 0;

            bool aPeekedSuccess = NativeMethods.PeekNamedPipe(
                streamHandle,
                aPeekBuffer, 1,
                ref aPeekedBytes, ref aAvailBytes, ref aLeftBytes);

            if (aPeekedSuccess && aPeekBuffer[0] != 0)
                return true;
            else
                return false;
        }
        private static SafeNativeHandle DuplicateTokenAsPrimary(SafeHandle hToken)
        {
            SafeNativeHandle pDupToken;
            if (!NativeMethods.DuplicateTokenEx(hToken, 0, IntPtr.Zero, SECURITY_IMPERSONATION_LEVEL.SecurityImpersonation,
                TOKEN_TYPE.TokenPrimary, out pDupToken))
            {
                throw new Win32Exception("DuplicateTokenEx failed.");
            }
            return pDupToken;
        }
        public static Dictionary<String, PrivilegeAttributes> GetTokenPrivileges()
        {
            Dictionary<string, PrivilegeAttributes> privileges = new Dictionary<string, PrivilegeAttributes>();

            using (SafeNativeHandle hToken = OpenProcessToken(NativeMethods.GetCurrentProcess(), TokenAccessLevels.Query))
            using (SafeMemoryBuffer tokenInfo = GetTokenInformation(hToken, 3))
            {
                NativeHelpers.TOKEN_PRIVILEGES privilegeInfo = (NativeHelpers.TOKEN_PRIVILEGES)Marshal.PtrToStructure(
                    tokenInfo.DangerousGetHandle(), typeof(NativeHelpers.TOKEN_PRIVILEGES));

                IntPtr ptrOffset = IntPtr.Add(tokenInfo.DangerousGetHandle(), Marshal.SizeOf(privilegeInfo.PrivilegeCount));
                for (int i = 0; i < privilegeInfo.PrivilegeCount; i++)
                {
                    NativeHelpers.LUID_AND_ATTRIBUTES info = (NativeHelpers.LUID_AND_ATTRIBUTES)Marshal.PtrToStructure(ptrOffset,
                        typeof(NativeHelpers.LUID_AND_ATTRIBUTES));

                    int nameLen = 0;
                    NativeHelpers.LUID privLuid = info.Luid;
                    NativeMethods.LookupPrivilegeName(null, ref privLuid, null, ref nameLen);

                    StringBuilder name = new StringBuilder(nameLen + 1);
                    if (!NativeMethods.LookupPrivilegeName(null, ref privLuid, name, ref nameLen))
                    {
                        throw new Win32Exception("LookupPrivilegeName() failed");
                    }

                    privileges[name.ToString()] = info.Attributes;

                    ptrOffset = IntPtr.Add(ptrOffset, Marshal.SizeOf(typeof(NativeHelpers.LUID_AND_ATTRIBUTES)));
                }
            }

            return privileges;
        }
        private static TokenElevationType GetTokenElevationType(SafeHandle hToken)
        {
            using (SafeMemoryBuffer tokenInfo = GetTokenInformation(hToken, 18))
            {
                return (TokenElevationType)Marshal.ReadInt32(tokenInfo.DangerousGetHandle());
            }
        }
        private static SafeNativeHandle GetTokenLinkedToken(SafeHandle hToken)
        {
            using (SafeMemoryBuffer tokenInfo = GetTokenInformation(hToken, 19))
            {
                return new SafeNativeHandle(Marshal.ReadIntPtr(tokenInfo.DangerousGetHandle()));
            }
        }
        private static SafeMemoryBuffer GetTokenInformation(SafeHandle hToken, uint infoClass)
        {
            int returnLength;
            bool res = NativeMethods.GetTokenInformation(hToken, infoClass, new SafeMemoryBuffer(IntPtr.Zero), 0,
                out returnLength);
            int errCode = Marshal.GetLastWin32Error();
            if (!res && errCode != 24 && errCode != 122)  // ERROR_INSUFFICIENT_BUFFER, ERROR_BAD_LENGTH
            {
                throw new Win32Exception(errCode, String.Format("GetTokenInformation({0}) failed to get buffer length", infoClass));
            }
            SafeMemoryBuffer tokenInfo = new SafeMemoryBuffer(returnLength);
            if (!NativeMethods.GetTokenInformation(hToken, infoClass, tokenInfo, returnLength, out returnLength))
                throw new Win32Exception(String.Format("GetTokenInformation({0}) failed", infoClass));
            return tokenInfo;
        }
        private static SafeNativeHandle OpenProcessToken(IntPtr process, TokenAccessLevels access)
        {
            SafeNativeHandle hToken = null;
            if (!NativeMethods.OpenProcessToken(process, access, out hToken))
            {
                throw new Win32Exception("OpenProcessToken() failed");
            }
            return hToken;
        }
    }
}
"@

function Invoke-AsCurrentUser {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [scriptblock]
        $ScriptBlock,
        [Parameter(Mandatory = $false)]
        [switch]$NoWait,
        [Parameter(Mandatory = $false)]
        [switch]$UseWindowsPowerShell,
        [Parameter(Mandatory = $false)]
        [switch]$UseMicrosoftPowerShell,
        [Parameter(Mandatory = $false)]
        [switch]$NonElevatedSession,
        [Parameter(Mandatory = $false)]
        [switch]$Visible,
        [Parameter(Mandatory = $false)]
        [switch]$CacheToDisk,
        [Parameter(Mandatory = $false)]
        [switch]$CaptureOutput
    )
    if (!("RunAsUser.ProcessExtensions" -as [type])) {
        Add-Type -TypeDefinition $script:source -Language CSharp
    }
    if ($CacheToDisk) {
        $ScriptGuid = new-guid
        $null = New-item "$($ENV:TEMP)\$($ScriptGuid).ps1" -Value $ScriptBlock -Force
        $pwshcommand = "-ExecutionPolicy Bypass -Window Normal -file `"$($ENV:TEMP)\$($ScriptGuid).ps1`""
    } else {
        $encodedcommand = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($ScriptBlock))
        $pwshcommand = "-ExecutionPolicy Bypass -Window Normal -EncodedCommand $($encodedcommand)"
    }
    $OSLevel = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentVersion
    if ($OSLevel -lt 6.2) { $MaxLength = 8190 } else { $MaxLength = 32767 }
    if ($encodedcommand.length -gt $MaxLength -and $CacheToDisk -eq $false) {
        Write-Error -Message "The encoded script is longer than the command line parameter limit. Please execute the script with the -CacheToDisk option."
        return
    }
    if ($UseMicrosoftPowerShell -and -not (Test-Path -Path "$env:ProgramFiles\PowerShell\7\pwsh.exe")) {
        Write-Error -Message "Not able to find Microsoft PowerShell v7 (pwsh.exe). Ensure that it is installed on this system"
        return
    }
    $privs = [RunAsUser.ProcessExtensions]::GetTokenPrivileges()['SeDelegateSessionUserImpersonatePrivilege']
    if (-not $privs -or ($privs -band [RunAsUser.PrivilegeAttributes]::Disabled)) {
        Write-Error -Message "Not running with correct privilege. You must run this script as system or have the SeDelegateSessionUserImpersonatePrivilege token."
        return
    } else {
        try {
            # Use the same PowerShell executable as the one that invoked the function, Unless -UseWindowsPowerShell or -UseMicrosoftPowerShell is defined.
            $pwshPath = if ($UseWindowsPowerShell) { "$($ENV:windir)\system32\WindowsPowerShell\v1.0\powershell.exe" }
            elseif ($UseMicrosoftPowerShell) { "$($env:ProgramFiles)\PowerShell\7\pwsh.exe" }
            else { (Get-Process -Id $pid).Path }

            if ($NoWait) { $ProcWaitTime = 1 } else { $ProcWaitTime = -1 }
            if ($NonElevatedSession) { $RunAsAdmin = $false } else { $RunAsAdmin = $true }
            [RunAsUser.ProcessExtensions]::StartProcessAsCurrentUser(
                $pwshPath, "`"$pwshPath`" $pwshcommand",
                (Split-Path $pwshPath -Parent), $Visible, $ProcWaitTime, $RunAsAdmin, $CaptureOutput)
            if ($CacheToDisk) { $null = remove-item "$($ENV:TEMP)\$($ScriptGuid).ps1" -Force }
        } catch {
            Write-Error -Message "Could not execute as currently logged on user: $($_.Exception.Message)" -Exception $_.Exception
            return
        }
    }
}
# ---------------------------------------------------------------------------
# Identity resolution
#
# Halo matches devices to users on UPN, so a UPN is what this script returns.
# 'whoami /upn' on its own isn't enough: on an on-prem AD estate it returns
# something like user@contoso.local, which M365 and Halo have never heard of.
#
# Instead we collect every identity held locally on the device, rank them, and
# return the best one that has a real internet-facing domain. Sign-in
# identities are genuine UPNs and rank highest. Mailbox addresses are a last
# resort, because a mailbox address is allowed to differ from the UPN.
#
# Nothing below needs credentials, an API key, or Microsoft Graph.
#
# The functions are held as text so the same code can run in both places the
# script needs it: inside the logged-on user's session, and as SYSTEM.
# ---------------------------------------------------------------------------
$IdentityFunctions = @'
# Used to break ties between equally ranked results, so repeat runs on the
# same device always return the same answer.
$script:CandidateSequence = 0

function Test-ConsumerEmail {
    param([string]$Value)

    # A personal mailbox signed into Outlook is never the device's work identity.
    $ConsumerDomains = @(
        'gmail.com', 'googlemail.com', 'yahoo.com', 'yahoo.co.uk', 'ymail.com',
        'hotmail.com', 'hotmail.co.uk', 'outlook.com', 'live.com', 'live.co.uk',
        'msn.com', 'aol.com', 'icloud.com', 'me.com', 'mac.com', 'gmx.com',
        'protonmail.com', 'proton.me', 'btinternet.com', 'sky.com',
        'virginmedia.com', 'talktalk.net', 'blueyonder.co.uk', 'ntlworld.com'
    )
    if ($Value -notmatch '@') { return $false }
    return ($ConsumerDomains -contains ($Value.Split('@')[-1].ToLower()))
}

function Test-RoutableEmail {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
    if ($Value -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$') { return $false }

    # user@contoso.local is a perfectly valid UPN, but it is not one that M365
    # or Halo will ever match, so results using these suffixes are rejected.
    $InternalTlds = @(
        'local', 'lan', 'internal', 'intranet', 'corp', 'ad', 'domain', 'priv',
        'private', 'home', 'localdomain', 'localhost', 'test', 'invalid',
        'example', 'pri', 'dmz'
    )
    return ($InternalTlds -notcontains (($Value -split '\.')[-1].ToLower()))
}

function Get-EmailLocalPart {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    if ($Value -notmatch '@') { return $null }
    return $Value.Split('@')[0].ToLower()
}

function New-IdentityCandidate {
    param(
        [string]$Value,
        [string]$Source,
        [int]$Rank,
        [ValidateSet('Upn', 'Mailbox', 'Fallback')]
        [string]$Kind = 'Upn',
        # Session sources identify the signed-in user directly, from their own
        # logon token or SID. Profile sources only report an account that has
        # been signed in somewhere inside their Windows profile, which is not
        # always the same person.
        [ValidateSet('Session', 'Profile')]
        [string]$Scope = 'Session'
    )

    if ([string]::IsNullOrWhiteSpace($Value)) { return }
    $script:CandidateSequence++
    [PSCustomObject]@{
        Value  = ($Value.Trim() -replace '^(?i)smtp:', '')
        Source = $Source
        Rank   = $Rank
        Kind   = $Kind
        Scope  = $Scope
        Order  = $script:CandidateSequence
    }
}

function Resolve-CandidateOwnership {
    param([object[]]$Candidates, [string[]]$KnownNames)

    # OneDrive, Office and Outlook report whichever account was signed in
    # inside the profile. On a handed-down device, or where a shared mailbox is
    # open, that can be a different person to the one using the machine.
    #
    # If at least one of them matches the account Windows says is signed in,
    # then we can tell the two apart, and the ones that don't match belong to
    # somebody else. If none of them match, we cannot tell, so nothing is
    # changed - plenty of tenants use a username that looks nothing like the
    # first part of the address.
    $Names = @($KnownNames | Where-Object { $_ } | ForEach-Object { $_.ToLower() } | Select-Object -Unique)
    if (-not $Names) { return $Candidates }

    $Scoped = @($Candidates | Where-Object { $_.Scope -eq 'Profile' })
    if (-not @($Scoped | Where-Object { $Names -contains (Get-EmailLocalPart $_.Value) })) { return $Candidates }

    foreach ($Candidate in $Scoped) {
        if ($Names -notcontains (Get-EmailLocalPart $Candidate.Value)) { $Candidate.Scope = 'Foreign' }
    }
    return $Candidates
}

function Sort-IdentityCandidate {
    param([object[]]$Candidates)

    # Anything belonging to another user goes last, then highest rank first,
    # then whichever was found first.
    $Candidates | Sort-Object `
        @{ Expression = { if ($_.Scope -eq 'Foreign') { 1 } else { 0 } }; Descending = $false },
        @{ Expression = 'Rank';  Descending = $true },
        @{ Expression = 'Order'; Descending = $false }
}

function Select-BestIdentity {
    param([object[]]$Candidates)

    $Valid = @($Candidates | Where-Object { $_ -and $_.Value -match '^[^@\s]+@[^@\s]+$' })

    $Best = Sort-IdentityCandidate -Candidates @(
        $Valid | Where-Object { $_.Scope -ne 'Foreign' -and (Test-RoutableEmail $_.Value) }) | Select-Object -First 1

    # If nothing has a usable domain, a user@contoso.local UPN is still a
    # better answer than DOMAIN\username.
    if (-not $Best) { $Best = Sort-IdentityCandidate -Candidates $Valid | Select-Object -First 1 }

    return $Best
}

function Get-IdentityStoreIdentity {
    param([string]$Sid)

    # Entra joined and hybrid joined devices cache the signed-in UPN against
    # the user's SID. This is the most reliable source available on the device.
    $Found = @()
    if ([string]::IsNullOrWhiteSpace($Sid)) { return $Found }

    try {
        $Cache = Get-ItemProperty -ErrorAction Stop `
            -Path "HKLM:\SOFTWARE\Microsoft\IdentityStore\Cache\$Sid\IdentityCache\$Sid"
        if ($Cache.UserName) { $Found += $Cache.UserName }
    } catch { }

    try {
        Get-ChildItem -Path 'HKLM:\SOFTWARE\Microsoft\IdentityStore\LogonCache' -ErrorAction Stop |
            ForEach-Object {
                Get-ChildItem -Path "$($_.PSPath)\Name2Sid" -ErrorAction SilentlyContinue | ForEach-Object {
                    $Entry = Get-ItemProperty -Path $_.PSPath -ErrorAction SilentlyContinue
                    if ($Entry.Sid -eq $Sid -and $Entry.IdentityName) { $Found += $Entry.IdentityName }
                }
            }
    } catch { }

    return $Found
}

function Get-AdUserIdentity {
    param([string]$SamAccountName = $env:USERNAME, [int]$TimeoutSeconds = 10)

    # Queried as the logged-on user, so no stored credentials are needed.
    # USERDNSDOMAIN is only set in a domain logon session, so checking it first
    # stops non-domain devices stalling on a domain controller that isn't there.
    $Result = [PSCustomObject]@{ Mail = $null; PrimarySmtp = $null; Upn = $null }
    if ([string]::IsNullOrWhiteSpace($env:USERDNSDOMAIN)) { return $Result }

    try {
        $Searcher = New-Object System.DirectoryServices.DirectorySearcher
        $Searcher.Filter = "(&(objectCategory=person)(objectClass=user)(sAMAccountName=$SamAccountName))"
        $Searcher.ClientTimeout   = [TimeSpan]::FromSeconds($TimeoutSeconds)
        $Searcher.ServerTimeLimit = [TimeSpan]::FromSeconds($TimeoutSeconds)
        $null = $Searcher.PropertiesToLoad.AddRange(@('mail', 'proxyaddresses', 'userprincipalname'))

        $Entry = $Searcher.FindOne()
        if ($Entry) {
            if ($Entry.Properties['mail'].Count)              { $Result.Mail = [string]$Entry.Properties['mail'][0] }
            if ($Entry.Properties['userprincipalname'].Count) { $Result.Upn  = [string]$Entry.Properties['userprincipalname'][0] }

            # An upper-case SMTP: prefix marks the primary address.
            foreach ($Address in $Entry.Properties['proxyaddresses']) {
                if ("$Address" -cmatch '^SMTP:') { $Result.PrimarySmtp = "$Address" -replace '^SMTP:', ''; break }
            }
        }
    } catch { }

    return $Result
}

function Get-OneDriveBusinessIdentity {
    # OneDrive records the account the user signed in with, so this is a UPN.
    $Found = @()
    try {
        Get-ChildItem -Path 'HKCU:\Software\Microsoft\OneDrive\Accounts' -ErrorAction Stop |
            Where-Object { $_.PSChildName -like 'Business*' } | ForEach-Object {
                $Account = Get-ItemProperty -Path $_.PSPath -ErrorAction SilentlyContinue
                if ($Account.UserEmail) { $Found += $Account.UserEmail }
            }
    } catch { }
    return $Found
}

function Get-OfficeIdentity {
    # As with OneDrive, this is the account Office is signed in as.
    $Found = @()
    foreach ($Version in '16.0', '15.0') {
        $Base = "HKCU:\Software\Microsoft\Office\$Version\Common\Identity"
        try {
            Get-ChildItem -Path "$Base\Identities" -ErrorAction Stop | ForEach-Object {
                # _LiveId keys are personal Microsoft accounts, not work accounts.
                if ($_.PSChildName -like '*LiveId*') { return }
                $Identity = Get-ItemProperty -Path $_.PSPath -ErrorAction SilentlyContinue
                if ($Identity.SignedOut -eq 1) { return }
                if ($Identity.EmailAddress) { $Found += $Identity.EmailAddress }
            }
        } catch { }

        try {
            $Root = Get-ItemProperty -Path $Base -ErrorAction Stop
            if ($Root.ADUserName) { $Found += $Root.ADUserName }
        } catch { }
    }
    return $Found
}

function Get-OutlookOstIdentity {
    param([string]$LocalAppData)

    # Outlook names its cached mailbox files after the mailbox address, so the
    # filename gives us an address. Most recently used mailbox first.
    $Found = @()
    if ([string]::IsNullOrWhiteSpace($LocalAppData)) { return $Found }

    $OutlookPath = Join-Path $LocalAppData 'Microsoft\Outlook'
    if (-not (Test-Path -Path $OutlookPath)) { return $Found }

    Get-ChildItem -Path $OutlookPath -Filter '*.ost' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | ForEach-Object {
            if ($_.BaseName -match '[^\s@]+@[^\s@]+\.[A-Za-z]{2,}') {
                if (-not (Test-ConsumerEmail $Matches[0])) { $Found += $Matches[0] }
            }
        }
    return $Found
}
'@

# This part runs inside the logged-on user's session. It reports everything it
# finds as "Source|Kind|Rank|Address", one per line, and the SYSTEM side of the
# script decides which one wins.
$UserContextBody = @'
$Sid = ([Security.Principal.WindowsIdentity]::GetCurrent()).User.Value
$Candidates = @()

# --- UPNs: the value Halo matches on -------------------------------------
foreach ($Entry in (Get-IdentityStoreIdentity -Sid $Sid)) {
    $Candidates += New-IdentityCandidate -Value $Entry -Source 'EntraIdentityStore' -Rank 100 -Kind Upn
}

$Ad = Get-AdUserIdentity

# The on-prem UPN wins outright unless its suffix is internal-only, in which
# case Test-RoutableEmail drops it and we continue down the list.
$Candidates += New-IdentityCandidate -Value (whoami /upn 2>$null) -Source 'WhoamiUpn' -Rank 95 -Kind Upn
$Candidates += New-IdentityCandidate -Value $Ad.Upn -Source 'ActiveDirectoryUpn' -Rank 90 -Kind Upn

foreach ($Entry in (Get-OneDriveBusinessIdentity)) {
    $Candidates += New-IdentityCandidate -Value $Entry -Source 'OneDriveBusiness' -Rank 85 -Kind Upn -Scope Profile
}
foreach ($Entry in (Get-OfficeIdentity)) {
    $Candidates += New-IdentityCandidate -Value $Entry -Source 'OfficeIdentity' -Rank 80 -Kind Upn -Scope Profile
}

# --- Mailbox addresses: may differ from the UPN, so last resort only ------
$Candidates += New-IdentityCandidate -Value $Ad.Mail        -Source 'ActiveDirectoryMail' -Rank 40 -Kind Mailbox
$Candidates += New-IdentityCandidate -Value $Ad.PrimarySmtp -Source 'ActiveDirectorySmtp' -Rank 38 -Kind Mailbox

foreach ($Entry in (Get-OutlookOstIdentity -LocalAppData $env:LOCALAPPDATA)) {
    $Candidates += New-IdentityCandidate -Value $Entry -Source 'OutlookOst' -Rank 35 -Kind Mailbox -Scope Profile
}

# Discard anything that belongs to a different user of this machine.
$KnownNames = @($env:USERNAME)
foreach ($Candidate in ($Candidates | Where-Object { $_.Scope -eq 'Session' })) {
    $KnownNames += Get-EmailLocalPart $Candidate.Value
}
$Candidates = Resolve-CandidateOwnership -Candidates $Candidates -KnownNames $KnownNames

if ($Candidates) {
    foreach ($Candidate in (Sort-IdentityCandidate -Candidates $Candidates)) {
        "$($Candidate.Source)|$($Candidate.Kind)|$($Candidate.Rank)|$($Candidate.Scope)|$($Candidate.Value)"
    }
} else {
    "SamAccountName|Fallback|0|Session|$env:USERDOMAIN\$env:USERNAME"
}
'@

# Reads one "Source|Kind|Rank|Scope|Address" line back from the user session.
function ConvertFrom-CandidateLine {
    param([string]$Line)

    if ([string]::IsNullOrWhiteSpace($Line)) { return }
    $Parts = $Line.Trim() -split '\|', 5
    if ($Parts.Count -ne 5) { return }

    $Rank = 0
    if (-not [int]::TryParse($Parts[2], [ref]$Rank)) { return }

    $script:CandidateSequence++
    [PSCustomObject]@{
        Value  = $Parts[4]
        Source = $Parts[0]
        Rank   = $Rank
        Kind   = $Parts[1]
        Scope  = $Parts[3]
        Order  = $script:CandidateSequence
    }
}

# Lists everything the device reported, so that an unexpected value in Halo can
# be traced back to whichever source produced it.
function Write-CandidateSummary {
    param([object[]]$Candidates)

    Write-Host 'Identity sources matched on this device:'

    $Grouped = $Candidates | Group-Object -Property Value | ForEach-Object {
        $Ordered = Sort-IdentityCandidate -Candidates $_.Group
        $Top = $Ordered | Select-Object -First 1
        [PSCustomObject]@{
            Value    = $Top.Value
            Kind     = $Top.Kind
            Rank     = $Top.Rank
            Scope    = $Top.Scope
            Order    = $Top.Order
            Routable = (Test-RoutableEmail $Top.Value)
            Sources  = (($Ordered |
                ForEach-Object { "$($_.Source)($($_.Rank))" } | Select-Object -Unique) -join ', ')
        }
    }

    foreach ($Entry in (Sort-IdentityCandidate -Candidates $Grouped)) {
        $Note = if ($Entry.Value -notmatch '^[^@\s]+@[^@\s]+$') { '   <- not an email address' }
                elseif ($Entry.Scope -eq 'Foreign') { '   <- belongs to a different user' }
                elseif (-not $Entry.Routable) { '   <- internal domain, not usable' }
                else { '' }
        Write-Host ("  {0,-10} {1}{2}" -f "[$($Entry.Kind)]", $Entry.Value, $Note)
        Write-Host ("             from: {0}" -f $Entry.Sources)
    }
}

# Windows caps a command line at 32767 characters, and the user session is
# started by passing it this script base64 encoded. The comments above are
# there for whoever reads this script, not for the machine, so they are
# stripped before it is handed over.
function ConvertTo-CompactScript {
    param([string]$Script)

    $Tokens = $null
    $ParseErrors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseInput($Script, [ref]$Tokens, [ref]$ParseErrors)
    if ($ParseErrors.Count) { return $Script }

    # Removed back to front so the earlier offsets stay valid.
    $Comments = @($Tokens | Where-Object { $_.Kind -eq 'Comment' })
    for ($i = $Comments.Count - 1; $i -ge 0; $i--) {
        $Extent = $Comments[$i].Extent
        $Script = $Script.Remove($Extent.StartOffset, $Extent.EndOffset - $Extent.StartOffset)
    }
    return (($Script -split "`r?`n" | Where-Object { $_.Trim() }) -join "`n")
}

. ([ScriptBlock]::Create($IdentityFunctions))

$Raw = Invoke-AsCurrentUser -CaptureOutput `
    -ScriptBlock ([ScriptBlock]::Create((ConvertTo-CompactScript ($IdentityFunctions + $UserContextBody))))

$Candidates = @()
foreach ($Line in ($Raw -split "`r?`n")) {
    $Candidate = ConvertFrom-CandidateLine -Line $Line
    if ($Candidate) { $Candidates += $Candidate }
}

# Nobody is signed in, so there was no user session to query. Fall back to the
# last user Windows recorded at the sign-in screen and look their SID up in the
# same caches, this time as SYSTEM.
if (-not $Candidates) {
    Write-Host 'No output from the user session - falling back to the last logged-on user.'

    $LogonUi = Get-ItemProperty -ErrorAction SilentlyContinue `
        -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI'
    $LastSid = $LogonUi.LastLoggedOnUserSID

    foreach ($Entry in (Get-IdentityStoreIdentity -Sid $LastSid)) {
        $Candidates += New-IdentityCandidate -Value $Entry -Source 'EntraIdentityStore' -Rank 100 -Kind Upn
    }

    $UserProfile = Get-ItemProperty -ErrorAction SilentlyContinue `
        -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$LastSid"
    if ($UserProfile.ProfileImagePath) {
        foreach ($Entry in (Get-OutlookOstIdentity -LocalAppData (Join-Path $UserProfile.ProfileImagePath 'AppData\Local'))) {
            $Candidates += New-IdentityCandidate -Value $Entry -Source 'OutlookOst' -Rank 35 -Kind Mailbox -Scope Profile
        }
    }

    # LastLoggedOnUser is recorded as DOMAIN\username, so it gives us the
    # username to check the profile-scoped results against.
    $KnownNames = @()
    if ($LogonUi.LastLoggedOnUser) { $KnownNames += ($LogonUi.LastLoggedOnUser.Trim() -split '\\')[-1] }
    foreach ($Candidate in ($Candidates | Where-Object { $_.Scope -eq 'Session' })) {
        $KnownNames += Get-EmailLocalPart $Candidate.Value
    }
    $Candidates = Resolve-CandidateOwnership -Candidates $Candidates -KnownNames $KnownNames

    if (-not $Candidates -and $LogonUi.LastLoggedOnUser) {
        $Candidates += New-IdentityCandidate -Value $LogonUi.LastLoggedOnUser -Source 'LogonUI' -Rank 0 -Kind Fallback
    }
}

if (-not $Candidates) {
    Write-Host 'Unable to determine a logged-in user. Leaving the custom field unchanged.'
    exit 1
}

Write-CandidateSummary -Candidates $Candidates

$Best = Select-BestIdentity -Candidates $Candidates
if (-not $Best) {
    # Nothing email-shaped at all, so fall back to DOMAIN\username.
    $Best = $Candidates | Where-Object { $_.Kind -eq 'Fallback' } | Select-Object -First 1
}

if (-not $Best) {
    Write-Host 'Unable to determine a logged-in user. Leaving the custom field unchanged.'
    exit 1
}

if (-not (Test-RoutableEmail $Best.Value)) {
    Write-Host "Warning: '$($Best.Value)' is not a routable email address - no better source was available."
} elseif ($Best.Kind -eq 'Mailbox') {
    # No usable UPN was found, so this is a mailbox address instead. Usually the
    # same value, but it can differ, which is worth knowing if Halo fails to match.
    Write-Host "Warning: no routable UPN found - '$($Best.Value)' is a mailbox address and may not match the user's UPN."
}

Write-Host "Setting '$CustomFieldName' to '$($Best.Value)' (matched via $($Best.Source), $($Best.Kind))."
Ninja-Property-Set $CustomFieldName $Best.Value