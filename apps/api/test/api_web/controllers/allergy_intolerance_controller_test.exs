defmodule Api.Web.AllergyIntoleranceControllerTest do
  @moduledoc false

  use ApiWeb.ConnCase
  alias Core.Patients

  describe "show allergy intolerance" do
    test "successful show", %{conn: conn} do
      allergy_intolerance_1 = build(:allergy_intolerance)
      allergy_intolerance_2 = build(:allergy_intolerance)

      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)

      insert(
        :patient,
        _id: patient_id_hash,
        allergy_intolerances: %{
          UUID.binary_to_string!(allergy_intolerance_1.id.binary) => allergy_intolerance_1,
          UUID.binary_to_string!(allergy_intolerance_2.id.binary) => allergy_intolerance_2
        }
      )

      resp =
        conn
        |> get(
          allergy_intolerance_path(conn, :show, patient_id, UUID.binary_to_string!(allergy_intolerance_1.id.binary))
        )
        |> json_response(200)

      resp
      |> Map.take(["data"])
      |> assert_json_schema("allergy_intolerances/allergy_intolerance_show.json")

      assert get_in(resp, ~w(data id)) == UUID.binary_to_string!(allergy_intolerance_1.id.binary)
      refute get_in(resp, ~w(data id)) == UUID.binary_to_string!(allergy_intolerance_2.id.binary)
    end

    test "successful show by episode context", %{conn: conn} do
      episode1 = build(:episode)
      episode2 = build(:episode)

      encounter1 = build(:encounter, episode: build(:reference, identifier: build(:identifier, value: episode1.id)))
      encounter2 = build(:encounter)

      context = build_encounter_context(encounter1.id)
      allergy_intolerance1 = build(:allergy_intolerance, context: context)
      allergy_intolerance2 = build(:allergy_intolerance)

      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)

      insert(
        :patient,
        _id: patient_id_hash,
        episodes: %{
          to_string(episode1.id) => episode1,
          to_string(episode2.id) => episode2
        },
        encounters: %{
          to_string(encounter1.id) => encounter1,
          to_string(encounter2.id) => encounter2
        },
        allergy_intolerances: %{
          to_string(allergy_intolerance1.id) => allergy_intolerance1,
          to_string(allergy_intolerance2.id) => allergy_intolerance2
        }
      )

      resp =
        conn
        |> get(
          episode_context_allergy_intolerance_path(
            conn,
            :show_by_episode,
            patient_id,
            to_string(episode1.id),
            to_string(allergy_intolerance1.id)
          )
        )
        |> json_response(200)

      resp
      |> Map.take(["data"])
      |> assert_json_schema("allergy_intolerances/allergy_intolerance_show.json")

      assert get_in(resp, ~w(data id)) == to_string(allergy_intolerance1.id)
      refute get_in(resp, ~w(data id)) == to_string(allergy_intolerance2.id)
    end

    test "not found by episode context", %{conn: conn} do
      episode1 = build(:episode)
      episode2 = build(:episode)

      encounter1 = build(:encounter, episode: build(:reference, identifier: build(:identifier, value: episode1.id)))
      encounter2 = build(:encounter)

      context = build_encounter_context(encounter1.id)
      allergy_intolerance1 = build(:allergy_intolerance, context: context)
      allergy_intolerance2 = build(:allergy_intolerance)

      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)

      insert(
        :patient,
        _id: patient_id_hash,
        episodes: %{
          to_string(episode1.id) => episode1,
          to_string(episode2.id) => episode2
        },
        encounters: %{
          to_string(encounter1.id) => encounter1,
          to_string(encounter2.id) => encounter2
        },
        allergy_intolerances: %{
          to_string(allergy_intolerance1.id) => allergy_intolerance1,
          to_string(allergy_intolerance2.id) => allergy_intolerance2
        }
      )

      assert conn
             |> get(
               episode_context_allergy_intolerance_path(
                 conn,
                 :show_by_episode,
                 patient_id,
                 to_string(episode2.id),
                 to_string(allergy_intolerance1.id)
               )
             )
             |> json_response(404)
    end

    test "invalid patient uuid", %{conn: conn} do
      conn
      |> get(allergy_intolerance_path(conn, :show, UUID.uuid4(), UUID.uuid4()))
      |> json_response(404)
    end

    test "invalid allergy intolerance uuid", %{conn: conn} do
      allergy_intolerance = build(:allergy_intolerance)

      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)

      insert(
        :patient,
        _id: patient_id_hash,
        allergy_intolerances: %{UUID.binary_to_string!(allergy_intolerance.id.binary) => allergy_intolerance}
      )

      conn
      |> get(allergy_intolerance_path(conn, :show, patient_id, UUID.uuid4()))
      |> json_response(404)
    end

    test "get patient when no allergy intolerances", %{conn: conn} do
      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)

      insert(:patient, _id: patient_id_hash, allergy_intolerances: %{})

      conn
      |> get(allergy_intolerance_path(conn, :show, patient_id, UUID.uuid4()))
      |> json_response(404)
    end
  end

  describe "index allergy intolerance" do
    test "successful search", %{conn: conn} do
      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)

      insert(:patient, _id: patient_id_hash)

      resp =
        conn
        |> get(allergy_intolerance_path(conn, :index, patient_id))
        |> json_response(200)

      resp
      |> Map.take(["data"])
      |> assert_json_schema("allergy_intolerances/allergy_intolerance_list.json")

      assert %{"page_number" => 1, "total_entries" => 2, "total_pages" => 1} = resp["paging"]
    end

    test "successful search with search parameters: encounter_id", %{conn: conn} do
      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)

      encounter_id = UUID.uuid4()
      context = build_encounter_context(Mongo.string_to_uuid(encounter_id))
      allergy_intolerance_1 = build(:allergy_intolerance, context: context)
      allergy_intolerance_2 = build(:allergy_intolerance)

      allergy_intolerances =
        [allergy_intolerance_1, allergy_intolerance_2]
        |> Enum.into(%{}, fn %{id: %BSON.Binary{binary: id}} = allergy_intolerance ->
          {UUID.binary_to_string!(id), allergy_intolerance}
        end)

      insert(:patient, _id: patient_id_hash, allergy_intolerances: allergy_intolerances)

      search_params = %{"encounter_id" => encounter_id}

      resp =
        conn
        |> get(allergy_intolerance_path(conn, :index, patient_id), search_params)
        |> json_response(200)

      resp
      |> Map.take(["data"])
      |> assert_json_schema("allergy_intolerances/allergy_intolerance_list.json")

      assert %{"page_number" => 1, "total_entries" => 1, "total_pages" => 1} = resp["paging"]

      resp =
        resp
        |> Map.get("data")
        |> hd()

      refute Map.get(resp, "id") == UUID.binary_to_string!(allergy_intolerance_2.id.binary)
      assert Map.get(resp, "id") == UUID.binary_to_string!(allergy_intolerance_1.id.binary)
      assert get_in(resp, ~w(context identifier value)) == encounter_id
    end

    test "successful search with search parameters: code", %{conn: conn} do
      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)

      code_value = "1"

      code =
        build(
          :codeable_concept,
          coding: [build(:coding, code: code_value, system: "eHealth/allergy_intolerance_codes")]
        )

      allergy_intolerance_1 = build(:allergy_intolerance, code: code)
      allergy_intolerance_2 = build(:allergy_intolerance)

      allergy_intolerances =
        [allergy_intolerance_1, allergy_intolerance_2]
        |> Enum.into(%{}, fn %{id: %BSON.Binary{binary: id}} = allergy_intolerance ->
          {UUID.binary_to_string!(id), allergy_intolerance}
        end)

      insert(:patient, _id: patient_id_hash, allergy_intolerances: allergy_intolerances)

      search_params = %{"code" => code_value}

      resp =
        conn
        |> get(allergy_intolerance_path(conn, :index, patient_id), search_params)
        |> json_response(200)

      resp
      |> Map.take(["data"])
      |> assert_json_schema("allergy_intolerances/allergy_intolerance_list.json")

      assert %{"page_number" => 1, "total_entries" => 1, "total_pages" => 1} = resp["paging"]

      resp =
        resp
        |> Map.get("data")
        |> hd()

      assert Map.get(resp, "id") == UUID.binary_to_string!(allergy_intolerance_1.id.binary)
      refute Map.get(resp, "id") == UUID.binary_to_string!(allergy_intolerance_2.id.binary)
    end

    test "successful search with search parameters: episode_id", %{conn: conn} do
      episode_1 = build(:episode)
      episode_2 = build(:episode)

      encounter_1 = build(:encounter, episode: build(:reference, identifier: build(:identifier, value: episode_1.id)))
      encounter_2 = build(:encounter)

      context = build_encounter_context(encounter_1.id)
      allergy_intolerance_1 = build(:allergy_intolerance, context: context)
      allergy_intolerance_2 = build(:allergy_intolerance)

      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)

      insert(
        :patient,
        _id: patient_id_hash,
        episodes: %{
          UUID.binary_to_string!(episode_1.id.binary) => episode_1,
          UUID.binary_to_string!(episode_2.id.binary) => episode_2
        },
        encounters: %{
          UUID.binary_to_string!(encounter_1.id.binary) => encounter_1,
          UUID.binary_to_string!(encounter_2.id.binary) => encounter_2
        },
        allergy_intolerances: %{
          UUID.binary_to_string!(allergy_intolerance_1.id.binary) => allergy_intolerance_1,
          UUID.binary_to_string!(allergy_intolerance_2.id.binary) => allergy_intolerance_2
        }
      )

      search_params = %{"episode_id" => UUID.binary_to_string!(episode_1.id.binary)}

      resp =
        conn
        |> get(allergy_intolerance_path(conn, :index, patient_id), search_params)
        |> json_response(200)

      resp
      |> Map.take(["data"])
      |> assert_json_schema("allergy_intolerances/allergy_intolerance_list.json")

      assert %{"page_number" => 1, "total_entries" => 1, "total_pages" => 1} = resp["paging"]

      resp =
        resp
        |> Map.get("data")
        |> hd()

      assert Map.get(resp, "id") == UUID.binary_to_string!(allergy_intolerance_1.id.binary)
      refute Map.get(resp, "id") == UUID.binary_to_string!(allergy_intolerance_2.id.binary)
    end

    test "successful index by episode context", %{conn: conn} do
      episode1 = build(:episode)
      episode2 = build(:episode)

      encounter1 = build(:encounter, episode: build(:reference, identifier: build(:identifier, value: episode1.id)))
      encounter2 = build(:encounter)

      context = build_encounter_context(encounter1.id)
      allergy_intolerance1 = build(:allergy_intolerance, context: context)
      allergy_intolerance2 = build(:allergy_intolerance)

      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)

      insert(
        :patient,
        _id: patient_id_hash,
        episodes: %{
          to_string(episode1.id) => episode1,
          to_string(episode2.id) => episode2
        },
        encounters: %{
          to_string(encounter1.id) => encounter1,
          to_string(encounter2.id) => encounter2
        },
        allergy_intolerances: %{
          to_string(allergy_intolerance1.id) => allergy_intolerance1,
          to_string(allergy_intolerance2.id) => allergy_intolerance2
        }
      )

      resp =
        conn
        |> get(episode_context_allergy_intolerance_path(conn, :index, patient_id, to_string(episode1.id)))
        |> json_response(200)

      resp
      |> Map.take(["data"])
      |> assert_json_schema("allergy_intolerances/allergy_intolerance_list.json")

      assert %{"page_number" => 1, "total_entries" => 1, "total_pages" => 1} = resp["paging"]

      resp =
        resp
        |> Map.get("data")
        |> hd()

      assert Map.get(resp, "id") == to_string(allergy_intolerance1.id)
      refute Map.get(resp, "id") == to_string(allergy_intolerance2.id)
    end

    test "successful search with search parameters: date", %{conn: conn} do
      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)

      onset_date_time_from = Date.utc_today() |> Date.add(-20) |> Date.to_iso8601()
      onset_date_time_to = Date.utc_today() |> Date.add(-10) |> Date.to_iso8601()

      allergy_intolerance_1 = build(:allergy_intolerance, onset_date_time: get_datetime(-30))
      allergy_intolerance_2 = build(:allergy_intolerance, onset_date_time: get_datetime(-20))
      allergy_intolerance_3 = build(:allergy_intolerance, onset_date_time: get_datetime(-15))
      allergy_intolerance_4 = build(:allergy_intolerance, onset_date_time: get_datetime(-10))
      allergy_intolerance_5 = build(:allergy_intolerance, onset_date_time: get_datetime(-5))

      allergy_intolerances =
        [
          allergy_intolerance_1,
          allergy_intolerance_2,
          allergy_intolerance_3,
          allergy_intolerance_4,
          allergy_intolerance_5
        ]
        |> Enum.into(%{}, fn %{id: %BSON.Binary{binary: id}} = allergy_intolerance ->
          {UUID.binary_to_string!(id), allergy_intolerance}
        end)

      insert(:patient, _id: patient_id_hash, allergy_intolerances: allergy_intolerances)

      call_endpoint = fn search_params ->
        conn
        |> get(allergy_intolerance_path(conn, :index, patient_id), search_params)
        |> json_response(200)
      end

      # both dates
      assert %{"page_number" => 1, "total_entries" => 3, "total_pages" => 1} =
               call_endpoint.(%{
                 "onset_date_time_from" => onset_date_time_from,
                 "onset_date_time_to" => onset_date_time_to
               })
               |> Map.get("paging")

      # date_from only
      assert %{"page_number" => 1, "total_entries" => 4, "total_pages" => 1} =
               call_endpoint.(%{"onset_date_time_from" => onset_date_time_from})
               |> Map.get("paging")

      # date_to only
      assert %{"page_number" => 1, "total_entries" => 4, "total_pages" => 1} =
               call_endpoint.(%{"onset_date_time_to" => onset_date_time_to})
               |> Map.get("paging")

      # without date search params
      assert %{"page_number" => 1, "total_entries" => 5, "total_pages" => 1} =
               call_endpoint.(%{})
               |> Map.get("paging")
    end

    test "successful search with search parameters: complex test", %{conn: conn} do
      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)

      code_value = "1"

      code =
        build(
          :codeable_concept,
          coding: [
            build(:coding, code: code_value, system: "eHealth/allergy_intolerance_codes"),
            build(:coding, code: "test", system: "eHealth/allergy_intolerance_codes")
          ]
        )

      onset_date_time_from = Date.utc_today() |> Date.add(-20) |> Date.to_iso8601()
      onset_date_time_to = Date.utc_today() |> Date.add(-10) |> Date.to_iso8601()

      encounter_id_1 = UUID.uuid4()
      context_encounter_id = build_encounter_context(Mongo.string_to_uuid(encounter_id_1))

      episode = build(:episode)
      encounter = build(:encounter, episode: build(:reference, identifier: build(:identifier, value: episode.id)))
      encounter_id_2 = UUID.binary_to_string!(encounter.id.binary)
      context_episode_id = build_encounter_context(Mongo.string_to_uuid(encounter_id_2))

      allergy_intolerance_1 =
        build(:allergy_intolerance, context: context_encounter_id, code: code, onset_date_time: get_datetime(-15))

      allergy_intolerance_2 =
        build(:allergy_intolerance, context: context_encounter_id, onset_date_time: get_datetime(-15))

      allergy_intolerance_3 = build(:allergy_intolerance, code: code, onset_date_time: get_datetime(-15))

      allergy_intolerance_4 =
        build(:allergy_intolerance, context: context_episode_id, code: code, onset_date_time: get_datetime(-15))

      allergy_intolerance_5 = build(:allergy_intolerance, onset_date_time: get_datetime(-30))
      allergy_intolerance_6 = build(:allergy_intolerance, onset_date_time: get_datetime(-15))
      allergy_intolerance_7 = build(:allergy_intolerance, onset_date_time: get_datetime(-5))

      allergy_intolerances =
        [
          allergy_intolerance_1,
          allergy_intolerance_2,
          allergy_intolerance_3,
          allergy_intolerance_4,
          allergy_intolerance_5,
          allergy_intolerance_6,
          allergy_intolerance_7
        ]
        |> Enum.into(%{}, fn %{id: %BSON.Binary{binary: id}} = allergy_intolerance ->
          {UUID.binary_to_string!(id), allergy_intolerance}
        end)

      insert(
        :patient,
        _id: patient_id_hash,
        allergy_intolerances: allergy_intolerances,
        episodes: %{
          UUID.binary_to_string!(episode.id.binary) => episode
        },
        encounters: %{
          UUID.binary_to_string!(encounter.id.binary) => encounter
        }
      )

      search_params = %{
        "encounter_id" => encounter_id_1,
        "code" => code_value,
        "episode_id" => UUID.binary_to_string!(episode.id.binary),
        "onset_date_time_from" => onset_date_time_from,
        "onset_date_time_to" => onset_date_time_to
      }

      call_endpoint = fn search_params ->
        conn
        |> get(allergy_intolerance_path(conn, :index, patient_id), search_params)
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

      assert Map.get(resp, "id") == UUID.binary_to_string!(allergy_intolerance_4.id.binary)
      assert get_in(resp, ~w(context identifier value)) == encounter_id_2

      # all params except episode_id
      resp = call_endpoint.(Map.delete(search_params, "episode_id"))

      assert %{"page_number" => 1, "total_entries" => 1, "total_pages" => 1} = resp["paging"]

      resp =
        resp
        |> Map.get("data")
        |> hd()

      assert Map.get(resp, "id") == UUID.binary_to_string!(allergy_intolerance_1.id.binary)
      assert get_in(resp, ~w(context identifier value)) == encounter_id_1
    end

    test "empty search list when episode_id not found in encounters", %{conn: conn} do
      episode_1 = build(:episode)
      episode_2 = build(:episode)

      encounter_1 = build(:encounter, episode: build(:reference, identifier: build(:identifier, value: episode_1.id)))
      encounter_2 = build(:encounter)

      context = build_encounter_context(encounter_1.id)
      allergy_intolerance_1 = build(:allergy_intolerance, context: context)
      allergy_intolerance_2 = build(:allergy_intolerance)

      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)

      insert(
        :patient,
        _id: patient_id_hash,
        episodes: %{
          UUID.binary_to_string!(episode_1.id.binary) => episode_1,
          UUID.binary_to_string!(episode_2.id.binary) => episode_2
        },
        encounters: %{
          UUID.binary_to_string!(encounter_1.id.binary) => encounter_1,
          UUID.binary_to_string!(encounter_2.id.binary) => encounter_2
        },
        allergy_intolerances: %{
          UUID.binary_to_string!(allergy_intolerance_1.id.binary) => allergy_intolerance_1,
          UUID.binary_to_string!(allergy_intolerance_2.id.binary) => allergy_intolerance_2
        }
      )

      search_params = %{"episode_id" => UUID.uuid4()}

      resp =
        conn
        |> get(allergy_intolerance_path(conn, :index, patient_id), search_params)
        |> json_response(200)

      resp
      |> Map.take(["data"])
      |> assert_json_schema("allergy_intolerances/allergy_intolerance_list.json")

      assert %{"page_number" => 1, "total_entries" => 0, "total_pages" => 0} = resp["paging"]
    end

    test "invalid search params", %{conn: conn} do
      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)

      insert(:patient, _id: patient_id_hash)

      search_params = %{
        "encounter_id" => "test",
        "code" => 12345,
        "episode_id" => "test",
        "onset_date_time_from" => "2018-02-31",
        "onset_date_time_to" => "2018-8-t"
      }

      resp =
        conn
        |> get(allergy_intolerance_path(conn, :index, patient_id), search_params)
        |> json_response(422)

      assert %{
               "invalid" => [
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
                 },
                 %{
                   "entry" => "$.onset_date_time_from",
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
                   "entry" => "$.onset_date_time_to",
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
                 }
               ]
             } = resp["error"]
    end

    test "invalid patient uuid", %{conn: conn} do
      assert %{"data" => []} =
               conn
               |> get(allergy_intolerance_path(conn, :index, UUID.uuid4()))
               |> json_response(200)
    end

    test "get patient when no allergy intolerances", %{conn: conn} do
      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)

      insert(:patient, _id: patient_id_hash, allergy_intolerances: %{})

      resp =
        conn
        |> get(allergy_intolerance_path(conn, :index, patient_id))
        |> json_response(200)

      resp
      |> Map.take(["data"])
      |> assert_json_schema("allergy_intolerances/allergy_intolerance_list.json")

      assert %{"page_number" => 1, "total_entries" => 0, "total_pages" => 0} = resp["paging"]
    end

    test "get patient when allergy intolerances list is null", %{conn: conn} do
      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)

      insert(:patient, _id: patient_id_hash, allergy_intolerances: nil)

      resp =
        conn
        |> get(allergy_intolerance_path(conn, :index, patient_id))
        |> json_response(200)

      resp
      |> Map.take(["data"])
      |> assert_json_schema("allergy_intolerances/allergy_intolerance_list.json")

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
