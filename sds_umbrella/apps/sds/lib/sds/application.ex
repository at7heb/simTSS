defmodule Sds.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      Sds.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: Sds.PubSub},
      # Start Finch
      {Finch, name: Sds.Finch}
      # Start a worker by calling: Sds.Worker.start_link(arg)
      # {Sds.Worker, arg}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Sds.Supervisor)
  end
end
