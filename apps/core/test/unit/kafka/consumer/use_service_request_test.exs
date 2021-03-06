defmodule Core.Kafka.Consumer.UseServiceRequestTest do
  @moduledoc false

  use Core.ModelCase
  alias Core.Job
  alias Core.Jobs
  alias Core.Jobs.ServiceRequestUseJob
  alias Core.Kafka.Consumer
  alias Core.Patients
  import Mox

  @status_pending Job.status(:pending)

  setup :verify_on_exit!

  describe "consume use service_request event" do
    test "success use service_request" do
      client_id = UUID.uuid4()
      job = insert(:job)

      service_request = insert(:service_request)
      %BSON.Binary{binary: id} = service_request._id

      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)
      insert(:patient, _id: patient_id_hash)
      user_id = UUID.uuid4()

      expect(WorkerMock, :run, fn _, _, :transaction, args ->
        assert %{
                 "actor_id" => _,
                 "operations" => [
                   %{"collection" => "service_requests", "operation" => "update_one"},
                   %{"collection" => "jobs", "operation" => "update_one", "filter" => filter, "set" => set}
                 ]
               } = Jason.decode!(args)

        assert %{"_id" => job._id} == filter |> Base.decode64!() |> BSON.decode()

        set_bson = set |> Base.decode64!() |> BSON.decode()

        response = %{
          "links" => [
            %{
              "entity" => "service_request",
              "href" => "/api/patients/#{patient_id}/service_requests/#{service_request._id}"
            }
          ]
        }

        status = Job.status(:processed)

        assert %{
                 "$set" => %{
                   "status" => ^status,
                   "status_code" => 200,
                   "response" => ^response
                 }
               } = set_bson

        :ok
      end)

      assert :ok =
               Consumer.consume(%ServiceRequestUseJob{
                 _id: to_string(job._id),
                 patient_id: patient_id,
                 patient_id_hash: patient_id_hash,
                 user_id: user_id,
                 client_id: client_id,
                 service_request_id: UUID.binary_to_string!(id),
                 used_by_legal_entity: %{
                   "identifier" => %{
                     "type" => %{"coding" => [%{"code" => "employee", "system" => "eHealth/resources"}]},
                     "value" => client_id
                   }
                 }
               })

      assert {:ok, %Job{status: @status_pending}} = Jobs.get_by_id(to_string(job._id))
    end

    test "fail on invalid drfo" do
      client_id = UUID.uuid4()
      job = insert(:job)

      service_request = insert(:service_request)
      %BSON.Binary{binary: id} = service_request._id
      employee_id = UUID.uuid4()

      expect(WorkerMock, :run, fn _, _, :employee_by_id, _ ->
        {:ok, %{employee_type: "DOCTOR", status: "APPROVED", legal_entity_id: UUID.uuid4()}}
      end)

      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)
      insert(:patient, _id: patient_id_hash)
      user_id = UUID.uuid4()

      expect_job_update(
        job._id,
        Job.status(:failed),
        %{
          "invalid" => [
            %{
              "entry" => "$.used_by_employee.identifier.value",
              "entry_type" => "json_data_property",
              "rules" => [
                %{
                  "description" => "Employee #{employee_id} doesn't belong to your legal entity",
                  "params" => [],
                  "rule" => nil
                }
              ]
            }
          ],
          "message" =>
            "Validation failed. You can find validators description at our API Manifest: http://docs.apimanifest.apiary.io/#introduction/interacting-with-api/errors.",
          "type" => "validation_failed"
        },
        422
      )

      assert :ok =
               Consumer.consume(%ServiceRequestUseJob{
                 _id: to_string(job._id),
                 patient_id: patient_id,
                 patient_id_hash: patient_id_hash,
                 user_id: user_id,
                 client_id: client_id,
                 service_request_id: UUID.binary_to_string!(id),
                 used_by_employee: %{
                   "identifier" => %{
                     "type" => %{"coding" => [%{"code" => "employee", "system" => "eHealth/resources"}]},
                     "value" => employee_id
                   }
                 },
                 used_by_legal_entity: %{
                   "identifier" => %{
                     "type" => %{"coding" => [%{"code" => "employee", "system" => "eHealth/resources"}]},
                     "value" => client_id
                   }
                 }
               })

      assert {:ok, %Job{status: @status_pending}} = Jobs.get_by_id(to_string(job._id))
    end

    test "fail on invalid used_by_legal_entity" do
      client_id = UUID.uuid4()
      job = insert(:job)

      service_request = insert(:service_request)
      %BSON.Binary{binary: id} = service_request._id
      legal_entity_id = UUID.uuid4()

      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)
      insert(:patient, _id: patient_id_hash)
      user_id = UUID.uuid4()

      expect_job_update(
        job._id,
        Job.status(:failed),
        %{
          "invalid" => [
            %{
              "entry" => "$.used_by_legal_entity.identifier.value",
              "entry_type" => "json_data_property",
              "rules" => [
                %{
                  "description" => "You can assign service request only to your legal entity",
                  "params" => [],
                  "rule" => nil
                }
              ]
            }
          ],
          "message" =>
            "Validation failed. You can find validators description at our API Manifest: http://docs.apimanifest.apiary.io/#introduction/interacting-with-api/errors.",
          "type" => "validation_failed"
        },
        422
      )

      assert :ok =
               Consumer.consume(%ServiceRequestUseJob{
                 _id: to_string(job._id),
                 patient_id: patient_id,
                 patient_id_hash: patient_id_hash,
                 user_id: user_id,
                 client_id: client_id,
                 service_request_id: UUID.binary_to_string!(id),
                 used_by_legal_entity: %{
                   "identifier" => %{
                     "type" => %{"coding" => [%{"code" => "employee", "system" => "eHealth/resources"}]},
                     "value" => legal_entity_id
                   }
                 }
               })

      assert {:ok, %Job{status: @status_pending}} = Jobs.get_by_id(to_string(job._id))
    end

    test "fail when used_by_legal_entity is already filled" do
      client_id = UUID.uuid4()
      job = insert(:job)

      service_request =
        insert(:service_request,
          used_by_legal_entity:
            build(:reference, identifier: build(:identifier, value: Mongo.string_to_uuid(client_id)))
        )

      %BSON.Binary{binary: id} = service_request._id

      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)
      insert(:patient, _id: patient_id_hash)
      user_id = UUID.uuid4()

      expect_job_update(
        job._id,
        Job.status(:failed),
        "Service request is already used",
        409
      )

      assert :ok =
               Consumer.consume(%ServiceRequestUseJob{
                 _id: to_string(job._id),
                 patient_id: patient_id,
                 patient_id_hash: patient_id_hash,
                 user_id: user_id,
                 client_id: client_id,
                 service_request_id: UUID.binary_to_string!(id),
                 used_by_legal_entity: %{
                   "identifier" => %{
                     "type" => %{"coding" => [%{"code" => "employee", "system" => "eHealth/resources"}]},
                     "value" => client_id
                   }
                 }
               })

      assert {:ok, %Job{status: @status_pending}} = Jobs.get_by_id(to_string(job._id))
    end

    test "fail on invalid expiration_date" do
      current_config = Application.get_env(:core, :service_request_expiration_days)
      expiration_days = 2

      on_exit(fn ->
        Application.put_env(:core, :service_request_expiration_days, current_config)
      end)

      Application.put_env(:core, :service_request_expiration_days, expiration_days)

      client_id = UUID.uuid4()
      now = DateTime.utc_now()
      job = insert(:job)

      service_request =
        insert(:service_request,
          inserted_at: DateTime.from_unix!(DateTime.to_unix(now) - 60 * 60 * 24 * (expiration_days + 1)),
          expiration_date: DateTime.from_unix!(DateTime.to_unix(now) - 60 * 60 * 24 * expiration_days)
        )

      %BSON.Binary{binary: id} = service_request._id
      employee_id = UUID.uuid4()
      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)
      insert(:patient, _id: patient_id_hash)
      user_id = UUID.uuid4()

      expect(WorkerMock, :run, fn _, _, :transaction, args ->
        assert %{
                 "actor_id" => _,
                 "operations" => [
                   %{"collection" => "jobs", "operation" => "update_one", "filter" => filter, "set" => set}
                 ]
               } = Jason.decode!(args)

        assert %{"_id" => job._id} == filter |> Base.decode64!() |> BSON.decode()

        set_bson = set |> Base.decode64!() |> BSON.decode()
        status = Job.status(:failed)

        assert %{
                 "$set" => %{
                   "status" => ^status,
                   "status_code" => 409,
                   "response" => "Service request is expired"
                 }
               } = set_bson

        :ok
      end)

      assert :ok =
               Consumer.consume(%ServiceRequestUseJob{
                 _id: to_string(job._id),
                 patient_id: patient_id,
                 patient_id_hash: patient_id_hash,
                 user_id: user_id,
                 client_id: client_id,
                 service_request_id: UUID.binary_to_string!(id),
                 used_by_employee: %{
                   "identifier" => %{
                     "type" => %{"coding" => [%{"code" => "employee", "system" => "eHealth/resources"}]},
                     "value" => employee_id
                   }
                 },
                 used_by_legal_entity: %{
                   "identifier" => %{
                     "type" => %{"coding" => [%{"code" => "employee", "system" => "eHealth/resources"}]},
                     "value" => client_id
                   }
                 }
               })
    end
  end
end
