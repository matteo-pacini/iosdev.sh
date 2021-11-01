# iosdev.sh

## Usage

```
Usage:
    iosdev.sh [options]

Arguments:
    --xcodes <comma separated list>
        List of Xcode versions to install
        e.g. iosdev.sh --xcodes 13.1,13.2
    --purge-xcodes
        Purge installed Xcode versions that are not in the "--xcodes" list.
        This flag does nothing if "--xcodes" is not specified.
        e.g. assuming Xcode 12.5.1 is installed:
        ./iosdev.sh --xcodes 13.1,13.2 --purge-xcodes
        This will install Xcode 13.1 and 13.2 and purge Xcode 12.5.1.
    --no-color
        Disable color output.
    --experimental
        Enable experimental features.
        This option is not recommended, as it may break the script or have an unexpected behavior.
        Current experimental features are:
            - M1 macs support
    --ruby-version <version>
        Specify the portable Ruby version to install.
        e.g. iosdev.sh --ruby-version 2.7.2
    --ruby-name <name>
        Specify the portable Ruby's folder name. Defaults to "ruby".
        This flag does nothing if "--ruby-version" is not specified.
        e.g. iosdev.sh --ruby-version 2.7.2 --ruby-name prettyruby
    -h, --help
        Show this help
```

## Examples

- Install Xcode 13.1 and 13.2 (beta), and discard other versions of Xcode:

```iosdev.sh --xcodes 13.1,13.2 --purge-xcodes```