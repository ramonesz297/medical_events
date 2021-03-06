defmodule PersonConsumer.Kafka.PersonEventConsumer do
  @moduledoc false

  alias Core.Mongo.Transaction
  alias Core.Patient
  alias Core.Patients
  require Logger

  @status_active Patient.status(:active)
  @status_inactive Patient.status(:inactive)

  def handle_messages(messages) do
    for %{offset: offset, value: value} <- messages do
      value = :erlang.binary_to_term(value)
      Logger.debug(fn -> "message: " <> inspect(value) end)
      Logger.info(fn -> "offset: #{offset}" end)
      :ok = consume(value)
    end

    :ok
  end

  def consume(%{"id" => person_id, "status" => status, "updated_by" => updated_by})
      when status in [@status_active, @status_inactive] do
    %Transaction{}
    |> Transaction.add_operation(
      Patient.collection(),
      :upsert,
      %{"_id" => Patients.get_pk_hash(person_id)},
      %{
        "$set" => %{"status" => status, "updated_by" => updated_by},
        "$setOnInsert" => %{
          "visits" => %{},
          "episodes" => %{},
          "encounters" => %{},
          "immunizations" => %{},
          "allergy_intolerances" => %{},
          "risk_assessments" => %{},
          "devices" => %{},
          "medication_statements" => %{},
          "diagnostic_reports" => %{},
          "status_history" => []
        }
      },
      Patients.get_pk_hash(person_id)
    )
    |> Transaction.flush()

    :ok
  end

  def consume(value) do
    Logger.warn(fn -> "unknown kafka event: #{inspect(value)}" end)
    :ok
  end
end
