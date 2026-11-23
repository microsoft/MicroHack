@{
    # Nonsecret source defaults. Scope and identities always come from the platform.
    EventId = 'agentic-pbi-v1'
    DefaultRegion = 'switzerlandnorth'
    VmSize = 'Standard_D4s_v5'
    Image = @{ publisher = 'MicrosoftWindowsServer'; offer = 'WindowsServer'; sku = '2022-datacenter-g2' }
    OsDiskSizeGB = 128
    BastionScaleUnits = 2
    SourceRef = '679f03ec391f2b8adfac4b1fdf58878f8674c272'
    Skills = @{
        uri = 'https://codeload.github.com/microsoft/skills-for-fabric/zip/540c3c58abc804c2715c6632026784f04b342388'
        sha256 = '7f8337365c0da98b4177c5deaf48eae09ed7e2a76e996a1ed7a39c8ab2cfd729'
        root = 'skills-for-fabric-540c3c58abc804c2715c6632026784f04b342388'
        names = @('spark-cli', 'semantic-model-authoring', 'powerbi-report-cli')
    }
    Extensions = @(
        @{
            id = 'GitHub.copilot'; version = '1.388.0'
            uri = 'https://github.gallerycdn.vsassets.io/extensions/github/copilot/1.388.0/1761326434179/Microsoft.VisualStudio.Services.VSIXPackage'
            sha256 = 'ed18caf3e3cd23eac8b9141f0b0a6fb30022cfdf7575a7113b6a9885cbf5be19'
        }
        @{
            id = 'GitHub.copilot-chat'; version = '0.48.1'
            uri = 'https://github.gallerycdn.vsassets.io/extensions/github/copilot-chat/0.48.1/1778884121163/Microsoft.VisualStudio.Services.VSIXPackage'
            sha256 = '7852df60c171be0b59b66c0bb317e778c8c3e233a0f3f524d04bbfebe03aa1d6'
        }
    )
    Tools = @(
        @{
            name = 'powershell'; version = '7.7.0'; format = 'zip'; executable = 'pwsh.exe'
            uri = 'https://github.com/PowerShell/PowerShell/releases/download/v7.7.0/PowerShell-7.7.0-win-x64.zip'
            sha256 = '7c74e03b20a75b59715847439d046a6214b1863ee79b187872980f139bb4a05f'
        }
        @{
            name = 'git'; version = '2.56.1'; format = 'zip'; executable = 'cmd\git.exe'
            uri = 'https://github.com/git-for-windows/git/releases/download/v2.56.1.windows.1/MinGit-2.56.1-64-bit.zip'
            sha256 = '4a92850b6e917da4fd010669b614b55dccf5b0ec333a534cc4be4700dfefdafd'
        }
        @{
            name = 'node'; version = '24.11.1'; format = 'zip'; executable = 'node-v24.11.1-win-x64\node.exe'
            uri = 'https://nodejs.org/dist/v24.11.1/node-v24.11.1-win-x64.zip'
            sha256 = '5355ae6d7c49eddcfde7d34ac3486820600a831bf81dc3bdca5c8db6a9bb0e76'
        }
        @{
            name = 'vscode'; version = '1.147.0'; format = 'zip'; executable = 'bin\code.cmd'
            uri = 'https://vscode.download.prss.microsoft.com/dbazure/download/stable/8a14f0cc1b08d531eb83255ea3764ae22aa932b5/VSCode-win32-x64-1.147.0.zip'
            sha256 = '42d65f18009959964d7cff8ca6f33149a195d52c08622821c8c681a08469c26e'
        }
        @{
            name = 'copilot'; version = '1.0.114'; format = 'zip'; executable = 'copilot.exe'
            uri = 'https://github.com/github/copilot-cli/releases/download/v1.0.114/copilot-win32-x64.zip'
            sha256 = 'be5af88c044842949560535b083c47e0c2b41904769cca599ee2cbf937dc9eed'
        }
        @{
            name = 'azure-cli'; version = '2.93.0'; format = 'msi'
            executable = 'C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd'
            uri = 'https://github.com/Azure/azure-cli/releases/download/azure-cli-2.93.0/azure-cli-2.93.0-x64.msi'
            sha256 = '66c7241d1a10d7c27110e4b434b4ecd3b850db4ddfce12c2e1f0b0d00071e45e'
        }
        @{
            name = 'python'; version = '3.12.10'; format = 'python'
            executable = 'C:\MicroHack\tools\python\python.exe'
            uri = 'https://www.python.org/ftp/python/3.12.10/python-3.12.10-amd64.exe'
            sha256 = '67b5635e80ea51072b87941312d00ec8927c4db9ba18938f7ad2d27b328b95fb'
        }
    )
}
