defmodule Mix.Tasks.GiocciBench.LocalTest do
  use ExUnit.Case, async: false

  alias Mix.Tasks.GiocciBench.Local, as: LocalTask

  setup do
    original = Application.get_env(:giocci_bench, :local_module)
    Mix.shell(Mix.Shell.Process)
    Mix.Task.clear()

    on_exit(fn ->
      Mix.shell(Mix.Shell.IO)
      Mix.Task.clear()

      if is_nil(original) do
        Application.delete_env(:giocci_bench, :local_module)
      else
        Application.put_env(:giocci_bench, :local_module, original)
      end
    end)

    :ok
  end

  @tag :tmp_dir
  test "generates report when --visualize is provided", %{tmp_dir: tmp_dir} do
    session_dir = Path.join(tmp_dir, "session_20260406-140000")
    File.mkdir_p!(session_dir)

    File.write!(
      Path.join(session_dir, "local_exec.csv"),
      "run_id,case_id,iteration,elapsed_ms\n1,local_exec,1,10.0\n"
    )

    stub_module =
      Module.concat(__MODULE__, "LocalStubWithDir#{System.unique_integer([:positive])}")

    Module.create(
      stub_module,
      quote do
        def run(_opts) do
          {:ok, unquote(session_dir)}
        end
      end,
      __ENV__
    )

    Application.put_env(:giocci_bench, :local_module, stub_module)

    LocalTask.run(["--visualize"])

    report_path = Path.join(session_dir, "report.html")
    assert File.exists?(report_path)
  end

  @tag :tmp_dir
  test "does not generate report when --visualize is not provided", %{tmp_dir: tmp_dir} do
    session_dir = Path.join(tmp_dir, "session_20260406-140001")
    File.mkdir_p!(session_dir)

    stub_module =
      Module.concat(__MODULE__, "LocalStubNoViz#{System.unique_integer([:positive])}")

    Module.create(
      stub_module,
      quote do
        def run(_opts) do
          {:ok, unquote(session_dir)}
        end
      end,
      __ENV__
    )

    Application.put_env(:giocci_bench, :local_module, stub_module)

    LocalTask.run([])

    report_path = Path.join(session_dir, "report.html")
    refute File.exists?(report_path)
  end

  @tag :tmp_dir
  test "passes session_dir explicitly to visualize when --visualize and --out-dir are provided",
       %{tmp_dir: tmp_dir} do
    out_dir = Path.join(tmp_dir, "bench_out")
    session_dir = Path.join(tmp_dir, "session_20260406-140002")
    File.mkdir_p!(session_dir)

    File.write!(
      Path.join(session_dir, "local_exec.csv"),
      "run_id,case_id,iteration,elapsed_ms\n1,local_exec,1,10.0\n"
    )

    stub_module =
      Module.concat(__MODULE__, "LocalStubWithOutDir#{System.unique_integer([:positive])}")

    Module.create(
      stub_module,
      quote do
        def run(_opts) do
          {:ok, unquote(session_dir)}
        end
      end,
      __ENV__
    )

    Application.put_env(:giocci_bench, :local_module, stub_module)

    LocalTask.run(["--visualize", "--out-dir", out_dir])

    report_path = Path.join(session_dir, "report.html")
    assert File.exists?(report_path)
  end
end
