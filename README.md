# fs_cache

Simple Ruby library caching file system information.
Plugins can be used to cache any properties on files' content (like MP3 tags, metadata, CRC...)

## Install

Via gem

``` bash
$ gem install fs_cache
```

Via a Gemfile

``` ruby
$ gem 'fs_cache'
```

## Usage

``` ruby
require 'fs_cache'

fs_cache = FsCache.new

# This will perform a real File.exist
fs_cache.exist?('/path/to/file')
# This will not
fs_cache.exist?('/path/to/file')

# Here we use the CRC plugin that computes files' CRC. It will read the whole file's content
file_crc = fs_cache.crc_for('/path/to/file')
# Here we have the same info without reading the file
fs_cache.crc_for('/path/to/file')

# Pre-load info about files from a directory (and do it with a nice progress bar!)
fs_cache.scan('/path/to/dir')
# Thanks to the previous scan, the following will use the cache
fs_cache.crc_for('/path/to/dir/other_file')

# Pre-load info about files from a directory, but only get the CRC information from those files (not other plugins, like size etc...)
fs_cache.scan('/path/to/other_dir', include_attributes: [:crc])

# Get all the files from a directory
fs_cache.files_in('/path/to/dir')

# Invalidate the cache for given files (for example if the file system has changed)
fs_cache.invalidate(['/path/to/file1', '/path/to/file2'])

# Check the cache information against the real file system, to invalidate possible changes that occurred
fs_cache.check

# Notify the cache that we know a file operation has been done, so that cache can be reused in an optimized way
fs_cache.notify_file_cp('/path/to/src_file', '/path/to/dst_file')

# Serialize the cache as JSON
json = fs_cache.to_json

# Get the cache back from a JSON
fs_cache.from_json(json)

```

## Change log

Please see [CHANGELOG](CHANGELOG.md) for more information on what has changed recently.

## Testing

Automated tests are done using rspec.

Do execute them, first install development dependencies:

```bash
bundle install
```

Then execute rspec

```bash
bundle exec rspec
```

## Contributing

Any contribution is welcome:
* Fork the github project and create pull requests.
* Report bugs by creating tickets.
* Suggest improvements and new features by creating tickets.

## Credits

- [Muriel Salvan][link-author]

## License

The BSD License. Please see [License File](LICENSE.md) for more information.

[link-curses]: https://rubygems.org/gems/curses/versions/1.2.4
[link-examples]: ./examples
