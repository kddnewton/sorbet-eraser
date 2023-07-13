# frozen_string_literal: true

require "sorbet/eraser"

if RubyVM::InstructionSequence.method_defined?(:load_iseq) &&
   RubyVM::InstructionSequence.method(:load_iseq).source_location[0].include?("/bootsnap/")
  # If the load_iseq method is defined by bootsnap, then we need to override it.
  module Sorbet::Eraser::Patch
    def input_to_storage(contents, filepath)
      super(Sorbet::Eraser.erase(contents), filepath)
    end
  end

  Bootsnap::CompileCache::ISeq.singleton_class.prepend(Sorbet::Eraser::Patch)
else
  # Otherwise if the method isn't defined by bootsnap, then we'll define it
  # ourselves.
  def (RubyVM::InstructionSequence).load_iseq(filepath)
    contents = File.read(filepath)
    erased = Sorbet::Eraser.erase(contents)
    RubyVM::InstructionSequence.compile(erased, filepath, filepath)
  end
end
