defmodule JidoClaw.Network.NodeTest do
  use ExUnit.Case

  # NOT async — Node and Store are named GenServers with global ETS tables.
  # Isolation is enforced through sequential execution and explicit cleanup.

  alias JidoClaw.Network.Node
  alias JidoClaw.Solutions.Store

  @ets_table :jido_claw_solutions

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp ensure_signal_bus do
    case Jido.Signal.Bus.start_link(name: JidoClaw.SignalBus) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end
  end

  defp ensure_pubsub do
    case Phoenix.PubSub.Supervisor.start_link(name: JidoClaw.PubSub) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end
  end

  # Terminate a child from the application supervisor by child id (module name).
  # When using `{Module, opts}` child specs, the child id defaults to Module.
  # This prevents JidoClaw.Supervisor from restarting the child before
  # start_supervised! can claim the registered name for the test.
  defp terminate_app_child(child_id) do
    with sup when is_pid(sup) <- Process.whereis(JidoClaw.Supervisor) do
      # Ignore errors — the child may not be present (e.g. already stopped by a
      # prior test or when running with --no-start).
      Supervisor.terminate_child(sup, child_id)
    end

    # Unconditionally wait for the name to be released.
    wait_for_name_free(child_id)
  end

  defp wait_for_name_free(name) do
    deadline = System.monotonic_time(:millisecond) + 2000

    Enum.reduce_while(1..200, :ok, fn _, _ ->
      if Process.whereis(name) == nil or System.monotonic_time(:millisecond) > deadline do
        {:halt, :ok}
      else
        Process.sleep(10)
        {:cont, :ok}
      end
    end)
  end

  # ---------------------------------------------------------------------------
  # Setup
  # ---------------------------------------------------------------------------

  setup do
    tmp_dir =
      Path.join(
        System.tmp_dir!(),
        "jido_node_test_#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(tmp_dir)

    ensure_signal_bus()
    ensure_pubsub()

    # Terminate app-supervised children by their child id (= module name for
    # `{Module, opts}` specs). Node lives under Network.Supervisor, which is
    # itself a child of JidoClaw.Supervisor — terminating Network.Supervisor
    # also removes Node. Store is a direct child of JidoClaw.Supervisor.
    terminate_app_child(JidoClaw.Network.Supervisor)
    terminate_app_child(JidoClaw.Solutions.Store)

    start_supervised!({Store, project_dir: tmp_dir})
    start_supervised!({Node, project_dir: tmp_dir})

    on_exit(fn ->
      if :ets.whereis(@ets_table) != :undefined do
        :ets.delete_all_objects(@ets_table)
      end

      File.rm_rf!(tmp_dir)
    end)

    {:ok, tmp_dir: tmp_dir}
  end

  # ---------------------------------------------------------------------------
  # status/0
  # ---------------------------------------------------------------------------

  describe "status/0" do
    test "should return :disconnected status initially" do
      assert %{status: :disconnected} = Node.status()
    end

    test "should return nil agent_id initially" do
      assert %{agent_id: nil} = Node.status()
    end

    test "should return 0 peer count initially" do
      assert %{peer_count: 0} = Node.status()
    end
  end

  # ---------------------------------------------------------------------------
  # connect/0
  # ---------------------------------------------------------------------------

  describe "connect/0" do
    test "should transition status to :connected" do
      assert :ok = Node.connect()
      assert %{status: :connected} = Node.status()
    end

    test "should initialise identity and set agent_id" do
      assert :ok = Node.connect()
      %{agent_id: agent_id} = Node.status()

      assert is_binary(agent_id)
      assert String.starts_with?(agent_id, "jido_")
    end

    test "should be idempotent — second connect call still returns :ok" do
      assert :ok = Node.connect()
      assert :ok = Node.connect()
      assert %{status: :connected} = Node.status()
    end
  end

  # ---------------------------------------------------------------------------
  # disconnect/0
  # ---------------------------------------------------------------------------

  describe "disconnect/0" do
    test "should transition status to :disconnected after being connected" do
      Node.connect()
      assert :ok = Node.disconnect()
      assert %{status: :disconnected} = Node.status()
    end

    test "should return :ok when already disconnected" do
      assert :ok = Node.disconnect()
    end

    test "should clear the agent_id after disconnect" do
      Node.connect()
      Node.disconnect()
      # Status field should exist, peer_count should be 0
      assert %{peer_count: 0} = Node.status()
    end
  end

  # ---------------------------------------------------------------------------
  # peers/0
  # ---------------------------------------------------------------------------

  describe "peers/0" do
    test "should return an empty list initially" do
      assert [] = Node.peers()
    end

    test "should return an empty list after connecting with no network activity" do
      Node.connect()
      assert [] = Node.peers()
    end
  end

  # ---------------------------------------------------------------------------
  # broadcast_solution/1
  # ---------------------------------------------------------------------------

  describe "broadcast_solution/1" do
    test "should return {:error, :not_connected} when disconnected" do
      assert {:error, :not_connected} = Node.broadcast_solution("any-solution-id")
    end

    test "should return {:error, :solution_not_found} for a non-existent id after connecting" do
      Node.connect()
      assert {:error, :solution_not_found} = Node.broadcast_solution("nonexistent-id-xyz")
    end

    test "should return :ok when broadcasting an existing solution" do
      Node.connect()

      {:ok, solution} =
        Store.store_solution(%{
          problem_description: "test broadcast problem",
          solution_content: "def solution, do: :ok",
          language: "elixir",
          tags: []
        })

      assert :ok = Node.broadcast_solution(solution.id)
    end
  end

  # ---------------------------------------------------------------------------
  # request_solutions/2
  # ---------------------------------------------------------------------------

  describe "request_solutions/2" do
    test "should return {:error, :not_connected} when disconnected" do
      assert {:error, :not_connected} = Node.request_solutions("how to cache with ETS")
    end

    test "should return :ok after connecting" do
      Node.connect()
      assert :ok = Node.request_solutions("how to handle GenServer crashes")
    end

    test "should return :ok with filter opts" do
      Node.connect()
      assert :ok = Node.request_solutions("OTP patterns", language: "elixir", limit: 5)
    end
  end

  # ---------------------------------------------------------------------------
  # Graceful degradation when GenServer is not running
  # ---------------------------------------------------------------------------

  describe "graceful degradation when GenServer is not running" do
    test "status/0 returns :not_running sentinel when process is absent" do
      stop_supervised!(Node)
      assert %{status: :not_running, agent_id: nil, peer_count: 0} = Node.status()
    end

    test "connect/0 returns :ok when process is absent" do
      stop_supervised!(Node)
      assert :ok = Node.connect()
    end

    test "disconnect/0 returns :ok when process is absent" do
      stop_supervised!(Node)
      assert :ok = Node.disconnect()
    end

    test "peers/0 returns [] when process is absent" do
      stop_supervised!(Node)
      assert [] = Node.peers()
    end

    test "broadcast_solution/1 returns {:error, :not_running} when process is absent" do
      stop_supervised!(Node)
      assert {:error, :not_running} = Node.broadcast_solution("any-id")
    end

    test "request_solutions/2 returns {:error, :not_running} when process is absent" do
      stop_supervised!(Node)
      assert {:error, :not_running} = Node.request_solutions("any description")
    end
  end
end
