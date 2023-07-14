# Sorbet::Eraser

[![Build Status](https://github.com/kddnewton/sorbet-eraser/workflows/Main/badge.svg)](https://github.com/kddnewton/sorbet-eraser/actions)
[![Gem](https://img.shields.io/gem/v/sorbet-eraser.svg)](https://rubygems.org/gems/sorbet-eraser)

Erase all traces of `sorbet-runtime` code.

[Sorbet](https://sorbet.org/) is a type checker for Ruby. To annotate types in your Ruby code, you use constructs like `sig` and `T.let`. Sorbet then uses a static analysis tool to check that your code is type safe. At runtime, these types are enforced by the `sorbet-runtime` gem that provides implementations of all of these constructs.

Sometimes, you want to use Sorbet for development, but don't want to run `sorbet-runtime` in production. This may be because you have a performance-critical application, or because you're writing a library and you don't want to impose a runtime dependency on your users.

To handle these use cases, `sorbet-eraser` provides a way to erase all traces of `sorbet-runtime` code from your source code. This means that you can use Sorbet for development, but not have to worry about `sorbet-runtime` in production. For example,

```ruby
# typed: true

class HelloWorld
  extend T::Sig

  sig { returns(String) }
  def hello
    T.let("World!", String)
  end
end
```

will be transformed into

```ruby
#            

class HelloWorld
  extend T::Sig

                         
  def hello
          "World!"         
  end
end
```

The `sig` method calls have been removed from your source code. `T::Sig` has been left in place, but is shimmed with an empty module to ensure any reflection is consistent. All line and column information has been preserved 1:1, so that stack traces and tracepoints will still be accurate.

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

There are two ways to use this gem, depending on your needs. You can erase `sorbet-runtime` code ahead of time or just in time.

### Ahead of time

To erase `sorbet-runtime` code ahead of time, you would either use the CLI provided with this gem or the Ruby API. With the CLI, you would run:

```bash
bundle exec sorbet-eraser '**/*.rb'
```

It accepts any number of filepaths/patterns on the command line and will modify the source files in place with their erased contents. If you would instead prefer to script it yourself using the Ruby API, you would run:

```ruby
Sorbet::Eraser.erase(source)
```

where `source` is a string that represents valid Ruby code.

### Just in time

If you're looking to avoid a build step like the one described above, you can instead erase your code immediately before it is compiled by the Ruby virtual machine. To do, call:

```ruby
require "sorbet/eraser/autoload"
```

as soon as possible when your application is first booting. This will hook into the autoload process to erase all `sorbet-runtime` code before it gets passed to Ruby to parse. Note that the tradeoff here is that it eliminates the need for a build step, but slows down your parse/boot time.

### Runtime structures

If you used any runtime structures like `T::Struct` or `T::Enum` you'll need a runtime shim. We provide very basic versions of these in the `sorbet-eraser` gem, and they are required automatically.

### Status

Below is a table of the status of each `sorbet-runtime` construct and its current support status.

| Construct                                           | Status | Replacement |
| --------------------------------------------------- | ------ | ----------- |
| `# typed: foo`                                      | ✅      | `#`         |
| `extend T::*`                                       | ✅      | Shimmed     |
| `abstract!`, `final!`, `interface!`, `sealed!`      | ✅      | Shimmed     |
| `mixes_in_class_methods(*)`, `requires_ancestor(*)` | ✅      | Shimmed     |
| `type_member(*)`, `type_template(*)`                | ✅      | Shimmed     |
| `class Foo < T::Enum`                               | ✅      | Shimmed     |
| `class Foo < T::InexactStruct`                      | 🛠      | Shimmed     |
| `class Foo < T::Struct`                             | 🛠      | Shimmed     |
| `class Foo < T::ImmutableStruct`                    | 🛠      | Shimmed     |
| `include T::Props`                                  | 🛠      | Shimmed     |
| `include T::Props::Serializable`                    | 🛠      | Shimmed     |
| `include T::Props::Constructor`                     | 🛠      | Shimmed     |
| `sig`                                               | ✅      | Removed     |
| `T.absurd(foo)`                                     | ✅      | Shimmed     |
| `T.assert_type!(foo, bar)`                          | ✅      | `foo`       |
| `T.bind(self, foo)`                                 | ✅      | `self`      |
| `T.cast(foo, bar)`                                  | ✅      | `foo`       |
| `T.let(foo, bar)`                                   | ✅      | `foo`       |
| `T.must(foo)`                                       | ✅      | `foo`       |
| `T.reveal_type(foo)`                                | ✅      | `foo`       |
| `T.type_alias { foo }`                              | ✅      | Shimmed     |
| `T.unsafe(foo)`                                     | ✅      | `foo`       |

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
