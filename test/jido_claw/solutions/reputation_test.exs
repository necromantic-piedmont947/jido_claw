defmodule JidoClaw.Solutions.ReputationTest do
  use ExUnit.Case
  # NOT async — Reputation is a named GenServer backed by a global named ETS table.
  # Sequential execution + explicit ETS cleanup provide test isolation.

  alias JidoClaw.Solutions.Reputation

  @ets_table :jido_claw_reputation

  # ---------------------------------------------------------------------------
  # Setup
  # ---------------------------------------------------------------------------

  setup do
    tmp_dir =
      Path.join(
        System.tmp_dir!(),
        "jido_reputation_test_#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(tmp_dir)

    # SignalBus is started by JidoClaw.Application — no need to start it here.
    # record_success/1 and record_failure/1 emit signals via
    # JidoClaw.SignalBus.emit/2, which swallows errors if the bus is unavailable.

    # JidoClaw.Application starts a Reputation process under JidoClaw.Supervisor.
    # Terminate it via the supervisor so it is not auto-restarted, then start a
    # test-scoped process (owned by the ExUnit supervisor) pointing at tmp_dir.
    case Process.whereis(JidoClaw.Supervisor) do
      nil ->
        :ok

      _sup ->
        Supervisor.terminate_child(JidoClaw.Supervisor, JidoClaw.Solutions.Reputation)
        Supervisor.delete_child(JidoClaw.Supervisor, JidoClaw.Solutions.Reputation)
    end

    start_supervised!({Reputation, project_dir: tmp_dir})

    on_exit(fn ->
      # Wipe ETS rows so the next test starts with an empty table.
      # The named table itself survives — only its contents are cleared.
      if :ets.whereis(@ets_table) != :undefined do
        :ets.delete_all_objects(@ets_table)
      end

      File.rm_rf!(tmp_dir)
    end)

    {:ok, tmp_dir: tmp_dir}
  end

  # ---------------------------------------------------------------------------
  # get/1
  # ---------------------------------------------------------------------------

  describe "get/1" do
    test "should return default entry for unknown agent" do
      entry = Reputation.get("unknown-agent-xyz")

      assert entry.agent_id == "unknown-agent-xyz"
      assert entry.solutions_shared == 0
      assert entry.solutions_verified == 0
      assert entry.solutions_failed == 0
      assert is_nil(entry.last_active)
    end

    test "should return stored entry for known agent" do
      Reputation.record_success("agent-known")
      entry = Reputation.get("agent-known")

      assert entry.agent_id == "agent-known"
      assert entry.solutions_verified == 1
    end

    test "default score should be 0.5" do
      entry = Reputation.get("brand-new-agent")

      assert entry.score == 0.5
    end
  end

  # ---------------------------------------------------------------------------
  # record_success/1
  # ---------------------------------------------------------------------------

  describe "record_success/1" do
    test "should increment solutions_verified" do
      Reputation.record_success("agent-s1")
      Reputation.record_success("agent-s1")
      entry = Reputation.get("agent-s1")

      assert entry.solutions_verified == 2
    end

    test "should update score upward from default" do
      # A fresh agent has score 0.5. After one success the success_rate rises
      # to 1.0, so the recomputed score must exceed 0.5.
      Reputation.record_success("agent-score-up")
      entry = Reputation.get("agent-score-up")

      assert entry.score > 0.5
    end

    test "should update last_active timestamp" do
      Reputation.record_success("agent-active-s")
      entry = Reputation.get("agent-active-s")

      refute is_nil(entry.last_active)
      # Must be a valid ISO 8601 string
      assert {:ok, _, _} = DateTime.from_iso8601(entry.last_active)
    end

    test "should return :ok" do
      assert :ok = Reputation.record_success("agent-ret")
    end
  end

  # ---------------------------------------------------------------------------
  # record_failure/1
  # ---------------------------------------------------------------------------

  describe "record_failure/1" do
    test "should increment solutions_failed" do
      Reputation.record_failure("agent-f1")
      Reputation.record_failure("agent-f1")
      entry = Reputation.get("agent-f1")

      assert entry.solutions_failed == 2
    end

    test "should decrease score relative to a pure-success baseline" do
      # Record one success then one failure for agent-mixed; compare to agent-pure
      # who only has successes.
      Reputation.record_success("agent-pure")
      pure_score = Reputation.get("agent-pure").score

      Reputation.record_success("agent-mixed")
      Reputation.record_failure("agent-mixed")
      mixed_score = Reputation.get("agent-mixed").score

      assert mixed_score < pure_score
    end

    test "should update last_active timestamp" do
      Reputation.record_failure("agent-active-f")
      entry = Reputation.get("agent-active-f")

      refute is_nil(entry.last_active)
      assert {:ok, _, _} = DateTime.from_iso8601(entry.last_active)
    end

    test "should return :ok" do
      assert :ok = Reputation.record_failure("agent-fail-ret")
    end
  end

  # ---------------------------------------------------------------------------
  # record_share/1
  # ---------------------------------------------------------------------------

  describe "record_share/1" do
    test "should increment solutions_shared" do
      Reputation.record_share("agent-share-1")
      Reputation.record_share("agent-share-1")
      Reputation.record_share("agent-share-1")
      entry = Reputation.get("agent-share-1")

      assert entry.solutions_shared == 3
    end

    test "should return :ok" do
      assert :ok = Reputation.record_share("agent-share-ret")
    end
  end

  # ---------------------------------------------------------------------------
  # all/0
  # ---------------------------------------------------------------------------

  describe "all/0" do
    test "should return empty list when no agents tracked" do
      assert Reputation.all() == []
    end

    test "should return all agents" do
      Reputation.record_success("all-agent-a")
      Reputation.record_success("all-agent-b")
      Reputation.record_failure("all-agent-c")

      entries = Reputation.all()
      ids = Enum.map(entries, & &1.agent_id)

      assert "all-agent-a" in ids
      assert "all-agent-b" in ids
      assert "all-agent-c" in ids
    end
  end

  # ---------------------------------------------------------------------------
  # top/1
  # ---------------------------------------------------------------------------

  describe "top/1" do
    test "should return agents sorted by score descending" do
      # Build three agents with distinct scores.
      # agent-top-high: 3 successes, 0 failures → high success_rate
      # agent-top-mid:  1 success,  1 failure   → mid success_rate
      # agent-top-low:  0 successes, 3 failures  → low success_rate
      Enum.each(1..3, fn _ -> Reputation.record_success("agent-top-high") end)
      Reputation.record_success("agent-top-mid")
      Reputation.record_failure("agent-top-mid")
      Enum.each(1..3, fn _ -> Reputation.record_failure("agent-top-low") end)

      [first, second, third] = Reputation.top(3)

      assert first.agent_id == "agent-top-high"
      assert second.agent_id == "agent-top-mid"
      assert third.agent_id == "agent-top-low"
      assert first.score >= second.score
      assert second.score >= third.score
    end

    test "should respect the limit" do
      for i <- 1..5 do
        Reputation.record_success("agent-limit-#{i}")
      end

      result = Reputation.top(3)

      assert length(result) == 3
    end

    test "should return fewer than limit when not enough agents exist" do
      Reputation.record_success("agent-only-one")

      result = Reputation.top(10)

      assert length(result) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # Disk persistence
  # ---------------------------------------------------------------------------

  describe "disk persistence" do
    test "should persist to reputation.json after a write", %{tmp_dir: tmp_dir} do
      Reputation.record_success("agent-persist")

      path = Path.join(tmp_dir, ".jido/reputation.json")
      assert File.exists?(path), "Expected #{path} to exist after record_success/1"
    end

    test "should write agent entry into reputation.json", %{tmp_dir: tmp_dir} do
      Reputation.record_success("agent-json-check")

      path = Path.join(tmp_dir, ".jido/reputation.json")
      {:ok, raw} = File.read(path)
      {:ok, decoded} = Jason.decode(raw)

      assert Map.has_key?(decoded, "agent-json-check"),
             "Expected 'agent-json-check' key in #{inspect(Map.keys(decoded))}"
    end

    test "should reload stored entries from disk on restart", %{tmp_dir: tmp_dir} do
      Reputation.record_success("agent-reload")
      Reputation.record_success("agent-reload")

      # Stop the supervised Reputation process.
      stop_supervised!(Reputation)

      # Wipe ETS so in-memory state is gone.
      if :ets.whereis(@ets_table) != :undefined do
        :ets.delete_all_objects(@ets_table)
      end

      # Restart against the same directory — it must reload the JSON.
      start_supervised!({Reputation, project_dir: tmp_dir})

      reloaded = Reputation.get("agent-reload")

      assert reloaded.solutions_verified == 2
    end

    test "should reload score from disk on restart", %{tmp_dir: tmp_dir} do
      Enum.each(1..3, fn _ -> Reputation.record_success("agent-score-reload") end)
      persisted_score = Reputation.get("agent-score-reload").score

      stop_supervised!(Reputation)

      if :ets.whereis(@ets_table) != :undefined do
        :ets.delete_all_objects(@ets_table)
      end

      start_supervised!({Reputation, project_dir: tmp_dir})

      reloaded_score = Reputation.get("agent-score-reload").score

      assert_in_delta reloaded_score, persisted_score, 0.001
    end
  end

  # ---------------------------------------------------------------------------
  # Graceful degradation when GenServer is not running
  # ---------------------------------------------------------------------------

  describe "graceful degradation when GenServer is not running" do
    test "get/1 should return default entry when process is absent" do
      stop_supervised!(Reputation)
      entry = Reputation.get("any-agent")

      assert entry.agent_id == "any-agent"
      assert entry.score == 0.5
    end

    test "record_success/1 should return :ok when process is absent" do
      stop_supervised!(Reputation)
      assert :ok = Reputation.record_success("any-agent")
    end

    test "record_failure/1 should return :ok when process is absent" do
      stop_supervised!(Reputation)
      assert :ok = Reputation.record_failure("any-agent")
    end

    test "record_share/1 should return :ok when process is absent" do
      stop_supervised!(Reputation)
      assert :ok = Reputation.record_share("any-agent")
    end

    test "all/0 should return [] when process is absent" do
      stop_supervised!(Reputation)
      assert [] = Reputation.all()
    end

    test "top/1 should return [] when process is absent" do
      stop_supervised!(Reputation)
      assert [] = Reputation.top(10)
    end
  end
end
