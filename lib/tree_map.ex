defmodule TreeMap do
  @moduledoc """
  TreeMap is a Set implemented using balanced binary trees - path length trees specifically.
  It implements the following protocols: Enumerable, Collectable and String.Chars.
  Conssequently you have access to every function in the Enum module.

  TODO implement range functions that leverage the ordered tree structure
  e.g. range(TreeMap, from, to) - iterate over elements of TreeMap from <= element <= to
  within?
  """

  @empty nil

  @doc """
  TreeMap struct

  ## Examples
      iex> %TreeMap{}
      %TreeMap{size: 0, root: nil}
  """
  defstruct size: 0, root: @empty, less: &Kernel.</2


  @left 0
  @key 1
  @value 2
  @size 3
  @right 4

  @type size :: non_neg_integer()
  @type node(key, value) :: {tree(key, value), key, value, size(), tree(key, value)}
  @type tree(key, value) :: node(key, value) | nil
  @type compare(key) :: (key, key -> boolean())
  @type resolve(key, value) :: (key, value, value -> value)
  @type t(key, value) :: %__MODULE__{size: non_neg_integer(), root: tree(key, value), less: compare(key)}

  @spec wrap(tree(key, value), compare(key)) :: t(key, value) when key: var, value: var
  def wrap(branch, less \\ &Kernel.</2), do: %TreeMap{size: size(branch), root: branch, less: less}
  @doc """
  Size of set

  ## Examples
      iex> TreeMap.size(TreeMap.new(Enum.zip(1..3, 4..6)).root)
      3
      iex> TreeMap.size(TreeMap.new().root)
      0
  """
  def size(@empty), do: 0
  def size(t), do: elem(t, @size)

  @doc """
  Left branch

  ## Examples
      iex> TreeMap.left(nil)
      nil
      iex> TreeMap.left({nil, 1, 1, nil})
      nil
      iex> TreeMap.left({{nil, 1, 1, nil}, 2, 3, {nil, 3, 1, nil}})
      {nil, 1, 1, nil}
  """
   def left(nil), do: @empty
   def left(t), do: elem(t, @left)

  def key(t), do: elem(t, @key)
  def value(t), do: elem(t, @value)
  def item(t), do: {key(t), value(t)}

  @doc """
  Right branch

  ## Examples
      iex> TreeMap.right(nil)
      nil
      iex> TreeMap.right({nil, 1, :a, 1, nil})
      nil
      iex> TreeMap.right({{nil, 1, :a, 1, nil}, 2, :b, 3, {nil, 3, :c, 1, nil}})
      {nil, 3, :c, 1, nil}
  """
  def right(@empty), do: @empty
  def right(t), do: elem(t, @right)

  @spec new() :: t(term(), term())
  def new(), do: wrap(@empty)


  @spec new(Enumerable.t({key, value}), compare(key)) :: t(key, value) when key: var, value: var
  def new(enumerable, less \\ &Kernel.</2), do: build(enumerable, less)

  @spec branch(tree(key, value), key, value, tree(key, value)) :: node(key, value) when key: var, value: var
  def branch(left, key, value, right), do: {left, key, value, 1 + size(left) + size(right), right}

  @spec leaf(key, value) :: node(key, value) when key: var, value: var
  def leaf(key, value), do: branch(@empty, key, value, @empty)
  @spec fix_size(node(key, value)) :: node(key, value) when key: var, value: var
  defp fix_size(t), do: put_elem(t, @size, 1 + size(left(t)) + size(right(t)))
  defp put_left(t, left), do: t |> put_elem(@left, left) |> fix_size()
  defp put_right(t, right), do: t |> put_elem(@right, right) |> fix_size()
  defp put_value(t, value), do: t |> put_elem(@value, value)

  @doc """
  Inserts item into a TreeMap

  ## Examples
      iex> TreeMap.new() |> TreeMap.put(1, :a) |> to_string()
      "#TreeMap<1 => a;>"

      iex> TreeMap.new() |> TreeMap.put(2, :b) |> TreeMap.put(1, :a) |> TreeMap.put(3, :c) |> to_string()
      "#TreeMap<1 => a;2 => b;3 => c;>"

      iex> 1..7 |> Enum.zip(~w(a b c d e f g)a) |> Enum.reduce(TreeMap.new(), fn {k, v}, t -> TreeMap.put(t, k, v) end) |> to_string()
      "#TreeMap<1 => a;2 => b;3 => c;4 => d;5 => e;6 => f;7 => g;>"

      iex> TreeMap.new() |> TreeMap.put(1,:a) |> TreeMap.put(1,:b) |> to_string()
      "#TreeMap<1 => b;>"
  """
  def put(%TreeMap{root: root, less: less}, key, value), do: root |> put_rec(key, value, less) |> wrap(less)

  @spec put_rec(tree(key, value), key, value, compare(key)) :: tree(key, value) when key: var, value: var
  def put_rec(t, k, v, less) do
    cond do
      is_nil(t) -> leaf(k, v)
      less.(k, key(t)) -> t |> put_left(put_rec(left(t), k, v, less)) |> check_right_rotate()
      less.(key(t), k) -> t |> put_right(put_rec(right(t), k, v, less)) |> check_left_rotate()
      true -> put_value(t, v)
    end
  end

  @doc """
  Implement left and right rotations.
  Also implement conditional versions that only rotate if it improves the path length
       d            b
      / \   right  / \
     b   E  ===>  A   d
    / \     <===     / \
   A   C    left    C   E

   right rotate? size(left(left(t)))   > size(right(t))
    left rotate? size(right(right(t))) > size(left(t))

  ## Examples
      iex> t1 = TreeMap.branch(TreeMap.leaf(1, :a), 2, :b, TreeMap.branch(TreeMap.leaf(3, :c), 4, :d, TreeMap.leaf(5, :e)))
      ...> t2 = TreeMap.branch(TreeMap.branch(TreeMap.leaf(1, :a), 2, :b, TreeMap.leaf(3, :c)), 4, :d, TreeMap.leaf(5, :e))
      ...> TreeMap.left_rotate(t1) == t2
      true
      iex> TreeMap.right_rotate(t2) == t1
      true
  """

  @spec left_rotate(tree(key, value)) :: tree(key, value) when key: var, value: var
  def left_rotate(t) do
    r = right(t)
    branch(branch(left(t), key(t), value(t), left(r)), key(r), value(r), right(r))
  end

  @spec right_rotate(tree(key, value)) :: tree(key, value) when key: var, value: var
  def right_rotate(t) do
    l = left(t)
    branch(left(l), key(l), value(l), branch(right(l), key(t), value(t), right(t)))
  end

  @spec check_left_rotate(tree(key, value)) :: tree(key, value) when key: var, value: var
  def check_left_rotate(t),
    do: if(size(right(right(t))) > size(left(t)), do: left_rotate(t), else: t)

  @spec check_right_rotate(tree(key, value)) :: tree(key, value) when key: var, value: var
  def check_right_rotate(t),
    do: if(size(left(left(t))) > size(right(t)), do: right_rotate(t), else: t)

  @doc """
  Pre-order iteration over a TreeMap

  ## Examples
      iex> iter = 1..7 |> Enum.zip(~w(a b c d e f g)a) |> TreeMap.build(true) |> TreeMap.preorder()
      ...> {item, iter} = iter.()
      ...> item
      {1, :a}
      iex> {item, iter} = iter.()
      ...> item
      {2, :b}
      iex> {item, iter} = iter.()
      ...> item
      {3, :c}
      iex> {item, iter} = iter.()
      ...> item
      {4, :d}
      iex> {item, iter} = iter.()
      ...> item
      {5, :e}
      iex> {item, iter} = iter.()
      ...> item
      {6, :f}
      iex> {item, iter} = iter.()
      ...> item
      {7, :g}
      iex> iter.()
      :done
  """

  @type rank :: non_neg_integer()
  @type iterator(item) :: (-> iterator_result(item))
  @type iterator_result(item) :: :done | {item, iterator(item)}

  @spec preorder(t(key, value)) :: iterator({key, value}) when key: var, value: var
  def preorder(t), do: fn -> preorder_next(t.root, []) end

  @spec preorder_next(tree(key, value), [t(key, value)]) :: :done | {{key, value}, iterator({key, value})} when key: var, value: var
  def preorder_next(@empty, []), do: :done

  def preorder_next(@empty, [t | stack]),
    do: {item(t), fn -> preorder_next(right(t), stack) end}

  def preorder_next(t, stack),
    do: preorder_next(left(t), [t | stack])

  @doc """
  Post order iteration over a TreeMap

  ## Examples
      iex> iter = 1..7 |> Enum.zip(~w(a b c d e f g)a) |> TreeMap.build(true) |> TreeMap.postorder
      ...> {item, iter} = iter.()
      ...> item
      {7, :g}
      iex> {item, iter} = iter.()
      ...> item
      {6, :f}
      iex> {item, iter} = iter.()
      ...> item
      {5, :e}
      iex> {item, iter} = iter.()
      ...> item
      {4, :d}
      iex> {item, iter} = iter.()
      ...> item
      {3, :c}
      iex> {item, iter} = iter.()
      ...> item
      {2, :b}
      iex> {item, iter} = iter.()
      ...> item
      {1, :a}
      iex> iter.()
      :done
  """
 @spec postorder(t(key, value)) :: iterator({key, value}) when key: var, value: var
  def postorder(%TreeMap{root: root}), do: fn -> postorder_next(root, []) end

  @spec postorder_next(tree(key, value), [t(key, value)]) :: iterator_result({key, value}) when key: var, value: var
  def postorder_next(@empty, []), do: :done

  def postorder_next(@empty, [t | stack]),
    do: {item(t), fn -> postorder_next(left(t), stack) end}

  def postorder_next(t, stack),
    do: postorder_next(right(t), [t | stack])

  @doc """
  Depth first iteration over a TreeMap

  ## Examples
      iex> iter = TreeMap.build(Enum.zip(1..7, ~w(a b c d e f g)a), true) |> TreeMap.depth_first()
      ...> {item, iter} = iter.()
      ...> item
      {4, :d}
      iex> {item, iter} = iter.()
      ...> item
      {2, :b}
      iex> {item, iter} = iter.()
      ...> item
      {6, :f}
      iex> {item, iter} = iter.()
      ...> item
      {1, :a}
      iex> {item, iter} = iter.()
      ...> item
      {3, :c}
      iex> {item, iter} = iter.()
      ...> item
      {5, :e}
      iex> {item, iter} = iter.()
      ...> item
      {7, :g}
      iex> iter.()
      :done
  """
  @spec depth_first(t(key, value)) :: iterator({key, value}) when key: var, value: var
  def depth_first(%TreeMap{root: root}), do: fn -> depth_first_next({[root], []}) end

  @spec depth_first_next({[tree(key,value)], [tree(key, value)]}) :: iterator_result({key, value}) when key: var, value: var
  def depth_first_next({[], []}), do: :done
  def depth_first_next({[], back}), do: depth_first_next({Enum.reverse(back), []})

  def depth_first_next({[t | front], back}),
    do: {item(t), fn -> depth_first_next({front, back |> add_back(left(t)) |> add_back(right(t))}) end}

  def add_back(queue, @empty), do: queue
  def add_back(queue, tree), do: [tree | queue]

  @doc """
  Deletes item from a TreeMap

  ## Examples
      iex> t = TreeMap.new([{1, :a}, {2, :b}, {3, :c}])
      ...> t |> to_string()
      "#TreeMap<1 => a;2 => b;3 => c;>"
      iex> t = t |> TreeMap.delete(3)
      ...> t |> to_string
      "#TreeMap<1 => a;2 => b;>"
      iex> t = t |> TreeMap.delete(1)
      ...> t |> to_string
      "#TreeMap<2 => b;>"

      iex> TreeMap.new |> TreeMap.delete(2) |> to_string()
      "#TreeMap<>"

      iex> TreeMap.delete_rec(nil, 1, &Kernel.</2)
      nil

      iex> TreeMap.branch(TreeMap.leaf(1, :a), 2, :b, TreeMap.leaf(3, :c)) |> TreeMap.delete_rec(1, &Kernel.</2)
      {nil, 2, :b, 2, {nil, 3, :c, 1, nil}}

      iex> TreeMap.branch(TreeMap.leaf(1, :a), 2, :b, TreeMap.leaf(3, :c)) |> TreeMap.delete_rec(3, &Kernel.</2)
      {{nil, 1, :a, 1, nil}, 2, :b, 2, nil}

      iex> t = TreeMap.new(Enum.zip(1..7, 1..7))
      iex> [3,4,5,2,6,7] |> Enum.reduce(t.root, fn k, t -> TreeMap.delete_rec(t, k, &Kernel.</2) end) |> TreeMap.wrap() |> to_string()
      "#TreeMap<1 => 1;>"

      iex> t = TreeMap.new(Enum.zip(1..7, 1..7))
      iex> [5,4,3,6,2,1] |> Enum.reduce(t.root, fn k, t -> TreeMap.delete_rec(t, k, &Kernel.</2) end) |> TreeMap.wrap() |> to_string()
      "#TreeMap<7 => 7;>"
  """

  @spec delete(t(key, value), key) :: t(key, value) when key: var, value: var
  def delete(%TreeMap{root: root, less: less}, key), do: root |> delete_rec(key, less) |> wrap()

  @spec delete_rec(tree(key, value), key, compare(key)) :: tree(key, value) when key: var, value: var
  def delete_rec(t, k, less) do
    cond do
      is_nil(t) -> t
      less.(k, key(t)) -> t |> put_left(delete_rec(left(t), k, less)) |> check_left_rotate()
      less.(key(t), k) -> t |> put_right(delete_rec(right(t), k, less)) |> check_right_rotate()
      is_nil(left(t)) -> right(t)
      is_nil(right(t)) -> left(t)
      size(left(t)) > size(right(t)) ->
        {k_max, v_max} = max(left(t))
        branch(delete_rec(left(t), k_max, less), k_max, v_max, right(t))
      true ->
        {k_min, v_min} = min(right(t))
        branch(left(t), k_min, v_min, delete_rec(right(t), k_min, less))
    end
  end

  @doc """
  Find the min

  ## Examples
      iex> TreeMap.min(TreeMap.branch(TreeMap.leaf(1, :a), 2, :b, TreeMap.leaf(3, :c)))
      {1, :a}
      iex> TreeMap.min(nil)
      nil
  """
  def min({@empty, k, v, _, _}), do: {k, v}
  def min({left, _, _, _, _}), do: min(left)
  def min(nil), do: nil

  @doc """
  Find the max

  ## Examples
      iex> TreeMap.max(TreeMap.branch(TreeMap.leaf(1, :a), 2, :b, TreeMap.leaf(3, :c)))
      {3, :c}
      iex> TreeMap.max(nil)
      nil
  """
  def max({_, k, v, _, @empty}), do: {k, v}
  def max({_, _, _, _, right}), do: max(right)
  def max(nil), do: nil
  @doc """
  Drop keys from a MapTree

  ## Examples
      iex> 1..7 |> Enum.zip(1..7) |> TreeMap.new() |> TreeMap.drop(1..4) |> to_string
      "#TreeMap<5 => 5;6 => 6;7 => 7;>"
  """
  def drop(tm, keys), do: keys |> Enum.reduce(tm.root, fn key, t -> delete_rec(t, key, tm.less) end) |> wrap(tm.less)

  @doc """
  Generate the difference of two sets

  ## Examples
      iex> TreeMap.difference(TreeMap.new(Enum.zip(1..7, 11..17)), TreeMap.new(Enum.zip(1..7, 11..17))) |> to_string
      "#TreeMap<>"
      iex> TreeMap.difference(TreeMap.new(Enum.zip(1..7, 11..17)), TreeMap.new(Enum.zip(8..14, 8..14))) |> to_string
      "#TreeMap<1 => 11;2 => 12;3 => 13;4 => 14;5 => 15;6 => 16;7 => 17;>"
      iex> TreeMap.difference(TreeMap.new(Enum.zip(8..14, 8..14)), TreeMap.new(Enum.zip(1..7, 11..17))) |> to_string
      "#TreeMap<8 => 8;9 => 9;10 => 10;11 => 11;12 => 12;13 => 13;14 => 14;>"
      iex> TreeMap.difference(TreeMap.new(Enum.zip(1..7, 11..17)), TreeMap.new(Enum.zip(1..8, 11..18))) |> to_string
      "#TreeMap<>"
  """
  @spec difference(t(key, value), t(key, value)) :: t(key, value) when key: var, value: var
  def difference(tree1, tree2), do: check(tree1, tree2, fn -> difference_rec(postorder(tree1).(), postorder(tree2).(), [], tree1.less) end)

  def difference_rec(:done, _, items, less), do: build(items, less, true)
  def difference_rec(a, :done, items, less), do: finish(a, items, less)

  def difference_rec({{a_k, _} = a_item, a_iter} = a, {{b_k, _}, b_iter} = b, items, less) do
    cond do
      less.(b_k, a_k) -> difference_rec(a_iter.(), b, [a_item | items], less)
      less.(a_k, b_k) -> difference_rec(a, b_iter.(), items, less)
      true -> difference_rec(a_iter.(), b_iter.(), items, less)
    end
  end

  @doc """
  Tests two sets have the same members

  ## Examples
      iex> TreeMap.equal?(TreeMap.new([{1, :a}]), TreeMap.new([{1, :a}]))
      true
      iex> TreeMap.equal?(TreeMap.new([]), TreeMap.new([{1, :a}]))
      false
      iex> TreeMap.equal?(TreeMap.new([{1, :a}]), TreeMap.new([]))
      false
      iex> TreeMap.equal?(TreeMap.new([{1, :a}]), TreeMap.new([{2, :b}]))
      false
      iex> TreeMap.equal?(TreeMap.new(Enum.zip(1..7, 11..17)), TreeMap.new(Enum.zip(1..7, 11..17)))
      true
      iex> TreeMap.equal?(TreeMap.new([{1, :a}], fn x, y -> 2*x < 2*y end), TreeMap.new([{1, :a}], fn x, y -> 3*x < 3*y end))
      false
  """
  @spec equal?(t(key, value), t(key, value)) :: boolean() when key: var, value: var
  def equal?(%TreeMap{} = tree1, %TreeMap{} = tree2) do
    tree1.less === tree2.less and equal_rec(preorder(tree1).(), preorder(tree2).(), tree1.less)
  end

  @spec equal_rec(iterator_result({key, value}), iterator_result({key, value}), compare(key)) :: boolean() when key: var, value: var
  def equal_rec(:done, :done, _), do: true
  def equal_rec(:done, _, _), do: false
  def equal_rec(_, :done, _), do: false
  def equal_rec({{a_k, a_v}, a_iter}, {{b_k, b_v}, b_iter}, less) do
    !less.(a_k, b_k) and !less.(b_k, a_k) and a_v == b_v and equal_rec(a_iter.(), b_iter.(), less)
  end

  @doc """
  Generate the intersect of two sets

  ## Examples
      iex> TreeMap.intersect(TreeMap.new([{1, :a}]), TreeMap.new([{1, :a}])) |> to_string
      "#TreeMap<1 => a;>"
      iex> TreeMap.intersect(TreeMap.new([{1, :a}]), TreeMap.new([{2, :b}])) |> to_string
      "#TreeMap<>"
      iex> TreeMap.intersect(TreeMap.new([{2, :b}]), TreeMap.new([{1, :a}])) |> to_string
      "#TreeMap<>"
      iex> TreeMap.intersect(TreeMap.new(Enum.zip(1..5, 1..5)), TreeMap.new(Enum.zip(3..8, 3..8))) |> to_string
      "#TreeMap<3 => 3;4 => 4;5 => 5;>"
  """
 @spec intersect(t(key, value), t(key, value), resolve(key, value)) :: t(key, value) when key: var, value: var
 def intersect(tree1, tree2, resolve \\ fn _, _, v2 -> v2 end) do
    check(tree1, tree2, fn -> intersect_rec(postorder(tree1).(), postorder(tree2).(), [], tree1.less, resolve) end)
  end

  def check(tree1, tree2, f) do
    if tree1.less == tree2.less do
      f.()
    else
      raise ArgumentError, message: "TreeMaps created with different less function"
    end
  end

  @spec intersect_rec(iterator_result({key, value}), iterator_result({key, value}), [{key, value}], compare(key), resolve(key, value)) :: t(key, value) when key: var, value: var
  def intersect_rec(:done, _, items, less, _), do: build(items, less, true)
  def intersect_rec(_, :done, items, less, _), do: build(items, less, true)
  def intersect_rec({{a_k, a_v}, a_iter} = a, {{b_k, b_v}, b_iter} = b, items, less, f) do
    cond do
      less.(b_k, a_k) -> intersect_rec(a_iter.(), b, items, less, f)
      less.(a_k, b_k) -> intersect_rec(a, b_iter.(), items, less, f)
      true -> intersect_rec(a_iter.(), b_iter.(), [{a_k, f.(a_k, a_v, b_v)} | items], less, f)
    end
  end

  @doc """
  Tests all the members of the first set is contained in the second set

  ## Examples
      iex> TreeMap.subset?(TreeMap.new([{1, :a}]), TreeMap.new([{1, :a}]))
      true
      iex> TreeMap.subset?(TreeMap.new([{1, :a}]), TreeMap.new([{2, :b}]))
      false
      iex> TreeMap.subset?(TreeMap.new([{2, :b}]), TreeMap.new([{1, :a}]))
      false
      iex> TreeMap.subset?(TreeMap.new([]), TreeMap.new([{1, :a}]))
      true
      iex> TreeMap.subset?(TreeMap.new([{1, :a}]), TreeMap.new([]))
      false
  """
  @spec subset?(t(key, value), t(key, value)) :: boolean() when key: var, value: var
  def subset?(tree1, tree2), do: check(tree1, tree2, fn -> subset_rec(preorder(tree1).(), preorder(tree2).(), tree1.less) end)

  @spec subset_rec(iterator_result({key, value}), iterator_result({key, value}), compare(key)) :: boolean() when key: var, value: var
  def subset_rec(:done, _, _), do: true
  def subset_rec(_, :done, _), do: false
  def subset_rec({{a_k, a_v}, a_iter} = a, {{b_k, b_v}, b_iter}, less) do
    cond do
    less.(a_k, b_k) -> false
    less.(b_k, a_k) -> subset_rec(a, b_iter.(), less)
    true -> a_v == b_v and subset_rec(a_iter.(), b_iter.(), less)
    end
  end

  @doc """
  Generate the union of two sets

  ## Examples
      iex> TreeMap.union(TreeMap.new([{1, :a},{2, :b}]), TreeMap.new([{3, :c}])) |> to_string
      "#TreeMap<1 => a;2 => b;3 => c;>"
      iex> TreeMap.union(TreeMap.new([{3, :c}]), TreeMap.new([{1, :a},{2, :b}])) |> to_string
      "#TreeMap<1 => a;2 => b;3 => c;>"
      iex> TreeMap.union(TreeMap.new([{2, :b},{3, :c}]), TreeMap.new([{1, :a},{2, :b}])) |> to_string
      "#TreeMap<1 => a;2 => b;3 => c;>"
      iex> TreeMap.union(TreeMap.new([{1, :a},{2, :b}]), TreeMap.new([{2, :b},{3, :c}])) |> to_string
      "#TreeMap<1 => a;2 => b;3 => c;>"
  """
  def union(tree1, tree2, resolve \\ fn _k, _v1, v2 -> v2 end), do: check(tree1, tree2, fn -> union_rec(postorder(tree1).(), postorder(tree2).(), [], resolve, tree1.less) end)

  def union_rec(:done, b, items, _f, less), do: finish(b, items, less)
  def union_rec(a, :done, items, _f, less), do: finish(a, items, less)
  def union_rec({{a_k, a_v} = a_item, a_iter} = a, {{b_k, b_v} = b_item, b_iter} = b, items, resolve, less) do
    cond do
      less.(b_k, a_k) -> union_rec(a_iter.(), b, [a_item | items], resolve, less)
      less.(a_k, b_k) -> union_rec(a, b_iter.(), [b_item | items], resolve, less)
      true -> union_rec(a_iter.(), b_iter.(), [{a_k, resolve.(a_k, a_v, b_v)} | items], resolve, less)
    end
  end

  @spec finish(iterator_result({key, value}), [{key, value}], compare(key)) :: t(key, value) when key: var, value: var
  def finish(:done, items, less), do: build(items, less, true)
  def finish({item, iter}, items, less), do: finish(iter.(), [item | items], less)


  @doc """
  Check for empty node

  ## Examples
      iex> TreeMap.empty?(TreeMap.new)
      true
      iex> TreeMap.empty?(TreeMap.new([{1, :b}]))
      false
  """
  def empty?(%TreeMap{root: root}), do: root == @empty

  @doc """
  Get the value for a key

  ## Examples
      iex> TreeMap.get(TreeMap.new([{2, :b}]), 1, :a)
      :a
      iex> TreeMap.get(TreeMap.new([{2, :b}]), 1)
      nil
      iex> TreeMap.get(TreeMap.new([{2, :b}]), 2)
      :b
      iex> TreeMap.get(TreeMap.new(), 1)
      nil
  """

  def member?(t, {k, v}), do: fetch(t, k) == {:ok, v}
  def member?(_, _), do: false

  def get(t, k, default \\ nil) do
    case fetch(t, k) do
      :error -> default
      {:ok, value} -> value
    end
  end

    @doc """
  Tests membership

  ## Examples
      iex> TreeMap.member?(TreeMap.new([{2, :b}]), {1, :b})
      false
      iex> TreeMap.member?(TreeMap.new(), 1)
      false
      iex> TreeMap.member?(TreeMap.new([{2, :b}]), {2, :b})
      true
  """

  def fetch(t, k), do: fetch_rec?(t.root, k, t.less)

  def fetch_rec?(t, k, less) do
    cond do
      is_nil(t) -> :error
      less.(k, key(t)) -> fetch_rec?(left(t), k, less)
      less.(key(t), k) -> fetch_rec?(right(t), k, less)
      true -> {:ok, value(t)}
    end
  end


  @doc """
  Fetch a key you expect to be there

  ## Examples
      iex> TreeMap.fetch!(TreeMap.new([{2, :b}]), 2)
      :b
      iex> TreeMap.fetch!(TreeMap.new([{2, :b}]), 1)
      ** (KeyError) key 1 not found
  """
  def fetch!(t, k) do
    case fetch(t,k) do
    :error -> raise KeyError, key: k
    {:ok, value} -> value
    end
  end
  @doc """
  Builds a TreeMap from a collection item

  ## Examples
      iex> TreeMap.build([]) |> to_string
      "#TreeMap<>"

      iex> TreeMap.build([{2, :b}, {1, :a}, {3, :c}]) |> to_string
      "#TreeMap<1 => a;2 => b;3 => c;>"
  """
  def build(items, less \\ &Kernel.</2, sorted \\ false) do
    if(sorted, do: items, else: Enum.sort(items))
    |> build_rec
    |> wrap(less)
  end

  @spec build_rec([{key, value}]) :: tree(key, value) when key: var, value: var
  def build_rec(items), do: build_rec(items, Enum.count(items))

  @spec build_rec([{key, value}], non_neg_integer()) :: tree(key, value) when key: var, value: var
  def build_rec(_, 0), do: @empty
  def build_rec(items, n) do
    left_n = div(n - 1, 2)
    right_n = n - 1 - left_n
    [{k, v} | right] = Enum.drop(items, left_n)
    {build_rec(items, left_n), k, v, n, build_rec(right, right_n)}
  end

  @doc """
  Converts a MapTree to a sorted list of pairs

  ## Examples

      iex> 1..7 |> Enum.zip(1..7) |> TreeMap.new() |> TreeMap.to_list() |> Enum.unzip()
      {[1, 2, 3, 4, 5, 6, 7], [1, 2, 3, 4, 5, 6, 7]}
  """
  def to_list(t), do: to_list_rec(postorder(t).(), [])

  def to_list_rec(:done, acc), do: acc
  def to_list_rec({item, iter}, acc), do: to_list_rec(iter.(), [item | acc])

  @doc """
  Returns a TreeMap containing only those pairs from `map`
  for which `fun` returns a truthy value.

  `fun` receives the key and value of each of the
  elements in the map as a key-value pair.

  See also `reject/2` which discards all elements where the
  function returns a truthy value.

  > #### Performance considerations {: .tip}
  >
  > If you find yourself doing multiple calls to `Map.filter/2`
  > and `Map.reject/2` in a pipeline, it is likely more efficient
  > to use `Enum.map/2` and `Enum.filter/2` instead and convert to
  > a map at the end using `Map.new/1`.

  ## Examples

      iex> [{:one, 1}, {:two, 2}, {:three, 3}] |> TreeMap.new() |> TreeMap.filter(fn {_key, val} -> rem(val, 2) == 1 end) |> to_string()
      "#TreeMap<one => 1;three => 3;>"

  """
  def filter(%TreeMap{} = t, fun), do: t |> to_list() |> Enum.filter(fun) |> build(t.less, true)

  @doc """
  Builds a map from the given `keys` and the fixed `value`.

  ## Examples

      iex> TreeMap.from_keys([1, 2, 3], :number) |> to_string()
      "#TreeMap<1 => number;2 => number;3 => number;>"

  """
  def from_keys(keys, value, less \\ &Kernel.</2), do: keys |> Enum.map(&{&1, value}) |> build(less, false)

  @doc """
  Gets the value from `key` and updates it, all in one pass.

  `fun` is called with the current value under `key` in `map` (or `nil` if `key`
  is not present in `map`) and must return a two-element tuple: the current value
  (the retrieved value, which can be operated on before being returned) and the
  new value to be stored under `key` in the resulting new map. `fun` may also
  return `:pop`, which means the current value shall be removed from `map` and
  returned (making this function behave like `Map.pop(map, key)`).

  The returned value is a two-element tuple with the current value returned by
  `fun` and a new map with the updated value under `key`.

  ## Examples

      iex> TreeMap.get_and_update(TreeMap.new([{:a, 1}]), :a, fn current_value ->
      ...>   {current_value, "new value!"}
      ...> end)
      {1, %TreeMap{less: &:erlang.</2, root: {nil, :a, "new value!", 1, nil}, size: 1}}

      iex> TreeMap.get_and_update(TreeMap.new([{:a, 1}]), :b, fn current_value ->
      ...>   {current_value, "new value!"}
      ...> end)
      {nil, %TreeMap{less: &:erlang.</2, root: {nil, :a, 1, 2, {nil, :b, "new value!", 1, nil}}, size: 2}}

      iex> TreeMap.get_and_update(TreeMap.new([{:a, 1}]), :a, fn _ -> :pop end)
      {1, %TreeMap{less: &:erlang.</2, root: nil, size: 0}}

      iex> TreeMap.get_and_update(TreeMap.new([{:a, 1}]), :b, fn _ -> :pop end)
      {nil, %TreeMap{less: &:erlang.</2, root: {nil, :a, 1, 1, nil}, size: 1}}

  """
  def get_and_update(tree, key, fun) when is_function(fun, 1) do
    current = get(tree, key)
    case fun.(current) do
      {get, update} ->
        {get, put(tree, key, update)}

      :pop ->
        {current, delete(tree, key)}

      other ->
        raise "the given function must return a two-element tuple or :pop, got: #{inspect(other)}"
    end
  end

  @doc """
  Gets the value from `key` and updates it, all in one pass. Raises if there is no `key`.

  Behaves exactly like `get_and_update/3`, but raises a `KeyError` exception if
  `key` is not present in `map`.

  ## Examples
      iex> TreeMap.new([{:a, 1}]) |> TreeMap.get_and_update!(:a, fn v -> {v, 2} end) |> elem(0)
      1
      iex> TreeMap.new([{:a, 1}]) |> TreeMap.get_and_update!(:a, fn v -> {v, 2} end) |> elem(1) |> to_string()
      "#TreeMap<a => 2;>"
      iex> TreeMap.new([{:a, 1}]) |> TreeMap.get_and_update!(:b, fn v -> {v, :c} end)
      ** (KeyError) key :b not found
      iex> TreeMap.new([{:a, 1}]) |> TreeMap.get_and_update!(:a, fn _ -> :pop end) |> elem(0)
      1
      iex> TreeMap.new([{:a, 1}]) |> TreeMap.get_and_update!(:a, fn _ -> :pop end) |> elem(1) |> to_string()
      "#TreeMap<>"

      iex> TreeMap.new([{:a, 1}]) |> TreeMap.get_and_update!(:a, fn _ -> :fred end) |> elem(1) |> to_string()
      ** (RuntimeError) the given function must return a two-element tuple or :pop, got: :fred
  """
  def get_and_update!(map, key, fun) when is_function(fun, 1) do
    value = fetch!(map, key)

    case fun.(value) do
      {get, update} ->
        {get, TreeMap.put(map, key, update)}

      :pop ->
        {value, delete(map, key)}

      other ->
        raise "the given function must return a two-element tuple or :pop, got: #{inspect(other)}"
    end
  end

  def get_lazy(tree, key, fun) do
    case fetch(tree, key) do
      {:ok, value} -> value
      _ -> fun.()
    end

  end

  def has_key?(tree, key), do: has_key_rec?(tree.root, key, tree.less)

  def has_key_rec?(t, k, less) do
    cond do
      is_nil(t) -> false
      less.(k, key(t)) -> has_key_rec?(left(t), k, less)
      less.(key(t), k) -> has_key_rec?(right(t), k, less)
      true -> true
    end
  end

  def keys(tree), do: tree |> to_list() |> Enum.unzip() |> elem(0)
  def values(tree), do: tree |> to_list() |> Enum.unzip() |> elem(1)

  def merge(t1, t2, f \\ fn _k, _v1, v2 -> v2 end), do: union(t1, t2, f)

  def pop(tree, key, default \\ nil) do
    case fetch(tree, key) do
      {:ok, value} -> {value, delete(tree, key)}
      :error -> {default, tree}
    end
  end

  def pop!(tree, key) do
    case fetch(tree, key) do
      {:ok, value} -> {value, delete(tree, key)}
      :error -> raise KeyError, key: key, term: tree
    end
  end

  def pop_lazy(tree, key, fun) do
    case fetch(tree, key) do
      {:ok, value} -> {value, delete(tree, key)}
      :error -> {fun.(), tree}
    end
  end

  def put_new(tree, key, value) do
    if has_key?(tree, key) do
      tree
    else
      put(tree, key, value)
    end
  end

  def put_new_lazy(tree, key, fun) do
    if has_key?(tree, key) do
      tree
    else
      put(tree, key, fun.())
    end
  end

  def reject(tree, fun), do: tree |> to_list() |> Enum.reject(fun) |> build(tree.less, true)

  def replace(tree, key, value) do
    if has_key?(tree, key) do
      put(tree, key, value)
    else
      tree
    end
  end

  def replace!(tree, key, value) do
    if has_key?(tree, key) do
      put(tree, key, value)
    else
      raise KeyError, key: key, term: tree
    end
  end

  def replace_lazy(tree, key, fun) do
    case fetch(tree, key) do
      {:ok, value} -> put(tree, key, fun.(value))
      :error -> tree
    end
  end

  def split(tree, keys) do
    Enum.reduce(keys, {tree, new()},
      fn key, {old, new} ->
        case fetch(old, key) do
          {:ok, value} -> {delete(old, key), put(new, key, value)}
          :error -> {old, new}
        end
      end
    )
  end

  def split_with(tree, fun) do
    tree
    |> to_list()
    |> Enum.split_with(fun)
    |> then(fn {as, bs} -> {new(as), new(bs)} end)
  end

  def take(tree, keys) do
    Enum.reduce(keys, new(),
      fn key, new ->
        case fetch(tree, key) do
          {:ok, value} -> put(new, key, value)
          :error -> new
        end
      end
    )
  end

  def update(tree, key, default, fun) do
    case fetch(tree, key) do
      {:ok, value} -> put(tree, key, fun.(value))
      :error -> put(tree, key, default)
    end
  end

  def update!(tree, key, fun) do
    case fetch(tree, key) do
      {:ok, value} -> put(tree, key, fun.(value))
      :error -> raise KeyError, key: key, term: tree
    end
  end

end
