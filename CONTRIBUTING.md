## Contribute to MicroHacks

Thank you for your interest in our MicroHacks! 

* [How to contribute](#how-to-contribute)
* [Contributing guidelines](#contributing-guidelines)
* [MicroHack intent](#microhack-intent)
* [Repository organization](#repository-organization)
* [Authoring Tools](#authoring-tools)
* [IaC Tools](#iac-tools)
* [How to use Markdown to format your topic](#how-to-use-markdown-to-format-your-topic)
* [Template](#template)
* [Formatting](#formatting)

## How to contribute 🚀

To contribute to the [MicroHacks](./README.md), you need to fork this repository and submit a pull request for the Markdown and/or image changes that you're proposing.

* [How to fork a repository](https://help.github.com/articles/fork-a-repo)
* [How to make a pull request](https://help.github.com/articles/creating-a-pull-request/)
* [Changing a commit message](https://help.github.com/articles/changing-a-commit-message/)
* [How to squash commits](https://help.github.com/articles/about-pull-request-merges/)


## Contributing guidelines 🚩

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.
<hr/>

## MicroHack intent

Please refer to the [MicroHack Readme](./README.md)

## Repository organization

The content in this repository follows the different solution areas in Azure and M365.

This repository contains the following folders:

`NOCHMAL anpassen`

* \01-Identity and Access Management
* \02-Security
* \03-Azure
* \04-Microsoft-365
* \99-MicroHack-Template

Within these folders, you'll find the MicroHacks and the Markdown files used for the content. Each of these folders also contains an `\images` folder that references the images (such as screenshots) used in the topics. The `\iac` folder includes necessary deploymemt files (ARM, Bicep, Terraform).

### Branches

We recommend that you create local working branches that target a specific scope of change (and then submit a pull request when your changes are ready). Each branch should be limited to a single MicroHack, both to streamline workflow, and to reduce the possibility of merge conflicts.  The following efforts are of the appropriate scope for a new branch:

* A new topic (and associated images).
* Spelling and grammar edits on a topic.
* Applying a single formatting change across a large set of topics.

## Authoring tools

[Visual Studio Code](https://code.visualstudio.com) is a great editor for Markdown!

## IaC Tools

In case that you need to deploy Azure services as a prerequisite for the MicroHack pelase use well-known solutions like ARM-, Bicep- or Terraform templates or Azure CLI.

## How to use Markdown to format your topic

The topics in this repository use Markdown.  Here is a good overview of [Markdown basics](https://help.github.com/articles/markdown-basics/).

## File and Folder names

Use lowercase for file and folder names and dashes `-` as separators.

For example:

* `/01-identity-and-access-management/01-zero-trust/readme.md`
* `/01-identity-and-access-management/02-azure-ad-pim/readme.md`
* `/02-azure/01-infrastructure/01-azure-virtual-desktop/readme.md`
* `/02-azure/02-data/01-azure-sql-mi/readme.md`
* `/03-microsoft365/01-exchange-online/readme.md`

## Template

In order to bootstrap new MicroHacks we created a [template file](/99-MicroHack-Template/readme.md) for your convenience. Feel free to use it for your new MicroHacks or copy exisiting MicroHacks that better fit your ideas. 

## Formatting

### Headings & Right Nav

H2 subheadings `##` end up in the right-hand jump list for the document (the jump list is created by our compile script).  It's a good idea to include h2 subheadings to help users get an overview of the doc and quickly navigate to the major topics.

### Text formatting

Use bold for VS Code commands and UI elements.

    **Extensions: Install Extension**
    **Debug Console**

Limit the use of bold for emphasis unless it is crucial to get the user's attention. Avoid the use of italics for emphasis since italics doesn't render well on the code.visualstudio.com site.

Use inline code formatting (backticks) for settings, filename, and JSON attributes.

    `files.exclude`
    `tasks.json`
    `preLaunchTask`

Use '>' to show menu sequence.

    **File** > **Preferences** > **Settings**
    **View** > **Command Palette**

### Links

For links within our own documentation, use a site relative link like `/readme.md`.

>For example: `[Code of Conduct](/CODE_OF_CONDUCT.md)` - links to the **Code of Conduct** page

>**Note:** For navigation on GitHub, you should add the .md suffix.

### Bookmarks

To provide links to h2 subheadings (Markdown ##), the format is `[Link Text](page.md#subheading-title)`.

Note the subheading title is lowercase and subheading title words are separated by '-' hyphens.

### Images

Images are important to bring the MicroHack to life and clarify the written content.

For images you're adding to the repo, store them in the `images` subfolder of the MicroHack section, for example: *`01-identity-and-access-management/01-zero-trust/images/`

When you link to an image, the path and filename are case-sensitive. The convention is for image filenames to be all lowercase and use dashes `-` for separators.

>For example: `![Screenshot](images/step1-create-vm.png)`