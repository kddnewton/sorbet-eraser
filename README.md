# Sorbet::Eraser

Erase all traces of `sorbet-runtime` code.

`sorbet` is a great tool for development. However, in production, it incurs a penalty because it still functions as Ruby code. Even if you completely shim all `sorbet-runtime` method calls (for example by replacing `sig {} ` with a method that immediately returns) you still pay the cost of a method call in the first place.

This gem takes a different approach, but entirely eliminating the `sig` method call (as well as all the other `sorbet-runtime` constructs) from the source before Ruby compiles it.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'sorbet-eraser'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install sorbet-eraser

## Usage

Before any code is loaded that would require a `sorbet-runtime` construct, call `require "sorbet/eraser/autoload"`. This will hook into the autoload process to erase all `sorbet-runtime` code before it gets passed to Ruby to parse.

Alternatively, you can programmatically use this gem through the `Sorbet::Eraser.erase(source)` API, where `source` is a string that represents valid Ruby code. Ruby code without the listed constructs will be returned.

### Status

Below is a table of the status of each `sorbet-runtime` construct and its current support status.

| Construct | Status | Replacement |
| --------- | ------ | ----------- |
| `include T::Generic` | ✅ | |
| `include T::Helpers` | ✅ | |
| `extend T::Sig` | ✅ | |
| `class Foo < T::Enum` | 🛠 | `class Foo < T::Enum` |
| `class Foo < T::Struct` | 🛠 | `class Foo < T::Struct` |
| `abstract!` | ✅ | |
| `final!` | ✅ | |
| `interface!` | ✅ | |
| `mixes_in_class_methods(foo)` | ✅ | `foo` |
| `sig` | ✅ | |
| `T.absurd(foo)` | ✅ | `T.absurd(foo)` |
| `T.assert_type!(foo, bar)` | ✅ | `foo` |
| `T.bind(self, foo)` | ✅ | `self` |
| `T.cast(foo, bar)` | ✅ | `foo` |
| `T.let(foo, bar)` | ✅ | `foo` |
| `T.must(foo)` | ✅ | `foo` |
| `T.must foo` | ✅ | `foo` |
| `T.reveal_type(foo)` | ✅ | `foo` |
| `T.type_alias { foo }` | ✅ | `T.type_alias { foo }` |
| `T.unsafe(foo)` | ✅ | `foo` |

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/kddnewton/sorbet-eraser.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
