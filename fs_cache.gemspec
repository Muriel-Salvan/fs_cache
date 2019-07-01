Gem::Specification.new do |spec|
  spec.name          = 'fs_cache'
  spec.version       = '0.0.1'
  spec.authors       = ['Muriel Salvan']
  spec.email         = ['muriel@x-aeon.com']
  spec.license       = 'BSD-3-Clause'

  spec.summary       = 'Simple file system caching to perform huge and repetitive accesses to files, directories and various files\' content analysis'
  spec.homepage      = 'http://x-aeon.com'

  spec.metadata['homepage_uri'] = spec.homepage

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir['lib/**/*']
  spec.require_paths = ['lib']

  spec.add_dependency 'progressbar', '~> 1.10'
end
