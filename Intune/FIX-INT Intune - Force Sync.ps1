[Windows.Management.MdmSessionManager,Windows.Management,ContentType=WindowsRuntime]
$session = [Windows.Management.MdmSessionManager]::TryCreateSession()
$session.StartAsync()