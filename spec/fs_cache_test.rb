require 'fileutils'
require 'tmpdir'
require 'fs_cache'

module FsCacheTest

  module OpsRecorder

    class << self

      # List of operations, or nil if we don't record
      # Array< Hash<Symbol,Object> >: List of operation description:
      # * *class* (Symbol): Class on which the method has been called
      # * *method* (Symbol): Method called
      # * *args* (Array<Object>): Arguments given to this method's call
      attr_accessor :ops

      # Start recording operations
      #
      # Parameters::
      # * Proc: Code called while operations are being recorded
      # Result::
      # * Array< Hash<Symbol,Object> >: List of recorded operations
      def record
        OpsRecorder.ops = []
        yield
        OpsRecorder.ops
      end

      # Decorate a list of class methods of a given class to record their call
      #
      # Parameters::
      # * *overrides* (Hash<Class, Array<Symbol> >): Set of methods to override to record activity, per class name
      def record_methods_from(overrides)
        overrides.each do |klass, methods|
          methods.each do |method_to_override|
            original_method = "#{method_to_override}__fs_cache_test__".to_sym
            klass.singleton_class.alias_method original_method, method_to_override
            klass.define_singleton_method(method_to_override) do |*args, &block|
              OpsRecorder.ops << {
                class: klass.name.to_sym,
                method: method_to_override,
                args: args
              } if OpsRecorder.ops
              self.send(original_method, *args, &block)
            end
          end
        end
      end

    end
    OpsRecorder.ops = nil

  end

  # Define an attribute plugin for the tests
  class TestAttribute < FsCache::Attribute

    # Get the attribute for a given file
    #
    # Parameters::
    # * *file* (String): File to get the attribute for
    # Result::
    # * Object: Corresponding attribute value
    def attribute_for(file)
      OpsRecorder.ops << {
        class: :TestAttribute,
        method: :attribute_for,
        args: [file]
      }
      'Sample attribute value'
    end

    module Helpers

      # Just a test helper
      def test_attr_helper
        OpsRecorder.ops << {
          class: :FsCache,
          method: :test_attr_helper,
          args: []
        }
        'Sample helper value'
      end

    end

  end

  # Some helpers for tests
  module Helpers

    # Setup a test fs_cache and a temporary directory to play with
    #
    # Parameters::
    # * *create_files* (Array<String> or Hash<String, Hash<Symbol,Object> >): Files to be created. That can be: [default: []]
    #   * Array<String>: List of file names to create with dummy content
    #   * Hash<String, String or Hash<Symbol,Object> >: Set of descriptive information, per file name. File info can be either a single string for the default property, or a more descriptive structure:
    #     * *content* (String): The file content. This is the default property [default = 'Dummy content']
    # * *register_plugins* (Hash<Symbol, Attribute>): Set of plugins to register, per attribute name [default: {}]
    # * Proc: Code called with the cache setup
    #   * Parameters::
    #     * *cache* (FsCache): The cache to be used
    #     * *dir* (String): The temporary directory to be used
    def with_cache(create_files: [], register_plugins: {})
      Dir.mktmpdir('fs_cache_tests') do |dir|
        create_files = Hash[create_files.map { |file_name| [file_name, 'Dummy content'] }] if create_files.is_a?(Array)
        create_files.each do |relative_file, file_info|
          file_info = { content: file_info } if file_info.is_a?(String)
          file_info[:content] = 'Dummy content' unless file_info.key?(:content)
          file = "#{dir}/#{relative_file}"
          FileUtils.mkdir_p File.dirname(file)
          File.write(file, file_info[:content])
        end
        fs_cache = FsCache.new
        register_plugins.each do |attr_name, attr_plugin|
          fs_cache.register_attribute_plugin(attr_name, attr_plugin)
        end
        yield fs_cache, dir
      end
    end

    # Expect a given set of operations to be cached when executing the same code twice
    #
    # Parameters::
    # * *create_files* (Array<String>): Files to be created [default: []]
    # * *register_plugins* (Hash<Symbol, Attribute>): Set of plugins to register, per attribute name [default: {}]
    # * *strict_ops_order* (Boolean): If true then make sure operations are ordered as expected [default: true]
    # * Proc: Code called to perform the operation
    #   This code can use the following instance variables:
    #   * *@fs_cache* (FsCache): The cache to be used
    #   * *@dir* (String): The temporary directory to be used
    #   Result::
    #   * Array< Hash<Symbol,Object> >): Expected operations that this code should have called first time only
    def expect_ops_to_be_cached(create_files: [], register_plugins: {}, strict_ops_order: true)
      with_cache(create_files: create_files, register_plugins: register_plugins) do |fs_cache, dir|
        @fs_cache = fs_cache
        @dir = dir
        expected_ops = nil
        ops = OpsRecorder.record do
          expected_ops = yield
        end
        if strict_ops_order
          expect(ops).to eq(expected_ops)
        else
          # Expect them without a specific order
          expect(ops.sort_by { |op| op.inspect }).to eq(expected_ops.sort_by { |op| op.inspect })
        end
        # Now we expect the operations to be empty
        ops = OpsRecorder.record do
          yield
        end
        expect(ops).to eq([])
      end
    end

  end

end

FsCacheTest::OpsRecorder.record_methods_from(
  File => %i[
    exist?
    stat
    open
    read
  ],
  Dir => %i[
    glob
  ]
)
