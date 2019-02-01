defmodule Core.Job do
  @moduledoc """
  Request is stored in capped collection, so document size can't change on update.
  That means all fields on update should have the same size
  """

  use Core.Schema

  @response_length 1800

  @status_pending 0
  @status_processed 1
  @status_failed 2
  @status_failed_with_error 3

  def status_to_string(@status_pending), do: "pending"
  def status_to_string(@status_processed), do: "processed"
  def status_to_string(@status_failed), do: "failed"
  def status_to_string(@status_failed_with_error), do: "failed_with_error"

  def status(:pending), do: @status_pending
  def status(:processed), do: @status_processed
  def status(:failed), do: @status_failed
  def status(:failed_with_error), do: @status_failed_with_error

  def response_length, do: @response_length

  @primary_key :_id
  schema :jobs do
    field(:_id)
    field(:hash, presence: true)
    field(:eta, presence: true)
    field(:status, presence: true, inclusion: [@status_pending, @status_processed, @status_failed])
    field(:status_code, presence: true, inclusion: [200, 202, 404, 422])
    field(:response, length: [is: @response_length])
    field(:response_size, presence: true)

    timestamps()
  end

  def valid_response?(response) when is_binary(response) do
    byte_size(response) <= @response_length
  end

  def valid_response?(response) when is_map(response) do
    byte_size(Jason.encode!(response)) <= @response_length
  end

  def encode_response(%__MODULE__{response: value} = job) do
    response = Jason.encode!(value)
    %{job | response: pad_trailing(response), response_size: byte_size(response)}
  end

  def encode_response(%{"response" => value} = data) do
    response = Jason.encode!(value)

    data
    |> Map.put("response", pad_trailing(response))
    |> Map.put("response_size", byte_size(response))
  end

  def decode_response(%__MODULE__{response: response, response_size: response_size} = job) do
    %{job | response: Jason.decode!(binary_part(response, 0, response_size))}
  end

  defp pad_trailing(data) do
    data <> String.duplicate(".", @response_length - byte_size(data))
  end
end
