Describe "SRV01 Service Validation" {

    $service = Get-Service -Name WinRM -ErrorAction SilentlyContinue

    It "WinRM service should exist" {

        $service | Should Not BeNullOrEmpty
    }

    if ($null -ne $service) {

        It "WinRM service should be running" {

            $service.Status | Should Be "Running"
        }
    }
}
