class FsCache

  module Attributes
  end

  # Common ancestor for all attributes
  class Attribute

    # Get the list of other attributes that invalidate this one.
    # If any of those attributes is chaning on a file, then reset our attribute for the file.
    #
    # Result::
    # * Array<Symbol>: List of dependent attributes
    def invalidated_on_change_of
      []
    end

  end

end
