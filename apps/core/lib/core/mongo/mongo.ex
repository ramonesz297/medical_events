defmodule Core.Mongo do
  @moduledoc false

  alias Mongo, as: M
  require Logger

  defdelegate start_link(opts), to: M
  defdelegate object_id, to: M

  defp execute(fun, args) do
    opts = List.last(args)

    enriched_args =
      args
      |> List.replace_at(Enum.count(args) - 1, opts)
      |> List.insert_at(0, :mongo)

    try do
      apply(M, fun, enriched_args)
    rescue
      error ->
        Logger.info("Error: #{inspect(error)}, #{fun}: #{inspect(enriched_args)}")
        reraise(error, __STACKTRACE__)
    end
  end

  def generate_id do
    Mongo.IdServer.new()
  end

  def aggregate(coll, pipeline, opts \\ []) do
    execute(:aggregate, [coll, pipeline, opts])
  end

  def command(query, opts \\ []) do
    execute(:command, [query, opts])
  end

  def command!(query, opts \\ []) do
    execute(:command!, [query, opts])
  end

  def count(coll, filter, opts \\ []) do
    execute(:count, [coll, filter, opts])
  end

  def count!(coll, filter, opts \\ []) do
    execute(:count!, [coll, filter, opts])
  end

  def delete_many(coll, filter, opts \\ []) do
    execute(:delete_many, [coll, filter, opts])
  end

  def delete_many!(coll, filter, opts \\ []) do
    execute(:delete_many!, [coll, filter, opts])
  end

  def delete_one(coll, %{"_id" => _} = filter, opts \\ []) do
    execute(:delete_one, [coll, filter, opts])
  end

  def delete_one!(coll, %{"_id" => _} = filter, opts \\ []) do
    execute(:delete_one!, [coll, filter, opts])
  end

  def distinct(coll, field, filter, opts \\ []) do
    execute(:distinct, [coll, field, filter, opts])
  end

  def distinct!(coll, field, filter, opts \\ []) do
    execute(:distinct!, [coll, field, filter, opts])
  end

  def find(coll, filter, opts \\ []) do
    execute(:find, [coll, filter, opts])
  end

  def find_one(coll, filter, opts \\ []) do
    execute(:find_one, [coll, filter, opts])
  end

  def find_one_and_delete(coll, %{"_id" => _} = filter, opts \\ []) do
    execute(:find_one_and_delete, [coll, filter, opts])
  end

  def find_one_and_replace(coll, %{"_id" => _} = filter, replacement, opts \\ []) do
    opts = maybe_add_return_document(opts)
    execute(:find_one_and_replace, [coll, filter, replacement, opts])
  end

  def find_one_and_update(coll, %{"_id" => _} = filter, update, opts \\ []) do
    opts = maybe_add_return_document(opts)
    execute(:find_one_and_update, [coll, filter, update, opts])
  end

  def insert_many(coll, [%{__meta__: _} | _] = docs, opts) do
    execute(:insert_many, [coll, prepare_doc(docs), opts])
  end

  def insert_many(coll, docs, opts) do
    execute(:insert_many, [coll, docs, opts])
  end

  def insert_many!(coll, [%{__meta__: _} | _] = docs, opts) do
    execute(:insert_many!, [coll, prepare_doc(docs), opts])
  end

  def insert_many!(coll, docs, opts) do
    execute(:insert_many!, [coll, docs, opts])
  end

  def insert_one(%{__meta__: metadata} = doc, opts \\ []) do
    insert_one(metadata.source, prepare_doc(doc), opts)
  end

  def insert_one(coll, doc, opts) do
    execute(:insert_one, [coll, doc, opts])
  end

  def insert_one!(%{__meta__: metadata} = doc, opts \\ []) do
    insert_one!(metadata.source, prepare_doc(doc), opts)
  end

  def insert_one!(coll, doc, opts) do
    execute(:insert_one!, [coll, doc, opts])
  end

  def replace_one(coll, %{"_id" => _} = filter, replacement, opts \\ []) do
    execute(:replace_one, [coll, filter, replacement, opts])
  end

  def replace_one!(coll, %{"_id" => _} = filter, replacement, opts \\ []) do
    execute(:replace_one!, [coll, filter, replacement, opts])
  end

  def update_many(coll, filter, update, opts \\ []) do
    execute(:update_many, [coll, filter, update, opts])
  end

  def update_many!(coll, filter, update, opts \\ []) do
    execute(:update_many!, [coll, filter, update, opts])
  end

  def update_one(coll, %{"_id" => _} = filter, update, opts \\ []) do
    execute(:update_one, [coll, filter, update, opts])
  end

  def update_one!(coll, %{"_id" => _} = filter, update, opts \\ []) do
    execute(:update_one!, [coll, filter, update, opts])
  end

  def prepare_doc([h | tail]) do
    [prepare_doc(h) | prepare_doc(tail)]
  end

  def prepare_doc(%{__meta__: _} = doc) do
    doc
    |> Map.from_struct()
    |> Map.drop(~w(__meta__)a)
    |> Enum.into(%{}, fn {k, v} -> {k, prepare_doc(v)} end)
  end

  def prepare_doc(%DateTime{} = doc), do: doc

  def prepare_doc(%Date{} = doc) do
    date = Date.to_erl(doc)
    {date, {0, 0, 0}} |> NaiveDateTime.from_erl!() |> DateTime.from_naive!("Etc/UTC")
  end

  def prepare_doc(%BSON.Binary{} = doc), do: doc
  def prepare_doc(%BSON.ObjectId{} = doc), do: doc

  def prepare_doc(%{__struct__: _} = doc) do
    doc
    |> Map.from_struct()
    |> prepare_doc()
  end

  def prepare_doc(%{} = doc) do
    Enum.into(doc, %{}, fn {k, v} -> {k, prepare_doc(v)} end)
  end

  def prepare_doc(doc) when is_binary(doc) do
    if String.length(doc) == 36 do
      case string_to_uuid(doc) do
        %BSON.Binary{} = value -> value
        _ -> doc
      end
    else
      doc
    end
  end

  def prepare_doc(doc), do: doc

  defp maybe_add_return_document(opts) do
    # for valid audit logging.
    # See `returnNewDocument` in https://docs.mongodb.com/manual/reference/method/db.collection.findOneAndReplace/
    case Keyword.get(opts, :upsert, false) do
      true -> opts ++ [return_document: :after]
      _ -> opts
    end
  end

  def add_to_set(set, nil, _), do: set

  def add_to_set(set, %DateTime{} = value, path), do: Map.put(set, path, value)
  def add_to_set(set, %Date{} = value, path), do: Map.put(set, path, value)

  def add_to_set(set, %{__struct__: _} = value, path) do
    fields = Map.keys(Map.from_struct(value))

    Enum.reduce(fields, set, fn field, acc ->
      add_to_set(acc, Map.get(value, field), "#{path}.#{field}")
    end)
  end

  def add_to_set(set, [%{__struct__: _module} | _] = values, path) do
    Map.put(set, path, values)
  end

  def add_to_set(set, value, path), do: Map.put(set, path, value)

  def add_to_push(push, nil, _), do: push

  def add_to_push(push, [%{__struct__: _} | _] = values, path) do
    Map.put(push, path, %{"$each" => values})
  end

  def add_to_push(push, value, path), do: Map.put(push, path, value)

  def convert_to_uuid(set, path) do
    uuid = Map.get(set, path)

    if is_binary(uuid) do
      Map.replace!(set, path, string_to_uuid(uuid))
    else
      set
    end
  end

  def convert_to_uuid(set, path, subpath) when is_binary(path) do
    convert_to_uuid(set, [path], subpath)
  end

  def convert_to_uuid(set, path, subpath) when is_list(path) do
    put_item = fn uuid, item ->
      if is_binary(uuid) do
        put_in(item, subpath, string_to_uuid(uuid))
      else
        item
      end
    end

    case get_in(set, path) do
      nil ->
        set

      values when is_list(values) ->
        items =
          Enum.map(values, fn item ->
            uuid = get_in(item, subpath)
            put_item.(uuid, item)
          end)

        put_in(set, path, items)

      %{} = value ->
        uuid = get_in(value, subpath)
        put_in(set, path, put_item.(uuid, value))
    end
  end

  def string_to_uuid(value) when is_binary(value) do
    %BSON.Binary{binary: UUID.string_to_binary!(value), subtype: :uuid}
  rescue
    _ -> nil
  end
end

defimpl Jason.Encoder, for: [BSON.Binary] do
  def encode(struct, opts) do
    Jason.Encode.string(to_string(struct), opts)
  end
end
