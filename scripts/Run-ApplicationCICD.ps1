[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $LandingZoneNameRootPath,
    [Parameter()]
    [string]
    $AppFolder,
    [Parameter()]
    [string]
    $Environment = "dev",
    [Parameter()]
    [string]
    $ApplicationBuildPhase = "build",
    [Parameter()]
    [string]
    $ApplicationWorkingPath,
    [Parameter()]
    [string]
    $ApplicationBuildTags,
    [Parameter()]
    [string]
    $ApplicationBuildDefaultTag,
    [Parameter()]
    [string]
    $ApplicationBuildImageName,
    [Parameter()]
    [string]
    $ApplicationBuildDockerfileArgs,
    [Parameter()]
    [string]
    $ApplicationBuildDockerfile = "Dockerfile",
    [Parameter()]
    [string]
    $ApplicationBuildImageRepository,
    [Parameter()]
    [string]
    $ApplicationBuildImageRegistry,
    [Parameter()]
    [switch]
    $AutomatedRun,
    [Parameter()]
    [switch]
    $IsBuildDryRun
)

begin {
    Write-Verbose "Starting $($MyInvocation.MyCommand.Name)"
    $CURRENT_WORKING_PATH = Get-Location
    trap {
        Write-Verbose "Cleaning up $($MyInvocation.MyCommand.Name)"
        Set-Location -Path $CURRENT_WORKING_PATH
    }
    . $PSScriptRoot\Set-PathSlashes.ps1

    if (Test-Path -Path $LandingZoneNameRootPath) {
        Write-Verbose "LandingZoneNameRootPath: $LandingZoneNameRootPath"
    }
    else {
        Write-Error "LandingZoneNameRootPath: $LandingZoneNameRootPath does not exist"
    }

    if ($AutomatedRun.IsPresent) {
        if ($env:ARM_CLIENT_ID) {
            Write-Verbose "ARM_CLIENT_ID is Set"
        }
        else {
            Write-Host $env:ARM_CLIENT_ID
            Write-Error "ARM_CLIENT_ID does not exist"
        }

        if ($env:ARM_CLIENT_SECRET) {
            Write-Verbose "ARM_CLIENT_SECRET is Set"
        }
        else {
            Write-Error "ARM_CLIENT_SECRET does not exist"
        }

        if ($env:ARM_TENANT_ID) {
            Write-Verbose "ARM_TENANT_ID is Set"
        }
        else {
            Write-Error "ARM_TENANT_ID does not exist"
        }

        if ($env:ARM_SUBSCRIPTION_ID) {
            Write-Verbose "ARM_SUBSCRIPTION_ID is Set"
        }
        else {
            Write-Error "ARM_SUBSCRIPTION_ID does not exist"
        }

        az login --service-principal --allow-no-subscriptions -u $env:ARM_CLIENT_ID -p $env:ARM_CLIENT_SECRET --tenant $env:ARM_TENANT_ID
        az account set --subscription $env:ARM_SUBSCRIPTION_ID
    }
    else {
        if ((Get-AzContext -ErrorAction 0)) {
            Write-Verbose "Azure Context is Set. Skipping Azure Login"
        }
        else {
            Write-Error "Azure Context is not Set. Please login to Azure"
        }
        Write-Verbose "Automation is not configured"
    }

    Write-Verbose "Setting ApplicationPath"
    $ApplicationPath = (Set-PathSlashes(("{0}/{1}" -f $LandingZoneNameRootPath, $AppFolder)))
    if (Test-Path -Path $ApplicationPath) {
        Write-Verbose "ApplicationPath: $ApplicationPath"
    }
    else {
        Write-Error "ApplicationPath: $ApplicationPath does not exist"
    }

    
    Write-Verbose "Setting working directory to $ApplicationWorkingPath"
    Set-Location -Path $ApplicationWorkingPath

    Write-Verbose "Copying Resource Files from $ApplicationPath to $ApplicationWorkingPath"
    Copy-Item -Path (Set-PathSlashes(("{0}\*" -f $ApplicationPath))) -Destination $ApplicationWorkingPath -Exclude "envs", ".terraform" -Force -Verbose

    Write-Verbose "Listing Files in $ApplicationWorkingPath"
    Get-Item -Path (Set-PathSlashes(("{0}\*" -f $ApplicationWorkingPath)))
}

process {
    switch ($ApplicationBuildPhase) {
        build {
            Write-Verbose "Starting Application Image Build"
            $BuildCommand = "az acr build"
            if($IsBuildDryRun.IsPresent) {
                $BuildCommand = "--no-push"
            }
            
            $Tags = $null
            foreach($Tag in ($ApplicationBuildTags -split ',')) {
                $BuildCommand += " -t {0}/{1}:{2}" -f $ApplicationBuildImageRepository, $ApplicationBuildImageName, $Tag.Trim()
            }

            foreach($BuildArg in ($ApplicationBuildDockerfileArgs.Split(','))) {
                $BuildArg = $BuildArg.Trim()
                $BuildArg = $BuildArg.Split('=')
                $BuildArg = "{0}='{1}'" -f $BuildArg[0], $BuildArg[1]
                $BuildCommand += " --build-arg {0}" -f $BuildArg
            }

            $BuildCommand = "{0} {1}" -f $BuildCommand, "-r $ApplicationBuildImageRegistry -f $ApplicationBuildDockerfile ."
            Write-Verbose "Build Command: $BuildCommand"
            Invoke-Expression($BuildCommand)
            break
        }
        deploy {
            Write-Verbose "Starting Application Image Deploy"
            # TODO: Add Deploy Logic
            break
        }
        default {
            Write-Verbose "Starting Application Image Deploy"
            # TODO: Add Deploy Logic
            break
        }
    }
    
    if ( $LASTEXITCODE -ne 0) {
        Write-Verbose "Cleaning up $($MyInvocation.MyCommand.Name)"
        Set-Location -Path $CURRENT_WORKING_PATH
        Write-Error "Error found in deploying $ApplicationWorkingPath. Exit code is: $LASTEXITCODE";
    }
    else {
        Write-Verbose "Terraform complete for $ApplicationWorkingPath";
    }
}

end {
    Set-Location -Path $CURRENT_WORKING_PATH
    Write-Verbose "Ending $($MyInvocation.MyCommand.Name)"
}