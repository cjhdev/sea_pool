SeaPool
=======

A tool for combining many C and/or C++ files into one file.

~~~ ruby
SeaPool.new do |a|

    # these files will be combined into output
    a.add_input 'src/input1.cpp'
    a.add_input 'src/input2.cpp'
    a.add_input 'src/sub/input3.cpp'
    a.add_input 'src/input4.cpp', 'src/input5.cpp', 'src/input6.cpp'

    # search for files here (e.g. #include "some_file.cpp")
    a.add_include 'include'
    a.add_include 'src'
    a.add_include 'src/sub'
    a.add_include 'src/another1', 'src/another2'

    # search for system files here (e.g. #include <some_file.h>)
    a.add_system_include '/opt/somearch/include'
    a.add_system_include '/opt/somearch2/include', '/opt/somearch3/include'

    # never expand these files
    a.add_ignore 'include/to_be_ignored.h'
    a.add_ignore 'include/another_to_be_ignored1.h', 'include/another_to_be_ignored2.h'

    # the combined output file (can only be one file)
    a.set_output 'combined.cpp'

).run
~~~

## Features

- expands `#include`
    - `#include""` if a file is found in the `include` search path
    - `#include<>` if a file is found in the `system_include` search path
- will not expand an `#include` if
    - no match is found in the search path
    - a match is found in the exclude list
    - non-exluded match has already been expanded
- comments out `#include` which have already been expanded (also a limitation)
- inserts `#file` into output so that compile time messages can be referenced back to the original files
- non-recursive and line based
- depends only on Ruby stdlib (should work with your system Ruby)

## Limitations

- currently does not evaluate include guards or `#pragma once`
- does not support including same file multiple times (workaround for the above)
- input files must be written in a way that makes them suitable for amalgamation
    - ensure no file static name collisions
    - ensure no 'using namespace' in c++
- it's a preprocessor, it won't check if your code can compile
- lines that are not UTF-8 are passed through to output without any processing
- doesn't consider if a file is a link

## The Future

- might evaluate guards
- might expand other macros
- might fix file static name problems

## Hints

- Don't combine C and C++ into the same file unless you want to compile C with a C++ compiler
- ensure file static preprocessor macros are `#undef` at end of a file

## Why?

- sometimes fewer source files can make a project easier to distribute/integrate
- sometimes fewer source files will speed up compile time (Arduino + gnu tools ported to Windows!)
