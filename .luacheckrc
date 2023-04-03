ignore = {
  "631", -- max_line_length
}
read_globals = {
  vim = {
    other_fields = true,
    fields = {
      bo = {
        read_only = false,
        other_fields = true,
      },
    },
  },
  "describe",
  "it",
  "assert",
}
