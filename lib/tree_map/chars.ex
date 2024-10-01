defimpl String.Chars, for: TreeMap do
  @empty nil

  def to_string(%TreeMap{root: root}),
    do: ["#TreeMap<", tree_to_iodata(root), ">"] |> IO.iodata_to_binary()

  defp tree_to_iodata(@empty), do: []

  defp tree_to_iodata({left, key, value, _, right}),
    do: [tree_to_iodata(left), Kernel.to_string(key), " => ", Kernel.to_string(value), ";", tree_to_iodata(right)]
end
