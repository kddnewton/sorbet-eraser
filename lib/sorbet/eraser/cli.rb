# frozen_string_literal: true

module Sorbet
  module Eraser
    # A small CLI that takes filepaths and erases them by writing back to the
    # original file.
    class CLI
      POOL_SIZE = 4

      attr_reader :verify, :filepaths

      def initialize(verify, filepaths)
        @verify = verify
        @filepaths = filepaths
      end

      def start
        queue = Queue.new
        filepaths.each { |filepath| queue << filepath }

        workers =
          POOL_SIZE.times.map do
            # push a symbol onto the queue for each thread so that it knows when
            # the end of the queue is and will exit its infinite loop
            queue << :eoq

            Thread.new do
              while filepath = queue.shift
                break if filepath == :eoq
                process(filepath)
              end
            end.tap { |thread| thread.abort_on_exception = true }
          end

        workers.each(&:join)
      end

      def self.start(argv)
        verify = false

        if argv.first == "--verify"
          verify = true
          argv.shift
        end

        filepaths = []
        argv.each { |pattern| filepaths.concat(Dir.glob(pattern)) }

        new(verify, filepaths).start
      end

      private

      def process(filepath)
        contents = Eraser.erase(File.read(filepath))

        if verify && Ripper.sexp_raw(contents).nil?
          warn("Internal error while parsing #{filepath}")
        else
          File.write(filepath, contents)
        end
      rescue Parser::ParsingError => error
        warn("Could not parse #{filepath}: #{error}")
      rescue => error
        warn("Could not parse #{filepath}: #{error}")
      end
    end
  end
end
