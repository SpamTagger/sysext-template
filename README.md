# <img src="https://raw.githubusercontent.com/SpamTagger/sysext-hello/refs/heads/main/sysext.svg" alt="systemd sysext logo" style="height:2em; vertical-align:middle;"> sysext-template

## About

This repository serves as a template for publishing Systemd extensions (`sysext`) using upstream Debian packages for use with SpamTagger.

The official SpamTagger images use `bootc` to distribute a standardized OS image with minimal dependencies for a VM appliance. The root filesystem of a `bootc` image is read-only and so it is not possible to install additional packages with `apt`. Despite this, there are additional packages which may be necessary in specific use-cases. For example, some hypervisors expect, or function better, with additional firmware or tools in the VM.

`sysext` provides a mechanism for overlaying additional files on top of the filesystem at runtime without needing to actually write to it.

This repository fetches the defined package from the Debian repositories, extracts the filesystem layout and produces `squashfs` files containing those directory trees and relevant metadata. These files can be ingested by `systemd-sysext merge` to apply the package files to the same locations that they would if installed by `apt`. Note that it does not currently handle any install scripts, so it may not be possible to provide any package by this means.

## Template Usage

In the most simple case, you should simply need to create a new repo with this one as a template and then update the `metadata.json` file to publish a new extension.

This template uses the `hello` example package which is build for `trixie` and `forky`, for both the `amd64` and `arm64` architectures. The `metadata.json` consists of:

```json
{
  "name": "sysext-hello",
  "description": "Provide the 'hello' package as extension for Bootc",
  "architectures": [ "amd64", "arm64" ],
  "dists": [ "trixie", "forky" ],
  "component": "main",
  "package": "hello",
  "update": "none",
  "repository": "https://github.com/SpamTagger/sysext-template"
}
```

The relevant fields are:

* "name" - This is largely cosmetic and is only used for naming the output files
* "description" - This is informational and is not used
* "architectures" - Array of architectures to build for
* "dists" - Array of Debian versions to build for
* "component" - The Debian component, used in download path for the Debian Sources.gz
* "package" - The actual name of the package in the Debian repository
* "update" - Mechanism for updating within SpamTagger
* "repository" - URL of repository where new releases should be found

At a minimum, you at least need to change the `name`, `package`, and `repository` to disambiguate from other packages.

Otherwise, you may need to change `update` if the package requires different steps to update. `none` means that no action will be taken after updating, such as when the command gets executed as necessary. `reboot` will prompt for the server to be restarted when a new version is available. `service: mailscanner` will restart a systemd service, in this case `mailscanner`.

You should verify that the component is correct and update the remaining fields as necessary.

## Actions

The repository ships with GitHub actions to automatically build the extensions and create a new GitHub release as well as to automatically check for new versions in the Debian repository in order to trigger the former.
