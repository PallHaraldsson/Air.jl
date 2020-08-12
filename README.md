[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://noahbenson.github.io/Air.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://noahbenson.github.io/Air.jl/dev)
[![Build Status](https://travis-ci.org/noahbenson/Air.jl.svg?branch=master)](https://travis-ci.com/noahbenson/Air.jl)
[![Codecov](https://codecov.io/gh/noahbenson/Air.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/noahbenson/Air.jl)


# Air ##########################################################################

Functional collections and utilities for Julia as light as air.


## Author ######################################################################

Noah C. Benson &lt;<nben@uw.edu>&gt;


## Description #################################################################

Air is a Julia library that aims to take advantage of Julia's builtin immutable
paradigms to provide a set of functional utilities. Air is currently heavily
under development and will be changing drastically in the foreseeable future.
Inspiration for Air's design is derived largely from paradigms in Clojure and
Scala.


### Plans

Note that many of the core components for Air already working (if
not-yet-optimized) implementations. Several more are currently undergoing
testing.

* Completed plans
  * Persistent data structures:
    * `PArray`, a persistent array type that mimics Julia's native `Array`
    * `PDict`, a persistent dictionary type that mimics Julia's native `Dict`
    * `PSet`, a persistent set type.
    * `PWDict`, a persistent weighted dictionary type that trackss an ordering
      (descending by weight) of the elements using a persistent heap and allows
      pairs to be sampled (using `rand(pwdict)`) with probabilities equal to
      their (relative) weights in the dictionary.
    * `PWSet`, a weighted persistent set type, like `PWDict` but just objects
      with weights instead of key-value pairs with weights.
* Plans that are implemented but require testing
    * `LazyDict`, a persistent lazy dictionary type.
  * Multi-threading utilities, inspired by Clojure
    * Thread-safe `Delay` and `Promise` types.
    * Thread-local `Var` type.
    * A `Volatile` type that operates with the `@tx` macro to ensure
      that all updates to references within a synchronized block are performed
      atomically.
    * An `Actor` type for sending asynchronous jobs to independent threads which
      also respects the atomic requirements of transactional `tx` blocks.
    * A `Source` type for safely reading from inputs such as sockets or files
      while respecting the syncronization of transactional `tx` blocks.
* Plans that are not yet implemented
  * **Persistent Record Types.** Tool for defining data structures that
    support lazy reification of members.
  * **Inheritable Method Parameters.** A common problem in many languages is
    that an API function that calls another lower-level function often needs to
    support some subset of the argument preprocessing that occurs in the
    lower-level function. The preprocessing and documentation of the shared
    arguments shouldn't need to be duplicated in multiple places; rather a
    simple macro should make it easy for common parameters to occur in both
    places and be documented identically in both.
  * Trransient types
    * `PDict` should be O(1)-time convertable into the transient `TDict`
      type that can be updated without copying memory and that can be 
      converted into a persistent equivalent very quickly.
    * `PArray` and `TArray` should have a similar relationship.
  * `ChannelSourceKernel` type that creates a source kernel that pops values
    from a channel.
  * Better query/build/update API tools?


## License

MIT License

Copyright (c) 2019 Noah C. Benson

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
