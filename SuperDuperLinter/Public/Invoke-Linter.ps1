using namespace System.Management.Automation
using namespace System.IO

function Invoke-Linter {
    param (
        #Linter Definitions to run. These must have filesToMatch already populated
        [Parameter(Mandatory)][Hashtable[]]$LinterDefinition,
        #How many different linters to run simultaneously
        [Int]$ThrottleLimit = 5
    )


    #Filter out linters that don't need to be run
    [HashTable[]]$LinterDefinition = $linterDefinition | Where-Object {
        if (-not $PSItem.filesToLint) {
            Write-Verbose "$($PSItem.name): No files matched. Skipping..."
        } else {
            $true
        }
    }
    function Clone-Object ($InputObject) {
        <#
        .SYNOPSIS
        Use the serializer to create an independent copy of an object, useful when using an object as a template
        #>
        [psserializer]::Deserialize(
            [psserializer]::Serialize(
                $InputObject
            )
        )
    }
    #Break out linters into individual files for those that need it (assume by default)
    [HashTable[]]$LinterDefinition = Foreach ($linter in $LinterDefinition) {
        if ($linter.filemode -eq 'multiple' -or $linter.filestolint.count -eq 1) {
            Write-Output $linter
        } else {
            foreach ($linterFilePath in $linter.filesToLint) {
                Write-Verbose "$($linter.name): Creating runner for $linterfilePath..."
                $newLinter = Clone-Object $linter
                $newLinter.filesToLint = $linterFilePath
                Write-Output $newLinter
            }
        }
    }

    $LinterDefinition | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {
        $linter = $PSItem
        $icons = @{
            success = "`u{2705}"
            failure = "`u{274C}"
        }

        $linterArgs = $linter.args
        $linter.result = & $linter.command @linterArgs $linter.filesToLint *>&1
        $linterExitCode = $LASTEXITCODE
        $linter.filesToLint.foreach{
            if ($linterExitCode -ne 0) {
                $linter.status = 'failure'
                #Write-Verbose "$($linter.name) exited with status - $linterExitCode"
            } else {
                $linter.status = 'success'
            }
            Write-Host "[$($icons[$linter.status])] $PSItem - $($linter.name)"
        }
        Write-Host -Fore Cyan $result
        #Return the formatted linter result
        Write-Output $linter
    }
}