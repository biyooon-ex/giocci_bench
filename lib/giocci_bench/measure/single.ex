defmodule GiocciBench.Measure.Single do
  @moduledoc false

  alias GiocciBench.Csv

  @default_warmup 1
  @default_iterations 5
  @default_timeout_ms 5_000
  @default_out_dir "giocci_bench_output"
  @default_cases ["register_client", "save_module", "exec_func"]
  @columns [
    :run_id,
    :case_id,
    :case_desc,
    :iteration,
    :elapsed_ms,
    :cpu_usage_pct,
    :memory_usage_pct,
    :input_size,
    :warmup,
    :elixir_version,
    :otp_version,
    :os,
    :cpu,
    :cpu_cores,
    :memory_gb,
    :started_at
  ]

  def run(opts \\ []) do
    relay_name = fetch_option(opts, :relay_name, default_relay())
    module = fetch_option(opts, :module, GiocciBench.Sample)
    mfargs = fetch_option(opts, :mfargs, {module, :add, [1, 2]})
    warmup = fetch_option(opts, :warmup, @default_warmup)
    iterations = fetch_option(opts, :iterations, @default_iterations)
    timeout_ms = fetch_option(opts, :timeout_ms, @default_timeout_ms)
    out_dir = fetch_option(opts, :out_dir, @default_out_dir)
    run_id = fetch_option(opts, :run_id, build_run_id())

    started_at = DateTime.utc_now() |> DateTime.to_iso8601()
    env = env_info()
    input_size = fetch_option(opts, :input_size, default_input_size(mfargs))
    selected_cases = normalize_cases(fetch_option(opts, :cases, @default_cases))

    cases = [
      {"register_client", "Giocci.register_client/2", fn -> Giocci.register_client(relay_name, timeout: timeout_ms) end},
      {"save_module", "Giocci.save_module/3", fn -> Giocci.save_module(relay_name, module, timeout: timeout_ms) end},
      {"exec_func", "Giocci.exec_func/3", fn -> Giocci.exec_func(relay_name, mfargs, timeout: timeout_ms) end}
    ]

    rows =
      cases
      |> Enum.filter(fn {case_id, _case_desc, _fun} -> case_id in selected_cases end)
      |> Enum.flat_map(fn {case_id, case_desc, fun} ->
        _ = prepare_case(case_id, relay_name, module, timeout_ms)
        warmup_runs(warmup, fun)
        measure_iterations(case_id, case_desc, iterations, fun, run_id, started_at, env, input_size)
      end)

    path = Path.join(out_dir, "single_#{run_id}.csv")
    header = Enum.map(@columns, &Atom.to_string/1)

    Csv.write_csv!(path, header, rows)
    {:ok, path}
  end

  defp warmup_runs(count, fun) when count > 0 do
    for _ <- 1..count, do: fun.()
    :ok
  end

  defp warmup_runs(_count, _fun), do: :ok

  defp measure_iterations(case_id, case_desc, iterations, fun, run_id, started_at, env, input_size) do
    for iteration <- 1..iterations do
      {elapsed_ms, _result} = timed_call(fun)

      values = %{
        run_id: run_id,
        case_id: case_id,
        case_desc: case_desc,
        iteration: iteration,
        elapsed_ms: elapsed_ms,
        cpu_usage_pct: nil,
        memory_usage_pct: nil,
        input_size: input_size,
        warmup: false,
        elixir_version: env.elixir_version,
        otp_version: env.otp_version,
        os: env.os,
        cpu: env.cpu,
        cpu_cores: env.cpu_cores,
        memory_gb: env.memory_gb,
        started_at: started_at
      }

      Enum.map(@columns, &Map.fetch!(values, &1))
    end
  end

  defp timed_call(fun) do
    start_time = System.monotonic_time()
    result = fun.()

    case result do
      {:error, reason} ->
        raise "giocci call failed: #{inspect(reason)}"

      _ ->
        elapsed_ms =
          System.monotonic_time()
          |> Kernel.-(start_time)
          |> System.convert_time_unit(:native, :microsecond)
          |> Kernel./(1000)
          |> Float.round(3)

        {elapsed_ms, result}
    end
  end

  defp prepare_case("register_client", _relay_name, _module, _timeout_ms), do: :ok

  defp prepare_case("save_module", relay_name, _module, timeout_ms) do
    Giocci.register_client(relay_name, timeout: timeout_ms)
  end

  defp prepare_case("exec_func", relay_name, module, timeout_ms) do
    :ok = Giocci.register_client(relay_name, timeout: timeout_ms)
    :ok = Giocci.save_module(relay_name, module, timeout: timeout_ms)
  end

  defp fetch_option(opts, key, default) do
    case Keyword.fetch(opts, key) do
      {:ok, nil} -> default
      {:ok, value} -> value
      :error -> default
    end
  end

  defp normalize_cases(cases) when is_list(cases) do
    normalized = Enum.map(cases, &to_string/1)
    invalid = Enum.reject(normalized, &(&1 in @default_cases))

    if invalid == [] do
      normalized
    else
      raise "unknown cases: #{Enum.join(invalid, ", ")}"
    end
  end

  defp env_info do
    %{
      elixir_version: System.version(),
      otp_version: System.otp_release(),
      os: os_string(),
      cpu: cpu_arch(),
      cpu_cores: cpu_cores(),
      memory_gb: nil
    }
  end

  defp os_string do
    {family, name} = :os.type()
    "#{family}-#{name}"
  end

  defp cpu_arch do
    :erlang.system_info(:system_architecture)
    |> List.to_string()
  end

  defp cpu_cores do
    case :erlang.system_info(:logical_processors_available) do
      :unknown ->
        case :erlang.system_info(:logical_processors_online) do
          :unknown -> nil
          value -> value
        end

      value ->
        value
    end
  end

  defp default_input_size({_, _, args}) when is_list(args), do: length(args)
  defp default_input_size(_mfargs), do: 0

  defp build_run_id do
    DateTime.utc_now()
    |> DateTime.to_unix(:millisecond)
    |> Integer.to_string()
  end

  defp default_relay do
    System.get_env("GIOCCI_RELAY", "giocci_relay")
  end
end
