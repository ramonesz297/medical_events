defmodule Api.Web.EncounterControllerTest do
  @moduledoc false

  use ApiWeb.ConnCase
  alias Core.Patient
  alias Core.Patients
  import Core.TestViews.CancelEncounterPackageView
  import Mox

  @status_error "entered_in_error"

  describe "create visit" do
    test "patient not found", %{conn: conn} do
      conn = post(conn, encounter_path(conn, :create, UUID.uuid4()))
      assert json_response(conn, 404)
    end

    test "patient is not active", %{conn: conn} do
      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)

      insert(:patient, status: Patient.status(:inactive), _id: patient_id_hash)

      conn = post(conn, encounter_path(conn, :create, patient_id))
      assert json_response(conn, 409)
    end

    test "no signed data set", %{conn: conn} do
      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)

      insert(:patient, _id: patient_id_hash)

      conn = post(conn, encounter_path(conn, :create, patient_id))
      assert response = json_response(conn, 422)

      assert [
               %{
                 "entry" => "$.signed_data",
                 "entry_type" => "json_data_property",
                 "rules" => [
                   %{
                     "description" => "required property signed_data was not present",
                     "params" => [],
                     "rule" => "required"
                   }
                 ]
               }
             ] = response["error"]["invalid"]
    end

    test "success create visit", %{conn: conn} do
      stub(KafkaMock, :publish_medical_event, fn _ -> :ok end)

      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)

      insert(:patient, _id: patient_id_hash)
      now = DateTime.utc_now()

      expect(WorkerMock, :run, fn _, _, :transaction, args ->
        assert %{
                 "actor_id" => _,
                 "operations" => [%{"collection" => "jobs", "operation" => "insert"}]
               } = Jason.decode!(args)

        :ok
      end)

      assert conn
             |> post(encounter_path(conn, :create, patient_id), %{
               "visit" => %{
                 "id" => UUID.uuid4(),
                 "period" => %{"start" => DateTime.to_iso8601(now), "end" => DateTime.to_iso8601(now)}
               },
               "signed_data" => Base.encode64(Jason.encode!(%{}))
             })
             |> json_response(202)
             |> Map.get("data")
             |> assert_json_schema("jobs/job_details_pending.json")
    end
  end

  describe "show encounter" do
    test "successful show", %{conn: conn} do
      encounter_1 = build(:encounter)
      encounter_2 = build(:encounter)

      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)

      insert(
        :patient,
        _id: patient_id_hash,
        encounters: %{
          UUID.binary_to_string!(encounter_1.id.binary) => encounter_1,
          UUID.binary_to_string!(encounter_2.id.binary) => encounter_2
        }
      )

      assert conn
             |> get(encounter_path(conn, :show, patient_id, UUID.binary_to_string!(encounter_1.id.binary)))
             |> json_response(200)
             |> Map.get("data")
             |> assert_json_schema("encounters/encounter_show.json")
    end

    test "invalid patient uuid", %{conn: conn} do
      conn
      |> get(encounter_path(conn, :show, UUID.uuid4(), UUID.uuid4()))
      |> json_response(404)
    end

    test "invalid encounter uuid", %{conn: conn} do
      encounter = build(:encounter)

      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)

      insert(:patient, _id: patient_id_hash, encounters: %{UUID.binary_to_string!(encounter.id.binary) => encounter})

      conn
      |> get(encounter_path(conn, :show, patient_id, UUID.uuid4()))
      |> json_response(404)
    end

    test "get patient when no encounters", %{conn: conn} do
      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)

      insert(:patient, _id: patient_id_hash, encounters: %{})

      conn
      |> get(encounter_path(conn, :show, patient_id, UUID.uuid4()))
      |> json_response(404)
    end

    test "success show encounter in episode context", %{conn: conn} do
      encounter_1 = build(:encounter)
      encounter_2 = build(:encounter)

      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)

      insert(
        :patient,
        _id: patient_id_hash,
        encounters: %{
          to_string(encounter_1.id) => encounter_1,
          to_string(encounter_2.id) => encounter_2
        }
      )

      assert conn
             |> get(
               episode_context_encounter_path(
                 conn,
                 :show_by_episode,
                 patient_id,
                 to_string(encounter_1.episode.identifier.value),
                 to_string(encounter_1.id)
               )
             )
             |> json_response(200)
             |> Map.get("data")
             |> assert_json_schema("encounters/encounter_show.json")
    end

    test "encounter not found in episode context", %{conn: conn} do
      encounter_1 = build(:encounter)
      encounter_2 = build(:encounter)

      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)

      insert(
        :patient,
        _id: patient_id_hash,
        encounters: %{
          to_string(encounter_1.id) => encounter_1,
          to_string(encounter_2.id) => encounter_2
        }
      )

      assert conn
             |> get(
               episode_context_encounter_path(
                 conn,
                 :show_by_episode,
                 patient_id,
                 to_string(encounter_2.episode.identifier.value),
                 to_string(encounter_1.id)
               )
             )
             |> json_response(404)
    end
  end

  describe "index encounter" do
    test "successful search", %{conn: conn} do
      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)

      insert(:patient, _id: patient_id_hash)

      resp =
        conn
        |> get(encounter_path(conn, :index, patient_id))
        |> json_response(200)

      Enum.each(resp["data"], &assert_json_schema(&1, "encounters/encounter_show.json"))
      assert %{"page_number" => 1, "total_entries" => 2, "total_pages" => 1} = resp["paging"]
    end

    test "successful search in episode context", %{conn: conn} do
      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)

      encounter1 = build(:encounter)
      encounter2 = build(:encounter)

      insert(:patient,
        _id: patient_id_hash,
        encounters: %{
          to_string(encounter1.id) => encounter1,
          to_string(encounter2.id) => encounter2
        }
      )

      resp =
        conn
        |> get(episode_context_encounter_path(conn, :index, patient_id, to_string(encounter1.episode.identifier.value)))
        |> json_response(200)

      Enum.each(resp["data"], &assert_json_schema(&1, "encounters/encounter_show.json"))
      assert %{"page_number" => 1, "total_entries" => 1, "total_pages" => 1} = resp["paging"]
    end

    test "successful search with search parameters", %{conn: conn} do
      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)

      episode = build(:reference)
      date_from = Date.utc_today() |> Date.add(-20) |> Date.to_iso8601()
      date_to = Date.utc_today() |> Date.add(-10) |> Date.to_iso8601()
      service_request_id = UUID.uuid4()

      service_request1 =
        build(:reference,
          identifier:
            build(:identifier,
              type: codeable_concept_coding(system: "eHealth/resources", code: "service_request"),
              value: Mongo.string_to_uuid(service_request_id)
            )
        )

      service_request2 =
        build(:reference,
          identifier:
            build(:identifier,
              type: codeable_concept_coding(system: "eHealth/resources", code: "service_request"),
              value: Mongo.string_to_uuid(UUID.uuid4())
            )
        )

      encounter_1 = build(:encounter, date: get_datetime(-15), episode: episode, incoming_referral: service_request1)
      encounter_2 = build(:encounter, date: get_datetime(-15), episode: episode, incoming_referral: service_request2)
      encounter_3 = build(:encounter, date: get_datetime(-15))
      encounter_4 = build(:encounter, date: get_datetime())

      encounters =
        [encounter_1, encounter_2, encounter_3, encounter_4]
        |> Enum.into(%{}, fn %{id: %BSON.Binary{binary: id}} = encounter ->
          {UUID.binary_to_string!(id), encounter}
        end)

      insert(:patient, _id: patient_id_hash, encounters: encounters)

      search_params = %{
        "episode_id" => UUID.binary_to_string!(episode.identifier.value.binary),
        "date_from" => date_from,
        "date_to" => date_to,
        "incoming_referral_id" => service_request_id
      }

      resp =
        conn
        |> get(encounter_path(conn, :index, patient_id), search_params)
        |> json_response(200)

      Enum.each(resp["data"], &assert_json_schema(&1, "encounters/encounter_show.json"))
      assert %{"page_number" => 1, "total_entries" => 1, "total_pages" => 1} = resp["paging"]

      encounter = hd(resp["data"])
      assert encounter["id"] == UUID.binary_to_string!(encounter_1.id.binary)
      refute encounter["id"] == UUID.binary_to_string!(encounter_2.id.binary)
      refute encounter["id"] == UUID.binary_to_string!(encounter_3.id.binary)
      refute encounter["id"] == UUID.binary_to_string!(encounter_4.id.binary)

      {:ok, datetime, _} = DateTime.from_iso8601(encounter["date"])
      assert Date.compare(Date.from_iso8601!(date_from), DateTime.to_date(datetime)) in [:lt, :eq]

      assert Date.compare(Date.from_iso8601!(date_to), DateTime.to_date(datetime)) in [:gt, :eq]

      assert get_in(encounter, ~w(episode identifier value)) == UUID.binary_to_string!(episode.identifier.value.binary)
    end

    test "invalid patient uuid", %{conn: conn} do
      assert %{"data" => []} =
               conn
               |> get(encounter_path(conn, :index, UUID.uuid4()))
               |> json_response(200)
    end

    test "get patient when no encounters", %{conn: conn} do
      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)

      insert(:patient, _id: patient_id_hash, encounters: %{})

      resp =
        conn
        |> get(encounter_path(conn, :index, patient_id))
        |> json_response(200)

      Enum.each(resp["data"], &assert_json_schema(&1, "encounters/encounter_show.json"))
      assert %{"page_number" => 1, "total_entries" => 0, "total_pages" => 0} = resp["paging"]
    end

    test "get patient when encounters list is null", %{conn: conn} do
      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)

      insert(:patient, _id: patient_id_hash, encounters: nil)

      resp =
        conn
        |> get(encounter_path(conn, :index, patient_id))
        |> json_response(200)

      Enum.each(resp["data"], &assert_json_schema(&1, "encounters/encounter_show.json"))
      assert %{"page_number" => 1, "total_entries" => 0, "total_pages" => 0} = resp["paging"]
    end
  end

  describe "cancel encounter" do
    setup %{conn: conn} do
      {:ok, conn: put_consumer_id_header(conn)}
    end

    test "success", %{conn: conn} do
      episode = build(:episode)
      encounter = build(:encounter, episode: reference_coding(episode.id, code: "episode"))
      context = reference_coding(encounter.id, code: "encounter")

      expect(KafkaMock, :publish_medical_event, fn _ -> :ok end)

      immunization = build(:immunization, context: context, status: @status_error)
      allergy_intolerance = build(:allergy_intolerance, context: context)
      allergy_intolerance2 = build(:allergy_intolerance)

      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)

      insert(
        :patient,
        _id: patient_id_hash,
        episodes: %{UUID.binary_to_string!(episode.id.binary) => episode},
        encounters: %{UUID.binary_to_string!(encounter.id.binary) => encounter},
        immunizations: %{UUID.binary_to_string!(immunization.id.binary) => immunization},
        allergy_intolerances: %{
          UUID.binary_to_string!(allergy_intolerance.id.binary) => allergy_intolerance,
          UUID.binary_to_string!(allergy_intolerance2.id.binary) => allergy_intolerance2
        }
      )

      condition =
        insert(
          :condition,
          patient_id: patient_id_hash,
          context: context,
          verification_status: @status_error
        )

      observation = insert(:observation, patient_id: patient_id_hash, context: context)

      request_data = %{
        "signed_data" =>
          %{
            "encounter" => render(:encounter, encounter),
            "conditions" => render(:conditions, [condition]),
            "observations" => render(:observations, [observation]),
            "immunizations" => render(:immunizations, [immunization]),
            "allergy_intolerances" => render(:allergy_intolerances, [allergy_intolerance])
          }
          |> Jason.encode!()
          |> Base.encode64()
      }

      expect(WorkerMock, :run, fn _, _, :transaction, args ->
        assert %{
                 "actor_id" => _,
                 "operations" => [%{"collection" => "jobs", "operation" => "insert"}]
               } = Jason.decode!(args)

        :ok
      end)

      assert conn
             |> patch(encounter_path(conn, :cancel, patient_id), request_data)
             |> json_response(202)
             |> get_in(["data", "status"])
             |> Kernel.==("pending")
    end

    test "fail on invalid signed content", %{conn: conn} do
      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)

      insert(:patient, _id: patient_id_hash)

      assert conn
             |> patch(encounter_path(conn, :cancel, patient_id), %{"invalid_signed_data" => 1})
             |> json_response(422)
             |> get_in(["error", "message"])
             |> String.contains?("Validation failed.")
    end
  end

  defp get_datetime(day_shift \\ 0) do
    date = Date.utc_today() |> Date.add(day_shift) |> Date.to_erl()
    {date, {0, 0, 0}} |> NaiveDateTime.from_erl!() |> DateTime.from_naive!("Etc/UTC")
  end
end
