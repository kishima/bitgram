# frozen_string_literal: true

require "spec_helper"
require "rbconfig"
require "bitgram/util/command"

RSpec.describe "External command execution" do
  def run_script(script, input: "", timeout: 2)
    Bitgram::Util::Command.run([RbConfig.ruby, "-e", script], stdin_data: input, timeout: timeout)
  end

  it "passes data over stdin without shell interpretation" do
    expect(run_script("STDOUT.write(STDIN.read)", input: "$(touch bad); <svg/>")).to eq("$(touch bad); <svg/>")
  end

  it "includes stderr when conversion fails" do
    expect { run_script('warn "bad svg"; exit 2') }.to raise_error(Bitgram::RasterizeError, /bad svg/)
  end

  it "bounds the timeout even when the child never reads a full input pipe" do
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    expect { run_script("sleep 10", input: "x" * 1_000_000, timeout: 0.1) }
      .to raise_error(Bitgram::RasterizerTimeout)
    expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 2
  end

  it "handles an early close of stdin without hiding the child error" do
    expect { run_script('STDIN.close; warn "refused"; exit 1', input: "x" * 1_000_000) }
      .to raise_error(Bitgram::RasterizeError, /refused/)
  end

  it "finds executable files and ignores absent commands" do
    expect(Bitgram::Util::Command.which("certainly-not-a-real-bitgram-command")).to be_nil
    expect(Bitgram::Util::Command.which("sh")).to end_with("/sh")
  end
end
