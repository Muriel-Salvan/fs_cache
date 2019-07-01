class FsCache

  module Attributes

    # Size attribute. Can be:
    # * Integer: File size
    class Size < Attribute

      # Get the attribute for a given file
      #
      # Parameters::
      # * *file* (String): File to get the attribute for
      # Result::
      # * Object: Corresponding attribute value
      def attribute_for(file)
        File.stat(file).size
      end

      # Add helpers to the cache
      module Helpers

        # Is a file empty?
        #
        # Parameters::
        # * *file* (String): File name
        # Result::
        # * String: Is the file empty?
        def empty?(file)
          size_for(file) == 0
        end

      end

    end

  end

end
