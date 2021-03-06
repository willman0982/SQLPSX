function Set-Property
{
    <#
    .Synopsis
        Sets properties on an object or subscribes to events
    .Description
        Set-Property is used by each parameter in the automatically generated
        controls in WPK.
    .Parameter InputObject
        The object to set properties on
    .Parameter Hashtable
        A Hashtable contains properties to set.
        The key is the name of the property on an object, or "On_" + the name 
        of an event you can subscribe to (i.e. On_Loaded).
        The value can either be a literal value (such as a string), a block of XAML,
        or a script block that produces the value that needs to be set.
    .Example
        $window = New-Window
        $window | Set-Property @{Width=100;Height={200}} 
        $window | show-Window
    #>
    param(    
    [Parameter(ValueFromPipeline=$true)]    
    $inputObject,
    [Parameter(Position=0)] 
    [Hashtable]$property
    )
       
    process {    
        if ($property) {
            foreach ($p in $property) {
                foreach ($k in $p.Keys) {
                    if (-not $k) { continue }
                    $realKey = $k
                    if ("$k".StartsWith("On_")) {
                        $realKey = "$k".Substring(3)
                    }
                    Write-Debug $k
                    
                    $realItem  = $inputObject.psObject.Members[$realKey ] 
                    if (-not $realItem) {
                        $realItem = $inputObject.psObject.Members | Where-Object { $_.Name -eq $realKey } 
                    }
                    switch ($realItem.MemberType) {
                        Method {
                            $inputObject."$($realItem.Name)".Invoke(@($p[$realKey]))
                        }
                        Property { 
                            $reflectedProperty = $realItem.TypeNameofValue -as [Type]                         
                            if ($reflectedProperty -and $reflectedProperty.GetInterface("IList")) {
                                Write-Debug $realKey
                                Write-Debug $p.GetType().FullName
                                Write-Debug "Hi"
                                $v = $p[$realKey]
                                if ($v -is [ScriptBlock]) { 
                                    try {
                                        $v = & ([ScriptBlock]::Create($v))
                                    } catch {
                                        Write-Error $_
                                    } 
                                } 
                                foreach ($i in $v) {                                    
                                    $ri = $i               
                                    $xaml = ConvertTo-Xaml $ri       
                                    if ($xaml) {
                                        try {                                            
                                            $rv = [Windows.Markup.XamlReader]::Parse($xaml)
                                            if ($rv) { $ri = $rv } 
                                        }
                                        catch {
                                        
                                        }
                                    }
                                    $null = $inputObject."$($realItem.Name)".Add($ri)                                                                                                        
                                }
                            } else {                                                                                                        
                                if ($realItem.IsSettable) {
                                    if ($debugPreference -eq "continue") {
                                        Write-Debug "Setting $($realItem.Name) to $($p[$realKey] | Out-String)"
                                    }
                                    if ($realItem.Name -eq "Name") {
                                        if (-not $global:namedControls) {
                                            $global:namedControls = @{}
                                        }
                                        $global:namedControls."$($p[$realKey])" = $inputObject
                                    }
                                    $v = $p[$realKey]
                                    if ($v -is [ScriptBlock]) {
                                        $v = & ([ScriptBlock]::Create($v))
                                    }
                                    $xaml = ConvertTo-Xaml $v
                                    if ($xaml) {
                                        try {                                            
                                            $rv = [Windows.Markup.XamlReader]::Parse($xaml)
                                            if ($rv) { $v = $rv } 
                                        }
                                        catch {
                                            Write-Debug ($_ | Out-String)
                                        }
                                    }
                                    $inputObject."$($realItem.Name)" = $v
                                }
                            }                            
                        }
                        Event {
                            $sb = [ScriptBlock]::Create($p[$k])
                            Add-EventHandler $InputObject $RealItem.Name $sb
#                            $sb = [ScriptBlock]::Create($p[$k])
#                                        
#                            if (-not $inputObject.EventHandlers) {
#                                Add-Member -inputObject $inputObject NoteProperty EventHandlers @{}
#                            }
#                            $ofs = "
#                            "                                                        
#                            $sb = [ScriptBlock]::Create($p[$k])
#                            $inputObject.EventHandlers."$realKey" = $sb
#                            if ($inputObject.Resources) {
#                            
#                            }
#                            $inputObject."add_$($realItem.Name)".Invoke(@($sb))

                        }
                    }
                }
            }
        }
    }
}