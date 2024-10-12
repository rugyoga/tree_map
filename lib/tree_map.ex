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

  @idx_left 0
  @idx_key 1
  @idx_value 2
  @idx_size 3
  @idx_right 4

  @type size :: non_neg_integer()
  @type node(key, value) :: {tree(key, value), key, value, size(), tree(key, value)}
  @type tree(key, value) :: node(key, value) | nil
  @type compare(key) :: (key, key -> boolean())
  @type resolve(key, value) :: (key, value, value -> value)
  @type t(key, value) :: %__MODULE__{size: non_neg_integer(), root: tree(key, value), less: compare(key)}
  @type rank :: non_neg_integer()
  @type iterator(item) :: (-> iterator_result(item))
  @type iterator_result(item) :: :done | {item, iterator(item)}

  @spec wrap(tree(key, value), compare(key)) :: t(key, value) when key: var, value: var
  def wrap(branch, less \\ &Kernel.</2), do: %TreeMap{size: size(branch), root: branch, less: less}
  @doc """
  Size of set

  ## Examples
      iex> size(new([a: 4, b: 5, c: 6]).root)
      3
      iex> size(new().root)
      0
  """
  @spec size(tree(any(), any)) :: non_neg_integer()
  def size(@empty), do: 0
  def size(t), do: elem(t, @idx_size)

  @doc """
  Left branch

  ## Examples
      iex> left(nil)
      nil
      iex> left({nil, 1, 1, nil})
      nil
      iex> left({{nil, 1, 1, nil}, 2, 3, {nil, 3, 1, nil}})
      {nil, 1, 1, nil}
  """
   @spec left(tree(key, value)) :: tree(key, value) when key: var, value: var
   def left(nil), do: @empty
   def left(t), do: elem(t, @idx_left)

  @spec key(node(key, term())) :: key when key: var
  def key(t), do: elem(t, @idx_key)

  @spec value(node(term(), value)) :: value when value: var
  def value(t), do: elem(t, @idx_value)

  @spec item(node(key, value)) :: {key, value} when key: var, value: var
  def item(t), do: {key(t), value(t)}

  @doc """
  Right branch

  ## Examples
      iex> right(nil)
      nil
      iex> right({nil, 1, :a, 1, nil})
      nil
      iex> right({{nil, 1, :a, 1, nil}, 2, :b, 3, {nil, 3, :c, 1, nil}})
      {nil, 3, :c, 1, nil}
  """
  @spec right(tree(any(), any())) :: tree(any(), any())
  def right(@empty), do: @empty
  def right(t), do: elem(t, @idx_right)

  @spec new() :: t(term(), term())
  def new(), do: wrap(@empty)


  @spec new(Enumerable.t({key, value}), compare(key)) :: t(key, value) when key: var, value: var
  def new(enumerable, less \\ &Kernel.</2), do: build(enumerable, less)

  @spec branch(tree(key, value), key, value, tree(key, value)) :: node(key, value) when key: var, value: var
  def branch(left, key, value, right), do: {left, key, value, 1 + size(left) + size(right), right}

  @spec leaf(key, value) :: node(key, value) when key: var, value: var
  def leaf(key, value), do: branch(@empty, key, value, @empty)

  @spec fix_size(node(key, value)) :: node(key, value) when key: var, value: var
  defp fix_size(t), do: put_elem(t, @idx_size, 1 + size(left(t)) + size(right(t)))

  @spec put_left(node(key, value), node(key, value)) :: node(key, value) when key: var, value: var
  defp put_left(t, left), do: t |> put_elem(@idx_left, left) |> fix_size()

  @spec put_right(node(key, value), node(key, value)) :: node(key, value) when key: var, value: var
  defp put_right(t, right), do: t |> put_elem(@idx_right, right) |> fix_size()

  @spec put_value(node(key, value), value) :: node(key, value) when key: var, value: var
  defp put_value(t, value), do: t |> put_elem(@idx_value, value)

  @doc """
  Inserts item into a TreeMap

  ## Examples
      iex> new() |> put(1, :a) |> to_string()
      "#TreeMap<1 => a;>"

      iex> new() |> put(2, :b) |> put(1, :a) |> put(3, :c) |> to_string()
      "#TreeMap<1 => a;2 => b;3 => c;>"

      iex> 1..7 |> Enum.zip(~w(a b c d e f g)a) |> Enum.reduce(new(), fn {k, v}, t -> put(t, k, v) end) |> to_string()
      "#TreeMap<1 => a;2 => b;3 => c;4 => d;5 => e;6 => f;7 => g;>"

      iex> new() |> put(1,:a) |> put(1,:b) |> to_string()
      "#TreeMap<1 => b;>"
  """
  @spec put(t(key, value), key, value) :: t(key, value) when key: var, value: var
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
      iex> t1 = branch(leaf(1, :a), 2, :b, branch(leaf(3, :c), 4, :d, leaf(5, :e)))
      ...> t2 = branch(branch(leaf(1, :a), 2, :b, leaf(3, :c)), 4, :d, leaf(5, :e))
      ...> left_rotate(t1) == t2
      true
      iex> right_rotate(t2) == t1
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
      iex> iter = 1..7 |> Enum.zip(~w(a b c d e f g)a) |> build(true) |> preorder()
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

  @spec preorder(t(key, value)) :: iterator({key, value}) when key: var, value: var
  def preorder(t), do: fn -> preorder_next(t.root, []) end

  @spec preorder_next(tree(key, value), [t(key, value)]) :: :done | {{key, value}, iterator({key, value})} when key: var, value: var
  def preorder_next(@empty, []), do: :done

  def preorder_next(@empty, [t | stack]),
    do: {item(t), fn -> preorder_next(right(t), stack) end}

  def preorder_next(t, stack),
    do: preorder_next(left(t), [t | stack])

  @doc """
  create a TreeMap iterator starting from at a given key

  ## Examples
      iex> iter = 1..7 |> Enum.zip(~w(a b c d e f g)a) |> build(true) |> from(4)
      iex> iter.()
      :foo
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
  @spec from(t(key, value), key) :: iterator({key, value}) when key: var, value: var
  def from(t, key), do: fn -> from_rec(t.root, [], key, t.less) end

  @spec from_rec(tree(key, value), [{key, value}], key, compare(key)) :: iterator_result({key, value}) when key: var, value: var
  def from_rec(t, stack, key, less) do
    cond do
      t == @empty ->
        case stack do
          [] -> :done
          [x | xs] -> {item(x), fn -> preorder_next(right(x), xs) end}
        end
      less.(key, item(t)) -> from_rec(left(t), [t | stack], key, less)
      less.(item(t), key) -> from_rec(right(t), stack, key, less)
      true -> {item(t), fn -> preorder_next(right(t), stack) end}
    end
  end

  @doc """
  Post order iteration over a TreeMap

  ## Examples
      iex> iter = 1..7 |> Enum.zip(~w(a b c d e f g)a) |> build(true) |> postorder
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
      iex> iter = build(Enum.zip(1..7, ~w(a b c d e f g)a), true) |> depth_first()
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

  @spec depth_first_next({[tree(key, value)], [tree(key, value)]}) :: iterator_result({key, value}) when key: var, value: var
  def depth_first_next({[], []}), do: :done
  def depth_first_next({[], back}), do: depth_first_next({Enum.reverse(back), []})

  def depth_first_next({[t | front], back}),
    do: {item(t), fn -> depth_first_next({front, back |> add_back(left(t)) |> add_back(right(t))}) end}

  @spec add_back([node(key, value)], tree(key, value)) :: [node(key, value)] when key: var, value: var
  def add_back(queue, @empty), do: queue
  def add_back(queue, tree), do: [tree | queue]

  @doc """
  Deletes item from a TreeMap

  ## Examples
      iex> t = new([a: 1, b: 2, c: 3])
      ...> t |> to_string()
      "#TreeMap<a => 1;b => 2;c => 3;>"
      iex> t = t |> delete(:c)
      ...> t |> to_string
      "#TreeMap<a => 1;b => 2;>"
      iex> t = t |> delete(:a)
      ...> t |> to_string
      "#TreeMap<b => 2;>"

      iex> new() |> delete(2) |> to_string()
      "#TreeMap<>"

      iex> delete_rec(nil, 1, &Kernel.</2)
      nil

      iex> branch(leaf(1, :a), 2, :b, leaf(3, :c)) |> delete_rec(1, &Kernel.</2)
      {nil, 2, :b, 2, {nil, 3, :c, 1, nil}}

      iex> branch(leaf(1, :a), 2, :b, leaf(3, :c)) |> delete_rec(3, &Kernel.</2)
      {{nil, 1, :a, 1, nil}, 2, :b, 2, nil}

      iex> t = new(Enum.zip(1..7, 1..7))
      iex> [3,4,5,2,6,7] |> Enum.reduce(t.root, fn k, t -> delete_rec(t, k, &Kernel.</2) end) |> wrap() |> to_string()
      "#TreeMap<1 => 1;>"

      iex> t = new(Enum.zip(1..7, 1..7))
      iex> [5,4,3,6,2,1] |> Enum.reduce(t.root, fn k, t -> delete_rec(t, k, &Kernel.</2) end) |> wrap() |> to_string()
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
      iex> min(branch(leaf(1, :a), 2, :b, leaf(3, :c)))
      {1, :a}
      iex> min(nil)
      nil
  """
  @spec min(tree(key, value)) :: {key, value} when key: var, value: var
  def min({@empty, k, v, _, _}), do: {k, v}
  def min({left, _, _, _, _}), do: min(left)
  def min(nil), do: nil

  @doc """
  Find the max

  ## Examples
      iex> max(branch(leaf(1, :a), 2, :b, leaf(3, :c)))
      {3, :c}
      iex> max(nil)
      nil
  """
  @spec max(tree(key, value)) :: {key, value} when key: var, value: var
  def max({_, k, v, _, @empty}), do: {k, v}
  def max({_, _, _, _, right}), do: max(right)
  def max(nil), do: nil
  @doc """
  Drop keys from a MapTree

  ## Examples
      iex> 1..7 |> Enum.zip(1..7) |> new() |> drop(1..4) |> to_string
      "#TreeMap<5 => 5;6 => 6;7 => 7;>"
  """
  @spec drop(t(key, value), Enumerable.t(key)) :: t(key, value) when key: var, value: var
  def drop(tm, keys), do: keys |> Enum.reduce(tm.root, fn key, t -> delete_rec(t, key, tm.less) end) |> wrap(tm.less)

  @doc """
  Generate the difference of two sets

  ## Examples
      iex> difference(new(Enum.zip(1..7, 11..17)), new(Enum.zip(1..7, 11..17))) |> to_string
      "#TreeMap<>"
      iex> difference(new(Enum.zip(1..7, 11..17)), new(Enum.zip(8..14, 8..14))) |> to_string
      "#TreeMap<1 => 11;2 => 12;3 => 13;4 => 14;5 => 15;6 => 16;7 => 17;>"
      iex> difference(new(Enum.zip(8..14, 8..14)), new(Enum.zip(1..7, 11..17))) |> to_string
      "#TreeMap<8 => 8;9 => 9;10 => 10;11 => 11;12 => 12;13 => 13;14 => 14;>"
      iex> difference(new(Enum.zip(1..7, 11..17)), new(Enum.zip(1..8, 11..18))) |> to_string
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
      iex> a = new([a: 1])
      iex> b = new([a: 1])
      iex> c = new([a: 2])
      iex> d = new([b: 2])
      iex> equal?(a, b)
      true
      iex> equal?(new([]), a)
      false
      iex> equal?(a, new([]))
      false
      iex> equal?(b, c)
      false
      iex> equal?(c, d)
      false
      iex> equal?(d, b)
      false
      iex> equal?(new(Enum.zip(1..7, 11..17)), new(Enum.zip(1..7, 11..17)))
      true
      iex> equal?(new([a: 1], fn x, y -> 2*x < 2*y end), new([a: 1], fn x, y -> 3*x < 3*y end))
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
      iex> a = new([a: 1])
      iex> ab = new([a: 1, b: 1])
      iex> b = new([b: 1])
      iex> intersect(a, ab) |> to_string
      "#TreeMap<a => 1;>"
      iex> intersect(ab, b) |> to_string
      "#TreeMap<b => 1;>"
      iex> intersect(a, b) |> to_string
      "#TreeMap<>"
      iex> intersect(b, a) |> to_string
      "#TreeMap<>"
      iex> intersect(new(Enum.zip(1..5, 1..5)), new(Enum.zip(3..8, 3..8))) |> to_string
      "#TreeMap<3 => 3;4 => 4;5 => 5;>"
  """
 @spec intersect(t(key, value), t(key, value), resolve(key, value)) :: t(key, value) when key: var, value: var
 def intersect(tree1, tree2, resolve \\ fn _, _, v2 -> v2 end) do
    check(tree1, tree2, fn -> intersect_rec(postorder(tree1).(), postorder(tree2).(), [], tree1.less, resolve) end)
 end

  @doc """
  Checks trees have same less function

  ## Examples
      iex> list = [a: 1]
      iex> check(new(list), new(list), fn -> :success end)
      :success
      iex> check(new(list), new(list, fn a, b -> 2*a < 2*b end), fn -> :success end)
      ** (ArgumentError) TreeMaps created with different less function
  """
  @spec check(t(key, value), t(key, value), (-> result)) :: result when key: var, value: var, result: var
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
      iex> a = new([a: 1])
      iex> b = new([b: 2])
      iex> ab = new([a: 1, b: 2])
      iex> subset?(a, a)
      true
      iex> subset?(a, b)
      false
      iex> subset?(b, a)
      false
      iex> subset?(ab, a)
      false
      iex> subset?(a, ab)
      true
      iex> subset?(ab, b)
      false
      iex> subset?(b, ab)
      true
      iex> subset?(new([]), a)
      true
      iex> subset?(a, new([]))
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
      iex> a = new([a: 1])
      iex> ab = new([a: 1, b: 2])
      iex> c = new([c: 3])
      iex> bc = new([b: 2, c: 3])
      iex> union(ab, c) |> to_string
      "#TreeMap<a => 1;b => 2;c => 3;>"
      iex> union(c, ab) |> to_string
      "#TreeMap<a => 1;b => 2;c => 3;>"
      iex> union(bc, ab) |> to_string
      "#TreeMap<a => 1;b => 2;c => 3;>"
      iex> union(a, bc) |> to_string
      "#TreeMap<a => 1;b => 2;c => 3;>"
  """
  @spec union(t(key, value), t(key, value), (key, value, value -> value)) :: t(key, value) when key: var, value: var
  def union(tree1, tree2, resolve \\ fn _k, _v1, v2 -> v2 end), do: check(tree1, tree2, fn -> union_rec(postorder(tree1).(), postorder(tree2).(), [], resolve, tree1.less) end)

  @spec subset_rec(iterator_result({key, value}), iterator_result({key, value}), compare(key)) :: boolean() when key: var, value: var

  @spec union_rec(iterator_result({key, value}), iterator_result({key, value}), [{key, value}], resolve(key, value), compare(key)) :: t(key, value) when key: var, value: var
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
      iex> empty?(new())
      true
      iex> empty?(new([a: 1]))
      false
  """
  @spec empty?(t(term(), term())) :: boolean()
  def empty?(%TreeMap{root: root}), do: root == @empty

  @doc """
  Tests membership

  ## Examples
      iex> map = new([b: 2])
      iex> member?(map, {:b, 1})
      false
      iex> member?(new(), 1)
      false
      iex> member?(map, {:b, 2})
      true
  """
  @spec member?(t(key, value), {key, value}) :: boolean() when key: var, value: var
  def member?(t, {k, v}), do: fetch(t, k) == {:ok, v}
  def member?(_, _), do: false


  @doc """
  Get the value for a key

  ## Examples
      iex> map = new([b: 2])
      iex> get(map, :a, 1)
      1
      iex> get(map, :a)
      nil
      iex> get(new(), 1)
      nil
  """
  @spec get(t(key, value), key, value) :: value when key: var, value: var
  def get(t, k, default \\ nil) do
    case fetch(t, k) do
      :error -> default
      {:ok, value} -> value
    end
  end

  @spec fetch(t(key, value), key) :: {:ok, value} | :error when key: var, value: var
  def fetch(t, k), do: fetch_rec?(t.root, k, t.less)

  @spec fetch_rec?(node(key, value), key, compare(key)) :: {:ok, value} | :error when key: var, value: var
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
      iex> map = new([b: 1])
      iex> fetch!(map, :b)
      1
      iex> fetch!(map, :a)
      ** (KeyError) key :a not found
  """
  @spec fetch!(t(key, value), key) :: value when key: var, value: var
  def fetch!(t, k) do
    case fetch(t, k) do
    :error -> raise KeyError, key: k
    {:ok, value} -> value
    end
  end
  @doc """
  Builds a TreeMap from a collection item

  ## Examples
      iex> build([]) |> to_string
      "#TreeMap<>"

      iex> build([b: 2, a: 1, c: 3]) |> to_string
      "#TreeMap<a => 1;b => 2;c => 3;>"
  """
  @spec build(Enumerable.t({key, value}), compare(key), boolean()) :: t(key, value) when key: var, value: var
  def build(items, less \\ &Kernel.</2, sorted \\ false) do
    if(sorted, do: items, else: Enum.sort(items))
    |> build_rec
    |> wrap(less)
  end

  @spec build_rec(Enumerable.t({key, value})) :: tree(key, value) when key: var, value: var
  def build_rec(items), do: build_rec(items, Enum.count(items))

  @spec build_rec(Enumerable.t({key, value}), non_neg_integer()) :: tree(key, value) when key: var, value: var
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

      iex> 1..7 |> Enum.zip(1..7) |> new() |> to_list() |> Enum.unzip()
      {[1, 2, 3, 4, 5, 6, 7], [1, 2, 3, 4, 5, 6, 7]}
  """
  @spec to_list(t(key, value)) :: [{key, value}] when key: var, value: var
  def to_list(t), do: to_list_rec(postorder(t).(), [])

  @spec to_list_rec(iterator_result({key, value}), [{key, value}]) :: [{key, value}] when key: var, value: var
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

      iex> [one: 1, two: 2, three: 3] |> new() |> filter(fn {_key, val} -> rem(val, 2) == 1 end) |> to_string()
      "#TreeMap<one => 1;three => 3;>"

  """
  @spec filter(t(key, value), ({key, value} -> boolean())) :: t(key, value) when key: var, value: var
  def filter(%TreeMap{} = t, fun), do: t |> to_list() |> Enum.filter(fun) |> build(t.less, true)

  @doc """
  Builds a map from the given `keys` and the fixed `value`.

  ## Examples

      iex> from_keys([1, 2, 3], :number) |> to_string()
      "#TreeMap<1 => number;2 => number;3 => number;>"

  """
  @spec from_keys(Enumerable.t(key), value, compare(key)) :: t(key, value) when key: var, value: var
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

      iex> map = new([a: 1])
      iex> get_and_update(map, :a, fn current_value ->
      ...>   {current_value, "new value!"}
      ...> end)
      {1, %TreeMap{less: &:erlang.</2, root: {nil, :a, "new value!", 1, nil}, size: 1}}
      iex> get_and_update(map, :b, fn current_value ->
      ...>   {current_value, "new value!"}
      ...> end)
      {nil, %TreeMap{less: &:erlang.</2, root: {nil, :a, 1, 2, {nil, :b, "new value!", 1, nil}}, size: 2}}
      iex> get_and_update(map, :a, fn _ -> :pop end)
      {1, %TreeMap{less: &:erlang.</2, root: nil, size: 0}}
      iex> get_and_update(map, :b, fn _ -> :pop end)
      {nil, %TreeMap{less: &:erlang.</2, root: {nil, :a, 1, 1, nil}, size: 1}}
      iex> get_and_update(map, :a, fn _ -> :fred end)
      ** (RuntimeError) the given function must return a two-element tuple or :pop, got: :fred
  """
  @spec get_and_update(t(key, value), key, (value -> :pop | {value, value} | any())) :: {value, t(key, value)} when key: var, value: var
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
      iex> map = new([a: 1])
      iex> get_and_update!(map, :a, fn v -> {v, 2} end) |> elem(0)
      1
      iex> get_and_update!(map, :a, fn v -> {v, 2} end) |> elem(1) |> to_string()
      "#TreeMap<a => 2;>"
      iex> get_and_update!(map, :b, fn v -> {v, :c} end)
      ** (KeyError) key :b not found

      iex> map = new([a: 1])
      iex> get_and_update!(map, :a, fn _ -> :pop end) |> elem(0)
      1
      iex> get_and_update!(map, :a, fn _ -> :pop end) |> elem(1) |> to_string()
      "#TreeMap<>"
      iex> get_and_update!(map, :a, fn _ -> :fred end) |> elem(1) |> to_string()
      ** (RuntimeError) the given function must return a two-element tuple or :pop, got: :fred
  """
  @spec get_and_update!(t(key, value), key, (value -> :pop | {value, value} | any())) :: {value, t(key, value)} when key: var, value: var
  def get_and_update!(map, key, fun) when is_function(fun, 1) do
    value = fetch!(map, key)

    case fun.(value) do
      {get, update} ->
        {get, put(map, key, update)}

      :pop ->
        {value, delete(map, key)}

      other ->
        raise "the given function must return a two-element tuple or :pop, got: #{inspect(other)}"
    end
  end

  @doc """
  Gets the value for a specific `key` in `map`.

  If `key` is present in `map` then its value `value` is
  returned. Otherwise, `fun` is evaluated and its result is returned.

  This is useful if the default value is very expensive to calculate or
  generally difficult to setup and teardown again.

  ## Examples
      iex> map = new([a: 1])
      iex> get_lazy(map, :a, fn -> 13 end)
      1
      iex> get_lazy(map, :b, fn -> 13 end)
      13

  """
  @spec get_lazy(t(key, value), key, (-> value)) :: value when key: var, value: var
  def get_lazy(tree, key, fun) do
    case fetch(tree, key) do
      {:ok, value} -> value
      _ -> fun.()
    end

  end

  @doc """
  Returns whether the given `key` exists in the given `map`.

  ## Examples
      iex> map = new([a: 1])
      iex> has_key?(map, :a)
      true
      iex> has_key?(map, :b)
      false
  """

  @spec has_key?(t(key, any()), key) :: boolean() when key: var
  def has_key?(tree, key), do: has_key_rec?(tree.root, key, tree.less)


  @spec has_key?(any(), any()) :: boolean()
  def has_key_rec?(t, k, less) do
    cond do
      is_nil(t) -> false
      less.(k, key(t)) -> has_key_rec?(left(t), k, less)
      less.(key(t), k) -> has_key_rec?(right(t), k, less)
      true -> true
    end
  end

  @doc """
  Returns all the keys (in order).

  ## Examples
      iex> [a: 1] |> new() |> keys()
      [:a]
      iex> keys(new())
      []
  """
  @spec keys(t(key, any())) :: [key] when key: var
  def keys(tree), do: tree |> to_list() |> Enum.unzip() |> elem(0)

  @doc """
  Returns all the values.

  ## Examples
      iex> [a: 1] |> new() |> values()
      [1]
      iex> values(new())
      []
  """
  @spec values(t(any(), value)) :: [value] when value: var
  def values(tree), do: tree |> to_list() |> Enum.unzip() |> elem(1)

    @doc """
  Merges two maps into one, resolving conflicts through the given `fun`.

  All keys in `map2` will be added to `map1`. The given function will be invoked
  when there are duplicate keys; its arguments are `key` (the duplicate key),
  `value1` (the value of `key` in `map1`), and `value2` (the value of `key` in
  `map2`). The value returned by `fun` is used as the value under `key` in
  the resulting map.

  ## Examples

      iex> merge(new([a: 1, b: 2]), new([a: 3, d: 4]), fn _k, v1, v2 -> v1 + v2 end) |> to_string()
      "#TreeMap<a => 4;b => 2;d => 4;>"

  """
  @spec merge(t(key, value), t(key, value), resolve(key, value)) :: t(key, value) when key: var, value: var
  def merge(t1, t2, f \\ fn _k, _v1, v2 -> v2 end), do: union(t1, t2, f)

  @doc """
  Removes the value associated with `key` in `map` and returns the value and the updated map.

  If `key` is present in `map`, it returns `{value, updated_map}` where `value` is the value of
  the key and `updated_map` is the result of removing `key` from `map`. If `key`
  is not present in `map`, `{default, map}` is returned.

  ## Examples

      iex> map = new([a: 1])
      iex> pop(map, :a)
      {1, %TreeMap{size: 0, root: nil, less: &Kernel.</2}}
      iex> pop(map, :b)
      {nil, %TreeMap{size: 1, root: {nil, :a, 1, 1, nil}, less: &:erlang.</2}}
      iex> pop(map, :b, 3)
      {3, %TreeMap{size: 1, root: {nil, :a, 1, 1, nil}, less: &:erlang.</2}}
  """
  @spec pop(t(key, value), key, value) :: {value, t(key, value)} when key: var, value: var
  def pop(tree, key, default \\ nil) do
    case fetch(tree, key) do
      {:ok, value} -> {value, delete(tree, key)}
      :error -> {default, tree}
    end
  end

  @doc """
  Removes and returns the value associated with `key` in `map` alongside
  the updated map, or raises if `key` is not present.

  Behaves the same as `pop/3` but raises a `KeyError` exception if `key` is not present in `map`.

  ## Examples
      iex> map = new([a: 1])
      iex> pop!(map, :a)
      {1, %TreeMap{size: 0, root: nil, less: &Kernel.</2}}
      iex> pop!(new([a: 1, b: 2]), :a)
      {1, %TreeMap{size: 1, root: {nil, :b, 2, 1, nil}, less: &:erlang.</2}}
      iex> pop!(map, :b)
      ** (KeyError) key :b not found in: %TreeMap{size: 1, root: {nil, :a, 1, 1, nil}, less: &:erlang.</2}

  """
 @spec pop!(t(key, value), key) :: {value, t(key, value)} when key: var, value: var
 def pop!(tree, key) do
    case fetch(tree, key) do
      {:ok, value} -> {value, delete(tree, key)}
      :error -> raise KeyError, key: key, term: tree
    end
  end


  @doc """
  Lazily returns and removes the value associated with `key` in `map`.

  If `key` is present in `map`, it returns `{value, new_map}` where `value` is the value of
  the key and `new_map` is the result of removing `key` from `map`. If `key`
  is not present in `map`, `{fun_result, map}` is returned, where `fun_result`
  is the result of applying `fun`.

  This is useful if the default value is very expensive to calculate or
  generally difficult to setup and teardown again.

  ## Examples

      iex> map = new([a: 1])
      iex> pop_lazy(map, :a, fn -> 13 end)
      {1, %TreeMap{size: 0, root: nil, less: &Kernel.</2}}
      iex> pop_lazy(map, :b, fn -> 13 end)
      {13, %TreeMap{size: 1, root: {nil, :a, 1, 1, nil}, less: &:erlang.</2}}

  """
  @spec pop_lazy(t(key, value), key, (-> value)) :: {value, t(key, value)} when key: var, value: var
  def pop_lazy(tree, key, fun) do
    case fetch(tree, key) do
      {:ok, value} -> {value, delete(tree, key)}
      :error -> {fun.(), tree}
    end
  end

  @doc """
  Puts the given `value` under `key` unless the entry `key`
  already exists in `map`.

  ## Examples

      iex> put_new(new([a: 1]), :b, 2)
      %TreeMap{less: &:erlang.</2, root: {nil, :a, 1, 2, {nil, :b, 2, 1, nil}}, size: 2}
      iex> put_new(new([a: 1, b: 2]), :a, 3)
      %TreeMap{less: &:erlang.</2, root: {nil, :a, 1, 2, {nil, :b, 2, 1, nil}}, size: 2}

  """
  @spec put_new(t(key, value), key, value) :: t(key, value) when key: var, value: var
  def put_new(tree, key, value) do
    if has_key?(tree, key) do
      tree
    else
      put(tree, key, value)
    end
  end

  @doc """
  Evaluates `fun` and puts the result under `key`
  in `map` unless `key` is already present.

  This function is useful in case you want to compute the value to put under
  `key` only if `key` is not already present, as for example, when the value is expensive to
  calculate or generally difficult to setup and teardown again.

  ## Examples

      iex> map = new([a: 1])
      iex> fun = fn ->
      ...>   # some expensive operation here
      ...>   3
      ...> end
      iex> put_new_lazy(map, :a, fun)
      %TreeMap{less: &:erlang.</2, root: {nil, :a, 1, 1, nil}, size: 1}
      iex> put_new_lazy(map, :b, fun)
      %TreeMap{less: &:erlang.</2, root: {nil, :a, 1, 2, {nil, :b, 3, 1, nil}}, size: 2}

  """
  @spec put_new_lazy(t(key, value), key, (-> value)) :: t(key, value) when key: var, value: var
  def put_new_lazy(tree, key, fun) do
    if has_key?(tree, key) do
      tree
    else
      put(tree, key, fun.())
    end
  end


  @doc """
  Returns map excluding the pairs from `map` for which `fun` returns
  a truthy value.

  See also `filter/2`.

  ## Examples

      iex> reject(new([one: 1, two: 2, three: 3]), fn {_key, val} -> rem(val, 2) == 1 end)
      %TreeMap{less: &:erlang.</2, root: {nil, :two, 2, 1, nil}, size: 1}

  """
  @spec reject(t(key, value), ({key, value} -> boolean())) :: t(key, value) when key: var, value: var
  def reject(tree, fun), do: tree |> to_list() |> Enum.reject(fun) |> build(tree.less, true)

  @doc """
  Puts a value under `key` only if the `key` already exists in `map`.

  ## Examples

      iex> replace(new([a: 1, b: 2]), :a, 3)
      %TreeMap{less: &:erlang.</2, root: {nil, :a, 3, 2, {nil, :b, 2, 1, nil}}, size: 2}

      iex> replace(new([a: 1]), :b, 2)
      %TreeMap{less: &:erlang.</2, root: {nil, :a, 1, 1, nil}, size: 1}

  """
  @spec replace(t(key, value), key, value) :: t(key, value) when key: var, value: var
  def replace(tree, key, value) do
    if has_key?(tree, key) do
      put(tree, key, value)
    else
      tree
    end
  end

  @doc """
  Puts a value under `key` only if the `key` already exists in `map`.

  If `key` is not present in `map`, a `KeyError` exception is raised.

  Inlined by the compiler.

  ## Examples

      iex> replace!(new([a: 1, b: 2]), :a, 3)
      %TreeMap{less: &:erlang.</2, root: {nil, :a, 3, 2, {nil, :b, 2, 1, nil}}, size: 2}

      iex> replace!(new([a: 1]), :b, 2)
      ** (KeyError) key :b not found in: %TreeMap{size: 1, root: {nil, :a, 1, 1, nil}, less: &:erlang.</2}

  """
  @spec replace!(t(key, value), key, value) :: t(key, value) when key: var, value: var
  def replace!(tree, key, value) do
    if has_key?(tree, key) do
      put(tree, key, value)
    else
      raise KeyError, key: key, term: tree
    end
  end

  @doc """
  Replaces the value under `key` using the given function only if
  `key` already exists in `map`.

  In comparison to `replace/3`, this can be useful when it's expensive to calculate the value.

  If `key` does not exist, the original map is returned unchanged.

  ## Examples

      iex> replace_lazy(new([a: 1, b: 2]), :a, fn v -> v * 4 end)
      %TreeMap{less: &:erlang.</2, root: {nil, :a, 4, 2, {nil, :b, 2, 1, nil}}, size: 2}

      iex> replace_lazy(new([a: 1, b: 2]), :c, fn v -> v * 4 end)
      %TreeMap{less: &:erlang.</2, root: {nil, :a, 1, 2, {nil, :b, 2, 1, nil}}, size: 2}

  """
  @spec replace_lazy(t(key, value), key, (value -> value)) :: t(key, value) when key: var, value: var
  def replace_lazy(tree, key, fun) do
    case fetch(tree, key) do
      {:ok, value} -> put(tree, key, fun.(value))
      :error -> tree
    end
  end

  @doc """
  Takes all entries corresponding to the given `keys` in `map` and extracts
  them into a separate map.

  Returns a tuple with the new map and the old map with removed keys.

  Keys for which there are no entries in `map` are ignored.

  ## Examples

      iex> split(new([a: 1, b: 2, c: 3]), [:a, :c, :e])
      {
        %TreeMap{less: &:erlang.</2, root: {nil, :b, 2, 1, nil}, size: 1},
        %TreeMap{less: &:erlang.</2, root: {nil, :a, 1, 2, {nil, :c, 3, 1, nil}}, size: 2}
      }

  """
  @spec split(t(key, value), Enumerable.t(key)) :: {t(key, value), t(key, value)} when key: var, value: var
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

  @doc """
  Splits the `map` into two maps according to the given function `fun`.

  `fun` receives each `{key, value}` pair in the `map` as its only argument. Returns
  a tuple with the first map containing all the elements in `map` for which
  applying `fun` returned a truthy value, and a second map with all the elements
  for which applying `fun` returned a falsy value (`false` or `nil`).

  ## Examples

      iex> split_with(new([a: 1, b: 2, c: 3, d: 4]), fn {_k, v} -> rem(v, 2) == 0 end)
      {
        %TreeMap{less: &:erlang.</2, root: {nil, :b, 2, 2, {nil, :d, 4, 1, nil}}, size: 2},
        %TreeMap{less: &:erlang.</2, root: {nil, :a, 1, 2, {nil, :c, 3, 1, nil}}, size: 2}
      }

      iex> split_with(new([a: 1, b: -2, c: 1, d: -3]), fn {k, _v} -> k in [:b, :d] end)
      {
        %TreeMap{less: &:erlang.</2, root: {nil, :b, -2, 2, {nil, :d, -3, 1, nil}}, size: 2},
        %TreeMap{less: &:erlang.</2, root: {nil, :a, 1, 2, {nil, :c, 1, 1, nil}}, size: 2}
      }

      iex> split_with(new([a: 1, b: -2, c: 1, d: -3]), fn {_k, v} -> v > 50 end)
      {
        %TreeMap{less: &:erlang.</2, root: nil, size: 0},
        %TreeMap{
          less: &:erlang.</2,
          root: {{nil, :a, 1, 1, nil}, :b, -2, 4, {nil, :c, 1, 2, {nil, :d, -3, 1, nil}}},
          size: 4
        }
      }

      iex> split_with(new(), fn {_k, v} -> v > 50 end)
      {%TreeMap{less: &:erlang.</2, root: nil, size: 0}, %TreeMap{less: &:erlang.</2, root: nil, size: 0}}

  """
  @spec split_with(t(key, value), ({key, value} -> boolean())) :: {t(key, value), t(key, value)} when key: var, value: var
  def split_with(tree, fun) do
    tree
    |> to_list()
    |> Enum.split_with(fun)
    |> then(fn {as, bs} -> {new(as), new(bs)} end)
  end

  @doc """
  Returns a new map with all the key-value pairs in `map` where the key
  is in `keys`.

  If `keys` contains keys that are not in `map`, they're simply ignored.

  ## Examples

      iex> take(new([a: 1, b: 2, c: 3]), [:a, :c, :e])
      %TreeMap{less: &:erlang.</2, root: {nil, :a, 1, 2, {nil, :c, 3, 1, nil}}, size: 2}

  """
  @spec take(t(key, value), Enumerable.t(key)) :: t(key, value) when key: var, value: var
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

  @doc """
  Updates the `key` in `map` with the given function.

  If `key` is present in `map` then the existing value is passed to `fun` and its result is
  used as the updated value of `key`. If `key` is
  not present in `map`, `default` is inserted as the value of `key`. The default
  value will not be passed through the update function.

  ## Examples

      iex> update(new([a: 1]), :a, 13, fn existing_value -> existing_value * 2 end)
      %TreeMap{less: &:erlang.</2, root: {nil, :a, 2, 1, nil}, size: 1}
      iex> update(new([a: 1]), :b, 11, fn existing_value -> existing_value * 2 end)
      %TreeMap{less: &:erlang.</2, root: {nil, :a, 1, 2, {nil, :b, 11, 1, nil}}, size: 2}

  """
  @spec update(t(key, value), key, value, (value -> value)) :: t(key, value) when key: var, value: var
  def update(tree, key, default, fun) do
    case fetch(tree, key) do
      {:ok, value} -> put(tree, key, fun.(value))
      :error -> put(tree, key, default)
    end
  end

  @doc """
  Updates `key` with the given function.

  If `key` is present in `map` then the existing value is passed to `fun` and its result is
  used as the updated value of `key`. If `key` is
  not present in `map`, a `KeyError` exception is raised.

  ## Examples

      iex> update!(new([a: 1]), :a, &(&1 * 2))
      %TreeMap{less: &:erlang.</2, root: {nil, :a, 2, 1, nil}, size: 1}

      iex> update!(new([a: 1]), :b, &(&1 * 2))
      ** (KeyError) key :b not found in: %TreeMap{size: 1, root: {nil, :a, 1, 1, nil}, less: &:erlang.</2}

  """
  @spec update!(t(key, value), key, (value -> value)) :: t(key, value) when key: var, value: var
  def update!(tree, key, fun) do
    case fetch(tree, key) do
      {:ok, value} -> put(tree, key, fun.(value))
      :error -> raise KeyError, key: key, term: tree
    end
  end

end
