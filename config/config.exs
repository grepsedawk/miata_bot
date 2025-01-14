# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :nostrum,
  token: System.get_env("DISCORD_TOKEN") || "${DISCORD_TOKEN}",
  num_shards: :auto

config :miata_bot, ecto_repos: [MiataBot.Repo]

config :miata_bot, MiataBot.Repo,
  ssl: false,
  url: System.get_env("DATABASE_URL"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "2")

config :miata_bot, MiataBot.Web.Endpoint, url: System.get_env("APP_URL")

config :logger, backends: [:console, RingLogger]

# config :logger,
#   handle_otp_reports: true,
#   handle_sasl_reports: true

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# third-party users, it should be done in your "mix.exs" file.

# You can configure your application as:
#
#     config :miata_bot, key: :value
#
# and access this configuration in your application as:
#
#     Application.get_env(:miata_bot, :key)
#
# You can also configure a third-party app:
#
#     config :logger, level: :info
#

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
#     import_config "#{Mix.env()}.exs"
