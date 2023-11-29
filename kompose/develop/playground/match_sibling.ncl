{
  foo | not_exported = [| 'a |],
  bar =
    foo
    |> match {
      'a => "aaaa",
      _ => "*",
    }
}
