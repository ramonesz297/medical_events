defmodule Core.Kafka.Consumer.CreateApprovalTest do
  @moduledoc false

  use Core.ModelCase

  import Mox
  import Core.Expectations.IlExpectations
  import Core.Expectations.MPIExpectations
  import Core.Expectations.OTPVerificationExpectations

  alias Core.Approval
  alias Core.Jobs.ApprovalCreateJob
  alias Core.Kafka.Consumer
  alias Core.Patients
  alias Core.ServiceRequest

  setup :verify_on_exit!

  describe "consume create approval event" do
    test "success approval create with resources request param" do
      stub(KafkaMock, :publish_mongo_event, fn _event -> :ok end)

      user_id = UUID.uuid4()
      client_id = UUID.uuid4()
      employee_id = UUID.uuid4()
      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)

      episode_1 =
        build(:episode, managing_organization: reference_coding(Mongo.string_to_uuid(client_id), code: "legal_entity"))

      episode_2 =
        build(:episode, managing_organization: reference_coding(Mongo.string_to_uuid(client_id), code: "legal_entity"))

      insert(
        :patient,
        _id: patient_id_hash,
        episodes: %{
          UUID.binary_to_string!(episode_1.id.binary) => episode_1,
          UUID.binary_to_string!(episode_2.id.binary) => episode_2
        }
      )

      expect_doctor(client_id)
      expect_employees_by_user_id_client_id([employee_id])
      expect_person(patient_id)
      expect_otp_verification_initialize()

      job = insert(:job)

      expect(KafkaMock, :publish_job_update_status_event, fn event ->
        id = to_string(job._id)
        link_id = event.response |> Map.get("links") |> hd() |> Map.get("id")

        assert %Core.Jobs.JobUpdateStatusJob{
                 _id: ^id,
                 response: %{
                   "links" => [
                     %{
                       "entity" => "approval",
                       "id" => ^link_id
                     }
                   ]
                 },
                 status_code: 200
               } = event

        :ok
      end)

      assert :ok =
               Consumer.consume(%ApprovalCreateJob{
                 _id: to_string(job._id),
                 patient_id: patient_id,
                 patient_id_hash: patient_id_hash,
                 resources: [
                   %{
                     "identifier" => %{
                       "type" => %{"coding" => [%{"code" => "episode_of_care", "system" => "eHealth/resources"}]},
                       "value" => UUID.binary_to_string!(episode_1.id.binary)
                     }
                   },
                   %{
                     "identifier" => %{
                       "type" => %{"coding" => [%{"code" => "episode_of_care", "system" => "eHealth/resources"}]},
                       "value" => UUID.binary_to_string!(episode_2.id.binary)
                     }
                   }
                 ],
                 service_request: nil,
                 granted_to: %{
                   "identifier" => %{
                     "type" => %{"coding" => [%{"code" => "employee", "system" => "eHealth/resources"}]},
                     "value" => employee_id
                   }
                 },
                 access_level: Approval.access_level(:read),
                 user_id: user_id,
                 client_id: client_id
               })
    end

    test "success approval create with service_request request param" do
      stub(KafkaMock, :publish_mongo_event, fn _event -> :ok end)

      user_id = UUID.uuid4()
      client_id = UUID.uuid4()
      employee_id = UUID.uuid4()
      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)

      episode_1 =
        build(:episode, managing_organization: reference_coding(Mongo.string_to_uuid(client_id), code: "legal_entity"))

      episode_2 =
        build(:episode, managing_organization: reference_coding(Mongo.string_to_uuid(client_id), code: "legal_entity"))

      insert(
        :patient,
        _id: patient_id_hash,
        episodes: %{
          UUID.binary_to_string!(episode_1.id.binary) => episode_1,
          UUID.binary_to_string!(episode_2.id.binary) => episode_2
        }
      )

      expect_doctor(client_id)
      expect_employees_by_user_id_client_id([employee_id])
      expect_person(patient_id)
      expect_otp_verification_initialize()

      episodes = build_episode_references([episode_1.id.binary, episode_2.id.binary])
      service_request = insert(:service_request, subject: patient_id_hash, permitted_episodes: episodes)
      service_request_id = to_string(service_request._id)

      job = insert(:job)

      expect(KafkaMock, :publish_job_update_status_event, fn event ->
        id = to_string(job._id)
        link_id = event.response |> Map.get("links") |> hd() |> Map.get("id")

        assert %Core.Jobs.JobUpdateStatusJob{
                 _id: ^id,
                 response: %{
                   "links" => [
                     %{
                       "entity" => "approval",
                       "id" => ^link_id
                     }
                   ]
                 },
                 status_code: 200
               } = event

        :ok
      end)

      assert :ok =
               Consumer.consume(%ApprovalCreateJob{
                 _id: to_string(job._id),
                 patient_id: patient_id,
                 patient_id_hash: patient_id_hash,
                 resources: nil,
                 service_request: %{
                   "identifier" => %{
                     "type" => %{"coding" => [%{"code" => "service_request", "system" => "eHealth/resources"}]},
                     "value" => service_request_id
                   }
                 },
                 granted_to: %{
                   "identifier" => %{
                     "type" => %{"coding" => [%{"code" => "employee", "system" => "eHealth/resources"}]},
                     "value" => employee_id
                   }
                 },
                 access_level: Approval.access_level(:read),
                 user_id: user_id,
                 client_id: client_id
               })
    end

    test "success approval create when person's auth method is not OTP" do
      stub(KafkaMock, :publish_mongo_event, fn _event -> :ok end)

      user_id = UUID.uuid4()
      client_id = UUID.uuid4()
      employee_id = UUID.uuid4()
      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)

      episode_1 =
        build(:episode, managing_organization: reference_coding(Mongo.string_to_uuid(client_id), code: "legal_entity"))

      episode_2 =
        build(:episode, managing_organization: reference_coding(Mongo.string_to_uuid(client_id), code: "legal_entity"))

      insert(
        :patient,
        _id: patient_id_hash,
        episodes: %{
          UUID.binary_to_string!(episode_1.id.binary) => episode_1,
          UUID.binary_to_string!(episode_2.id.binary) => episode_2
        }
      )

      expect_doctor(client_id)
      expect_employees_by_user_id_client_id([employee_id])
      expect_person_offline_auth_method(patient_id)

      job = insert(:job)

      expect(KafkaMock, :publish_job_update_status_event, fn event ->
        id = to_string(job._id)
        link_id = event.response |> Map.get("links") |> hd() |> Map.get("id")

        assert %Core.Jobs.JobUpdateStatusJob{
                 _id: ^id,
                 response: %{
                   "links" => [
                     %{
                       "entity" => "approval",
                       "id" => ^link_id
                     }
                   ]
                 },
                 status_code: 200
               } = event

        :ok
      end)

      assert :ok =
               Consumer.consume(%ApprovalCreateJob{
                 _id: to_string(job._id),
                 patient_id: patient_id,
                 patient_id_hash: patient_id_hash,
                 resources: [
                   %{
                     "identifier" => %{
                       "type" => %{"coding" => [%{"code" => "episode_of_care", "system" => "eHealth/resources"}]},
                       "value" => UUID.binary_to_string!(episode_1.id.binary)
                     }
                   },
                   %{
                     "identifier" => %{
                       "type" => %{"coding" => [%{"code" => "episode_of_care", "system" => "eHealth/resources"}]},
                       "value" => UUID.binary_to_string!(episode_2.id.binary)
                     }
                   }
                 ],
                 service_request: nil,
                 granted_to: %{
                   "identifier" => %{
                     "type" => %{"coding" => [%{"code" => "employee", "system" => "eHealth/resources"}]},
                     "value" => employee_id
                   }
                 },
                 access_level: Approval.access_level(:read),
                 user_id: user_id,
                 client_id: client_id
               })
    end

    test "failed approval create with service_request request param when service_request is not active" do
      stub(KafkaMock, :publish_mongo_event, fn _event -> :ok end)

      user_id = UUID.uuid4()
      client_id = UUID.uuid4()
      employee_id = UUID.uuid4()
      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)

      episode_1 =
        build(:episode, managing_organization: reference_coding(Mongo.string_to_uuid(client_id), code: "legal_entity"))

      episode_2 =
        build(:episode, managing_organization: reference_coding(Mongo.string_to_uuid(client_id), code: "legal_entity"))

      insert(
        :patient,
        _id: patient_id_hash,
        episodes: %{
          UUID.binary_to_string!(episode_1.id.binary) => episode_1,
          UUID.binary_to_string!(episode_2.id.binary) => episode_2
        }
      )

      episodes = build_episode_references([episode_1.id.binary, episode_2.id.binary])

      service_request =
        insert(:service_request,
          subject: patient_id_hash,
          permitted_episodes: episodes,
          status: ServiceRequest.status(:cancelled)
        )

      service_request_id = to_string(service_request._id)

      job = insert(:job)
      expect_job_update(job._id, "Service request should be active", 409)

      assert :ok =
               Consumer.consume(%ApprovalCreateJob{
                 _id: to_string(job._id),
                 patient_id: patient_id,
                 patient_id_hash: patient_id_hash,
                 resources: nil,
                 service_request: %{
                   "identifier" => %{
                     "type" => %{"coding" => [%{"code" => "service_request", "system" => "eHealth/resources"}]},
                     "value" => service_request_id
                   }
                 },
                 granted_to: %{
                   "identifier" => %{
                     "type" => %{"coding" => [%{"code" => "employee", "system" => "eHealth/resources"}]},
                     "value" => employee_id
                   }
                 },
                 access_level: Approval.access_level(:read),
                 user_id: user_id,
                 client_id: client_id
               })
    end

    test "failed approval create with service_request request param when service_request does not contain episode references" do
      stub(KafkaMock, :publish_mongo_event, fn _event -> :ok end)

      user_id = UUID.uuid4()
      client_id = UUID.uuid4()
      employee_id = UUID.uuid4()
      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)
      insert(:patient, _id: patient_id_hash)

      service_request = insert(:service_request, subject: patient_id_hash, permitted_episodes: nil)
      service_request_id = to_string(service_request._id)

      job = insert(:job)
      expect_job_update(job._id, "Service request does not contain episode references", 409)

      assert :ok =
               Consumer.consume(%ApprovalCreateJob{
                 _id: to_string(job._id),
                 patient_id: patient_id,
                 patient_id_hash: patient_id_hash,
                 resources: nil,
                 service_request: %{
                   "identifier" => %{
                     "type" => %{"coding" => [%{"code" => "service_request", "system" => "eHealth/resources"}]},
                     "value" => service_request_id
                   }
                 },
                 granted_to: %{
                   "identifier" => %{
                     "type" => %{"coding" => [%{"code" => "employee", "system" => "eHealth/resources"}]},
                     "value" => employee_id
                   }
                 },
                 access_level: Approval.access_level(:read),
                 user_id: user_id,
                 client_id: client_id
               })
    end

    test "failed approval create with service_request request param when service_request is not found" do
      stub(KafkaMock, :publish_mongo_event, fn _event -> :ok end)

      user_id = UUID.uuid4()
      client_id = UUID.uuid4()
      employee_id = UUID.uuid4()
      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)
      insert(:patient, _id: patient_id_hash)

      job = insert(:job)
      expect_job_update(job._id, "Service request is not found", 409)

      assert :ok =
               Consumer.consume(%ApprovalCreateJob{
                 _id: to_string(job._id),
                 patient_id: patient_id,
                 patient_id_hash: patient_id_hash,
                 resources: nil,
                 service_request: %{
                   "identifier" => %{
                     "type" => %{"coding" => [%{"code" => "service_request", "system" => "eHealth/resources"}]},
                     "value" => UUID.uuid4()
                   }
                 },
                 granted_to: %{
                   "identifier" => %{
                     "type" => %{"coding" => [%{"code" => "employee", "system" => "eHealth/resources"}]},
                     "value" => employee_id
                   }
                 },
                 access_level: Approval.access_level(:read),
                 user_id: user_id,
                 client_id: client_id
               })
    end

    test "failed approval create when granted_to and granted_resources params are invalid" do
      stub(KafkaMock, :publish_mongo_event, fn _event -> :ok end)

      user_id = UUID.uuid4()
      client_id = UUID.uuid4()
      employee_id = UUID.uuid4()
      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)

      episode_1 =
        build(:episode, managing_organization: reference_coding(Mongo.string_to_uuid(client_id), code: "legal_entity"))

      episode_2 = build(:episode)

      insert(
        :patient,
        _id: patient_id_hash,
        episodes: %{
          UUID.binary_to_string!(episode_1.id.binary) => episode_1,
          UUID.binary_to_string!(episode_2.id.binary) => episode_2
        }
      )

      expect_doctor(client_id)
      expect_employees_by_user_id_client_id([UUID.uuid4()])
      expect_person(patient_id)

      job = insert(:job)

      expect_job_update(
        job._id,
        %{
          invalid: [
            %{
              entry: "$.granted_resources.[1].identifier.value",
              entry_type: "json_data_property",
              rules: [
                %{
                  description: "Managing_organization does not correspond to user's legal_entity",
                  params: [],
                  rule: :invalid
                }
              ]
            },
            %{
              entry: "$.granted_to.identifier.value",
              entry_type: "json_data_property",
              rules: [
                %{
                  description: "Employee does not related to user",
                  params: [],
                  rule: :invalid
                }
              ]
            }
          ],
          message:
            "Validation failed. You can find validators description at our API Manifest: http://docs.apimanifest.apiary.io/#introduction/interacting-with-api/errors.",
          type: :validation_failed
        },
        422
      )

      assert :ok =
               Consumer.consume(%ApprovalCreateJob{
                 _id: to_string(job._id),
                 patient_id: patient_id,
                 patient_id_hash: patient_id_hash,
                 resources: [
                   %{
                     "identifier" => %{
                       "type" => %{"coding" => [%{"code" => "episode_of_care", "system" => "eHealth/resources"}]},
                       "value" => UUID.binary_to_string!(episode_1.id.binary)
                     }
                   },
                   %{
                     "identifier" => %{
                       "type" => %{"coding" => [%{"code" => "episode_of_care", "system" => "eHealth/resources"}]},
                       "value" => UUID.binary_to_string!(episode_2.id.binary)
                     }
                   }
                 ],
                 service_request: nil,
                 granted_to: %{
                   "identifier" => %{
                     "type" => %{"coding" => [%{"code" => "employee", "system" => "eHealth/resources"}]},
                     "value" => employee_id
                   }
                 },
                 access_level: Approval.access_level(:read),
                 user_id: user_id,
                 client_id: client_id
               })
    end
  end

  defp build_episode_references(episode_ids) when is_list(episode_ids) do
    Enum.map(episode_ids, fn episode_id ->
      build(:reference,
        identifier:
          build(:identifier,
            value: UUID.binary_to_string!(episode_id),
            type: codeable_concept_coding(system: "eHealth/resources", code: "episode_of_care")
          )
      )
    end)
  end
end