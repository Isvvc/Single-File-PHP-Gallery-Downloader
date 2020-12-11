# Single-File-PHP-Gallery-Downloader

Download script for images hosted using [Single File PHP Gallery](http://sye.dk/sfpg/) (SFPG).

### Features

+ Download all images in a given SFPG directory
+ Specify output directory
+ Download count limit
+ Run recursively on subdirectories
  + Limit traversal depth

Planned

+ Skip existing files (for canceling and resuming later)

## Usage

```
USAGE: sfpgd [--verbose] [--recursive] [--depth <depth>] [--count <count>] [--output <output>] <url>

ARGUMENTS:
  <url>                   The URL of the Single File PHP Gallery. 

OPTIONS:
  -v, --verbose           Show verbose printout. 
  -r, --recursive         Recurively download subdirectories. Is overridden by --depth. 
  -d, --depth <depth>     Maximum depth of folders to traverse. Overrides --recursive. 
  -c, --count <count>     Maximum number of images to download. 
  -o, --output <output>   Output directory. 
  -h, --help              Show help information.
```

## Build

Currently only building for macOS is supported.

Open `Single File PHP Gallery Downloader.xcodeproj` in Xcode.
Specify arguments in private Run scheme for testing.

Archive in Xcode to get standalone executable.
