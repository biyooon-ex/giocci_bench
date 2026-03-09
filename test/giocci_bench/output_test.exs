defmodule GiocciBench.OutputTest do
  use ExUnit.Case

  alias GiocciBench.Output

  @tag :tmp_dir
  test "write_metadata_json! writes valid JSON metadata", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "meta.json")

    metadata = %{
      "run_id" => "20260309-140530",
      "started_at" => "2026-02-17T10:00:00Z",
      "elixir_version" => "1.14.0",
      "otp_version" => "24.0",
      "os" => "Linux",
      "cpu" => "x86_64",
      "cpu_cores" => 4
    }

    Output.write_metadata_json!(path, metadata)

    # ファイルが作成されたことを確認
    assert File.exists?(path)

    # ファイルの内容を読み込む
    content = File.read!(path)

    # JSON をデコード
    decoded = :json.decode(content)

    # デコードが成功して、元のデータと一致することを確認
    assert decoded == metadata
  end

  @tag :tmp_dir
  test "write_metadata_json! creates directory if it doesn't exist", %{tmp_dir: tmp_dir} do
    nested_dir = Path.join([tmp_dir, "nested", "dir"])
    path = Path.join(nested_dir, "meta.json")

    metadata = %{"test" => "value"}

    Output.write_metadata_json!(path, metadata)

    assert File.exists?(path)
    assert File.exists?(nested_dir)
  end

  @tag :tmp_dir
  test "write_metadata_json! handles :null atom as JSON null", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "meta.json")

    metadata = %{
      "string" => "test",
      "null_value" => :null
    }

    Output.write_metadata_json!(path, metadata)

    content = File.read!(path)
    decoded = :json.decode(content)

    # :null atom は JSON null にエンコードされ、デコード後も :null になる
    assert decoded == metadata
  end

  @tag :tmp_dir
  test "write_metadata_json! handles various types", %{tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "meta.json")

    metadata = %{
      "string" => "test",
      "integer" => 42,
      "float" => 3.14,
      "boolean" => true
    }

    Output.write_metadata_json!(path, metadata)

    content = File.read!(path)
    decoded = :json.decode(content)

    assert decoded == metadata
  end
end
