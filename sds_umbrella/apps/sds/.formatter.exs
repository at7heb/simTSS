[
  import_deps: [:ecto, :ecto_sql],
  subdirectories: ["priv/*/migrations"],
  plugins: [],
  inputs: ["*.{heex,ex,exs}", "{config,lib,test}/**/*.{heex,ex,exs}", "priv/*/seeds.exs"]
]
