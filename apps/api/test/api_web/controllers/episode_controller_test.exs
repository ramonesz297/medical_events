defmodule Api.Web.EpisodeControllerTest do
  @moduledoc false

  use ApiWeb.ConnCase
  alias Core.Episode
  alias Core.Patient
  import Mox

  setup %{conn: conn} do
    {:ok, conn: put_consumer_id_header(conn)}
  end

  describe "create episode" do
    test "patient not found", %{conn: conn} do
      expect(IlMock, :get_dictionaries, fn _, _ ->
        {:ok, %{"data" => %{}}}
      end)

      conn = post(conn, episode_path(conn, :create, UUID.uuid4()))
      assert json_response(conn, 404)
    end

    test "patient is not active", %{conn: conn} do
      expect(KafkaMock, :publish_mongo_event, fn _event -> :ok end)

      expect(IlMock, :get_dictionaries, fn _, _ ->
        {:ok, %{"data" => %{}}}
      end)

      patient = insert(:patient, status: Patient.status(:inactive))

      conn = post(conn, episode_path(conn, :create, patient._id))
      assert json_response(conn, 409)
    end

    test "json schema validation failed", %{conn: conn} do
      expect(KafkaMock, :publish_mongo_event, fn _event -> :ok end)

      expect(IlMock, :get_dictionaries, fn _, _ ->
        {:ok, %{"data" => %{}}}
      end)

      expect(KafkaMock, :publish_medical_event, fn _ -> :ok end)
      patient = insert(:patient)

      conn = post(conn, episode_path(conn, :create, patient._id), %{})
      assert json_response(conn, 422)
    end

    test "success create episode", %{conn: conn} do
      expect(KafkaMock, :publish_mongo_event, 2, fn _event -> :ok end)

      expect(IlMock, :get_dictionaries, fn _, _ ->
        {:ok, %{"data" => %{}}}
      end)

      expect(KafkaMock, :publish_medical_event, fn _ -> :ok end)
      patient = insert(:patient)

      conn =
        post(conn, episode_path(conn, :create, patient._id), %{
          "id" => UUID.uuid4(),
          "name" => "ОРВИ 2018",
          "status" => Episode.status(:active),
          "type" => "primary_care",
          "managing_organization" => %{
            "identifier" => %{
              "type" => %{"coding" => [%{"system" => "eHealth/resources", "code" => "legal_entity"}]},
              "value" => UUID.uuid4()
            }
          },
          "period" => %{"start" => DateTime.to_iso8601(DateTime.utc_now())},
          "care_manager" => %{
            "identifier" => %{
              "type" => %{"coding" => [%{"system" => "eHealth/resources", "code" => "employee"}]},
              "value" => UUID.uuid4()
            }
          }
        })

      assert json_response(conn, 202)
    end
  end

  describe "show episode" do
    test "get episode success", %{conn: conn} do
      expect(KafkaMock, :publish_mongo_event, 2, fn _event -> :ok end)

      episode = build(:episode)
      patient = insert(:patient, episodes: %{episode.id => episode})

      conn
      |> get(episode_path(conn, :show, patient._id, episode.id))
      |> json_response(200)
      |> Map.get("data")
      |> assert_json_schema("episodes/episode_show.json")
    end

    test "get episode invalid patient uuid", %{conn: conn} do
      expect(KafkaMock, :publish_mongo_event, 2, fn _event -> :ok end)

      conn
      |> get(episode_path(conn, :show, "invalid-uuid", UUID.uuid4()))
      |> json_response(404)
    end

    test "get episode invalid episode uuid", %{conn: conn} do
      expect(KafkaMock, :publish_mongo_event, 2, fn _event -> :ok end)

      episode = build(:episode)
      patient = insert(:patient, episodes: %{episode.id => episode})

      conn
      |> get(episode_path(conn, :show, patient._id, "invalid-episode-uuid"))
      |> json_response(404)
    end

    test "get episode when no episodes", %{conn: conn} do
      expect(KafkaMock, :publish_mongo_event, 2, fn _event -> :ok end)

      patient = insert(:patient, episodes: %{})

      conn
      |> get(episode_path(conn, :show, patient._id, patient._id))
      |> json_response(404)
    end
  end

  describe "list episodes" do
    test "get episodes success", %{conn: conn} do
      expect(KafkaMock, :publish_mongo_event, 2, fn _event -> :ok end)

      patient = insert(:patient)

      resp =
        conn
        |> get(episode_path(conn, :index, patient._id))
        |> json_response(200)

      Enum.each(resp["data"], &assert_json_schema(&1, "episodes/episode_show.json"))
      assert %{"page_number" => 1, "total_entries" => 2, "total_pages" => 1} = resp["paging"]
    end

    test "get episodes not found", %{conn: conn} do
      expect(KafkaMock, :publish_mongo_event, 2, fn _event -> :ok end)

      resp =
        conn
        |> get(episode_path(conn, :index, "any"))
        |> json_response(200)

      Enum.each(resp["data"], &assert_json_schema(&1, "episodes/episode_show.json"))
      assert %{"page_number" => 1, "total_entries" => 0, "total_pages" => 0} = resp["paging"]
    end

    test "get episodes no episodes", %{conn: conn} do
      expect(KafkaMock, :publish_mongo_event, 2, fn _event -> :ok end)

      patient = insert(:patient, episodes: %{})

      resp =
        conn
        |> get(episode_path(conn, :index, patient._id))
        |> json_response(200)

      Enum.each(resp["data"], &assert_json_schema(&1, "episodes/episode_show.json"))
      assert %{"page_number" => 1, "total_entries" => 0, "total_pages" => 0} = resp["paging"]
    end

    test "get episodes is nil", %{conn: conn} do
      expect(KafkaMock, :publish_mongo_event, 2, fn _event -> :ok end)

      patient = insert(:patient, episodes: nil)

      resp =
        conn
        |> get(episode_path(conn, :index, patient._id))
        |> json_response(200)

      Enum.each(resp["data"], &assert_json_schema(&1, "episodes/episode_show.json"))
      assert %{"page_number" => 1, "total_entries" => 0, "total_pages" => 0} = resp["paging"]
    end

    test "get episodes order by inserted first episode", %{conn: conn} do
      expect(KafkaMock, :publish_mongo_event, 2, fn _event -> :ok end)

      tomorrow = DateTime.from_unix!(DateTime.to_unix(DateTime.utc_now()) + 60 * 60 * 24)
      yesterday = DateTime.from_unix!(DateTime.to_unix(DateTime.utc_now()) - 60 * 60 * 24)

      episode_t = build(:episode, inserted_at: tomorrow)
      episode_y = build(:episode, inserted_at: yesterday)

      episodes =
        1..200
        |> Enum.reduce(%{}, fn _, acc ->
          episode = build(:episode)
          Map.put(acc, episode.id, episode)
        end)
        |> Map.put(episode_t.id, episode_t)
        |> Map.put(episode_y.id, episode_y)

      patient =
        insert(
          :patient,
          episodes: episodes
        )

      resp =
        conn
        |> get(episode_path(conn, :index, patient._id), %{"page_size" => 1})
        |> json_response(200)

      Enum.each(resp["data"], &assert_json_schema(&1, "episodes/episode_show.json"))
      assert [%{"id" => idt} | _] = resp["data"]
      assert idt == episode_t.id
      assert %{"page_number" => 1, "total_entries" => 202, "total_pages" => 202, "page_size" => 1} = resp["paging"]
    end

    test "get episodes order by inserted last episode", %{conn: conn} do
      expect(KafkaMock, :publish_mongo_event, 2, fn _event -> :ok end)

      tomorrow = DateTime.from_unix!(DateTime.to_unix(DateTime.utc_now()) + 60 * 60 * 24)
      yesterday = DateTime.from_unix!(DateTime.to_unix(DateTime.utc_now()) - 60 * 60 * 24)

      episode_t = build(:episode, inserted_at: tomorrow)
      episode_y = build(:episode, inserted_at: yesterday)

      episodes =
        1..200
        |> Enum.reduce(%{}, fn _, acc ->
          episode = build(:episode)
          Map.put(acc, episode.id, episode)
        end)
        |> Map.put(episode_t.id, episode_t)
        |> Map.put(episode_y.id, episode_y)

      patient =
        insert(
          :patient,
          episodes: episodes
        )

      resp =
        conn
        |> get(episode_path(conn, :index, patient._id), %{"page_size" => 200, "page_number" => 2})
        |> json_response(200)

      Enum.each(resp["data"], &assert_json_schema(&1, "episodes/episode_show.json"))
      assert [_, %{"id" => idy}] = resp["data"]
      assert idy == episode_y.id
      assert %{"page_number" => 2, "total_entries" => 202, "total_pages" => 2, "page_size" => 200} = resp["paging"]
    end
  end
end
