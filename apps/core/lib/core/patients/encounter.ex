defmodule Core.Encounter do
  @moduledoc false

  use Core.Schema
  alias Core.CodeableConcept
  alias Core.Coding
  alias Core.Diagnosis
  alias Core.Reference

  @status_finished "finished"
  @status_entered_in_error "entered_in_error"

  def status(:finished), do: @status_finished
  def status(:entered_in_error), do: @status_entered_in_error

  embedded_schema do
    field(:id, presence: true, mongo_uuid: true)
    field(:status, presence: true)
    field(:status_history)
    field(:class, presence: true, reference: [path: "class"])
    field(:type, presence: true, reference: [path: "type"])
    field(:incoming_referrals)
    field(:duration)
    field(:reasons, presence: true, reference: [path: "reasons"])
    field(:diagnoses, presence: true, reference: [path: "diagnoses"])
    field(:service_provider)
    field(:division, presence: true, reference: [path: "division"])
    field(:actions, presence: true, reference: [path: "actions"])
    field(:signed_content_links)
    field(:performer, presence: true, reference: [path: "performer"])
    field(:episode, presence: true, reference: [path: "episode"])
    field(:visit, presence: true, reference: [path: "visit"])

    timestamps()
    changed_by()
  end

  def create(data) do
    struct(
      __MODULE__,
      Enum.map(data, fn
        {"episode", v} -> {:episode, Reference.create(v)}
        {"visit", v} -> {:visit, Reference.create(v)}
        {"division", v} -> {:division, Reference.create(v)}
        {"diagnoses", v} -> {:diagnoses, Enum.map(v, &Diagnosis.create/1)}
        {"actions", v} -> {:actions, Enum.map(v, &CodeableConcept.create/1)}
        {"reasons", v} -> {:reasons, Enum.map(v, &CodeableConcept.create/1)}
        {"class", v} -> {:class, Coding.create(v)}
        {"type", v} -> {:type, CodeableConcept.create(v)}
        {"performer", v} -> {:performer, Reference.create(v)}
        {k, v} -> {String.to_atom(k), v}
      end)
    )
  end
end
