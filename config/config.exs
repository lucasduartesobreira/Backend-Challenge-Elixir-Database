# config/config.exs
if Mix.env() == :dev do
  Config.config(:mix_test_watch,
    tasks: [
      "test",
      "escript.build"
    ]
  )
end
