<h1 id="pasfmt-rad">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/images/pasfmt-rad-title-dark.png">
    <source media="(prefers-color-scheme: light)" srcset="docs/images/pasfmt-rad-title-light.png">
    <img alt="pasfmt-rad" src="docs/images/pasfmt-rad-title-light.png"/>
  </picture>
</h1>

A RAD Studio plugin integrating [`pasfmt`](https://github.com/integrated-application-development/pasfmt/), a complete
and opinionated formatter for Delphi code, into the IDE.

`pasfmt-rad` is available for Delphi 11 and above - earlier versions may be able to be
[built from source](#building-from-source), but are not officially supported.

## Installation

1. Download and install the package BPL for your Delphi version
2. Download [`pasfmt`](https://github.com/integrated-application-development/pasfmt) and add to PATH
3. Restart RAD Studio

## Usage

With a file open in the editor, a format can be triggered with `Ctrl+Alt+F` (`Tools > Pasfmt > Format`).

The formatter can optionally be triggered on save; this can be enabled in  `Tools > Pasfmt > Settings...` by toggling
`Format on save`.

> [!WARNING]
> `Ctrl+Alt+F` is also the default shortcut for the GExperts formatter. If you have GExperts installed, please make sure
> to disable the formatter in the GExperts settings.

## Configuration

To customise the configuration, create a file called `pasfmt.toml` in the root directory of the project you are
formatting. For more information, see the
[Configuration section](https://github.com/integrated-application-development/pasfmt#Configuration) of `pasfmt`.

## Building from source

1. Install Delphi 11.2 or above
2. Build [Pasfmt.dproj](Pasfmt.dproj)

## License

Licensed under the [GNU Lesser General Public License, Version 3.0](https://www.gnu.org/licenses/lgpl-3.0.txt).