defmodule Sds.Repo do
  use Ecto.Repo,
    otp_app: :sds,
    adapter: Ecto.Adapters.Postgres
end
