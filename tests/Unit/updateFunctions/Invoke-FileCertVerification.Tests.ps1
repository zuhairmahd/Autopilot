<#
.SYNOPSIS
    Unit tests for Invoke-FileCertVerification function
.DESCRIPTION
    Tests certificate validation, chain verification, and trust validation
    Compatible with PowerShell 5.1 and Pester 5.x
.NOTES
    Part of Week 2 Phase 1 coverage improvement initiative
    Tests use mocked certificate objects to avoid file system dependencies
#>

Import-Module "$PSScriptRoot/../../Helpers/AutopilotTestHelpers.psm1" -Force

Describe "Function: Invoke-FileCertVerification" -Tags 'Unit', 'UpdateFunctions' {
    BeforeAll {
        # Direct dot-sourcing for PS 5.1 compatibility
        $script:RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
        
        # Load Write-Log dependency
        . "$script:RepoRoot/functions/utilityFunctions/Write-Log.ps1"
        
        # Load function under test
        . "$script:RepoRoot/functions/updateFunctions/Invoke-FileCertVerification.ps1"
        
        # Mock Write-Log and Write-Output for all tests
        Mock Write-Log {}
        Mock Write-Output {}
        
        # Initialize required script variable
        $script:LogFile = "TestDrive:\test.log"
    }
    
    Context "When file is properly signed and trusted" {
        It "Should return true for valid signature with Microsoft root" {
            # Mock certificate objects
            $mockCert = [PSCustomObject]@{
                Subject    = "CN=Test, O=Zuhair Mahmoud"
                Issuer     = "CN=Microsoft Identity Verification"
                NotBefore  = (Get-Date).AddDays(-30)
                NotAfter   = (Get-Date).AddDays(365)
                Thumbprint = "ABC123"
            }
            
            $mockRootCert = [PSCustomObject]@{
                Subject    = "CN=Microsoft Identity Verification Root"
                Thumbprint = "ABC123"
            }
            
            Mock Get-AuthenticodeSignature {
                return @{
                    SignerCertificate = $mockCert
                    Status            = "Valid"
                }
            }
            
            Mock New-Object {
                param($TypeName)
                if ($TypeName -eq "System.Security.Cryptography.X509Certificates.X509Chain")
                {
                    return [PSCustomObject]@{
                        ChainElements = @(
                            @{ Certificate = $mockCert },
                            @{ Certificate = $mockRootCert }
                        )
                    } | Add-Member -MemberType ScriptMethod -Name Build -Value { $true } -PassThru
                }
            }
            
            Mock Get-ChildItem {
                param($Path, $Recurse)
                if ($Path -eq "Cert:\\LocalMachine\\Root")
                {
                    return @($mockRootCert)
                }
            }
            
            $result = Invoke-FileCertVerification -FilePath "C:\test\file.exe"
            
            $result | Should -Be $true
        }
        
        It "Should call Get-AuthenticodeSignature with correct file path" {
            Mock Get-AuthenticodeSignature {
                param($FilePath)
                $FilePath | Should -Be "C:\TestFile.exe"
                return @{
                    SignerCertificate = $null
                    Status            = "NotSigned"
                }
            }
            
            $result = Invoke-FileCertVerification -FilePath "C:\TestFile.exe"
        }
    }
    
    Context "When file is not signed" {
        It "Should return false for unsigned file" {
            Mock Get-AuthenticodeSignature {
                return @{
                    SignerCertificate = $null
                    Status            = "NotSigned"
                }
            }
            
            $result = Invoke-FileCertVerification -FilePath "C:\unsigned.exe"
            
            $result | Should -Be $false
        }
        
        It "Should log error message for unsigned file" {
            Mock Get-AuthenticodeSignature {
                return @{
                    SignerCertificate = $null
                    Status            = "NotSigned"
                }
            }
            Mock Write-Output {} -ParameterFilter { $InputObject -match "not signed" }
            
            $result = Invoke-FileCertVerification -FilePath "C:\unsigned.exe"
            
            Should -Invoke Write-Output -ParameterFilter { $InputObject -match "not signed" }
        }
    }
    
    Context "When certificate is invalid or untrusted" {
        It "Should return false when certificate status is not Valid" {
            $mockCert = [PSCustomObject]@{
                Subject   = "CN=Test, O=Zuhair Mahmoud"
                Issuer    = "CN=Unknown CA"
                NotBefore = (Get-Date).AddDays(-30)
                NotAfter  = (Get-Date).AddDays(365)
            }
            
            Mock Get-AuthenticodeSignature {
                return @{
                    SignerCertificate = $mockCert
                    Status            = "UnknownError"
                }
            }
            
            $result = Invoke-FileCertVerification -FilePath "C:\invalid.exe"
            
            $result | Should -Be $false
        }
        
        It "Should return false when certificate is not from Zuhair Mahmoud" {
            $mockCert = [PSCustomObject]@{
                Subject   = "CN=Test, O=Other Organization"
                Issuer    = "CN=Some CA"
                NotBefore = (Get-Date).AddDays(-30)
                NotAfter  = (Get-Date).AddDays(365)
            }
            
            Mock Get-AuthenticodeSignature {
                return @{
                    SignerCertificate = $mockCert
                    Status            = "Valid"
                }
            }
            
            $result = Invoke-FileCertVerification -FilePath "C:\other.exe"
            
            $result | Should -Be $false
        }
    }
    
    Context "When certificate chain validation fails" {
        It "Should return false when root cert is not Microsoft" {
            $mockCert = [PSCustomObject]@{
                Subject   = "CN=Test, O=Zuhair Mahmoud"
                Issuer    = "CN=Some CA"
                NotBefore = (Get-Date).AddDays(-30)
                NotAfter  = (Get-Date).AddDays(365)
            }
            
            $mockNonMSRootCert = [PSCustomObject]@{
                Subject    = "CN=Other Root"
                Thumbprint = "XYZ789"
            }
            
            Mock Get-AuthenticodeSignature {
                return @{
                    SignerCertificate = $mockCert
                    Status            = "Valid"
                }
            }
            
            Mock New-Object {
                param($TypeName)
                if ($TypeName -eq "System.Security.Cryptography.X509Certificates.X509Chain")
                {
                    return [PSCustomObject]@{
                        ChainElements = @(
                            @{ Certificate = $mockCert },
                            @{ Certificate = $mockNonMSRootCert }
                        )
                    } | Add-Member -MemberType ScriptMethod -Name Build -Value { $true } -PassThru
                }
            }
            
            $result = Invoke-FileCertVerification -FilePath "C:\test.exe"
            
            $result | Should -Be $false
        }
        
        It "Should return false when root cert is not in trusted store" {
            $mockCert = [PSCustomObject]@{
                Subject    = "CN=Test, O=Zuhair Mahmoud"
                Issuer     = "CN=Microsoft CA"
                NotBefore  = (Get-Date).AddDays(-30)
                NotAfter   = (Get-Date).AddDays(365)
                Thumbprint = "ABC123"
            }
            
            $mockRootCert = [PSCustomObject]@{
                Subject    = "CN=Microsoft Identity Verification Root"
                Thumbprint = "DIFFERENT123"
            }
            
            Mock Get-AuthenticodeSignature {
                return @{
                    SignerCertificate = $mockCert
                    Status            = "Valid"
                }
            }
            
            Mock New-Object {
                param($TypeName)
                if ($TypeName -eq "System.Security.Cryptography.X509Certificates.X509Chain")
                {
                    return [PSCustomObject]@{
                        ChainElements = @(
                            @{ Certificate = $mockCert },
                            @{ Certificate = $mockRootCert }
                        )
                    } | Add-Member -MemberType ScriptMethod -Name Build -Value { $true } -PassThru
                }
            }
            
            Mock Get-ChildItem {
                param($Path)
                if ($Path -eq "Cert:\\LocalMachine\\Root")
                {
                    # Return cert with different thumbprint
                    return @([PSCustomObject]@{ Thumbprint = "OTHER456" })
                }
            }
            
            $result = Invoke-FileCertVerification -FilePath "C:\test.exe"
            
            $result | Should -Be $false
        }
    }
    
    Context "When exception occurs during verification" {
        It "Should return false and log exception for Get-AuthenticodeSignature error" {
            Mock Get-AuthenticodeSignature {
                throw "File not found"
            }
            Mock Write-Output {} -ParameterFilter { $InputObject -match "Exception" }
            
            $result = Invoke-FileCertVerification -FilePath "C:\missing.exe"
            
            $result | Should -Be $false
            Should -Invoke Write-Output -ParameterFilter { $InputObject -match "Exception" }
        }
        
        It "Should return false for chain building exception" {
            $mockCert = [PSCustomObject]@{
                Subject   = "CN=Test, O=Zuhair Mahmoud"
                Issuer    = "CN=Test CA"
                NotBefore = (Get-Date).AddDays(-30)
                NotAfter  = (Get-Date).AddDays(365)
            }
            
            Mock Get-AuthenticodeSignature {
                return @{
                    SignerCertificate = $mockCert
                    Status            = "Valid"
                }
            }
            
            Mock New-Object {
                throw "Chain building failed"
            }
            
            $result = Invoke-FileCertVerification -FilePath "C:\test.exe"
            
            $result | Should -Be $false
        }
    }
    
    Context "When testing parameter validation" {
        It "Should require FilePath parameter" {
            # Verify Mandatory attribute exists by checking function definition
            $funcDef = (Get-Command Invoke-FileCertVerification).Parameters['FilePath']
            $funcDef.Attributes.Mandatory | Should -Contain $true
        }
        
        It "Should not accept null or empty FilePath" {
            # This test verifies the ValidateNotNullOrEmpty attribute
            { Invoke-FileCertVerification -FilePath "" } | Should -Throw
            { Invoke-FileCertVerification -FilePath $null } | Should -Throw
        }
    }
    
    Context "When testing logging behavior" {
        It "Should log certificate status" {
            Mock Get-AuthenticodeSignature {
                return @{
                    SignerCertificate = [PSCustomObject]@{
                        Subject = "CN=Test, O=Zuhair Mahmoud"
                    }
                    Status            = "Valid"
                }
            }
            Mock New-Object { throw "Chain test" }  # Force early exit
            Mock Write-Output {} -ParameterFilter { $InputObject -match "Certificate status" }
            
            $result = Invoke-FileCertVerification -FilePath "C:\test.exe"
            
            Should -Invoke Write-Output -ParameterFilter { $InputObject -match "Certificate status" }
        }
        
        It "Should log certificate details" {
            $mockCert = [PSCustomObject]@{
                Subject   = "CN=Test, O=Zuhair Mahmoud"
                Issuer    = "CN=Test Issuer"
                NotBefore = (Get-Date).AddDays(-30)
                NotAfter  = (Get-Date).AddDays(365)
            }
            
            Mock Get-AuthenticodeSignature {
                return @{
                    SignerCertificate = $mockCert
                    Status            = "Valid"
                }
            }
            Mock New-Object { throw "Chain test" }  # Force early exit
            Mock Write-Output {} -ParameterFilter { $InputObject -match "Certificate subject" }
            
            $result = Invoke-FileCertVerification -FilePath "C:\test.exe"
            
            Should -Invoke Write-Output -ParameterFilter { $InputObject -match "Certificate subject" }
            Should -Invoke Write-Output -ParameterFilter { $InputObject -match "Certificate issuer" }
        }
    }
    
    AfterAll {
        # Clean up TestDrive to prevent GUID folder remnants
        if (Test-Path "TestDrive:\")
        {
            Get-ChildItem "TestDrive:\" -Recurse | Remove-Item -Force -ErrorAction SilentlyContinue | Out-Null
        }
    }
}
