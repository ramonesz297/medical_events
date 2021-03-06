defmodule Api.Rpc.RpcTest do
  @moduledoc false

  use ExUnit.Case
  import Core.Factories

  alias Api.Rpc
  alias Core.Approval
  alias Core.Patients

  test "get encounter status by id" do
    encounter_1 = build(:encounter)
    encounter_2 = build(:encounter, status: "entered_in_error")
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

    assert {:ok, "finished"} == Rpc.encounter_status_by_id(patient_id, UUID.binary_to_string!(encounter_1.id.binary))

    assert {:ok, "entered_in_error"} ==
             Rpc.encounter_status_by_id(patient_id, UUID.binary_to_string!(encounter_2.id.binary))

    refute Rpc.encounter_status_by_id(patient_id, UUID.uuid4())
  end

  describe "episode_by_id/2" do
    test "episode not found" do
      refute Rpc.episode_by_id(UUID.uuid4(), UUID.uuid4())
    end

    test "episode was found" do
      episode_1 = build(:episode)
      episode_2 = build(:episode)
      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)
      episode_id = UUID.binary_to_string!(episode_1.id.binary)

      insert(
        :patient,
        _id: patient_id_hash,
        episodes: %{
          episode_id => episode_1,
          UUID.binary_to_string!(episode_2.id.binary) => episode_2
        }
      )

      assert {:ok, %{id: ^episode_id}} = Rpc.episode_by_id(patient_id, episode_id)
    end
  end

  describe "service_request_by_id/2" do
    test "service_request not found" do
      refute Rpc.service_request_by_id(UUID.uuid4(), UUID.uuid4())
    end

    test "service_request was found" do
      patient_id = UUID.uuid4()
      service_request_1 = insert(:service_request, subject: Patients.get_pk_hash(patient_id))
      insert(:service_request)
      service_request_id = to_string(service_request_1._id)

      assert {:ok, %{id: ^service_request_id}} = Rpc.service_request_by_id(patient_id, service_request_id)
    end
  end

  describe "diagnostic_report_by_id/2" do
    test "diagnostic_report not found" do
      refute Rpc.diagnostic_report_by_id(UUID.uuid4(), UUID.uuid4())
    end

    test "diagnostic_report was found" do
      episode_1 = build(:episode)
      episode_2 = build(:episode)

      encounter_1 =
        build(:encounter, episode: reference_coding(episode_1.id, system: "eHealth/resources", code: "episode"))

      encounter_2 = build(:encounter)

      diagnostic_report_1 =
        build(:diagnostic_report,
          encounter: reference_coding(encounter_1.id, system: "eHealth/resources", code: "encounter")
        )

      diagnostic_report_2 =
        build(:diagnostic_report,
          encounter: reference_coding(encounter_2.id, system: "eHealth/resources", code: "encounter")
        )

      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)
      episode_id = to_string(episode_1.id)
      diagnostic_report_id = to_string(diagnostic_report_1.id)

      insert(
        :patient,
        _id: patient_id_hash,
        episodes: %{
          episode_id => episode_1,
          to_string(episode_2.id) => episode_2
        },
        encounters: %{to_string(encounter_1.id) => encounter_1, to_string(encounter_2.id) => encounter_2},
        diagnostic_reports: %{
          diagnostic_report_id => diagnostic_report_1,
          to_string(diagnostic_report_2.id) => diagnostic_report_2
        }
      )

      assert {:ok, %{id: ^diagnostic_report_id}} = Rpc.diagnostic_report_by_id(patient_id, diagnostic_report_id)
    end
  end

  describe "episode_by_encounter_id/2" do
    test "episode not found" do
      refute Rpc.episode_by_encounter_id(UUID.uuid4(), UUID.uuid4())
    end

    test "episode was found" do
      episode_1 = build(:episode)
      episode_2 = build(:episode)

      encounter_1 =
        build(:encounter, episode: reference_coding(episode_1.id, system: "eHealth/resources", code: "episode"))

      encounter_2 = build(:encounter)

      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)
      episode_id = to_string(episode_1.id)
      encounter_id = to_string(encounter_1.id)

      insert(
        :patient,
        _id: patient_id_hash,
        episodes: %{
          episode_id => episode_1,
          to_string(episode_2.id) => episode_2
        },
        encounters: %{encounter_id => encounter_1, to_string(encounter_2.id) => encounter_2}
      )

      assert {:ok, %{id: ^episode_id}} = Rpc.episode_by_encounter_id(patient_id, encounter_id)
    end
  end

  describe "episode_by_observation_id/2" do
    test "episode not found" do
      refute Rpc.episode_by_observation_id(UUID.uuid4(), UUID.uuid4())
    end

    test "encounter not found" do
      observation = insert(:observation)
      refute Rpc.episode_by_observation_id(UUID.uuid4(), to_string(observation._id))
    end

    test "episode was found" do
      episode_1 = build(:episode)
      episode_2 = build(:episode)

      encounter_1 =
        build(:encounter, episode: reference_coding(episode_1.id, system: "eHealth/resources", code: "episode"))

      encounter_2 = build(:encounter)

      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)
      episode_id = to_string(episode_1.id)
      encounter_id = to_string(encounter_1.id)

      insert(
        :patient,
        _id: patient_id_hash,
        episodes: %{
          episode_id => episode_1,
          to_string(episode_2.id) => episode_2
        },
        encounters: %{encounter_id => encounter_1, to_string(encounter_2.id) => encounter_2}
      )

      observation =
        insert(:observation,
          patient_id: patient_id_hash,
          context: reference_coding(encounter_id, system: "eHealth/resources", code: "encounter")
        )

      assert {:ok, %{id: ^episode_id}} = Rpc.episode_by_observation_id(patient_id, to_string(observation._id))
    end
  end

  describe "episode_by_condition_id/2" do
    test "episode not found" do
      refute Rpc.episode_by_condition_id(UUID.uuid4(), UUID.uuid4())
    end

    test "encounter not found" do
      condition = insert(:condition)
      refute Rpc.episode_by_condition_id(UUID.uuid4(), to_string(condition._id))
    end

    test "episode was found" do
      episode_1 = build(:episode)
      episode_2 = build(:episode)

      encounter_1 =
        build(:encounter, episode: reference_coding(episode_1.id, system: "eHealth/resources", code: "episode"))

      encounter_2 = build(:encounter)

      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)
      episode_id = to_string(episode_1.id)
      encounter_id = to_string(encounter_1.id)

      insert(
        :patient,
        _id: patient_id_hash,
        episodes: %{
          episode_id => episode_1,
          to_string(episode_2.id) => episode_2
        },
        encounters: %{encounter_id => encounter_1, to_string(encounter_2.id) => encounter_2}
      )

      condition =
        insert(:condition,
          patient_id: patient_id_hash,
          context: reference_coding(encounter_id, system: "eHealth/resources", code: "encounter")
        )

      assert {:ok, %{id: ^episode_id}} = Rpc.episode_by_condition_id(patient_id, to_string(condition._id))
    end
  end

  describe "episode_by_allergy_intolerance_id/2" do
    test "episode not found" do
      refute Rpc.episode_by_allergy_intolerance_id(UUID.uuid4(), UUID.uuid4())
    end

    test "episode was found" do
      episode_1 = build(:episode)
      episode_2 = build(:episode)

      encounter_1 =
        build(:encounter, episode: reference_coding(episode_1.id, system: "eHealth/resources", code: "episode"))

      encounter_2 = build(:encounter)

      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)
      episode_id = to_string(episode_1.id)
      encounter_id = to_string(encounter_1.id)

      allergy_intolerance_1 =
        build(:allergy_intolerance,
          context: reference_coding(encounter_id, system: "eHealth/resources", code: "encounter")
        )

      allergy_intolerance_2 = build(:allergy_intolerance)
      allergy_intolerance_id = to_string(allergy_intolerance_1.id)

      insert(
        :patient,
        _id: patient_id_hash,
        episodes: %{
          episode_id => episode_1,
          to_string(episode_2.id) => episode_2
        },
        encounters: %{encounter_id => encounter_1, to_string(encounter_2.id) => encounter_2},
        allergy_intolerances: %{
          allergy_intolerance_id => allergy_intolerance_1,
          to_string(allergy_intolerance_2.id) => allergy_intolerance_2
        }
      )

      assert {:ok, %{id: ^episode_id}} = Rpc.episode_by_allergy_intolerance_id(patient_id, allergy_intolerance_id)
    end
  end

  describe "episode_by_immunization_id/2" do
    test "episode not found" do
      refute Rpc.episode_by_immunization_id(UUID.uuid4(), UUID.uuid4())
    end

    test "episode was found" do
      episode_1 = build(:episode)
      episode_2 = build(:episode)

      encounter_1 =
        build(:encounter, episode: reference_coding(episode_1.id, system: "eHealth/resources", code: "episode"))

      encounter_2 = build(:encounter)

      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)
      episode_id = to_string(episode_1.id)
      encounter_id = to_string(encounter_1.id)

      immunization_1 =
        build(:immunization,
          context: reference_coding(encounter_id, system: "eHealth/resources", code: "encounter")
        )

      immunization_2 = build(:immunization)
      immunization_id = to_string(immunization_1.id)

      insert(
        :patient,
        _id: patient_id_hash,
        episodes: %{
          episode_id => episode_1,
          to_string(episode_2.id) => episode_2
        },
        encounters: %{encounter_id => encounter_1, to_string(encounter_2.id) => encounter_2},
        immunizations: %{
          immunization_id => immunization_1,
          to_string(immunization_2.id) => immunization_2
        }
      )

      assert {:ok, %{id: ^episode_id}} = Rpc.episode_by_immunization_id(patient_id, immunization_id)
    end
  end

  describe "episode_by_risk_assessment_id/2" do
    test "episode not found" do
      refute Rpc.episode_by_risk_assessment_id(UUID.uuid4(), UUID.uuid4())
    end

    test "episode was found" do
      episode_1 = build(:episode)
      episode_2 = build(:episode)

      encounter_1 =
        build(:encounter, episode: reference_coding(episode_1.id, system: "eHealth/resources", code: "episode"))

      encounter_2 = build(:encounter)

      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)
      episode_id = to_string(episode_1.id)
      encounter_id = to_string(encounter_1.id)

      risk_assessment_1 =
        build(:risk_assessment,
          context: reference_coding(encounter_id, system: "eHealth/resources", code: "encounter")
        )

      risk_assessment_2 = build(:risk_assessment)
      risk_assessment_id = to_string(risk_assessment_1.id)

      insert(
        :patient,
        _id: patient_id_hash,
        episodes: %{
          episode_id => episode_1,
          to_string(episode_2.id) => episode_2
        },
        encounters: %{encounter_id => encounter_1, to_string(encounter_2.id) => encounter_2},
        risk_assessments: %{
          risk_assessment_id => risk_assessment_1,
          to_string(risk_assessment_2.id) => risk_assessment_2
        }
      )

      assert {:ok, %{id: ^episode_id}} = Rpc.episode_by_risk_assessment_id(patient_id, risk_assessment_id)
    end
  end

  describe "episode_by_device_id/2" do
    test "episode not found" do
      refute Rpc.episode_by_device_id(UUID.uuid4(), UUID.uuid4())
    end

    test "episode was found" do
      episode_1 = build(:episode)
      episode_2 = build(:episode)

      encounter_1 =
        build(:encounter, episode: reference_coding(episode_1.id, system: "eHealth/resources", code: "episode"))

      encounter_2 = build(:encounter)

      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)
      episode_id = to_string(episode_1.id)
      encounter_id = to_string(encounter_1.id)

      device_1 =
        build(:device,
          context: reference_coding(encounter_id, system: "eHealth/resources", code: "encounter")
        )

      device_2 = build(:device)
      device_id = to_string(device_1.id)

      insert(
        :patient,
        _id: patient_id_hash,
        episodes: %{
          episode_id => episode_1,
          to_string(episode_2.id) => episode_2
        },
        encounters: %{encounter_id => encounter_1, to_string(encounter_2.id) => encounter_2},
        devices: %{
          device_id => device_1,
          to_string(device_2.id) => device_2
        }
      )

      assert {:ok, %{id: ^episode_id}} = Rpc.episode_by_device_id(patient_id, device_id)
    end
  end

  describe "episode_by_medication_statement_id/2" do
    test "episode not found" do
      refute Rpc.episode_by_medication_statement_id(UUID.uuid4(), UUID.uuid4())
    end

    test "episode was found" do
      episode_1 = build(:episode)
      episode_2 = build(:episode)

      encounter_1 =
        build(:encounter, episode: reference_coding(episode_1.id, system: "eHealth/resources", code: "episode"))

      encounter_2 = build(:encounter)

      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)
      episode_id = to_string(episode_1.id)
      encounter_id = to_string(encounter_1.id)

      medication_statement_1 =
        build(:medication_statement,
          context: reference_coding(encounter_id, system: "eHealth/resources", code: "encounter")
        )

      medication_statement_2 = build(:medication_statement)
      medication_statement_id = to_string(medication_statement_1.id)

      insert(
        :patient,
        _id: patient_id_hash,
        episodes: %{
          episode_id => episode_1,
          to_string(episode_2.id) => episode_2
        },
        encounters: %{encounter_id => encounter_1, to_string(encounter_2.id) => encounter_2},
        medication_statements: %{
          medication_statement_id => medication_statement_1,
          to_string(medication_statement_2.id) => medication_statement_2
        }
      )

      assert {:ok, %{id: ^episode_id}} = Rpc.episode_by_medication_statement_id(patient_id, medication_statement_id)
    end
  end

  describe "episode_by_service_request_id/2" do
    test "episode not found" do
      refute Rpc.episode_by_service_request_id(UUID.uuid4(), UUID.uuid4())
    end

    test "episode was found" do
      episode_1 = build(:episode)
      episode_2 = build(:episode)

      encounter_1 =
        build(:encounter, episode: reference_coding(episode_1.id, system: "eHealth/resources", code: "episode"))

      encounter_2 = build(:encounter)

      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)
      episode_id = to_string(episode_1.id)
      encounter_id = to_string(encounter_1.id)

      service_request_1 =
        insert(:service_request,
          context: reference_coding(encounter_id, system: "eHealth/resources", code: "encounter")
        )

      insert(:service_request)
      service_request_id = to_string(service_request_1._id)

      insert(
        :patient,
        _id: patient_id_hash,
        episodes: %{
          episode_id => episode_1,
          to_string(episode_2.id) => episode_2
        },
        encounters: %{encounter_id => encounter_1, to_string(encounter_2.id) => encounter_2}
      )

      assert {:ok, %{id: ^episode_id}} = Rpc.episode_by_service_request_id(patient_id, service_request_id)
    end
  end

  describe "episode_by_diagnostic_report_id/2" do
    test "episode not found" do
      refute Rpc.episode_by_diagnostic_report_id(UUID.uuid4(), UUID.uuid4())
    end

    test "episode was found" do
      episode_1 = build(:episode)
      episode_2 = build(:episode)

      encounter_1 =
        build(:encounter, episode: reference_coding(episode_1.id, system: "eHealth/resources", code: "episode"))

      encounter_2 = build(:encounter)

      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)
      episode_id = to_string(episode_1.id)
      encounter_id = to_string(encounter_1.id)

      diagnostic_report_1 =
        build(:diagnostic_report,
          encounter: reference_coding(encounter_id, system: "eHealth/resources", code: "encounter")
        )

      diagnostic_report_2 = build(:diagnostic_report)
      diagnostic_report_id = to_string(diagnostic_report_1.id)

      insert(
        :patient,
        _id: patient_id_hash,
        episodes: %{
          episode_id => episode_1,
          to_string(episode_2.id) => episode_2
        },
        diagnostic_reports: %{
          diagnostic_report_id => diagnostic_report_1,
          to_string(diagnostic_report_2.id) => diagnostic_report_2
        },
        encounters: %{encounter_id => encounter_1, to_string(encounter_2.id) => encounter_2}
      )

      assert {:ok, %{id: ^episode_id}} = Rpc.episode_by_diagnostic_report_id(patient_id, diagnostic_report_id)
    end
  end

  describe "approvals_by_episode/3" do
    test "success get approvals by episode" do
      patient_id = UUID.uuid4()
      patient_id_hash = Patients.get_pk_hash(patient_id)

      approval = insert(:approval, patient_id: patient_id_hash, status: Approval.status(:active))
      insert(:approval, patient_id: patient_id_hash)
      [%{identifier: %{value: episode_id}}] = approval.granted_resources
      approval_id = to_string(approval._id)

      approvals =
        Rpc.approvals_by_episode(patient_id, [to_string(approval.granted_to.identifier.value)], to_string(episode_id))

      assert [%{id: ^approval_id}] = approvals
    end
  end
end
