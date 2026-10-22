#Check for embedded digital key
$EmbedKey = (Get-WmiObject -query ‘select * from SoftwareLicensingService’).OA3xOriginalProductKey

#Only proceed if embedded key is found
If ($EmbedKey)
{
  #Uninstall current key
  slmgr.vbs /upk
  #Remove old key from the registry
  slmgr.vbs /cpky
  #Install embedded Windows key
  slmgr -ipk $EmbedKey
  #Force activation
  slmgr /ato
}

Exit
