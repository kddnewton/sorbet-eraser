# frozen_string_literal: true

require "sorbet/eraser"

# Hook into bootsnap so that before the source is compiled through
# RubyVM::InstructionSequence it gets erased through the eraser.
if RubyVM::InstructionSequence.method_defined?(:load_iseq)
  load_iseq, = RubyVM::InstructionSequence.method(:load_iseq).source_location

  if load_iseq.include?("/bootsnap/")
    module Sorbet::Eraser::Patch
      def input_to_storage(contents, filepath)
        erased = Sorbet::Eraser.erase(contents)
        RubyVM::InstructionSequence.compile(erased, filepath, filepath).to_binary
      rescue SyntaxError
        raise ::Bootsnap::CompileCache::Uncompilable, "syntax error"
      end
    end

    Bootsnap::CompileCache::ISeq.singleton_class.prepend(Sorbet::Eraser::Patch)
  end
end
