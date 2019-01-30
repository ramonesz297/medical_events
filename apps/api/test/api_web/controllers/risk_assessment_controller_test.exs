defmodule Api.Web.RiskAssessmentControllerTest do
  @moduledoc false

  use ApiWeb.ConnCase

  import Core.Expectations.CasherExpectation
  import Mox

  alias Core.Patients

  describe "show risk assessment" do
    test "successful show", %{conn: conn} do
      expect(KafkaMock, :publish_mongo_event, fn _event -> :ok end)

      risk_assessment_in = build(:risk_assessment)
      risk_assessment_out = build(:risk_assessment)

      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)

      insert(
        :patient,
        _id: patient_id_hash,
        risk_assessments: %{
          UUID.binary_to_string!(risk_assessment_in.id.binary) => risk_assessment_in,
          UUID.binary_to_string!(risk_assessment_out.id.binary) => risk_assessment_out
        }
      )

      expect_get_person_data(patient_id)

      resp =
        conn
        |> get(risk_assessment_path(conn, :show, patient_id, UUID.binary_to_string!(risk_assessment_in.id.binary)))
        |> json_response(200)

      resp
      |> Map.take(["data"])
      |> assert_json_schema("risk_assessments/risk_assessment_show.json")

      assert get_in(resp, ~w(data id)) == UUID.binary_to_string!(risk_assessment_in.id.binary)
      refute get_in(resp, ~w(data id)) == UUID.binary_to_string!(risk_assessment_out.id.binary)
    end

    test "invalid patient uuid", %{conn: conn} do
      expect(KafkaMock, :publish_mongo_event, 2, fn _event -> :ok end)
      expect_get_person_data_empty()

      conn
      |> get(risk_assessment_path(conn, :show, UUID.uuid4(), UUID.uuid4()))
      |> json_response(403)
    end

    test "invalid risk assessment uuid", %{conn: conn} do
      expect(KafkaMock, :publish_mongo_event, 2, fn _event -> :ok end)

      risk_assessment = build(:risk_assessment)

      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)

      insert(
        :patient,
        _id: patient_id_hash,
        risk_assessments: %{UUID.binary_to_string!(risk_assessment.id.binary) => risk_assessment}
      )

      expect_get_person_data(patient_id)

      conn
      |> get(risk_assessment_path(conn, :show, patient_id, UUID.uuid4()))
      |> json_response(404)
    end

    test "get patient when no risk assessments", %{conn: conn} do
      expect(KafkaMock, :publish_mongo_event, 2, fn _event -> :ok end)

      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)

      insert(:patient, _id: patient_id_hash, risk_assessments: %{})
      expect_get_person_data(patient_id)

      conn
      |> get(risk_assessment_path(conn, :show, patient_id, UUID.uuid4()))
      |> json_response(404)
    end
  end

  describe "index risk assessments" do
    test "successful search", %{conn: conn} do
      expect(KafkaMock, :publish_mongo_event, 2, fn _event -> :ok end)

      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)

      insert(:patient, _id: patient_id_hash)
      expect_get_person_data(patient_id)

      resp =
        conn
        |> get(risk_assessment_path(conn, :index, patient_id))
        |> json_response(200)

      resp
      |> Map.take(["data"])
      |> assert_json_schema("risk_assessments/risk_assessment_list.json")

      assert %{"page_number" => 1, "total_entries" => 2, "total_pages" => 1} = resp["paging"]
    end

    test "successful search with search parameters: encounter_id", %{conn: conn} do
      expect(KafkaMock, :publish_mongo_event, 2, fn _event -> :ok end)

      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)

      encounter_id = UUID.uuid4()
      context = build_encounter_context(Mongo.string_to_uuid(encounter_id))
      risk_assessment_in = build(:risk_assessment, context: context)
      risk_assessment_out = build(:risk_assessment)

      risk_assessments =
        [risk_assessment_in, risk_assessment_out]
        |> Enum.into(%{}, fn %{id: %BSON.Binary{binary: id}} = risk_assessment ->
          {UUID.binary_to_string!(id), risk_assessment}
        end)

      insert(:patient, _id: patient_id_hash, risk_assessments: risk_assessments)
      expect_get_person_data(patient_id)

      search_params = %{"encounter_id" => encounter_id}

      resp =
        conn
        |> get(risk_assessment_path(conn, :index, patient_id), search_params)
        |> json_response(200)

      resp
      |> Map.take(["data"])
      |> assert_json_schema("risk_assessments/risk_assessment_list.json")

      assert %{"page_number" => 1, "total_entries" => 1, "total_pages" => 1} = resp["paging"]

      resp =
        resp
        |> Map.get("data")
        |> hd()

      refute Map.get(resp, "id") == UUID.binary_to_string!(risk_assessment_out.id.binary)
      assert Map.get(resp, "id") == UUID.binary_to_string!(risk_assessment_in.id.binary)
      assert get_in(resp, ~w(context identifier value)) == encounter_id
    end

    test "successful search with search parameters: code", %{conn: conn} do
      expect(KafkaMock, :publish_mongo_event, 2, fn _event -> :ok end)

      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)

      code_value = "1"

      code =
        build(
          :codeable_concept,
          coding: [build(:coding, code: code_value, system: "eHealth/risk_assessment_codes")]
        )

      risk_assessment_in = build(:risk_assessment, code: code)
      risk_assessment_out = build(:risk_assessment)

      risk_assessments =
        [risk_assessment_in, risk_assessment_out]
        |> Enum.into(%{}, fn %{id: %BSON.Binary{binary: id}} = risk_assessment ->
          {UUID.binary_to_string!(id), risk_assessment}
        end)

      insert(:patient, _id: patient_id_hash, risk_assessments: risk_assessments)
      expect_get_person_data(patient_id)

      search_params = %{"code" => code_value}

      resp =
        conn
        |> get(risk_assessment_path(conn, :index, patient_id), search_params)
        |> json_response(200)

      resp
      |> Map.take(["data"])
      |> assert_json_schema("risk_assessments/risk_assessment_list.json")

      assert %{"page_number" => 1, "total_entries" => 1, "total_pages" => 1} = resp["paging"]

      resp =
        resp
        |> Map.get("data")
        |> hd()

      assert Map.get(resp, "id") == UUID.binary_to_string!(risk_assessment_in.id.binary)
      refute Map.get(resp, "id") == UUID.binary_to_string!(risk_assessment_out.id.binary)
    end

    test "successful search with search parameters: episode_id", %{conn: conn} do
      expect(KafkaMock, :publish_mongo_event, 2, fn _event -> :ok end)

      episode_in = build(:episode)
      episode_out = build(:episode)

      encounter_in = build(:encounter, episode: build(:reference, identifier: build(:identifier, value: episode_in.id)))
      encounter_out = build(:encounter)

      context = build_encounter_context(encounter_in.id)
      risk_assessment_in = build(:risk_assessment, context: context)
      risk_assessment_out = build(:risk_assessment)

      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)

      insert(
        :patient,
        _id: patient_id_hash,
        episodes: %{
          UUID.binary_to_string!(episode_in.id.binary) => episode_in,
          UUID.binary_to_string!(episode_out.id.binary) => episode_out
        },
        encounters: %{
          UUID.binary_to_string!(encounter_in.id.binary) => encounter_in,
          UUID.binary_to_string!(encounter_out.id.binary) => encounter_out
        },
        risk_assessments: %{
          UUID.binary_to_string!(risk_assessment_in.id.binary) => risk_assessment_in,
          UUID.binary_to_string!(risk_assessment_out.id.binary) => risk_assessment_out
        }
      )

      expect_get_person_data(patient_id)

      search_params = %{"episode_id" => UUID.binary_to_string!(episode_in.id.binary)}

      resp =
        conn
        |> get(risk_assessment_path(conn, :index, patient_id), search_params)
        |> json_response(200)

      resp
      |> Map.take(["data"])
      |> assert_json_schema("risk_assessments/risk_assessment_list.json")

      assert %{"page_number" => 1, "total_entries" => 1, "total_pages" => 1} = resp["paging"]

      resp =
        resp
        |> Map.get("data")
        |> hd()

      assert Map.get(resp, "id") == UUID.binary_to_string!(risk_assessment_in.id.binary)
      refute Map.get(resp, "id") == UUID.binary_to_string!(risk_assessment_out.id.binary)
    end

    test "successful search with search parameters: date", %{conn: conn} do
      expect(KafkaMock, :publish_mongo_event, 2, fn _event -> :ok end)

      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)

      asserted_date_from = Date.utc_today() |> Date.add(-20) |> Date.to_iso8601()
      asserted_date_to = Date.utc_today() |> Date.add(-10) |> Date.to_iso8601()

      risk_assessment_1 = build(:risk_assessment, asserted_date: get_datetime(-30))
      risk_assessment_2 = build(:risk_assessment, asserted_date: get_datetime(-20))
      risk_assessment_3 = build(:risk_assessment, asserted_date: get_datetime(-15))
      risk_assessment_4 = build(:risk_assessment, asserted_date: get_datetime(-10))
      risk_assessment_5 = build(:risk_assessment, asserted_date: get_datetime(-5))

      risk_assessments =
        [
          risk_assessment_1,
          risk_assessment_2,
          risk_assessment_3,
          risk_assessment_4,
          risk_assessment_5
        ]
        |> Enum.into(%{}, fn %{id: %BSON.Binary{binary: id}} = risk_assessment ->
          {UUID.binary_to_string!(id), risk_assessment}
        end)

      insert(:patient, _id: patient_id_hash, risk_assessments: risk_assessments)
      expect_get_person_data(patient_id, 4)

      call_endpoint = fn search_params ->
        conn
        |> get(risk_assessment_path(conn, :index, patient_id), search_params)
        |> json_response(200)
      end

      # both dates
      assert %{"page_number" => 1, "total_entries" => 3, "total_pages" => 1} =
               call_endpoint.(%{
                 "asserted_date_from" => asserted_date_from,
                 "asserted_date_to" => asserted_date_to
               })
               |> Map.get("paging")

      # date_from only
      assert %{"page_number" => 1, "total_entries" => 4, "total_pages" => 1} =
               call_endpoint.(%{"asserted_date_from" => asserted_date_from})
               |> Map.get("paging")

      # date_to only
      assert %{"page_number" => 1, "total_entries" => 4, "total_pages" => 1} =
               call_endpoint.(%{"asserted_date_to" => asserted_date_to})
               |> Map.get("paging")

      # without date search params
      assert %{"page_number" => 1, "total_entries" => 5, "total_pages" => 1} =
               call_endpoint.(%{})
               |> Map.get("paging")
    end

    test "successful search with search parameters: complex test", %{conn: conn} do
      expect(KafkaMock, :publish_mongo_event, 2, fn _event -> :ok end)

      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)

      code_value = "1"

      code =
        build(
          :codeable_concept,
          coding: [
            build(:coding, code: code_value, system: "eHealth/risk_assessment_codes"),
            build(:coding, code: "test", system: "eHealth/risk_assessment_codes")
          ]
        )

      asserted_date_from = Date.utc_today() |> Date.add(-20) |> Date.to_iso8601()
      asserted_date_to = Date.utc_today() |> Date.add(-10) |> Date.to_iso8601()

      encounter_id_1 = UUID.uuid4()
      context_encounter_id = build_encounter_context(Mongo.string_to_uuid(encounter_id_1))

      episode = build(:episode)
      encounter = build(:encounter, episode: build(:reference, identifier: build(:identifier, value: episode.id)))
      encounter_id_2 = UUID.binary_to_string!(encounter.id.binary)
      context_episode_id = build_encounter_context(Mongo.string_to_uuid(encounter_id_2))

      risk_assessment_in_1 =
        build(:risk_assessment, context: context_encounter_id, code: code, asserted_date: get_datetime(-15))

      risk_assessment_out_1 = build(:risk_assessment, context: context_encounter_id, asserted_date: get_datetime(-15))

      risk_assessment_out_2 = build(:risk_assessment, code: code, asserted_date: get_datetime(-15))

      risk_assessment_in_2 =
        build(:risk_assessment, context: context_episode_id, code: code, asserted_date: get_datetime(-15))

      risk_assessment_out_3 = build(:risk_assessment, asserted_date: get_datetime(-30))
      risk_assessment_out_4 = build(:risk_assessment, asserted_date: get_datetime(-15))
      risk_assessment_out_5 = build(:risk_assessment, asserted_date: get_datetime(-5))

      risk_assessments =
        [
          risk_assessment_in_1,
          risk_assessment_in_2,
          risk_assessment_out_1,
          risk_assessment_out_2,
          risk_assessment_out_3,
          risk_assessment_out_4,
          risk_assessment_out_5
        ]
        |> Enum.into(%{}, fn %{id: %BSON.Binary{binary: id}} = risk_assessment ->
          {UUID.binary_to_string!(id), risk_assessment}
        end)

      insert(
        :patient,
        _id: patient_id_hash,
        risk_assessments: risk_assessments,
        episodes: %{
          UUID.binary_to_string!(episode.id.binary) => episode
        },
        encounters: %{
          UUID.binary_to_string!(encounter.id.binary) => encounter
        }
      )

      expect_get_person_data(patient_id, 3)

      search_params = %{
        "encounter_id" => encounter_id_1,
        "code" => code_value,
        "episode_id" => UUID.binary_to_string!(episode.id.binary),
        "asserted_date_from" => asserted_date_from,
        "asserted_date_to" => asserted_date_to
      }

      call_endpoint = fn search_params ->
        conn
        |> get(risk_assessment_path(conn, :index, patient_id), search_params)
        |> json_response(200)
      end

      # all params
      assert %{"page_number" => 1, "total_entries" => 0, "total_pages" => 0} =
               call_endpoint.(search_params)
               |> Map.get("paging")

      # all params except encounter_id
      resp = call_endpoint.(Map.delete(search_params, "encounter_id"))

      assert %{"page_number" => 1, "total_entries" => 1, "total_pages" => 1} = resp["paging"]

      resp =
        resp
        |> Map.get("data")
        |> hd()

      assert Map.get(resp, "id") == UUID.binary_to_string!(risk_assessment_in_2.id.binary)
      assert get_in(resp, ~w(context identifier value)) == encounter_id_2

      # all params except episode_id
      resp = call_endpoint.(Map.delete(search_params, "episode_id"))

      assert %{"page_number" => 1, "total_entries" => 1, "total_pages" => 1} = resp["paging"]

      resp =
        resp
        |> Map.get("data")
        |> hd()

      assert Map.get(resp, "id") == UUID.binary_to_string!(risk_assessment_in_1.id.binary)
      assert get_in(resp, ~w(context identifier value)) == encounter_id_1
    end

    test "empty search list when episode_id not found in encounters", %{conn: conn} do
      expect(KafkaMock, :publish_mongo_event, 2, fn _event -> :ok end)

      episode_in = build(:episode)
      episode_out = build(:episode)

      encounter_in = build(:encounter, episode: build(:reference, identifier: build(:identifier, value: episode_in.id)))
      encounter_out = build(:encounter)

      context = build_encounter_context(encounter_in.id)
      risk_assessment_in = build(:risk_assessment, context: context)
      risk_assessment_out = build(:risk_assessment)

      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)

      insert(
        :patient,
        _id: patient_id_hash,
        episodes: %{
          UUID.binary_to_string!(episode_in.id.binary) => episode_in,
          UUID.binary_to_string!(episode_out.id.binary) => episode_out
        },
        encounters: %{
          UUID.binary_to_string!(encounter_in.id.binary) => encounter_in,
          UUID.binary_to_string!(encounter_out.id.binary) => encounter_out
        },
        risk_assessments: %{
          UUID.binary_to_string!(risk_assessment_in.id.binary) => risk_assessment_in,
          UUID.binary_to_string!(risk_assessment_out.id.binary) => risk_assessment_out
        }
      )

      expect_get_person_data(patient_id)

      search_params = %{"episode_id" => UUID.uuid4()}

      resp =
        conn
        |> get(risk_assessment_path(conn, :index, patient_id), search_params)
        |> json_response(200)

      resp
      |> Map.take(["data"])
      |> assert_json_schema("risk_assessments/risk_assessment_list.json")

      assert %{"page_number" => 1, "total_entries" => 0, "total_pages" => 0} = resp["paging"]
    end

    test "invalid search params", %{conn: conn} do
      expect(KafkaMock, :publish_mongo_event, 2, fn _event -> :ok end)

      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)

      insert(:patient, _id: patient_id_hash)
      expect_get_person_data(patient_id)

      search_params = %{
        "encounter_id" => "test",
        "code" => 12345,
        "episode_id" => "test",
        "asserted_date_from" => "2018-02-31",
        "asserted_date_to" => "2018-8-t"
      }

      resp =
        conn
        |> get(risk_assessment_path(conn, :index, patient_id), search_params)
        |> json_response(422)

      assert %{
               "invalid" => [
                 %{
                   "entry" => "$.asserted_date_from",
                   "entry_type" => "json_data_property",
                   "rules" => [
                     %{
                       "description" => "expected \"2018-02-31\" to be an existing date",
                       "params" => [],
                       "rule" => "date"
                     }
                   ]
                 },
                 %{
                   "entry" => "$.asserted_date_to",
                   "entry_type" => "json_data_property",
                   "rules" => [
                     %{
                       "description" => "expected \"2018-8-t\" to be a valid ISO 8601 date",
                       "params" => [
                         "~r/^([\\+-]?\\d{4}(?!\\d{2}\\b))((-?)((0[1-9]|1[0-2])(\\3([12]\\d|0[1-9]|3[01]))?|W([0-4]\\d|5[0-2])(-?[1-7])?|(00[1-9]|0[1-9]\\d|[12]\\d{2}|3([0-5]\\d|6[1-6])))?)?$/"
                       ],
                       "rule" => "date"
                     }
                   ]
                 },
                 %{
                   "entry" => "$.code",
                   "entry_type" => "json_data_property",
                   "rules" => [
                     %{
                       "description" => "type mismatch. Expected String but got Integer",
                       "params" => ["string"],
                       "rule" => "cast"
                     }
                   ]
                 },
                 %{
                   "entry" => "$.encounter_id",
                   "entry_type" => "json_data_property",
                   "rules" => [
                     %{
                       "description" =>
                         "string does not match pattern \"^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$\"",
                       "params" => ["^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"],
                       "rule" => "format"
                     }
                   ]
                 },
                 %{
                   "entry" => "$.episode_id",
                   "entry_type" => "json_data_property",
                   "rules" => [
                     %{
                       "description" =>
                         "string does not match pattern \"^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$\"",
                       "params" => ["^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"],
                       "rule" => "format"
                     }
                   ]
                 }
               ]
             } = resp["error"]
    end

    test "invalid patient uuid", %{conn: conn} do
      expect(KafkaMock, :publish_mongo_event, 2, fn _event -> :ok end)
      expect_get_person_data_empty()

      conn
      |> get(risk_assessment_path(conn, :index, UUID.uuid4()))
      |> json_response(403)
    end

    test "get patient when no risk assessments", %{conn: conn} do
      expect(KafkaMock, :publish_mongo_event, 2, fn _event -> :ok end)

      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)

      insert(:patient, _id: patient_id_hash, risk_assessments: %{})
      expect_get_person_data(patient_id)

      resp =
        conn
        |> get(risk_assessment_path(conn, :index, patient_id))
        |> json_response(200)

      resp
      |> Map.take(["data"])
      |> assert_json_schema("risk_assessments/risk_assessment_list.json")

      assert %{"page_number" => 1, "total_entries" => 0, "total_pages" => 0} = resp["paging"]
    end

    test "get patient when risk assessments list is null", %{conn: conn} do
      expect(KafkaMock, :publish_mongo_event, 2, fn _event -> :ok end)

      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)

      insert(:patient, _id: patient_id_hash, risk_assessments: nil)
      expect_get_person_data(patient_id)

      resp =
        conn
        |> get(risk_assessment_path(conn, :index, patient_id))
        |> json_response(200)

      resp
      |> Map.take(["data"])
      |> assert_json_schema("risk_assessments/risk_assessment_list.json")

      assert %{"page_number" => 1, "total_entries" => 0, "total_pages" => 0} = resp["paging"]
    end
  end

  defp build_encounter_context(encounter_id) do
    build(
      :reference,
      identifier: build(:identifier, value: encounter_id, type: codeable_concept_coding(code: "encounter"))
    )
  end

  defp get_datetime(day_shift) do
    date = Date.utc_today() |> Date.add(day_shift) |> Date.to_erl()
    {date, {0, 0, 0}} |> NaiveDateTime.from_erl!() |> DateTime.from_naive!("Etc/UTC")
  end
end