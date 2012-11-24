mimosa-import-source
===========

## Overview

This is a Mimosa module for copying files from somewhere on the file system into your project as the first step of a build/watch. This allows, among other things, files from other projects to merge with files from the project using this module, giving the function of a single codebase.

For more information regarding Mimosa, see http://mimosajs.com

## Usage

Add `'import-source'` to your list of modules.  That's all!  Mimosa will install the module for you when you start up.

## Functionality

When Mimosa starts up, and before it begins handling your code during the initial startup build, this module will copy files from other places on the file system into your codebase.

After Mimosa is started, this module will continue watching the files at their original locations and copy them in as they change.

## Default Config

```
importSource:
  copy:[]
```

## Example Config

If this module had a default config placeholder like other Mimosa modules, it would look something like this:

```
  importSource:
    copy:[
      {
        from:""
        to:""
      },
      {
        from:""
        to:""
      }
    ]
  ]
```

* `copy`: an array of source importing configurations
* `from`: a string, path of the files you'd like to import into your project. Can be a file, or a folder.  If a folder, all the contents of the folder (recursive) will be copied. Path can be relative to the root of the project or absolute.
* `to`: a string, location in your project where the folder or file will be copied. Path can be relative to the root of the project or absolute. The path need not exist.

