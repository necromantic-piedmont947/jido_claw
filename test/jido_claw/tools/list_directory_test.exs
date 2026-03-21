defmodule JidoClaw.Tools.ListDirectoryTest do
  use ExUnit.Case, async: true

  alias JidoClaw.Tools.ListDirectory

  setup do
    dir = Path.join(System.tmp_dir!(), "jido_list_dir_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)

    on_exit(fn -> File.rm_rf!(dir) end)

    {:ok, dir: dir}
  end

  defp touch(path) do
    File.write!(path, "")
  end

  describe "run/2 basic listing" do
    test "should list files with 'file' type indicator", %{dir: dir} do
      touch(Path.join(dir, "file_a.txt"))
      touch(Path.join(dir, "file_b.txt"))

      assert {:ok, result} = ListDirectory.run(%{path: dir}, %{})

      assert result.path == dir
      assert result.entries =~ "file  file_a.txt"
      assert result.entries =~ "file  file_b.txt"
    end

    test "should list subdirectories with 'dir' type indicator", %{dir: dir} do
      File.mkdir_p!(Path.join(dir, "subdir"))

      assert {:ok, result} = ListDirectory.run(%{path: dir}, %{})

      assert result.entries =~ "dir  subdir"
    end

    test "should list both files and directories in the same result", %{dir: dir} do
      touch(Path.join(dir, "readme.md"))
      File.mkdir_p!(Path.join(dir, "src"))

      assert {:ok, result} = ListDirectory.run(%{path: dir}, %{})

      assert result.entries =~ "file  readme.md"
      assert result.entries =~ "dir  src"
    end

    test "should return total count equal to number of entries", %{dir: dir} do
      touch(Path.join(dir, "a.txt"))
      touch(Path.join(dir, "b.txt"))
      File.mkdir_p!(Path.join(dir, "c"))

      assert {:ok, result} = ListDirectory.run(%{path: dir}, %{})

      assert result.total == 3
    end

    test "should return empty entries string for an empty directory", %{dir: dir} do
      assert {:ok, result} = ListDirectory.run(%{path: dir}, %{})

      assert result.entries == ""
      assert result.total == 0
    end
  end

  describe "run/2 glob pattern" do
    test "should return only files matching glob pattern", %{dir: dir} do
      touch(Path.join(dir, "app.ex"))
      touch(Path.join(dir, "app_test.exs"))
      touch(Path.join(dir, "README.md"))

      assert {:ok, result} = ListDirectory.run(%{path: dir, pattern: "*.ex"}, %{})

      assert result.entries =~ "app.ex"
      refute result.entries =~ "app_test.exs"
      refute result.entries =~ "README.md"
    end

    test "should support recursive glob pattern", %{dir: dir} do
      nested = Path.join(dir, "lib/deep")
      File.mkdir_p!(nested)
      touch(Path.join(nested, "module.ex"))
      touch(Path.join(dir, "mix.exs"))

      assert {:ok, result} = ListDirectory.run(%{path: dir, pattern: "**/*.ex"}, %{})

      assert result.entries =~ "module.ex"
      refute result.entries =~ "mix.exs"
    end

    test "should return zero total when no files match pattern", %{dir: dir} do
      touch(Path.join(dir, "notes.txt"))

      assert {:ok, result} = ListDirectory.run(%{path: dir, pattern: "*.ex"}, %{})

      assert result.total == 0
      assert result.entries == ""
    end
  end

  describe "run/2 max_results" do
    test "should respect max_results and truncate excess entries", %{dir: dir} do
      Enum.each(1..10, fn i -> touch(Path.join(dir, "file_#{i}.txt")) end)

      assert {:ok, result} = ListDirectory.run(%{path: dir, max_results: 3}, %{})

      listed_lines = result.entries |> String.split("\n") |> Enum.reject(&(&1 == ""))
      # 3 entry lines + 1 truncation note line
      assert length(listed_lines) == 4
      assert result.entries =~ "more entries truncated"
      assert result.total == 10
    end

    test "should not add truncation note when results fit within max_results", %{dir: dir} do
      touch(Path.join(dir, "only_one.txt"))

      assert {:ok, result} = ListDirectory.run(%{path: dir, max_results: 5}, %{})

      refute result.entries =~ "truncated"
    end
  end

  describe "run/2 error" do
    test "should return error when path does not exist", %{dir: dir} do
      nonexistent = Path.join(dir, "no_such_directory")

      assert {:error, message} = ListDirectory.run(%{path: nonexistent}, %{})

      assert message =~ "Cannot list"
      assert message =~ nonexistent
    end

    test "should return error when path is a file not a directory", %{dir: dir} do
      file_path = Path.join(dir, "a_file.txt")
      touch(file_path)

      assert {:error, message} = ListDirectory.run(%{path: file_path}, %{})

      assert message =~ "Cannot list"
    end
  end
end
