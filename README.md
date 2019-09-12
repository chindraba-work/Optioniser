# Optioniser

## Contents

- [Description](#description)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Version Numbers](#version-numbers)
- [Copyright and License](#copyright-and-license)


## Description

A script to replace the use of `getopt` and `getops` in BASH scripts. It provides a robust and flexible parsing of the command-line options that allows for configuring almost any variation which seems practical.

[TOP](#contents)

## Requirements

BASH

[TOP](#contents)

## Installation

Source the Optioniser script in your script using one line near the top of your main script:

```
    source /path/to/script/optioniser.sh
```

[TOP](#contents)

## Usage

1. Create the functions to handle the command-line options the user
   enters.
2. Create the definitions for each option you wish to make the parser process.
3. Select the options you wish to allow in the optioniser.conf file.
4. Source the `optioniser.sh` script from your script.

[TOP](#contents)

## Version Numbers

Optioniser uses [Semantic Versioning v2.0.0](https://semver.org/spec/v2.0.0.html) as created by [Tom Preston-Werner](http://tom.preston-werner.com/), inventor of Gravatars and cofounder of GitHub.

Version numbers take the form `X.Y.Z` where `X` is the major version, `Y` is the minor version and `Z` is the patch version. The meaning of the different levels are:

- Major version increases indicates that there is some kind of change in the API (how this program works as seen by the user) or the program features which is incompatible with previous version

- Minor version increases indicates that there is some kind of change in the API (how this program works as seen by the user) or the program features which might be new, while still being compatible with all other versions of the same major version

- Patch version increases indicate that there is some internal change, bug fixes, changes in logic, or other internal changes which do not create any incompatible changes within the same major version, and which do not add any features to the program operations or functionality

[TOP](#contents)

# Copyright and License

## The MIT License
```
    Permission is hereby granted, free of charge, to any person
    obtaining a copy of this software and associated documentation
    files (the "Software"), to deal in the Software without restriction,
    including without limitation the rights to use, copy, modify, merge,
    publish, distribute, sublicense, and/or sell copies of the Software,
    and to permit persons to whom the Software is furnished to do so,
    subject to the following conditions:

    The above copyright notice and this permission notice shall be
    included in all copies or substantial portions of the Software

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
    EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGE-
    MENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
    FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
    CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
    WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
```

### License Alternatives

If this is useful in your project, and the MIT license is somehow not compatible with your codebase, contact the creator and specify your concerns and the options which would make this acceptable.

[TOP](#contents)
