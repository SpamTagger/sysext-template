# <img src="https://raw.githubusercontent.com/SpamTagger/sysext-template/refs/heads/main/sysext.svg" alt="systemd sysext logo" style="height:2em; vertical-align:middle;"> sysext-template

## About

This repository serves as a template for publishing Systemd extensions (`sysext`) using upstream Debian packages for use with SpamTagger.

The official SpamTagger images use `bootc` to distribute a standardized OS image with minimal dependencies for a VM appliance. The root filesystem of a `bootc` image is read-only and so it is not possible to install additional packages with `apt`. Despite this, there are additional packages which may be necessary in specific use-cases. For example, some hypervisors expect, or function better, with additional firmware or tools in the VM.

`sysext` provides a mechanism for overlaying additional files on top of the filesystem at runtime without needing to actually write to it.

This repository installs any of the additional packages needed for the `open-vm-tools` package, copies any new files provided by those packages into a `squashfs` directory trees and produces metadata file. SpamTagger machines have a `sysext.pl` management script which can fetch the extensions built by this repository and then layer them on top of your running filesystem with `systemd-sysext merge`.

## Need another package not provided by SpamTagger?

If there is a package which you feel is missing in the SpamTagger base image, which is not already provided as an extension, and which would be broadly applicable to many other users, please place a request for it [here](https://github.com/SpamTagger/SpamTagger/blob/main/install/sysext.pl).

If you have a niche package requirement not likely to be needed by (m)any other users, you can see the next section on how to create your own SpamTagger-compatible extension. Once you have published releases available (currently only GitHub is supported), you can make it discoverable by the `sysext.pl` utility by creating the file `/etc/spamtagger/etc/sysext.toml` with contents similar to the official manifest at `/usr/spamtagger/etc/sysext.toml`:

```
[package-name]
url = "https://github.com/USERNAME/sysext-repo"
```

Replace `package-name` with the actual Debian package, `USERNAME` with your GitHub user or organization and `sysext-repo` with the name of the repository within your user or organization. Note: Only GitHub is currently supported. If you would like to host an extension on a different host, consider contributing to [the `sysext.pl` manager script](https://github.com/SpamTagger/SpamTagger/blob/main/install/sysext.pl).

You can additionally add one of the following to "recommend" the package in a specific context:

* `pci_id = [ "1234:5678" ]` - This will automatically install the extension if you have a PCI device with Vendor ID `1234` and Product ID `5678`. You can provide a list of IDs and can provide just `"1234"` to match any product from that Vendor ID. These can be found with `lspci -nn`.
* `dmi = [ "LENOVO:20W8S0K900" ]` - This will automatically install the extension if your hardware reports a DMI Vendor ID `LENOVO` and DMI Product ID `20W8S0K900`. You can provide a list of IDs and can provide just `"LENOVO"` to match any product from that DMI Vendor ID. These can be found with `cat /sys/class/dmi/id/{sys_vendor,product_name}`.
* `device_tree = [ "raspberrypi,4-model-b" ]` - This will automatically install the extension if your device-tree enabled device matches. You can provide a list of IDs and can provide just `raspberrypi` to match the first comma-delimted field. These can be found with `cat /proc/device-tree/compatible`.
* `virt_env = [ "qemu", "kvm", "amazon" ]` - This will automatically install the extension if `systemd-detect-virt` detects any of the listed virtual environments.
* `if_file = "/var/spamtagger/spool/mailcleaner/sysext-package.flag"` - This will automatically install the extension if the defined file exists. `/var/spamtagger` is portable across migrations and persistent across updates, so this is the best place to keep flags and have the extensions automatically re-installed.

If multiple exist, only one is required to match for the extension to be installed automatically. There is also:

* `conflicts = [ "open-vm-tools" ]` - This will automatically remove `open-vm-tools` if the extension with this variable is set. Likewise, this extension will be removed if `open-vm-tools` is added. Only one has to include this setting for them to be mutually excluded. Please don't abuse this by creating an extension which blocks others unnecessarily.

## Template Usage

In the most simple case, you should simply need to create a new repo with this one as a template and then update the `metadata.json` file to publish a new extension.

In order to include only the necessary dependencies (ie. those not already provided by `spamtagger-bootc` images), the build script resolves the missing dependencies from inside the relevant `spamtagger-bootc` container. This means that we can only produce extension packages for distribution versions and architectures which have an existing image in the registry.

This template uses the `hello` example package which is built for `trixie` for the `amd64` architectures. The `metadata.json` consists of:

```json
{
  "name": "sysext-hello",
  "description": "Provide the 'hello' package as extension for Bootc",
  "architectures": [ "amd64" ],
  "dists": [ "trixie" ],
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

To create a release, you need to add a "RELEASE_TOKEN" secret to the repository which includes a Personal Access Token with the permission to create releases. For fine-grained tokens, this means that it needs tho following **Repository permissions** for the user or organization housing the repo:

* **Read** access to metadata
* **Read** and **Write** access to code and workflows
