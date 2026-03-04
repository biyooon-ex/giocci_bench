defmodule GiocciBench.Samples.MemoryEeater do
  @behaviour GiocciBench.Samples.BenchmarkBehaviour

  @spec run(list()) :: {:ok, float()}
  @impl true
  def run([]) do
    start_time = System.monotonic_time()
    result = alloc_memory(1000, 10)
    end_time = System.monotonic_time()

    elapsed_ms =
      (end_time - start_time)
      |> System.convert_time_unit(:native, :microsecond)
      |> Kernel./(1000)
      |> Float.round(3)

    {result, elapsed_ms}
  end

  @mib 1024 * 1024

  def alloc_memory(mib \\ 100, chunk_mib \\ 1)
      when is_integer(mib) and mib > 0 and is_integer(chunk_mib) and chunk_mib > 0 do
    target_bytes = mib * @mib
    chunk_bytes = chunk_mib * @mib
    n = div(target_bytes, chunk_bytes)

    _chunks =
      Enum.reduce(1..n, [], fn _i, acc ->
        {_time_us, chunk} = :timer.tc(fn -> :binary.copy(<<0>>, chunk_bytes) end)
        acc = [chunk | acc]
        acc
      end)

    :ok
  end
end
