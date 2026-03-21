defmodule JidoClaw.Tools.WriteFileTest do
  # Not async — writes to tmp filesystem (isolated per test via unique dirs, but
  # keeping sync as a conservative default for file-mutating tests)
  use ExUnit.Case

  alias JidoClaw.Tools.WriteFile

  setup do
    dir = Path.join(System.tmp_dir!(), "jido_write_file_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)

    on_exit(fn -> File.rm_rf!(dir) end)

    {:ok, dir: dir}
  end

  describe "run/2 success" do
    test "should create new file with given content when file does not exist", %{dir: dir} do
      path = Path.join(dir, "new_file.txt")
      content = "hello\nworld"

      assert {:ok, result} = WriteFile.run(%{path: path, content: content}, %{})

      assert result.path == path
      assert File.read!(path) == content
    end

    test "should return lines_written equal to newline count plus one", %{dir: dir} do
      path = Path.join(dir, "counted.txt")
      content = "line1\nline2\nline3"

      assert {:ok, result} = WriteFile.run(%{path: path, content: content}, %{})

      assert result.lines_written == 3
    end

    test "should return lines_written of 1 for single-line content", %{dir: dir} do
      path = Path.join(dir, "single.txt")

      assert {:ok, result} = WriteFile.run(%{path: path, content: "just one line"}, %{})

      assert result.lines_written == 1
    end

    test "should create nested parent directories when they do not exist", %{dir: dir} do
      path = Path.join([dir, "deep", "nested", "dir", "file.txt"])

      assert {:ok, result} = WriteFile.run(%{path: path, content: "deep content"}, %{})

      assert result.path == path
      assert File.exists?(path)
      assert File.read!(path) == "deep content"
    end

    test "should overwrite existing file with new content", %{dir: dir} do
      path = Path.join(dir, "overwrite.txt")
      File.write!(path, "original content")

      assert {:ok, _result} = WriteFile.run(%{path: path, content: "new content"}, %{})

      assert File.read!(path) == "new content"
    end

    test "should handle empty content", %{dir: dir} do
      path = Path.join(dir, "empty.txt")

      assert {:ok, result} = WriteFile.run(%{path: path, content: ""}, %{})

      assert File.read!(path) == ""
      assert result.lines_written == 1
    end
  end
end
