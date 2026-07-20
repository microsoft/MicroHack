# Clone Partial Repository

This guide shows how to clone only the "Oracle on Azure" project from the GIT repository without downloading the entire project history.

> NOTE: During Challenge we did setup Azure CloudShell, feel free to use the Azure CloudShell to clone the repo. Alternative you can execute this commands from your local PC.

## Quick Start

```powershell
# Clone with sparse-checkout (recommended)
git clone --depth 1 --filter=blob:none --sparse https://github.com/cpinotossi/msftmh.git

cd msftmh

# Checkout only the Oracle on Azure folder
git sparse-checkout set 03-Azure/01-03-Infrastructure/10_Oracle_on_Azure
```

## What This Does

- `--depth 1`: Downloads only the latest commit (shallow clone)
- `--filter=blob:none`: Downloads only necessary files, not all file versions
- `--sparse`: Enables sparse-checkout mode
- `git sparse-checkout set`: Specifies which folder to download

## Switch to the right folder

You'll have only the `10_Oracle_on_Azure` folder with its contents, saving bandwidth and disk space.

~~~powershell
cd 03-Azure/01-03-Infrastructure/10_Oracle_on_Azure
~~~

## Tips and Tricks

### Customizing the Prompt 

The following PowerShell function customizes your prompt to show only the current folder name, making it easier to identify your location in the terminal.

~~~powershell
function prompt {
    $currentFolder = (Get-Item -Path ".\" -Verbose).Name
    "PS $currentFolder> "
}
~~~