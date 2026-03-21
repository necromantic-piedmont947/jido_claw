defmodule JidoClaw.Tools.RunCommandTest do
  use ExUnit.Case, async: false

  alias JidoClaw.Tools.RunCommand

  describe "run/2 success" do
    test "should execute command and return stdout output" do
      assert {:ok, result} = RunCommand.run(%{command: "echo hello"}, %{})

      assert String.trim(result.output) == "hello"
    end

    test "should return exit_code 0 for successful command" do
      assert {:ok, result} = RunCommand.run(%{command: "true"}, %{})

      assert result.exit_code == 0
    end

    test "should return non-zero exit_code when command fails" do
      assert {:ok, result} = RunCommand.run(%{command: "false"}, %{})

      assert result.exit_code != 0
    end

    test "should capture stderr merged into output" do
      assert {:ok, result} = RunCommand.run(%{command: "echo err >&2"}, %{})

      assert result.output =~ "err"
    end

    test "should return correct output for multi-word command" do
      assert {:ok, result} = RunCommand.run(%{command: "echo foo bar baz"}, %{})

      assert String.trim(result.output) == "foo bar baz"
    end

    test "should execute commands with pipes" do
      # seq produces one number per line; pipe through wc -l to count them
      assert {:ok, result} = RunCommand.run(%{command: "seq 1 5 | wc -l"}, %{})

      assert String.trim(result.output) =~ "5"
    end

    test "should report correct exit_code for failing command" do
      assert {:ok, result} = RunCommand.run(%{command: "exit 42"}, %{})

      assert result.exit_code == 42
    end
  end

  describe "run/2 output truncation" do
    test "should truncate output longer than 10_000 characters" do
      # generate ~12KB of output: 12000 'x' chars plus newline
      command = "python3 -c \"print('x' * 12000)\""

      assert {:ok, result} = RunCommand.run(%{command: command}, %{})

      assert String.length(result.output) <= 10_000 + 100
      assert result.output =~ "output truncated"
    end

    test "should not truncate output shorter than 10_000 characters" do
      assert {:ok, result} = RunCommand.run(%{command: "echo short"}, %{})

      refute result.output =~ "truncated"
    end
  end

  describe "run/2 timeout" do
    test "should return error when command exceeds timeout" do
      assert {:error, message} =
               RunCommand.run(%{command: "sleep 10", timeout: 100}, %{})

      assert message =~ "timed out"
    end

    test "should complete within timeout when command finishes in time" do
      assert {:ok, result} = RunCommand.run(%{command: "echo fast", timeout: 5_000}, %{})

      assert String.trim(result.output) == "fast"
    end
  end
end
