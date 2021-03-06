defmodule Core.Patients do
  @moduledoc false

  use Confex, otp_app: :core

  alias Core.Condition
  alias Core.DiagnosesHistory
  alias Core.DigitalSignature
  alias Core.Encounter
  alias Core.Encryptor
  alias Core.Episode
  alias Core.Immunization
  alias Core.Jobs
  alias Core.Jobs.PackageCancelJob
  alias Core.Jobs.PackageCreateJob
  alias Core.Mongo
  alias Core.Observation
  alias Core.Patient
  alias Core.Patients.AllergyIntolerances
  alias Core.Patients.Devices
  alias Core.Patients.DiagnosticReports
  alias Core.Patients.Encounters
  alias Core.Patients.Encounters.Cancel, as: CancelEncounter
  alias Core.Patients.Encounters.Validations, as: EncounterValidations
  alias Core.Patients.Episodes
  alias Core.Patients.Immunizations
  alias Core.Patients.MedicationStatements
  alias Core.Patients.Package
  alias Core.Patients.RiskAssessments
  alias Core.ValidationError, as: CoreValidationError
  alias Core.Validators.Error
  alias Core.Validators.JsonSchema
  alias Core.Validators.OneOf
  alias Core.Validators.Patient, as: PatientValidator
  alias Core.Visit
  alias Ecto.Changeset
  alias EView.Views.ValidationError

  require Logger

  @collection Patient.collection()
  @media_storage Application.get_env(:core, :microservices)[:media_storage]
  @kafka_producer Application.get_env(:core, :kafka)[:producer]

  @one_of_request_params %{
    "$.conditions" => %{"params" => ["report_origin", "asserter"], "required" => true},
    "$.observations" => [
      %{"params" => ["report_origin", "performer"], "required" => true},
      %{"params" => ["effective_date_time", "effective_period"], "required" => false},
      %{
        "params" => [
          "value_quantity",
          "value_codeable_concept",
          "value_sampled_data",
          "value_string",
          "value_boolean",
          "value_range",
          "value_ratio",
          "value_time",
          "value_date_time",
          "value_period"
        ],
        "required" => true
      }
    ],
    "$.observations.components" => %{
      "params" => [
        "value_quantity",
        "value_codeable_concept",
        "value_sampled_data",
        "value_string",
        "value_boolean",
        "value_range",
        "value_ratio",
        "value_time",
        "value_date_time",
        "value_period"
      ],
      "required" => true
    },
    "$.immunizations" => %{"params" => ["report_origin", "performer"], "required" => true},
    "$.immunizations.explanation" => %{
      "params" => ["reasons", "reasons_not_given"],
      "required" => false
    },
    "$.allergy_intolerances" => %{"params" => ["report_origin", "asserter"], "required" => true},
    "$.risk_assessments.predictions" => [
      %{"params" => ["probability_range", "probability_decimal"], "required" => false},
      %{"params" => ["when_range", "when_period"], "required" => false}
    ],
    "$.devices" => %{"params" => ["report_origin", "asserter"], "required" => true},
    "$.medication_statements" => %{"params" => ["report_origin", "asserter"], "required" => true},
    "$.diagnostic_reports.results_interpreter" => %{
      "params" => ["reference", "text"],
      "required" => true
    },
    "$.diagnostic_reports.performer" => %{"params" => ["reference", "text"], "required" => true}
  }

  def get_pk_hash(nil), do: nil

  def get_pk_hash(value) do
    Encryptor.encrypt(value)
  end

  def get_by_id(id, opts \\ []) do
    Mongo.find_one(@collection, %{"_id" => id}, opts)
  end

  def produce_create_package(%{"patient_id_hash" => patient_id_hash} = params, user_id, client_id) do
    with %{"status" => patient_status} <- get_by_id(patient_id_hash, projection: [status: true]),
         :ok <- PatientValidator.is_active(patient_status),
         :ok <- JsonSchema.validate(:package_create, Map.take(params, ["signed_data", "visit"])),
         {:ok, job, package_create_job} <-
           Jobs.create(
             user_id,
             patient_id_hash,
             PackageCreateJob,
             params |> Map.put("user_id", user_id) |> Map.put("client_id", client_id)
           ),
         :ok <- @kafka_producer.publish_medical_event(package_create_job) do
      {:ok, job}
    end
  end

  def produce_cancel_package(%{"patient_id_hash" => patient_id_hash} = params, user_id, client_id) do
    with :ok <- JsonSchema.validate(:package_cancel, Map.take(params, ["signed_data"])),
         %{"status" => patient_status} <- get_by_id(patient_id_hash, projection: [status: true]),
         :ok <- PatientValidator.is_active(patient_status) do
      job_data =
        params
        |> Map.put("user_id", user_id)
        |> Map.put("client_id", client_id)

      with {:ok, job, package_cancel_job} <-
             Jobs.create(user_id, patient_id_hash, PackageCancelJob, job_data),
           :ok <- @kafka_producer.publish_medical_event(package_cancel_job) do
        {:ok, job}
      end
    end
  end

  def consume_cancel_package(%PackageCancelJob{patient_id_hash: patient_id_hash, user_id: user_id} = job) do
    with {:ok, %{content: content, signer: signer}} <- DigitalSignature.decode_and_validate(job.signed_data),
         :ok <- JsonSchema.validate(:package_cancel_signed_content, content),
         :ok <- OneOf.validate(content, @one_of_request_params),
         employee_id <- get_in(content, ["encounter", "performer", "identifier", "value"]),
         encounter_id <- content["encounter"]["id"],
         :ok <- validate_signatures(signer, employee_id, user_id, job.client_id),
         {_, %{} = patient} <- {:patient, get_by_id(patient_id_hash)},
         {_, {:ok, %Encounter{} = encounter}} <-
           {:encounter, Encounters.get_by_id(patient_id_hash, encounter_id)},
         {_, {:ok, %Episode{} = episode}} <-
           {:episode, Episodes.get_by_id(patient_id_hash, to_string(encounter.episode.identifier.value))},
         :ok <-
           CancelEncounter.validate(content, episode, encounter, patient_id_hash, job.client_id),
         :ok <- CancelEncounter.save(patient, content, episode, encounter_id, job) do
      :ok
    else
      {:patient, _} ->
        Jobs.produce_update_status(job, "Patient not found", 404)

      {:episode, _} ->
        Jobs.produce_update_status(job, "Encounter's episode not found", 404)

      {:encounter, _} ->
        Jobs.produce_update_status(job, "Encounter not found", 404)

      {:error, error} ->
        Jobs.produce_update_status(job, ValidationError.render("422.json", %{schema: error}), 422)

      {_, response, status_code} ->
        Jobs.produce_update_status(job, response, status_code)
    end
  end

  def consume_create_package(%PackageCreateJob{patient_id: patient_id, user_id: user_id} = job) do
    schema =
      if Confex.fetch_env!(:core, :encounter_package)[:use_encounter_package_short_schema] do
        :package_create_signed_content_short
      else
        :package_create_signed_content
      end

    with {:ok, %{content: content, signer: signer}} <- DigitalSignature.decode_and_validate(job.signed_data),
         :ok <- JsonSchema.validate(schema, content),
         :ok <- OneOf.validate(content, @one_of_request_params),
         employee_id <- get_in(content, ["encounter", "performer", "identifier", "value"]),
         :ok <- validate_signatures(signer, employee_id, user_id, job.client_id) do
      with {:ok, visit} <- create_visit(job),
           {:ok, diagnostic_reports} <- create_diagnostic_reports(job, content),
           {:ok, observations} <- create_observations(job, content, diagnostic_reports),
           {:ok, conditions} <- create_conditions(job, content, observations),
           {:ok, encounter, diagnoses_history} <-
             create_encounter(job, content, conditions, visit),
           {:ok, immunizations, immunization_updates} <-
             create_immunizations(job, content, observations),
           {:ok, allergy_intolerances} <- create_allergy_intolerances(job, content),
           {:ok, risk_assessments} <-
             create_risk_assessments(job, observations, conditions, diagnostic_reports, content),
           {:ok, devices} <- create_devices(job, content),
           {:ok, medication_statements} <- create_medication_statements(job, content) do
        encounter =
          encounter
          |> Encounter.fill_up_performer()
          |> Encounter.fill_up_diagnoses_codes()

        resource_name = "#{encounter.id}/create"
        files = [{'signed_content.txt', job.signed_data}]
        {:ok, {_, compressed_content}} = :zip.create("signed_content.zip", files, [:memory])

        with :ok <-
               @media_storage.save(
                 patient_id,
                 compressed_content,
                 Confex.fetch_env!(:core, Core.Microservices.MediaStorage)[:encounter_bucket],
                 resource_name
               ) do
          encounter = %{encounter | signed_content_links: [resource_name]}

          Package.save(
            job,
            %{
              "visit" => visit,
              "encounter" => encounter,
              "diagnoses_history" => diagnoses_history,
              "immunizations" => immunizations,
              "immunization_updates" => immunization_updates,
              "allergy_intolerances" => allergy_intolerances,
              "risk_assessments" => risk_assessments,
              "devices" => devices,
              "medication_statements" => medication_statements,
              "diagnostic_reports" => diagnostic_reports,
              "observations" => observations,
              "conditions" => conditions
            }
          )
        else
          _ ->
            Jobs.produce_update_status(job, "Failed to save signed content", 500)
        end
      else
        # Invalid changeset
        %Changeset{valid?: false} = changeset ->
          Jobs.produce_update_status(job, ValidationError.render("422.json", changeset), 422)

        # All other errors
        {_, error, status_code} ->
          Jobs.produce_update_status(job, error, status_code)
      end
    else
      # Json schema error
      {:error, error} ->
        Jobs.produce_update_status(job, ValidationError.render("422.json", %{schema: error}), 422)

      # All other errors
      {_, response, status} ->
        Jobs.produce_update_status(job, response, status)
    end
  end

  defp create_visit(%PackageCreateJob{visit: nil}), do: {:ok, nil}

  defp create_visit(%PackageCreateJob{
         patient_id_hash: patient_id_hash,
         user_id: user_id,
         visit: visit
       }) do
    now = DateTime.utc_now()

    changeset =
      %Visit{}
      |> Visit.create_changeset(
        Map.merge(visit, %{
          "inserted_by" => user_id,
          "updated_by" => user_id,
          "inserted_at" => now,
          "updated_at" => now
        })
      )

    case changeset do
      %Changeset{valid?: true} ->
        visit = Changeset.apply_changes(changeset)

        result =
          Patient.collection()
          |> Mongo.aggregate([
            %{"$match" => %{"_id" => patient_id_hash}},
            %{"$project" => %{"_id" => "$visits.#{visit.id}.id"}}
          ])
          |> Enum.to_list()

        case result do
          [%{"_id" => _}] ->
            {:error, error} =
              Error.dump(%CoreValidationError{
                description: "Visit with such id already exists",
                path: "$.visit.id"
              })

            {:error, error, 422}

          _ ->
            {:ok, visit}
        end

      changeset ->
        changeset
    end
  end

  defp create_encounter(
         %PackageCreateJob{
           patient_id_hash: patient_id_hash,
           user_id: user_id,
           client_id: client_id
         },
         content,
         conditions,
         visit
       ) do
    now = DateTime.utc_now()

    encounter =
      Map.merge(content["encounter"], %{
        "inserted_by" => user_id,
        "updated_by" => user_id,
        "inserted_at" => now,
        "updated_at" => now
      })

    changeset =
      Package.encounter_changeset(
        %Package{},
        %{"encounter" => encounter},
        patient_id_hash,
        client_id,
        visit,
        conditions
      )

    case changeset do
      %Changeset{valid?: false} ->
        changeset

      _ ->
        package = Changeset.apply_changes(changeset)
        encounter = package.encounter

        diagnoses_history =
          DiagnosesHistory.create_changeset(%DiagnosesHistory{}, %{
            "date" => now,
            "evidence" => %{
              "identifier" => %{
                "type" => %{
                  "coding" => [
                    %{
                      "system" => "eHealth/resources",
                      "code" => "encounter"
                    }
                  ]
                },
                "value" => Mongo.string_to_uuid(encounter.id)
              }
            },
            "is_active" => true,
            "diagnoses" => content["encounter"]["diagnoses"]
          })

        case Encounters.get_by_id(patient_id_hash, encounter.id) do
          {:ok, _} ->
            {:error, error} =
              Error.dump(%CoreValidationError{
                description: "Encounter with such id already exists",
                path: "$.encounter.id"
              })

            {:error, error, 422}

          _ ->
            {:ok, encounter, diagnoses_history |> Changeset.apply_changes() |> Encounter.fill_up_diagnoses_codes()}
        end
    end
  end

  defp create_conditions(
         %PackageCreateJob{
           patient_id_hash: patient_id_hash,
           user_id: user_id,
           client_id: client_id
         },
         %{"conditions" => _} = content,
         observations
       ) do
    now = DateTime.utc_now()
    encounter_id = content["encounter"]["id"]
    episode_id = get_in(content, ~w(encounter episode identifier value))

    conditions =
      Enum.map(content["conditions"], fn data ->
        Map.merge(data, %{
          "inserted_by" => user_id,
          "updated_by" => user_id,
          "inserted_at" => now,
          "updated_at" => now,
          "patient_id" => patient_id_hash,
          "context_episode_id" => episode_id,
          "source" => Map.take(data, ~w(report_origin asserter))
        })
      end)

    changeset =
      Package.conditions_changeset(
        %Package{},
        %{"conditions" => conditions},
        patient_id_hash,
        observations,
        encounter_id,
        client_id
      )

    case changeset do
      %Changeset{valid?: false} ->
        changeset

      _ ->
        package = Changeset.apply_changes(changeset)

        package.conditions
        |> Enum.map(&Condition.fill_up_asserter/1)
        |> validate_conditions()
    end
  end

  defp create_conditions(_, _, _), do: {:ok, []}

  defp create_observations(
         %PackageCreateJob{
           patient_id_hash: patient_id_hash,
           user_id: user_id,
           client_id: client_id
         },
         %{"observations" => _} = content,
         diagnostic_reports
       ) do
    now = DateTime.utc_now()
    encounter_id = content["encounter"]["id"]
    episode_id = get_in(content, ~w(encounter episode identifier value))

    observations =
      Enum.map(content["observations"], fn data ->
        Map.merge(data, %{
          "inserted_by" => user_id,
          "updated_by" => user_id,
          "inserted_at" => now,
          "updated_at" => now,
          "patient_id" => patient_id_hash,
          "context_episode_id" => episode_id,
          "effective_at" => Map.take(data, ~w(effective_date_time effective_period)),
          "value" => Map.take(data, ~w(
            value_string
            value_time
            value_boolean
            value_date_time
            value_quantity
            value_codeable_concept
            value_sampled_data
            value_range
            value_ratio
            value_period
          )),
          "source" => Map.take(data, ~w(report_origin performer))
        })
      end)

    changeset =
      Package.observations_changeset(
        %Package{},
        %{"observations" => observations},
        patient_id_hash,
        diagnostic_reports,
        encounter_id,
        client_id
      )

    case changeset do
      %Changeset{valid?: false} ->
        changeset

      _ ->
        package = Changeset.apply_changes(changeset)

        package.observations
        |> Enum.map(&Observation.fill_up_performer/1)
        |> validate_observations()
    end
  end

  defp create_observations(_, _, _), do: {:ok, []}

  defp create_immunizations(
         %PackageCreateJob{
           patient_id_hash: patient_id_hash,
           user_id: user_id,
           client_id: client_id
         },
         content,
         observations
       ) do
    reactions =
      observations
      |> Enum.group_by(&Map.get(&1, :reaction_on), &Map.get(&1, :id))
      |> Enum.filter(fn {k, _} -> !is_nil(k) end)
      |> Enum.into(%{}, fn {reaction, observation_ids} ->
        {
          reaction.identifier.value,
          Enum.map(observation_ids, fn v ->
            %{
              "detail" => %{
                "identifier" => %{
                  "type" => %{
                    "coding" => [
                      %{
                        "system" => "eHealth/resources",
                        "code" => "observation"
                      }
                    ]
                  },
                  "value" => v
                }
              }
            }
          end)
        }
      end)

    now = DateTime.utc_now()
    encounter_id = content["encounter"]["id"]

    {immunizations, reactions} =
      Enum.reduce(content["immunizations"] || [], {[], reactions}, fn data, {immunizations, reactions_to_push} ->
        {immunization_reactions, reactions_to_push} = Map.pop(reactions_to_push, data["id"], [])

        immunization =
          Map.merge(data, %{
            "inserted_by" => user_id,
            "updated_by" => user_id,
            "inserted_at" => now,
            "updated_at" => now,
            "patient_id" => patient_id_hash,
            "reactions" => immunization_reactions,
            "source" => Map.take(data, ~w(report_origin performer))
          })

        {immunizations ++ [immunization], reactions_to_push}
      end)

    changeset =
      Package.immunizations_changeset(
        %Package{},
        %{"immunizations" => immunizations},
        patient_id_hash,
        observations,
        encounter_id,
        client_id
      )

    case changeset do
      %Changeset{valid?: false} ->
        changeset

      _ ->
        package = Changeset.apply_changes(changeset)

        with {:ok, immunization_updates} <-
               get_db_immunizations(patient_id_hash, Map.keys(reactions)),
             {:ok, immunizations} <-
               validate_immunizations(patient_id_hash, package.immunizations) do
          {
            :ok,
            immunizations,
            # This changeset should be always valid
            Enum.map(immunization_updates, fn immunization ->
              immunization
              |> Immunization.reactions_update_changeset(
                %{
                  "reactions" => reactions[to_string(immunization.id)],
                  "updated_at" => now,
                  "updated_by" => user_id
                },
                patient_id_hash,
                observations
              )
              |> Changeset.apply_changes()
            end)
          }
        end
    end
  end

  defp get_db_immunizations(patient_id_hash, ids) do
    case Immunizations.get_by_ids(patient_id_hash, ids) do
      {:ok, immunizations} -> {:ok, immunizations}
      {:error, message} -> {:error, message, 404}
    end
  end

  defp create_allergy_intolerances(
         %PackageCreateJob{
           patient_id_hash: patient_id_hash,
           user_id: user_id,
           client_id: client_id
         },
         %{"allergy_intolerances" => _} = content
       ) do
    now = DateTime.utc_now()
    encounter_id = content["encounter"]["id"]

    allergy_intolerances =
      Enum.map(content["allergy_intolerances"], fn data ->
        Map.merge(data, %{
          "inserted_by" => user_id,
          "updated_by" => user_id,
          "inserted_at" => now,
          "updated_at" => now,
          "source" => Map.take(data, ~w(report_origin asserter))
        })
      end)

    changeset =
      Package.allergy_intolerances_changeset(
        %Package{},
        %{"allergy_intolerances" => allergy_intolerances},
        encounter_id,
        client_id
      )

    case changeset do
      %Changeset{valid?: false} ->
        changeset

      _ ->
        package = Changeset.apply_changes(changeset)
        validate_allergy_intolerances(patient_id_hash, package.allergy_intolerances)
    end
  end

  defp create_allergy_intolerances(_, _), do: {:ok, []}

  defp create_risk_assessments(
         %PackageCreateJob{
           patient_id_hash: patient_id_hash,
           user_id: user_id,
           client_id: client_id
         },
         observations,
         conditions,
         diagnostic_reports,
         %{"risk_assessments" => _} = content
       ) do
    now = DateTime.utc_now()
    encounter_id = content["encounter"]["id"]

    risk_assessments =
      Enum.map(content["risk_assessments"], fn data ->
        Map.merge(data, %{
          "inserted_by" => user_id,
          "updated_by" => user_id,
          "inserted_at" => now,
          "updated_at" => now,
          "reason" => Map.take(data, ~w(reason_references reason_codes))
        })
      end)

    changeset =
      Package.risk_assessments_changeset(
        %Package{},
        %{"risk_assessments" => risk_assessments},
        patient_id_hash,
        observations,
        conditions,
        diagnostic_reports,
        encounter_id,
        client_id
      )

    case changeset do
      %Changeset{valid?: false} ->
        changeset

      _ ->
        package = Changeset.apply_changes(changeset)
        validate_risk_assessments(patient_id_hash, package.risk_assessments)
    end
  end

  defp create_risk_assessments(_, _, _, _, _), do: {:ok, []}

  defp create_devices(
         %PackageCreateJob{
           patient_id_hash: patient_id_hash,
           user_id: user_id,
           client_id: client_id
         },
         %{"devices" => _} = content
       ) do
    now = DateTime.utc_now()
    encounter_id = content["encounter"]["id"]

    devices =
      Enum.map(content["devices"], fn data ->
        Map.merge(data, %{
          "inserted_by" => user_id,
          "updated_by" => user_id,
          "inserted_at" => now,
          "updated_at" => now,
          "source" => Map.take(data, ~w(report_origin asserter))
        })
      end)

    changeset =
      Package.devices_changeset(
        %Package{},
        %{"devices" => devices},
        encounter_id,
        client_id
      )

    case changeset do
      %Changeset{valid?: false} ->
        changeset

      _ ->
        package = Changeset.apply_changes(changeset)
        validate_devices(patient_id_hash, package.devices)
    end
  end

  defp create_devices(_, _), do: {:ok, []}

  defp create_medication_statements(
         %PackageCreateJob{
           patient_id_hash: patient_id_hash,
           user_id: user_id,
           client_id: client_id
         },
         %{"medication_statements" => _} = content
       ) do
    now = DateTime.utc_now()
    encounter_id = content["encounter"]["id"]

    medication_statements =
      Enum.map(content["medication_statements"], fn data ->
        Map.merge(data, %{
          "inserted_by" => user_id,
          "updated_by" => user_id,
          "inserted_at" => now,
          "updated_at" => now,
          "source" => Map.take(data, ~w(report_origin asserter))
        })
      end)

    changeset =
      Package.medication_statements_changeset(
        %Package{},
        %{"medication_statements" => medication_statements},
        patient_id_hash,
        encounter_id,
        client_id
      )

    case changeset do
      %Changeset{valid?: false} ->
        changeset

      _ ->
        package = Changeset.apply_changes(changeset)
        validate_medication_statements(patient_id_hash, package.medication_statements)
    end
  end

  defp create_medication_statements(_, _), do: {:ok, []}

  defp create_diagnostic_reports(
         %PackageCreateJob{
           patient_id_hash: patient_id_hash,
           user_id: user_id,
           client_id: client_id
         },
         %{"diagnostic_reports" => _} = content
       ) do
    now = DateTime.utc_now()
    encounter_id = content["encounter"]["id"]

    diagnostic_reports =
      Enum.map(content["diagnostic_reports"], fn data ->
        Map.merge(data, %{
          "inserted_by" => user_id,
          "updated_by" => user_id,
          "inserted_at" => now,
          "updated_at" => now,
          "effective" => Map.take(data, ~w(effective_date_time effective_period)),
          "source" => Map.take(data, ~w(performer report_origin))
        })
      end)

    changeset =
      Package.diagnostic_reports_changeset(
        %Package{},
        %{"diagnostic_reports" => diagnostic_reports},
        client_id,
        encounter_id,
        content["observations"]
      )

    case changeset do
      %Changeset{valid?: false} ->
        changeset

      _ ->
        package = Changeset.apply_changes(changeset)
        validate_diagnostic_reports(patient_id_hash, package.diagnostic_reports)
    end
  end

  defp create_diagnostic_reports(_, _), do: {:ok, []}

  defp validate_conditions(conditions) do
    conditions
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, conditions}, fn {condition, i}, acc ->
      if Mongo.find_one(
           Condition.collection(),
           %{"_id" => Mongo.string_to_uuid(condition._id)},
           projection: %{"_id" => true}
         ) do
        {:error, error} =
          Error.dump(%CoreValidationError{
            description: "Condition with id '#{condition._id}' already exists",
            path: "$.conditions.#{i}.id"
          })

        {:halt, {:error, error, 422}}
      else
        {:cont, acc}
      end
    end)
  end

  defp validate_observations(observations) do
    observations
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, observations}, fn {observation, i}, acc ->
      if Mongo.find_one(
           Observation.collection(),
           %{"_id" => Mongo.string_to_uuid(observation._id)},
           projection: %{"_id" => true}
         ) do
        {:error, error} =
          Error.dump(%CoreValidationError{
            description: "Observation with id '#{observation._id}' already exists",
            path: "$.observations.#{i}.id"
          })

        {:halt, {:error, error, 422}}
      else
        {:cont, acc}
      end
    end)
  end

  defp validate_immunizations(patient_id_hash, immunizations) do
    immunizations
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, immunizations}, fn {immunization, i}, acc ->
      case Immunizations.get_by_id(patient_id_hash, immunization.id) do
        {:ok, _} ->
          {:error, error} =
            Error.dump(%CoreValidationError{
              description: "Immunization with id '#{immunization.id}' already exists",
              path: "$.immunizations.#{i}.id"
            })

          {:halt, {:error, error, 422}}

        _ ->
          {:cont, acc}
      end
    end)
  end

  defp validate_allergy_intolerances(patient_id_hash, allergy_intolerances) do
    allergy_intolerances
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, allergy_intolerances}, fn {allergy_intolerance, i}, acc ->
      case AllergyIntolerances.get_by_id(patient_id_hash, allergy_intolerance.id) do
        {:ok, _} ->
          {:error, error} =
            Error.dump(%CoreValidationError{
              description: "Allergy intolerance with id '#{allergy_intolerance.id}' already exists",
              path: "$.allergy_intolerances.#{i}.id"
            })

          {:halt, {:error, error, 422}}

        _ ->
          {:cont, acc}
      end
    end)
  end

  defp validate_risk_assessments(patient_id_hash, risk_assessments) do
    risk_assessments
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, risk_assessments}, fn {risk_assessment, i}, acc ->
      case RiskAssessments.get_by_id(patient_id_hash, risk_assessment.id) do
        {:ok, _} ->
          {:error, error} =
            Error.dump(%CoreValidationError{
              description: "Risk assessment with id '#{risk_assessment.id}' already exists",
              path: "$.risk_assessments.#{i}.id"
            })

          {:halt, {:error, error, 422}}

        _ ->
          {:cont, acc}
      end
    end)
  end

  defp validate_devices(patient_id_hash, devices) do
    devices
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, devices}, fn {device, i}, acc ->
      case Devices.get_by_id(patient_id_hash, device.id) do
        {:ok, _} ->
          {:error, error} =
            Error.dump(%CoreValidationError{
              description: "Device with id '#{device.id}' already exists",
              path: "$.devices.#{i}.id"
            })

          {:halt, {:error, error, 422}}

        _ ->
          {:cont, acc}
      end
    end)
  end

  defp validate_medication_statements(patient_id_hash, medication_statements) do
    medication_statements
    |> Enum.with_index()
    |> Enum.reduce_while(
      {:ok, medication_statements},
      fn {medication_statement, i}, acc ->
        case MedicationStatements.get_by_id(patient_id_hash, medication_statement.id) do
          {:ok, _} ->
            {:error, error} =
              Error.dump(%CoreValidationError{
                description: "Medication statement with id '#{medication_statement.id}' already exists",
                path: "$.medication_statements.#{i}.id"
              })

            {:halt, {:error, error, 422}}

          _ ->
            {:cont, acc}
        end
      end
    )
  end

  defp validate_diagnostic_reports(patient_id_hash, diagnostic_reports) do
    diagnostic_reports
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, diagnostic_reports}, fn {diagnostic_report, i}, acc ->
      case DiagnosticReports.get_by_id(patient_id_hash, diagnostic_report.id) do
        {:ok, _} ->
          {:error, error} =
            Error.dump(%CoreValidationError{
              description: "Diagnostic report with id '#{diagnostic_report.id}' already exists",
              path: "$.diagnostic_reports.#{i}.id"
            })

          {:halt, {:error, error, 422}}

        _ ->
          {:cont, acc}
      end
    end)
  end

  defp validate_signatures(signer, employee_id, user_id, client_id) do
    EncounterValidations.validate_signatures(signer, employee_id, user_id, client_id)
  end
end
