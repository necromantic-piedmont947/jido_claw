defmodule JidoClaw.Tools.ReadFileTest do
  use ExUnit.Case, async: true

  alias JidoClaw.Tools.ReadFile

  setup do
    dir = Path.join(System.tmp_dir!(), "jido_read_file_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)

    on_exit(fn -> File.rm_rf!(dir) end)

    {:ok, dir: dir}
  end

  describe "run/2 success" do
    test "should return numbered lines when file exists", %{dir: dir} do
      path = Path.join(dir, "sample.txt")
      File.write!(path, "alpha\nbeta\ngamma")

      assert {:ok, result} = ReadFile.run(%{path: path}, %{})

      assert result.path == path
      assert result.total_lines == 3
      assert result.content =~ "   1 │ alpha"
      assert result.content =~ "   2 │ beta"
      assert result.content =~ "   3 │ gamma"
    end

    test "should pad line numbers to four characters", %{dir: dir} do
      path = Path.join(dir, "padded.txt")
      File.write!(path, "only one line")

      assert {:ok, result} = ReadFile.run(%{path: path}, %{})

      assert result.content =~ "   1 │ only one line"
    end

    test "should respect offset param by skipping leading lines", %{dir: dir} do
      path = Path.join(dir, "offset.txt")
      File.write!(path, "line1\nline2\nline3\nline4")

      assert {:ok, result} = ReadFile.run(%{path: path, offset: 2}, %{})

      refute result.content =~ "│ line1"
      refute result.content =~ "│ line2"
      assert result.content =~ "│ line3"
      assert result.content =~ "│ line4"
    end

    test "should respect limit param by capping returned lines", %{dir: dir} do
      path = Path.join(dir, "limit.txt")
      content = Enum.map_join(1..10, "\n", &"line#{&1}")
      File.write!(path, content)

      assert {:ok, result} = ReadFile.run(%{path: path, limit: 3}, %{})

      lines = String.split(result.content, "\n", trim: true)
      assert length(lines) == 3
    end

    test "should apply offset and limit together", %{dir: dir} do
      path = Path.join(dir, "combined.txt")
      content = Enum.map_join(1..10, "\n", &"line#{&1}")
      File.write!(path, content)

      assert {:ok, result} = ReadFile.run(%{path: path, offset: 3, limit: 2}, %{})

      assert result.content =~ "│ line4"
      assert result.content =~ "│ line5"
      refute result.content =~ "│ line3"
      refute result.content =~ "│ line6"
    end

    test "should report total_lines regardless of offset or limit", %{dir: dir} do
      path = Path.join(dir, "total.txt")
      File.write!(path, "a\nb\nc\nd\ne")

      assert {:ok, result} = ReadFile.run(%{path: path, offset: 2, limit: 1}, %{})

      assert result.total_lines == 5
    end

    test "should handle empty file", %{dir: dir} do
      path = Path.join(dir, "empty.txt")
      File.write!(path, "")

      assert {:ok, result} = ReadFile.run(%{path: path}, %{})

      assert result.total_lines == 1
      assert result.content =~ "│"
    end
  end

  describe "run/2 error" do
    test "should return error when file does not exist", %{dir: dir} do
      path = Path.join(dir, "no_such_file.txt")

      assert {:error, message} = ReadFile.run(%{path: path}, %{})

      assert message =~ "Cannot read"
      assert message =~ path
    end

    test "should return error when path is a directory", %{dir: dir} do
      assert {:error, message} = ReadFile.run(%{path: dir}, %{})

      assert message =~ "Cannot read"
    end
  end
end
