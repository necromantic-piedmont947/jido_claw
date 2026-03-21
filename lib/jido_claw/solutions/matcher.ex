defmodule JidoClaw.Solutions.Matcher do
  @moduledoc "Orchestrates finding and ranking the best matching solutions for a problem description."

  alias JidoClaw.Solutions.{Fingerprint, Store}

  @default_threshold 0.3
  @default_limit 5
  @bm25_k1 1.2

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Find the best matching solutions for a problem description.

  ## Options

    * `:language`   - primary language string
    * `:framework`  - framework string
    * `:threshold`  - minimum combined score to include (default #{@default_threshold})
    * `:limit`      - maximum number of results (default #{@default_limit})

  Returns a list of maps: `%{solution: solution, score: float, match_type: :exact | :fuzzy}`.
  """
  @spec find_solutions(String.t(), keyword()) :: [
          %{solution: term(), score: float(), match_type: :exact | :fuzzy}
        ]
  def find_solutions(problem_description, opts \\ [])

  def find_solutions(problem_description, _opts)
      when not is_binary(problem_description) or problem_description == "" do
    []
  end

  def find_solutions(problem_description, opts) do
    threshold = Keyword.get(opts, :threshold, @default_threshold)
    limit = Keyword.get(opts, :limit, @default_limit)

    query_fp = Fingerprint.generate(problem_description, opts)

    case Store.find_by_signature(query_fp.signature) do
      {:ok, solution} ->
        [%{solution: solution, score: 1.0, match_type: :exact}]

      _ ->
        query = Enum.join(query_fp.search_terms, " ")

        candidates =
          if query == "" do
            Store.all(opts)
          else
            Store.search(query, opts)
          end

        candidates
        |> score_candidates(query_fp)
        |> Enum.filter(fn %{score: s} -> s >= threshold end)
        |> Enum.sort_by(& &1.score, :desc)
        |> Enum.take(limit)
    end
  end

  @doc """
  Score and rank a list of solutions against a query fingerprint.

  Returns a sorted list of `{solution, combined_score}` tuples, highest score first.
  """
  @spec rank_solutions(
          [JidoClaw.Solutions.Solution.t()],
          Fingerprint.t()
        ) :: [{JidoClaw.Solutions.Solution.t(), float()}]
  def rank_solutions(solutions, %Fingerprint{} = query_fp) when is_list(solutions) do
    solutions
    |> Enum.map(fn solution ->
      candidate_fp =
        Fingerprint.generate(
          solution.solution_content,
          language: solution.language,
          framework: solution.framework
        )

      fp_score = Fingerprint.match_score(query_fp, candidate_fp)
      combined = combine(fp_score, solution.trust_score)
      {solution, combined}
    end)
    |> Enum.sort_by(fn {_sol, score} -> score end, :desc)
  end

  @doc """
  Return the single best matching solution for a problem description, or `nil` when none qualify.
  """
  @spec best_match(String.t(), keyword()) ::
          %{solution: term(), score: float(), match_type: :exact | :fuzzy} | nil
  def best_match(problem_description, opts \\ []) do
    problem_description
    |> find_solutions(Keyword.put(opts, :limit, 1))
    |> List.first()
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec score_candidates(
          [JidoClaw.Solutions.Solution.t()],
          Fingerprint.t()
        ) :: [%{solution: term(), score: float(), match_type: :fuzzy}]
  defp score_candidates(candidates, query_fp) do
    Enum.map(candidates, fn solution ->
      candidate_fp =
        Fingerprint.generate(
          solution.solution_content,
          language: solution.language,
          framework: solution.framework
        )

      fp_score = Fingerprint.match_score(query_fp, candidate_fp)
      combined = combine(fp_score, solution.trust_score)

      %{solution: solution, score: combined, match_type: :fuzzy}
    end)
  end

  @spec combine(float(), float()) :: float()
  defp combine(fp_score, trust_score) do
    fp_score * 0.6 + trust_score * 0.4
  end

  @doc false
  @spec text_relevance([String.t()], String.t()) :: float()
  def text_relevance(query_terms, document_text)
      when is_list(query_terms) and is_binary(document_text) do
    doc_tokens =
      document_text
      |> String.downcase()
      |> String.split(~r/[\s\p{P}]+/u, trim: true)
      |> Enum.reject(&(String.length(&1) < 3))

    scored =
      Enum.map(query_terms, fn term ->
        tf = Enum.count(doc_tokens, &(&1 == term))
        tf / (tf + @bm25_k1)
      end)

    total = Enum.sum(scored)
    term_count = length(query_terms)

    if term_count == 0, do: 0.0, else: total / term_count
  end

  def text_relevance(_, _), do: 0.0
end
