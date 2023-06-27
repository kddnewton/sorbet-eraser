# Sorbet::Eraser

[![Build Status](https://github.com/kddnewton/sorbet-eraser/workflows/Main/badge.svg)](https://github.com/kddnewton/sorbet-eraser/actions)
[![Gem](https://img.shields.io/gem/v/sorbet-eraser.svg)](https://rubygems.org/gems/sorbet-eraser)

Erase all traces of `sorbet-runtime` code.

`sorbet` is a great tool for development. However, in production, it incurs a penalty because it still functions as Ruby code. Even if you completely shim all `sorbet-runtime` method calls (for example by replacing `sig {} ` with a method that immediately returns) you still pay the cost of a method call in the first place.

This gem takes a different approach, but entirely eliminating the `sig` method call (as well as all the other `sorbet-runtime` constructs) from the source before Ruby compiles it.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "sorbet-eraser"
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install sorbet-eraser

## Usage

There are two ways to use this gem, depending on your needs.

The first is that you can hook into the Ruby compilation process and do just-in-time erasure. To do this — before any code is loaded that would require a `sorbet-runtime` construct — call `require "sorbet/eraser/autoload"`. This will hook into the autoload process to erase all `sorbet-runtime` code before it gets passed to Ruby to parse. This eliminates the need for a build step, but slows down your parse/boot time.

The second is that you can preprocess your Ruby files using either the CLI or the Ruby API. With the CLI, you would run:

```bash
bundle exec sorbet-eraser '**/*.rb'
```

It accepts any number of filepaths/patterns on the command line and will modify the source files with their erased contents.  Alternatively, you can programmatically use this gem through the `Sorbet::Eraser.erase(source)` API, where `source` is a string that represents valid Ruby code. Ruby code without the listed constructs will be returned.

### Status

Below is a table of the status of each `sorbet-runtime` construct and its current support status.

| Construct                                           | Status | Replacement |
| --------------------------------------------------- | ------ | ----------- |
| `extend T::*`                                       | ✅     | Shimmed     |
| `abstract!`, `final!`, `interface!`, `sealed!`      | ✅     | Shimmed     |
| `mixes_in_class_methods(*)`, `requires_ancestor(*)` | ✅     | Shimmed     |
| `type_member(*)`, `type_template(*)`                | ✅     | Shimmed     |
| `class Foo < T::Enum`                               | ✅     | Shimmed     |
| `class Foo < T::InexactStruct`                      | 🛠     | Shimmed     |
| `class Foo < T::Struct`                             | 🛠     | Shimmed     |
| `class Foo < T::ImmutableStruct`                    | 🛠     | Shimmed     |
| `include T::Props`                                  | 🛠     | Shimmed     |
| `include T::Props::Serializable`                    | 🛠     | Shimmed     |
| `include T::Props::Constructor`                     | 🛠     | Shimmed     |
| `sig`                                               | ✅     | Removed     |
| `T.absurd(foo)`                                     | ✅     | Shimmed     |
| `T.assert_type!(foo, bar)`                          | ✅     | `foo`       |
| `T.bind(self, foo)`                                 | ✅     | `self`      |
| `T.cast(foo, bar)`                                  | ✅     | `foo`       |
| `T.let(foo, bar)`                                   | ✅     | `foo`       |
| `T.must(foo)`                                       | ✅     | `foo`       |
| `T.reveal_type(foo)`                                | ✅     | `foo`       |
| `T.type_alias { foo }`                              | ✅     | Shimmed     |
| `T.unsafe(foo)`                                     | ✅     | `foo`       |

In the above table, for `Status`:

* ✅ means that we are confident this is replaced 1:1.
* 🛠 means there may be APIs that are not entirely supported. If you run into something that is missing, please open an issue.

In the above table, for `Replacement`:

* `Shimmed` means that this gem provides a replacement module that will simply do nothing when its respective methods are called. We do this in order to maintain the same interface in the case that someone is doing runtime reflection. Also because anything that is shimmed will not be called that much/will not be in a hot path so performance is not really a consideration for those cases.
* `Removed` means that the construct is removed entirely from the source.
* Anything else means that the inputted code is replaced with that output.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/kddnewton/sorbet-eraser.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
