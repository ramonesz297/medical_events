defmodule Core.Factories do
  @moduledoc false

  use ExMachina

  alias Core.CodeableConcept
  alias Core.Coding
  alias Core.Condition
  alias Core.DiagnosesHistory
  alias Core.Diagnosis
  alias Core.Encounter
  alias Core.Episode
  alias Core.Evidence
  alias Core.Identifier
  alias Core.Job
  alias Core.Mongo
  alias Core.Observation
  alias Core.Observations.Component
  alias Core.Observations.EffectiveAt
  alias Core.Observations.ReferenceRange
  alias Core.Observations.Value
  alias Core.Observations.Values.Quantity
  alias Core.Patient
  alias Core.Patients
  alias Core.Period
  alias Core.Reference
  alias Core.Source
  alias Core.Stage
  alias Core.StatusHistory
  alias Core.Visit

  def patient_factory do
    visits = build_list(2, :visit)

    visits =
      Enum.into(visits, %{}, fn %{id: %BSON.Binary{binary: id}} = visit ->
        {UUID.binary_to_string!(id), visit}
      end)

    episodes = build_list(2, :episode)

    episodes =
      Enum.into(episodes, %{}, fn %{id: %BSON.Binary{binary: id}} = episode ->
        {UUID.binary_to_string!(id), episode}
      end)

    encounters = build_list(2, :encounter)

    encounters =
      Enum.into(encounters, %{}, fn %{id: %BSON.Binary{binary: id}} = encounter ->
        {UUID.binary_to_string!(id), encounter}
      end)

    id = Patients.get_pk_hash(UUID.uuid4())
    user_id = UUID.uuid4()

    %Patient{
      _id: id,
      status: Patient.status(:active),
      visits: visits,
      episodes: episodes,
      encounters: encounters,
      immunizations: %{},
      allergy_intolerances: %{},
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now(),
      inserted_by: user_id,
      updated_by: user_id
    }
  end

  def visit_factory do
    id = UUID.uuid4()

    %Visit{
      id: Mongo.string_to_uuid(id),
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now(),
      inserted_by: Mongo.string_to_uuid(id),
      updated_by: Mongo.string_to_uuid(id),
      period: build(:period)
    }
  end

  def period_factory do
    %Period{
      start: DateTime.utc_now(),
      end: DateTime.utc_now()
    }
  end

  def job_factory do
    %Job{
      _id: Mongo.generate_id(),
      hash: :crypto.hash(:md5, to_string(DateTime.to_unix(DateTime.utc_now()))),
      eta: NaiveDateTime.utc_now() |> NaiveDateTime.to_iso8601(),
      status_code: 200,
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now(),
      status: Job.status(:pending),
      response: ""
    }
  end

  def observation_factory do
    user_id = UUID.uuid4()
    now = DateTime.utc_now()

    %Observation{
      _id: Mongo.string_to_uuid(UUID.uuid4()),
      status: Observation.status(:valid),
      categories: [codeable_concept_coding(system: "eHealth/observation_categories")],
      code: codeable_concept_coding(system: "eHealth/observations_codes"),
      comment: "some comment",
      patient_id: Patients.get_pk_hash(UUID.uuid4()),
      based_on: [reference_coding(system: "eHealth/resources", code: "referral")],
      context: reference_coding(system: "eHealth/resources", code: "encounter"),
      effective_at: %EffectiveAt{type: "effective_date_time", value: now},
      issued: DateTime.utc_now(),
      primary_source: true,
      source: build(:source, type: "performer", value: reference_coding(system: "eHealth/resources", code: "employee")),
      interpretation: codeable_concept_coding(system: "eHealth/observation_interpretations"),
      method: codeable_concept_coding(system: "eHealth/observation_methods"),
      value: build(:value),
      body_site: codeable_concept_coding(system: "eHealth/body_sites"),
      reference_ranges: [
        build(
          :reference_range,
          type: codeable_concept_coding(system: "eHealth/resources"),
          applies_to: [codeable_concept_coding(system: "eHealth/resources")]
        )
      ],
      components:
        build_list(
          2,
          :component,
          code: codeable_concept_coding(system: "eHealth/resources"),
          interpretation: codeable_concept_coding(system: "eHealth/observation_interpretations"),
          reference_ranges: [
            build(
              :reference_range,
              type: codeable_concept_coding(system: "eHealth/resources"),
              applies_to: [codeable_concept_coding(system: "eHealth/resources")]
            )
          ]
        ),
      inserted_at: now,
      updated_at: now,
      inserted_by: Mongo.string_to_uuid(user_id),
      updated_by: Mongo.string_to_uuid(user_id)
    }
  end

  def source_factory do
    %Source{type: "performer", value: build(:reference)}
  end

  def reference_range_factory do
    %ReferenceRange{
      low: build(:quantity),
      high: build(:quantity),
      type: build(:codeable_concept),
      applies_to: build_list(2, :codeable_concept),
      age: %{
        low: build(:quantity, comparator: ">", unit: "years"),
        high: build(:quantity, comparator: "<", unit: "years")
      },
      text: "some text"
    }
  end

  def component_factory do
    %Component{
      code: build(:codeable_concept),
      value: build(:value),
      interpretation: build(:codeable_concept),
      reference_ranges: build_list(2, :reference_range)
    }
  end

  def quantity_factory do
    %Quantity{
      value: :rand.uniform(100),
      comparator: "<",
      unit: "mg",
      system: "eHealth/units",
      code: "mg"
    }
  end

  def encounter_factory do
    id = UUID.uuid4()
    now = DateTime.utc_now()

    %Encounter{
      id: Mongo.string_to_uuid(UUID.uuid4()),
      status: Encounter.status(:finished),
      date: Date.utc_today(),
      episode: build(:reference),
      class: build(:coding),
      performer: build(:reference),
      visit: build(:reference),
      type: build(:codeable_concept),
      incoming_referrals: build_list(1, :reference),
      reasons: build_list(2, :codeable_concept),
      diagnoses: build_list(1, :diagnosis),
      actions: build_list(2, :codeable_concept),
      division: build(:reference),
      service_provider: build(:reference),
      inserted_at: now,
      updated_at: now,
      inserted_by: Mongo.string_to_uuid(id),
      updated_by: Mongo.string_to_uuid(id)
    }
  end

  def diagnosis_factory do
    %Diagnosis{
      condition: build(:reference),
      code: build(:codeable_concept),
      role: build(:codeable_concept),
      rank: 1
    }
  end

  def episode_factory do
    id = UUID.uuid4()

    date = Date.to_erl(Date.utc_today())
    date = {date, {0, 0, 0}} |> NaiveDateTime.from_erl!() |> DateTime.from_naive!("Etc/UTC")

    %Episode{
      id: Mongo.string_to_uuid(UUID.uuid4()),
      status: Episode.status(:active),
      closing_summary: "closing summary",
      closing_reason: build(:codeable_concept),
      cancellation_reason: build(:codeable_concept),
      explanatory_letter: "explanatory letter",
      status_history: build_list(1, :status_history),
      diagnoses_history: build_list(1, :diagnoses_history),
      type: "primary_care",
      name: "ОРВИ 2018",
      managing_organization: build(:reference),
      period: build(:period, start: date),
      care_manager: build(:reference),
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now(),
      inserted_by: Mongo.string_to_uuid(id),
      updated_by: Mongo.string_to_uuid(id)
    }
  end

  def diagnoses_history_factory do
    %DiagnosesHistory{
      date: DateTime.utc_now(),
      is_active: true,
      evidence: build(:reference),
      diagnoses: build_list(1, :diagnosis)
    }
  end

  def diagnosis_factory do
    %Diagnosis{
      condition: build(:reference),
      role: build(:codeable_concept),
      rank: Enum.random(1..1000),
      code: build(:codeable_concept)
    }
  end

  def value_factory do
    %Value{type: "string", value: "some value"}
  end

  def codeable_concept_factory do
    %CodeableConcept{
      coding: [build(:coding)],
      text: "code text"
    }
  end

  def coding_factory do
    %Coding{
      system: "eHealth/resources",
      code: "1"
    }
  end

  def reference_factory do
    %Reference{
      identifier: build(:identifier)
    }
  end

  def identifier_factory do
    %Identifier{
      type: build(:codeable_concept),
      value: Mongo.string_to_uuid(UUID.uuid4())
    }
  end

  def stage_factory do
    %Stage{
      summary: build(:codeable_concept)
    }
  end

  def evidence_factory do
    %Evidence{
      codes: [build(:codeable_concept)],
      details: [build(:reference)]
    }
  end

  def condition_factory do
    patient_id = Patients.get_pk_hash(UUID.uuid4())
    user_id = UUID.uuid4()
    today = Date.utc_today()

    %Condition{
      _id: Mongo.string_to_uuid(UUID.uuid4()),
      context: reference_coding(code: "encounter"),
      code: codeable_concept_coding(system: "eHealth/ICD10/conditions"),
      clinical_status: "active",
      verification_status: "provisional",
      severity: codeable_concept_coding(system: "eHealth/severity"),
      body_sites: [codeable_concept_coding(system: "eHealth/body_sites")],
      onset_date: today,
      asserted_date: today,
      stage: build(:stage, summary: codeable_concept_coding(system: "eHealth/condition_stages")),
      evidences: [
        build(
          :evidence,
          codes: [codeable_concept_coding(system: "eHealth/ICPC2/conditions", code: "condition")],
          details: [reference_coding(code: "observation")]
        )
      ],
      patient_id: patient_id,
      inserted_by: Mongo.string_to_uuid(user_id),
      updated_by: Mongo.string_to_uuid(user_id),
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now(),
      source: build(:source, type: "asserter", value: reference_coding(system: "eHealth/resources", code: "employee")),
      primary_source: true
    }
  end

  def status_history_factory do
    %StatusHistory{
      status: Episode.status(:active),
      inserted_at: DateTime.utc_now(),
      inserted_by: Mongo.string_to_uuid(UUID.uuid4())
    }
  end

  def reference_coding(attrs) do
    build(:reference, identifier: build(:identifier, type: codeable_concept_coding(attrs)))
  end

  def codeable_concept_coding(attrs) do
    build(:codeable_concept, coding: [build(:coding, attrs)])
  end

  def insert(factory, args \\ [])

  def insert(:job, args) do
    :job
    |> build(args)
    |> Job.encode_response()
    |> insert_entity()
  end

  def insert(factory, args) do
    factory
    |> build(args)
    |> insert_entity()
  end

  def insert_list(count, factory, args \\ []) do
    for _ <- 1..count, do: insert(factory, args)
  end

  defp insert_entity(entity) do
    {:ok, _} = Mongo.insert_one(entity)
    entity
  end
end
