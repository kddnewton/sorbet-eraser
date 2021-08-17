# frozen_string_literal: true

module Sorbet
  module Eraser
    # A small CLI that takes filepaths and erases them by writing back to the
    # original file.
    class CLI
      POOL_SIZE = 4

      attr_reader :filepaths

      def initialize(filepaths)
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
            end
          end

        workers.each(&:join)
      end

      def self.start(argv)
        new(argv.flat_map { |pattern| Dir.glob(pattern) }).start
      end

      private

      def process(filepath)
        File.write(filepath, Eraser.erase(File.read(filepath)))
      rescue Parser::ParsingError => error
        warn("Could not parse #{filepath}: #{error}")
      rescue => error
        warn("Could not parse #{filepath}: #{error}")
      end
    end
  end
end
