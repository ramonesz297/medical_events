defmodule Core.Validators.DictionaryReference do
  @moduledoc """
  Validate dictionary value based on referenced field value
  """

  use Vex.Validator
  alias Core.CodeableConcept
  alias Core.Coding

  @validator_cache Application.get_env(:core, :cache)[:validators]

  def validate(%Coding{} = value, options) do
    field = String.to_atom(Keyword.get(options, :field))
    referenced_field = String.to_atom(Keyword.get(options, :referenced_field))
    field = Map.get(value, field)
    referenced_field = Map.get(value, referenced_field)

    with {:ok, dictionaries} <- @validator_cache.get_dictionaries(),
         %{"values" => values} <- Enum.find(dictionaries, fn %{"name" => name} -> name == referenced_field end),
         true <- Map.has_key?(values, field) do
      :ok
    else
      _ ->
        if Keyword.has_key?(options, :path) do
          {:error, "#{Keyword.get(options, :path)}", :dictionary_reference,
           "Value #{field} not found in the dictionary #{referenced_field}"}
        else
          error(options, "Value #{field} not found in the dictionary #{referenced_field}")
        end
    end
  end

  def validate([], _), do: :ok

  def validate([%CodeableConcept{} | _] = values, options) do
    errors =
      values
      |> Enum.with_index()
      |> Enum.reduce([], fn {value, i}, acc ->
        case validate(value, Keyword.put(options, :path, "#{Keyword.get(options, :path)}.#{i}")) do
          :ok -> acc
          error -> acc ++ [error]
        end
      end)

    case errors do
      [] -> :ok
      _ -> errors
    end
  end

  def validate(%CodeableConcept{} = value, options) do
    validate(hd(value.coding), options)
  end

  def validate(%{__struct__: _}, _), do: :ok

  def validate(%{} = value, options) do
    field = Keyword.get(options, :field)
    referenced_field = Keyword.get(options, :referenced_field)
    coding = hd(value["coding"])
    field = Map.get(coding, field)
    referenced_field = Map.get(coding, referenced_field)

    with {:ok, dictionaries} <- @validator_cache.get_dictionaries(),
         %{"values" => values} <- Enum.find(dictionaries, fn %{"name" => name} -> name == referenced_field end),
         true <- Map.has_key?(values, field) do
      :ok
    else
      _ -> error(options, "Value #{field} not found in the dictionary #{referenced_field}")
    end
  end

  def validate(nil, _), do: :ok

  def error(options, error_message) do
    {:error, message(options, error_message)}
  end
end
