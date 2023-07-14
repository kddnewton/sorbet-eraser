# frozen_string_literal: true

class String
  # This is a polyfill for the String#bytesplice method that didn't exist before
  # Ruby 3.2.0, and didn't return the receiver until 3.2.1.
  def bytesplice(range, value)
    previous_encoding = encoding

    begin
      force_encoding(Encoding::ASCII_8BIT)
      self[range] = value
    ensure
      force_encoding(previous_encoding)
    end

    self
  end
end
