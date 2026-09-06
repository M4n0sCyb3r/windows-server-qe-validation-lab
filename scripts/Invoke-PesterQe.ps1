param(
    [Parameter(Mandatory = $true)]
    [string]$TestContent
)

$ErrorActionPreference = "Stop"

$testPath = Join-Path $env:TEMP "QE.Pester.Tests.ps1"

try {
    $pesterModule = Get-Module -ListAvailable Pester |
        Sort-Object Version -Descending |
        Select-Object -First 1

    if ($null -eq $pesterModule) {
        throw "Pester module is not available."
    }

    Set-Content `
        -Path $testPath `
        -Value $TestContent `
        -Encoding UTF8

    $result = Invoke-Pester `
        -Script $testPath `
        -PassThru

    $tests = @(
        foreach ($test in $result.TestResult) {

            [PSCustomObject]@{
                name            = $test.Name
                describe        = $test.Describe
                context         = $test.Context
                result          = $test.Result
                passed          = [bool]$test.Passed
                duration_ms     = [math]::Round($test.Time.TotalMilliseconds, 2)
                failure_message = $test.FailureMessage
            }
        }
    )

    $evidence = [PSCustomObject]@{
        schema_version    = 1
        framework         = "Pester"
        framework_version = $pesterModule.Version.ToString()
        total             = [int]$result.TotalCount
        passed            = [int]$result.PassedCount
        failed            = [int]$result.FailedCount
        skipped           = [int]$result.SkippedCount
        pending           = [int]$result.PendingCount
        tests             = $tests
    }

    $evidence | ConvertTo-Json -Depth 5 -Compress
}
finally {
    if (Test-Path $testPath) {
        Remove-Item $testPath -Force
    }
}
