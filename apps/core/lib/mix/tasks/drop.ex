defmodule Mix.Tasks.Drop do
  @moduledoc false

  use Mix.Task
  alias Core.Mongo
  require Logger

  def run(_) do
    {:ok, _} = Application.ensure_all_started(:mongodb)

    {:ok, pid} = Mongo.start_link(name: :mongo, url: Confex.fetch_env!(:core, :mongo)[:url])

    Mongo.command!(dropDatabase: 1)
    Logger.info(IO.ANSI.green() <> "Database dropped" <> IO.ANSI.default_color())

    GenServer.stop(pid)
  end
end
