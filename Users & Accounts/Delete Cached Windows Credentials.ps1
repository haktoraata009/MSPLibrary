$keys = cmdkey /list 
ForEach($key in $keys){
    if($key -like "*Target:*" -and $key -like "*microsoft*"){
        cmdkey /del:($key -replace " ","" -replace "Target:","")
    }
} 