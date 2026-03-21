defmodule JidoClaw.Session do
  @moduledoc """
  JSON file-based session persistence at .jido/sessions/.
  """

  def save_turn(project_dir, session_id, role, content) do
    dir = Path.join([project_dir, ".jido", "sessions"])
    File.mkdir_p!(dir)

    path = session_path(project_dir, session_id)

    session =
      case File.read(path) do
        {:ok, json} -> Jason.decode!(json)
        _ -> %{"id" => session_id, "created_at" => now_ms(), "messages" => []}
      end

    message = %{"role" => to_string(role), "content" => content, "timestamp" => now_ms()}
    updated = Map.update!(session, "messages", &(&1 ++ [message]))

    File.write!(path, Jason.encode!(updated, pretty: true))
    :ok
  end

  def load_recent(project_dir, max_age_ms \\ 3_600_000) do
    dir = Path.join([project_dir, ".jido", "sessions"])

    case File.ls(dir) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".json"))
        |> Enum.sort(:desc)
        |> Enum.take(1)
        |> case do
          [file] ->
            path = Path.join(dir, file)

            case File.read(path) do
              {:ok, json} ->
                session = Jason.decode!(json)
                created = Map.get(session, "created_at", 0)

                if now_ms() - created < max_age_ms do
                  {:ok, session}
                else
                  :none
                end

              _ ->
                :none
            end

          [] ->
            :none
        end

      _ ->
        :none
    end
  end

  def new_session_id do
    now = NaiveDateTime.utc_now()
    "session_#{NaiveDateTime.to_iso8601(now) |> String.replace(~r/[^0-9]/, "")}"
  end

  defp session_path(project_dir, session_id) do
    Path.join([project_dir, ".jido", "sessions", "#{session_id}.json"])
  end

  defp now_ms, do: System.system_time(:millisecond)
end
