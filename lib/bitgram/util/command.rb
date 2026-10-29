# frozen_string_literal: true

require "open3"
require "timeout"

module Bitgram
  # @api private
  module Util
    # @api private
    module Command
      module_function

      def which(name)
        ENV.fetch("PATH", "").split(File::PATH_SEPARATOR)
           .map { |directory| File.join(directory, name) }
           .find { |path| File.executable?(path) && !File.directory?(path) }
      end

      def run(command, stdin_data:, timeout:)
        Open3.popen3(*command, pgroup: true) do |stdin, stdout, stderr, process|
          threads = [Thread.new { write_input(stdin, stdin_data) },
                     Thread.new { stdout.read }, Thread.new { stderr.read }]
          begin
            Timeout.timeout(timeout, RasterizerTimeout, "#{command.first} timed out after #{timeout}s") do
              threads.each(&:join)
              raise RasterizeError, "#{command.first} failed: #{threads[2].value.strip}" unless process.value.success?

              threads[1].value
            end
          ensure
            # Kill the process group as delegates can otherwise retain open pipes.
            begin
              Process.kill(:KILL, -process.pid)
            rescue Errno::ESRCH
              nil
            end
            threads.each { |thread| thread.kill.join }
          end
        end
      rescue Errno::ENOENT => e
        raise RasterizeError, e.message
      end

      def write_input(stdin, data)
        stdin.write(data)
      rescue Errno::EPIPE, IOError
        nil # The process exit status reports early input rejection.
      ensure
        stdin.close
      end
    end
  end
end
