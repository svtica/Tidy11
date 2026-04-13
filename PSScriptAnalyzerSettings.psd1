@{
    # PSScriptAnalyzer settings tuned for Tidy11
    # See https://learn.microsoft.com/powershell/utility-modules/psscriptanalyzer/rules/readme

    Severity = @('Error', 'Warning', 'Information')

    # Rules we explicitly opt out of, with rationale.
    ExcludeRules = @(

        # Tidy11 logs to a WPF TextBox via Write-Host wrapped in Write-Log.
        # The wrapper IS the logger, and the GUI surfaces it. Suppressing here
        # because the rule fires on every Write-Log call.
        'PSAvoidUsingWriteHost',

        # Many functions in the module deliberately don't use ShouldProcess
        # (e.g. Set-Reg, Disable-Svc) because they're called from a single
        # interactive entry point that already shows a confirmation dialog.
        'PSUseShouldProcessForStateChangingFunctions',

        # Module uses script-scoped variables intentionally for snapshot path,
        # log file path, created-values list, telemetry hosts array, etc.
        'PSAvoidGlobalVars',

        # The wrapper extras and registry helpers create reg values whose
        # plural form is fine; PSSA's noun-singularization rule is too noisy.
        'PSUseSingularNouns',

        # Some helper functions intentionally use approved-but-uncommon verbs
        # (Test-RegValue, Add-BlockDomain, Remove-BlockDomain). They ARE
        # approved verbs; this rule sometimes false-flags them in older PSSA.
        'PSUseApprovedVerbs'
    )

    # Rules we want elevated to Error so they never slip through.
    Rules = @{

        PSPlaceOpenBrace = @{
            Enable             = $true
            OnSameLine         = $true
            NewLineAfter       = $true
            IgnoreOneLineBlock = $true
        }

        PSPlaceCloseBrace = @{
            Enable             = $true
            NoEmptyLineBefore  = $true
            IgnoreOneLineBlock = $true
            NewLineAfter       = $false
        }

        PSUseConsistentIndentation = @{
            Enable          = $true
            Kind            = 'space'
            IndentationSize = 4
        }

        PSAvoidTrailingWhitespace = @{
            Enable = $true
        }

        PSAvoidUsingPlainTextForPassword = @{
            Enable = $true
        }

        PSAvoidUsingConvertToSecureStringWithPlainText = @{
            Enable = $true
        }

        PSAvoidUsingInvokeExpression = @{
            Enable = $true
        }
    }
}
