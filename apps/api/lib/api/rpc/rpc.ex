defmodule Api.Rpc do
  @moduledoc """
  This module contains functions that are called from other pods via RPC.
  """

  alias Api.Web.ApprovalView
  alias Api.Web.DiagnosticReportView
  alias Api.Web.EpisodeView
  alias Api.Web.ServiceRequestView
  alias Core.Approval
  alias Core.Approvals
  alias Core.Conditions
  alias Core.Observations
  alias Core.Patients
  alias Core.Patients.AllergyIntolerances
  alias Core.Patients.Devices
  alias Core.Patients.DiagnosticReports
  alias Core.Patients.Encounters
  alias Core.Patients.Episodes
  alias Core.Patients.Immunizations
  alias Core.Patients.MedicationStatements
  alias Core.Patients.RiskAssessments
  alias Core.ServiceRequests

  @status_active Approval.status(:active)

  @type approval() :: %{
          access_level: binary(),
          granted_by: reference_(),
          granted_resources: list(reference_()),
          granted_to: reference_(),
          id: binary(),
          inserted_at: DateTime,
          reason: nil | reference_(),
          status: binary(),
          updated_at: DateTime,
          urgent: map()
        }

  @type coding() :: %{
          system: binary(),
          code: binary()
        }

  @type codeable_concept() :: %{
          coding: list(coding),
          text: binary()
        }

  @type diagnosis() :: %{
          code: codeable_concept(),
          condition: reference_(),
          rank: integer(),
          role: coding()
        }

  @type evidence() :: %{
          codes: list(codeable_concept()),
          details: list(reference_())
        }

  @type diagnoses_history() :: %{
          date: Date,
          diagnoses: list(diagnosis),
          evidence: evidence(),
          is_active: boolean()
        }

  @type identifier_() :: %{
          type: map(),
          value: binary()
        }

  @type reference_() :: %{
          display_value: nil | binary(),
          identifier: identifier_()
        }

  @type period() :: %{
          start: binary(),
          end: binary()
        }

  @type status_history() :: %{
          status: binary(),
          status_reason: codeable_concept(),
          inserted_at: binary(),
          inserted_by: binary()
        }

  @type episode() :: %{
          care_manager: reference_(),
          closing_summary: binary(),
          current_diagnoses: list(diagnosis),
          diagnoses_history: list(diagnoses_history),
          explanator_letter: binary(),
          id: binary(),
          inserted_at: DateTime,
          managing_organization: reference_(),
          name: binary(),
          period: period(),
          status: binary(),
          status_history: list(status_history()),
          status_reason: codeable_concept(),
          type: coding(),
          updated_at: DateTime
        }

  @type service_request() :: %{
          authored_on: binary(),
          category: codeable_concept(),
          code: reference_(),
          completed_with: reference_(),
          context: reference_(),
          expiration_date: DateTime,
          id: binary(),
          inserted_at: DateTime,
          intent: binary(),
          note: binary(),
          occurrence_date_time: DateTime,
          patient_instruction: binary(),
          permitted_resources: list(reference_()),
          priority: binary(),
          reason_reference: list(reference_()),
          requester_legal_entity: reference_(),
          requisition: binary(),
          status: binary(),
          status_history: list(status_history()),
          status_reason: codeable_concept(),
          subject: binary(),
          supporting_info: list(reference_()),
          updated_at: DateTime,
          used_by_employee: reference_(),
          used_by_legal_entity: reference_()
        }

  @type diagnostic_report() :: %{
          based_on: reference_(),
          cancellation_reason: codeable_concept(),
          category: list(codeable_concept()),
          code: reference_(),
          conclusion: binary(),
          conclusion_code: codeable_concept(),
          effective_date_time: binary(),
          encounter: reference_(),
          explanatory_letter: binary(),
          id: binary(),
          inserted_at: DateTime,
          issued: binary(),
          managing_organization: reference_(),
          origin_episode: reference_(),
          performer: map(),
          recorded_by: reference_(),
          results_interpreter: map(),
          status: binary(),
          updated_at: DateTime
        }

  @doc """
  Get encounter status by patient id, encounter id

  ## Examples

      iex> Api.Rpc.encounter_status_by_id(
        "26e673e1-1d68-413e-b96c-407b45d9f572",
        "d221d7f1-81cb-44d3-b6d4-8d7e42f97ff9"
      )
      {:ok, "finished"}
  """
  @spec encounter_status_by_id(patient_id :: binary(), encounter_id :: binary()) :: nil | {:ok, binary}
  def encounter_status_by_id(patient_id, encounter_id) do
    patient_id
    |> Patients.get_pk_hash()
    |> Encounters.get_status_by_id(encounter_id)
  end

  @doc """
  Get episode by patient id, episode id

  ## Examples

      iex> Api.Rpc.episode_by_id(
        "26e673e1-1d68-413e-b96c-407b45d9f572",
        "d221d7f1-81cb-44d3-b6d4-8d7e42f97ff9"
      )
      {:ok, %{
        care_manager: %{
          display_value: nil,
          identifier: %{
            type: %{
              coding: [%{code: "employee", system: "eHealth/resources"}],
              text: "code text"
            },
            value: "6e3db345-f493-404d-bac0-83e7ef13bd64"
          }
        },
        closing_summary: "closing summary",
        current_diagnoses: [
          %{
            code: %{
              coding: [%{code: "R80", system: "eHealth/ICPC2/condition_codes"}],
              text: "code text"
            },
            condition: %{
              display_value: nil,
              identifier: %{
                type: %{
                  coding: [%{code: "condition", system: "eHealth/resources"}],
                  text: "code text"
                },
                value: "9b319b2c-644f-45b2-b35b-e01181e053c7"
              }
            },
            rank: 554,
            role: %{
              coding: [%{code: "primary", system: "eHealth/diagnosis_roles"}],
              text: "code text"
            }
          },
          %{
            code: %{
              coding: [%{code: "R80", system: "eHealth/ICPC2/condition_codes"}],
              text: "code text"
            },
            condition: %{
              display_value: nil,
              identifier: %{
                type: %{
                  coding: [%{code: "condition", system: "eHealth/resources"}],
                  text: "code text"
                },
                value: "09576df2-a2dd-4dbe-84e6-8c875379eeed"
              }
            },
            rank: 843,
            role: %{
              coding: [%{code: "primary", system: "eHealth/diagnosis_roles"}],
              text: "code text"
            }
          }
        ],
        diagnoses_history: [
          %{
            date: ~D[2019-01-14],
            diagnoses: [
              %{
                code: %{
                  coding: [%{code: "R80", system: "eHealth/ICPC2/condition_codes"}],
                  text: "code text"
                },
                condition: %{
                  display_value: nil,
                  identifier: %{
                    type: %{
                      coding: [%{code: "condition", system: "eHealth/resources"}],
                      text: "code text"
                    },
                    value: "9b319b2c-644f-45b2-b35b-e01181e053c7"
                  }
                },
                rank: 554,
                role: %{
                  coding: [%{code: "primary", system: "eHealth/diagnosis_roles"}],
                  text: "code text"
                }
              },
              %{
                code: %{
                  coding: [%{code: "R80", system: "eHealth/ICPC2/condition_codes"}],
                  text: "code text"
                },
                condition: %{
                  display_value: nil,
                  identifier: %{
                    type: %{
                      coding: [%{code: "condition", system: "eHealth/resources"}],
                      text: "code text"
                    },
                    value: "09576df2-a2dd-4dbe-84e6-8c875379eeed"
                  }
                },
                rank: 843,
                role: %{
                  coding: [%{code: "primary", system: "eHealth/diagnosis_roles"}],
                  text: "code text"
                }
              }
            ],
            evidence: %{
              display_value: nil,
              identifier: %{
                type: %{
                  coding: [%{code: "1", system: "eHealth/resources"}],
                  text: "code text"
                },
                value: "e2e8d8ed-7c68-4721-a202-0fab733a3a00"
              }
            },
            is_active: true
          }
        ],
        explanatory_letter: "explanatory letter",
        id: "2b1479b2-aa5f-4ea4-b333-662f1236dff5",
        inserted_at: #DateTime<2019-01-14 14:29:44.167Z>,
        managing_organization: %{
          display_value: nil,
          identifier: %{
            type: %{
              coding: [%{code: "legal_entity", system: "eHealth/resources"}],
              text: "code text"
            },
            value: "79707880-e3f6-471a-b6bf-e19725ad749e"
          }
        },
        name: "ОРВИ 2018",
        period: %{end: "2019-01-14", start: "2019-01-14"},
        status: "active",
        status_history: [
          %{
            inserted_at: "2019-01-14T14:29:44.167Z",
            inserted_by: "cfaaca23-0536-42da-9f0c-055dcd32c467",
            status: "active",
            status_reason: %{
              coding: [%{code: "1", system: "eHealth/episode_closing_reasons"}],
              text: "code text"
            }
          }
        ],
        status_reason: %{
          coding: [%{code: "1", system: "eHealth/resources"}],
          text: "code text"
        },
        type: %{code: "primary_care", system: "eHealth/episode_types"},
        updated_at: #DateTime<2019-01-14 14:29:44.167Z>
      }}
  """
  @spec episode_by_id(patient_id :: binary(), episode_id :: binary()) :: nil | {:ok, episode}
  def episode_by_id(patient_id, episode_id) do
    with {:ok, episode} <-
           patient_id
           |> Patients.get_pk_hash()
           |> Episodes.get_by_id(episode_id) do
      {:ok, EpisodeView.render("show.json", %{episode: episode})}
    end
  end

  @doc """
  Get episode by patient id, encounter id

  ## Examples

      iex> Api.Rpc.episode_by_encounter_id(
        "26e673e1-1d68-413e-b96c-407b45d9f572",
        "d221d7f1-81cb-44d3-b6d4-8d7e42f97ff9"
      )
      {:ok, %{
        care_manager: %{
          display_value: nil,
          identifier: %{
            type: %{
              coding: [%{code: "employee", system: "eHealth/resources"}],
              text: "code text"
            },
            value: "1857c60a-cbc5-4244-9a31-9dd310828346"
          }
        },
        closing_summary: "closing summary",
        current_diagnoses: [
          %{
            code: %{
              coding: [%{code: "R80", system: "eHealth/ICPC2/condition_codes"}],
              text: "code text"
            },
            condition: %{
              display_value: nil,
              identifier: %{
                type: %{
                  coding: [%{code: "condition", system: "eHealth/resources"}],
                  text: "code text"
                },
                value: "9547dfe3-7830-470e-a95a-4c046e59fd46"
              }
            },
            rank: 930,
            role: %{
              coding: [%{code: "primary", system: "eHealth/diagnosis_roles"}],
              text: "code text"
            }
          },
          %{
            code: %{
              coding: [%{code: "R80", system: "eHealth/ICPC2/condition_codes"}],
              text: "code text"
            },
            condition: %{
              display_value: nil,
              identifier: %{
                type: %{
                  coding: [%{code: "condition", system: "eHealth/resources"}],
                  text: "code text"
                },
                value: "aa456b10-141f-4e88-a7a2-f41cae4b8b50"
              }
            },
            rank: 890,
            role: %{
              coding: [%{code: "primary", system: "eHealth/diagnosis_roles"}],
              text: "code text"
            }
          }
        ],
        diagnoses_history: [
          %{
            date: ~D[2019-02-04],
            diagnoses: [
              %{
                code: %{
                  coding: [%{code: "R80", system: "eHealth/ICPC2/condition_codes"}],
                  text: "code text"
                },
                condition: %{
                  display_value: nil,
                  identifier: %{
                    type: %{
                      coding: [%{code: "condition", system: "eHealth/resources"}],
                      text: "code text"
                    },
                    value: "9547dfe3-7830-470e-a95a-4c046e59fd46"
                  }
                },
                rank: 930,
                role: %{
                  coding: [%{code: "primary", system: "eHealth/diagnosis_roles"}],
                  text: "code text"
                }
              },
              %{
                code: %{
                  coding: [%{code: "R80", system: "eHealth/ICPC2/condition_codes"}],
                  text: "code text"
                },
                condition: %{
                  display_value: nil,
                  identifier: %{
                    type: %{
                      coding: [%{code: "condition", system: "eHealth/resources"}],
                      text: "code text"
                    },
                    value: "aa456b10-141f-4e88-a7a2-f41cae4b8b50"
                  }
                },
                rank: 890,
                role: %{
                  coding: [%{code: "primary", system: "eHealth/diagnosis_roles"}],
                  text: "code text"
                }
              }
            ],
            evidence: %{
              display_value: nil,
              identifier: %{
                type: %{
                  coding: [%{code: "1", system: "eHealth/resources"}],
                  text: "code text"
                },
                value: "30c96863-6579-47ee-9811-a6ec45ed0914"
              }
            },
            is_active: true
          }
        ],
        explanatory_letter: "explanatory letter",
        id: "4d5d59bb-9341-449b-905a-bd1aef84c68f",
        inserted_at: #DateTime<2019-02-04 13:29:00.630Z>,
        managing_organization: %{
          display_value: nil,
          identifier: %{
            type: %{
              coding: [%{code: "legal_entity", system: "eHealth/resources"}],
              text: "code text"
            },
            value: "8264b816-5d74-4039-a68d-3b486f48c4b1"
          }
        },
        name: "ОРВИ 2018",
        period: %{end: "2019-02-04", start: "2019-02-04"},
        referral_requests: [
          %{
            display_value: nil,
            identifier: %{
              type: %{
                coding: [%{code: "service_request", system: "eHealth/resources"}],
                text: "code text"
              },
              value: "1a403ff8-9ccb-433e-8a5f-b3e252ee3b8c"
            }
          }
        ],
        status: "active",
        status_history: [
          %{
            inserted_at: "2019-02-04T13:29:00.630Z",
            inserted_by: "c056e131-433e-462b-a1d6-d35e75ff6106",
            status: "active",
            status_reason: %{
              coding: [%{code: "1", system: "eHealth/episode_closing_reasons"}],
              text: "code text"
            }
          }
        ],
        status_reason: %{
          coding: [%{code: "1", system: "eHealth/resources"}],
          text: "code text"
        },
        type: %{code: "primary_care", system: "eHealth/episode_types"},
        updated_at: #DateTime<2019-02-04 13:29:00.630Z>
      }}
  """
  @spec episode_by_encounter_id(patient_id :: binary(), encounter_id :: binary()) :: nil | {:ok, episode}
  def episode_by_encounter_id(patient_id, encounter_id) do
    patient_id_hash = Patients.get_pk_hash(patient_id)

    with {:ok, encounter} <- Encounters.get_by_id(patient_id_hash, encounter_id),
         {:ok, episode} <- Episodes.get_by_id(patient_id_hash, to_string(encounter.episode.identifier.value)) do
      {:ok, EpisodeView.render("show.json", %{episode: episode})}
    end
  end

  @doc """
  Get episode by patient id, observation id

  ## Examples

      iex> Api.Rpc.episode_by_observation_id(
        "26e673e1-1d68-413e-b96c-407b45d9f572",
        "d221d7f1-81cb-44d3-b6d4-8d7e42f97ff9"
      )
      {:ok, %{
        care_manager: %{
          display_value: nil,
          identifier: %{
            type: %{
              coding: [%{code: "employee", system: "eHealth/resources"}],
              text: "code text"
            },
            value: "1857c60a-cbc5-4244-9a31-9dd310828346"
          }
        },
        closing_summary: "closing summary",
        current_diagnoses: [
          %{
            code: %{
              coding: [%{code: "R80", system: "eHealth/ICPC2/condition_codes"}],
              text: "code text"
            },
            condition: %{
              display_value: nil,
              identifier: %{
                type: %{
                  coding: [%{code: "condition", system: "eHealth/resources"}],
                  text: "code text"
                },
                value: "9547dfe3-7830-470e-a95a-4c046e59fd46"
              }
            },
            rank: 930,
            role: %{
              coding: [%{code: "primary", system: "eHealth/diagnosis_roles"}],
              text: "code text"
            }
          },
          %{
            code: %{
              coding: [%{code: "R80", system: "eHealth/ICPC2/condition_codes"}],
              text: "code text"
            },
            condition: %{
              display_value: nil,
              identifier: %{
                type: %{
                  coding: [%{code: "condition", system: "eHealth/resources"}],
                  text: "code text"
                },
                value: "aa456b10-141f-4e88-a7a2-f41cae4b8b50"
              }
            },
            rank: 890,
            role: %{
              coding: [%{code: "primary", system: "eHealth/diagnosis_roles"}],
              text: "code text"
            }
          }
        ],
        diagnoses_history: [
          %{
            date: ~D[2019-02-04],
            diagnoses: [
              %{
                code: %{
                  coding: [%{code: "R80", system: "eHealth/ICPC2/condition_codes"}],
                  text: "code text"
                },
                condition: %{
                  display_value: nil,
                  identifier: %{
                    type: %{
                      coding: [%{code: "condition", system: "eHealth/resources"}],
                      text: "code text"
                    },
                    value: "9547dfe3-7830-470e-a95a-4c046e59fd46"
                  }
                },
                rank: 930,
                role: %{
                  coding: [%{code: "primary", system: "eHealth/diagnosis_roles"}],
                  text: "code text"
                }
              },
              %{
                code: %{
                  coding: [%{code: "R80", system: "eHealth/ICPC2/condition_codes"}],
                  text: "code text"
                },
                condition: %{
                  display_value: nil,
                  identifier: %{
                    type: %{
                      coding: [%{code: "condition", system: "eHealth/resources"}],
                      text: "code text"
                    },
                    value: "aa456b10-141f-4e88-a7a2-f41cae4b8b50"
                  }
                },
                rank: 890,
                role: %{
                  coding: [%{code: "primary", system: "eHealth/diagnosis_roles"}],
                  text: "code text"
                }
              }
            ],
            evidence: %{
              display_value: nil,
              identifier: %{
                type: %{
                  coding: [%{code: "1", system: "eHealth/resources"}],
                  text: "code text"
                },
                value: "30c96863-6579-47ee-9811-a6ec45ed0914"
              }
            },
            is_active: true
          }
        ],
        explanatory_letter: "explanatory letter",
        id: "4d5d59bb-9341-449b-905a-bd1aef84c68f",
        inserted_at: #DateTime<2019-02-04 13:29:00.630Z>,
        managing_organization: %{
          display_value: nil,
          identifier: %{
            type: %{
              coding: [%{code: "legal_entity", system: "eHealth/resources"}],
              text: "code text"
            },
            value: "8264b816-5d74-4039-a68d-3b486f48c4b1"
          }
        },
        name: "ОРВИ 2018",
        period: %{end: "2019-02-04", start: "2019-02-04"},
        referral_requests: [
          %{
            display_value: nil,
            identifier: %{
              type: %{
                coding: [%{code: "service_request", system: "eHealth/resources"}],
                text: "code text"
              },
              value: "1a403ff8-9ccb-433e-8a5f-b3e252ee3b8c"
            }
          }
        ],
        status: "active",
        status_history: [
          %{
            inserted_at: "2019-02-04T13:29:00.630Z",
            inserted_by: "c056e131-433e-462b-a1d6-d35e75ff6106",
            status: "active",
            status_reason: %{
              coding: [%{code: "1", system: "eHealth/episode_closing_reasons"}],
              text: "code text"
            }
          }
        ],
        status_reason: %{
          coding: [%{code: "1", system: "eHealth/resources"}],
          text: "code text"
        },
        type: %{code: "primary_care", system: "eHealth/episode_types"},
        updated_at: #DateTime<2019-02-04 13:29:00.630Z>
      }}
  """
  @spec episode_by_observation_id(patient_id :: binary(), observation_id :: binary()) :: nil | {:ok, episode}
  def episode_by_observation_id(patient_id, observation_id) do
    patient_id_hash = Patients.get_pk_hash(patient_id)

    with {:ok, observation} <- Observations.get_by_id(patient_id_hash, observation_id),
         {:ok, encounter} <- Encounters.get_by_id(patient_id_hash, to_string(observation.context.identifier.value)),
         {:ok, episode} <- Episodes.get_by_id(patient_id_hash, to_string(encounter.episode.identifier.value)) do
      {:ok, EpisodeView.render("show.json", %{episode: episode})}
    end
  end

  @doc """
  Get episode by patient id, condition id

  ## Examples

      iex> Api.Rpc.episode_by_condition_id(
        "26e673e1-1d68-413e-b96c-407b45d9f572",
        "d221d7f1-81cb-44d3-b6d4-8d7e42f97ff9"
      )
      {:ok, %{
        care_manager: %{
          display_value: nil,
          identifier: %{
            type: %{
              coding: [%{code: "employee", system: "eHealth/resources"}],
              text: "code text"
            },
            value: "1857c60a-cbc5-4244-9a31-9dd310828346"
          }
        },
        closing_summary: "closing summary",
        current_diagnoses: [
          %{
            code: %{
              coding: [%{code: "R80", system: "eHealth/ICPC2/condition_codes"}],
              text: "code text"
            },
            condition: %{
              display_value: nil,
              identifier: %{
                type: %{
                  coding: [%{code: "condition", system: "eHealth/resources"}],
                  text: "code text"
                },
                value: "9547dfe3-7830-470e-a95a-4c046e59fd46"
              }
            },
            rank: 930,
            role: %{
              coding: [%{code: "primary", system: "eHealth/diagnosis_roles"}],
              text: "code text"
            }
          },
          %{
            code: %{
              coding: [%{code: "R80", system: "eHealth/ICPC2/condition_codes"}],
              text: "code text"
            },
            condition: %{
              display_value: nil,
              identifier: %{
                type: %{
                  coding: [%{code: "condition", system: "eHealth/resources"}],
                  text: "code text"
                },
                value: "aa456b10-141f-4e88-a7a2-f41cae4b8b50"
              }
            },
            rank: 890,
            role: %{
              coding: [%{code: "primary", system: "eHealth/diagnosis_roles"}],
              text: "code text"
            }
          }
        ],
        diagnoses_history: [
          %{
            date: ~D[2019-02-04],
            diagnoses: [
              %{
                code: %{
                  coding: [%{code: "R80", system: "eHealth/ICPC2/condition_codes"}],
                  text: "code text"
                },
                condition: %{
                  display_value: nil,
                  identifier: %{
                    type: %{
                      coding: [%{code: "condition", system: "eHealth/resources"}],
                      text: "code text"
                    },
                    value: "9547dfe3-7830-470e-a95a-4c046e59fd46"
                  }
                },
                rank: 930,
                role: %{
                  coding: [%{code: "primary", system: "eHealth/diagnosis_roles"}],
                  text: "code text"
                }
              },
              %{
                code: %{
                  coding: [%{code: "R80", system: "eHealth/ICPC2/condition_codes"}],
                  text: "code text"
                },
                condition: %{
                  display_value: nil,
                  identifier: %{
                    type: %{
                      coding: [%{code: "condition", system: "eHealth/resources"}],
                      text: "code text"
                    },
                    value: "aa456b10-141f-4e88-a7a2-f41cae4b8b50"
                  }
                },
                rank: 890,
                role: %{
                  coding: [%{code: "primary", system: "eHealth/diagnosis_roles"}],
                  text: "code text"
                }
              }
            ],
            evidence: %{
              display_value: nil,
              identifier: %{
                type: %{
                  coding: [%{code: "1", system: "eHealth/resources"}],
                  text: "code text"
                },
                value: "30c96863-6579-47ee-9811-a6ec45ed0914"
              }
            },
            is_active: true
          }
        ],
        explanatory_letter: "explanatory letter",
        id: "4d5d59bb-9341-449b-905a-bd1aef84c68f",
        inserted_at: #DateTime<2019-02-04 13:29:00.630Z>,
        managing_organization: %{
          display_value: nil,
          identifier: %{
            type: %{
              coding: [%{code: "legal_entity", system: "eHealth/resources"}],
              text: "code text"
            },
            value: "8264b816-5d74-4039-a68d-3b486f48c4b1"
          }
        },
        name: "ОРВИ 2018",
        period: %{end: "2019-02-04", start: "2019-02-04"},
        referral_requests: [
          %{
            display_value: nil,
            identifier: %{
              type: %{
                coding: [%{code: "service_request", system: "eHealth/resources"}],
                text: "code text"
              },
              value: "1a403ff8-9ccb-433e-8a5f-b3e252ee3b8c"
            }
          }
        ],
        status: "active",
        status_history: [
          %{
            inserted_at: "2019-02-04T13:29:00.630Z",
            inserted_by: "c056e131-433e-462b-a1d6-d35e75ff6106",
            status: "active",
            status_reason: %{
              coding: [%{code: "1", system: "eHealth/episode_closing_reasons"}],
              text: "code text"
            }
          }
        ],
        status_reason: %{
          coding: [%{code: "1", system: "eHealth/resources"}],
          text: "code text"
        },
        type: %{code: "primary_care", system: "eHealth/episode_types"},
        updated_at: #DateTime<2019-02-04 13:29:00.630Z>
      }}
  """
  @spec episode_by_condition_id(patient_id :: binary(), condition_id :: binary()) :: nil | {:ok, episode}
  def episode_by_condition_id(patient_id, condition_id) do
    patient_id_hash = Patients.get_pk_hash(patient_id)

    with {:ok, condition} <- Conditions.get_by_id(patient_id_hash, condition_id),
         {:ok, encounter} <- Encounters.get_by_id(patient_id_hash, to_string(condition.context.identifier.value)),
         {:ok, episode} <- Episodes.get_by_id(patient_id_hash, to_string(encounter.episode.identifier.value)) do
      {:ok, EpisodeView.render("show.json", %{episode: episode})}
    end
  end

  @doc """
  Get episode by patient id, allergy intolerance id

  ## Examples

      iex> Api.Rpc.episode_by_allergy_intolerance_id(
        "26e673e1-1d68-413e-b96c-407b45d9f572",
        "d221d7f1-81cb-44d3-b6d4-8d7e42f97ff9"
      )
      {:ok, %{
        care_manager: %{
          display_value: nil,
          identifier: %{
            type: %{
              coding: [%{code: "employee", system: "eHealth/resources"}],
              text: "code text"
            },
            value: "1857c60a-cbc5-4244-9a31-9dd310828346"
          }
        },
        closing_summary: "closing summary",
        current_diagnoses: [
          %{
            code: %{
              coding: [%{code: "R80", system: "eHealth/ICPC2/condition_codes"}],
              text: "code text"
            },
            condition: %{
              display_value: nil,
              identifier: %{
                type: %{
                  coding: [%{code: "condition", system: "eHealth/resources"}],
                  text: "code text"
                },
                value: "9547dfe3-7830-470e-a95a-4c046e59fd46"
              }
            },
            rank: 930,
            role: %{
              coding: [%{code: "primary", system: "eHealth/diagnosis_roles"}],
              text: "code text"
            }
          },
          %{
            code: %{
              coding: [%{code: "R80", system: "eHealth/ICPC2/condition_codes"}],
              text: "code text"
            },
            condition: %{
              display_value: nil,
              identifier: %{
                type: %{
                  coding: [%{code: "condition", system: "eHealth/resources"}],
                  text: "code text"
                },
                value: "aa456b10-141f-4e88-a7a2-f41cae4b8b50"
              }
            },
            rank: 890,
            role: %{
              coding: [%{code: "primary", system: "eHealth/diagnosis_roles"}],
              text: "code text"
            }
          }
        ],
        diagnoses_history: [
          %{
            date: ~D[2019-02-04],
            diagnoses: [
              %{
                code: %{
                  coding: [%{code: "R80", system: "eHealth/ICPC2/condition_codes"}],
                  text: "code text"
                },
                condition: %{
                  display_value: nil,
                  identifier: %{
                    type: %{
                      coding: [%{code: "condition", system: "eHealth/resources"}],
                      text: "code text"
                    },
                    value: "9547dfe3-7830-470e-a95a-4c046e59fd46"
                  }
                },
                rank: 930,
                role: %{
                  coding: [%{code: "primary", system: "eHealth/diagnosis_roles"}],
                  text: "code text"
                }
              },
              %{
                code: %{
                  coding: [%{code: "R80", system: "eHealth/ICPC2/condition_codes"}],
                  text: "code text"
                },
                condition: %{
                  display_value: nil,
                  identifier: %{
                    type: %{
                      coding: [%{code: "condition", system: "eHealth/resources"}],
                      text: "code text"
                    },
                    value: "aa456b10-141f-4e88-a7a2-f41cae4b8b50"
                  }
                },
                rank: 890,
                role: %{
                  coding: [%{code: "primary", system: "eHealth/diagnosis_roles"}],
                  text: "code text"
                }
              }
            ],
            evidence: %{
              display_value: nil,
              identifier: %{
                type: %{
                  coding: [%{code: "1", system: "eHealth/resources"}],
                  text: "code text"
                },
                value: "30c96863-6579-47ee-9811-a6ec45ed0914"
              }
            },
            is_active: true
          }
        ],
        explanatory_letter: "explanatory letter",
        id: "4d5d59bb-9341-449b-905a-bd1aef84c68f",
        inserted_at: #DateTime<2019-02-04 13:29:00.630Z>,
        managing_organization: %{
          display_value: nil,
          identifier: %{
            type: %{
              coding: [%{code: "legal_entity", system: "eHealth/resources"}],
              text: "code text"
            },
            value: "8264b816-5d74-4039-a68d-3b486f48c4b1"
          }
        },
        name: "ОРВИ 2018",
        period: %{end: "2019-02-04", start: "2019-02-04"},
        referral_requests: [
          %{
            display_value: nil,
            identifier: %{
              type: %{
                coding: [%{code: "service_request", system: "eHealth/resources"}],
                text: "code text"
              },
              value: "1a403ff8-9ccb-433e-8a5f-b3e252ee3b8c"
            }
          }
        ],
        status: "active",
        status_history: [
          %{
            inserted_at: "2019-02-04T13:29:00.630Z",
            inserted_by: "c056e131-433e-462b-a1d6-d35e75ff6106",
            status: "active",
            status_reason: %{
              coding: [%{code: "1", system: "eHealth/episode_closing_reasons"}],
              text: "code text"
            }
          }
        ],
        status_reason: %{
          coding: [%{code: "1", system: "eHealth/resources"}],
          text: "code text"
        },
        type: %{code: "primary_care", system: "eHealth/episode_types"},
        updated_at: #DateTime<2019-02-04 13:29:00.630Z>
      }}
  """
  @spec episode_by_allergy_intolerance_id(
          patient_id :: binary(),
          allergy_intolerance_id :: binary()
        ) :: nil | {:ok, episode}
  def episode_by_allergy_intolerance_id(patient_id, allergy_intolerance_id) do
    patient_id_hash = Patients.get_pk_hash(patient_id)

    with {:ok, allergy_intolerance} <- AllergyIntolerances.get_by_id(patient_id_hash, allergy_intolerance_id),
         {:ok, encounter} <-
           Encounters.get_by_id(patient_id_hash, to_string(allergy_intolerance.context.identifier.value)),
         {:ok, episode} <- Episodes.get_by_id(patient_id_hash, to_string(encounter.episode.identifier.value)) do
      {:ok, EpisodeView.render("show.json", %{episode: episode})}
    end
  end

  @doc """
  Get episode by patient id, immunization id

  ## Examples

      iex> Api.Rpc.episode_by_immunization_id(
        "26e673e1-1d68-413e-b96c-407b45d9f572",
        "d221d7f1-81cb-44d3-b6d4-8d7e42f97ff9"
      )
      {:ok, %{
        care_manager: %{
          display_value: nil,
          identifier: %{
            type: %{
              coding: [%{code: "employee", system: "eHealth/resources"}],
              text: "code text"
            },
            value: "1857c60a-cbc5-4244-9a31-9dd310828346"
          }
        },
        closing_summary: "closing summary",
        current_diagnoses: [
          %{
            code: %{
              coding: [%{code: "R80", system: "eHealth/ICPC2/condition_codes"}],
              text: "code text"
            },
            condition: %{
              display_value: nil,
              identifier: %{
                type: %{
                  coding: [%{code: "condition", system: "eHealth/resources"}],
                  text: "code text"
                },
                value: "9547dfe3-7830-470e-a95a-4c046e59fd46"
              }
            },
            rank: 930,
            role: %{
              coding: [%{code: "primary", system: "eHealth/diagnosis_roles"}],
              text: "code text"
            }
          },
          %{
            code: %{
              coding: [%{code: "R80", system: "eHealth/ICPC2/condition_codes"}],
              text: "code text"
            },
            condition: %{
              display_value: nil,
              identifier: %{
                type: %{
                  coding: [%{code: "condition", system: "eHealth/resources"}],
                  text: "code text"
                },
                value: "aa456b10-141f-4e88-a7a2-f41cae4b8b50"
              }
            },
            rank: 890,
            role: %{
              coding: [%{code: "primary", system: "eHealth/diagnosis_roles"}],
              text: "code text"
            }
          }
        ],
        diagnoses_history: [
          %{
            date: ~D[2019-02-04],
            diagnoses: [
              %{
                code: %{
                  coding: [%{code: "R80", system: "eHealth/ICPC2/condition_codes"}],
                  text: "code text"
                },
                condition: %{
                  display_value: nil,
                  identifier: %{
                    type: %{
                      coding: [%{code: "condition", system: "eHealth/resources"}],
                      text: "code text"
                    },
                    value: "9547dfe3-7830-470e-a95a-4c046e59fd46"
                  }
                },
                rank: 930,
                role: %{
                  coding: [%{code: "primary", system: "eHealth/diagnosis_roles"}],
                  text: "code text"
                }
              },
              %{
                code: %{
                  coding: [%{code: "R80", system: "eHealth/ICPC2/condition_codes"}],
                  text: "code text"
                },
                condition: %{
                  display_value: nil,
                  identifier: %{
                    type: %{
                      coding: [%{code: "condition", system: "eHealth/resources"}],
                      text: "code text"
                    },
                    value: "aa456b10-141f-4e88-a7a2-f41cae4b8b50"
                  }
                },
                rank: 890,
                role: %{
                  coding: [%{code: "primary", system: "eHealth/diagnosis_roles"}],
                  text: "code text"
                }
              }
            ],
            evidence: %{
              display_value: nil,
              identifier: %{
                type: %{
                  coding: [%{code: "1", system: "eHealth/resources"}],
                  text: "code text"
                },
                value: "30c96863-6579-47ee-9811-a6ec45ed0914"
              }
            },
            is_active: true
          }
        ],
        explanatory_letter: "explanatory letter",
        id: "4d5d59bb-9341-449b-905a-bd1aef84c68f",
        inserted_at: #DateTime<2019-02-04 13:29:00.630Z>,
        managing_organization: %{
          display_value: nil,
          identifier: %{
            type: %{
              coding: [%{code: "legal_entity", system: "eHealth/resources"}],
              text: "code text"
            },
            value: "8264b816-5d74-4039-a68d-3b486f48c4b1"
          }
        },
        name: "ОРВИ 2018",
        period: %{end: "2019-02-04", start: "2019-02-04"},
        referral_requests: [
          %{
            display_value: nil,
            identifier: %{
              type: %{
                coding: [%{code: "service_request", system: "eHealth/resources"}],
                text: "code text"
              },
              value: "1a403ff8-9ccb-433e-8a5f-b3e252ee3b8c"
            }
          }
        ],
        status: "active",
        status_history: [
          %{
            inserted_at: "2019-02-04T13:29:00.630Z",
            inserted_by: "c056e131-433e-462b-a1d6-d35e75ff6106",
            status: "active",
            status_reason: %{
              coding: [%{code: "1", system: "eHealth/episode_closing_reasons"}],
              text: "code text"
            }
          }
        ],
        status_reason: %{
          coding: [%{code: "1", system: "eHealth/resources"}],
          text: "code text"
        },
        type: %{code: "primary_care", system: "eHealth/episode_types"},
        updated_at: #DateTime<2019-02-04 13:29:00.630Z>
      }}
  """
  @spec episode_by_immunization_id(
          patient_id :: binary(),
          immunization_id :: binary()
        ) :: nil | {:ok, episode}
  def episode_by_immunization_id(patient_id, immunization_id) do
    patient_id_hash = Patients.get_pk_hash(patient_id)

    with {:ok, immunization} <- Immunizations.get_by_id(patient_id_hash, immunization_id),
         {:ok, encounter} <- Encounters.get_by_id(patient_id_hash, to_string(immunization.context.identifier.value)),
         {:ok, episode} <- Episodes.get_by_id(patient_id_hash, to_string(encounter.episode.identifier.value)) do
      {:ok, EpisodeView.render("show.json", %{episode: episode})}
    end
  end

  @doc """
  Get episode by patient id, risk assessment id

  ## Examples

      iex> Api.Rpc.episode_by_risk_assessment_id(
        "26e673e1-1d68-413e-b96c-407b45d9f572",
        "1ff18cca-8957-4354-b8e6-81eb42c39efc"
      )
      {:ok,
      %{
        care_manager: %{
          display_value: nil,
          identifier: %{
            type: %{
              coding: [%{code: "employee", system: "eHealth/resources"}],
              text: "code text"
            },
            value: "db05ab15-087c-45c1-80ec-6862b717069a"
          }
        },
        closing_summary: "closing summary",
        current_diagnoses: [
          %{
            code: %{
              coding: [%{code: "R80", system: "eHealth/ICPC2/condition_codes"}],
              text: "code text"
            },
            condition: %{
              display_value: nil,
              identifier: %{
                type: %{
                  coding: [%{code: "condition", system: "eHealth/resources"}],
                  text: "code text"
                },
                value: "4911e2d8-6d34-4354-a33a-b5c126dea5d8"
              }
            },
            rank: 467,
            role: %{
              coding: [%{code: "primary", system: "eHealth/diagnosis_roles"}],
              text: "code text"
            }
          },
          %{
            code: %{
              coding: [%{code: "R80", system: "eHealth/ICPC2/condition_codes"}],
              text: "code text"
            },
            condition: %{
              display_value: nil,
              identifier: %{
                type: %{
                  coding: [%{code: "condition", system: "eHealth/resources"}],
                  text: "code text"
                },
                value: "8f1dfa5e-ca9b-46b5-a05b-4c851b011c6d"
              }
            },
            rank: 651,
            role: %{
              coding: [%{code: "primary", system: "eHealth/diagnosis_roles"}],
              text: "code text"
            }
          }
        ],
        diagnoses_history: [
          %{
            date: ~D[2019-03-18],
            diagnoses: [
              %{
                code: %{
                  coding: [%{code: "R80", system: "eHealth/ICPC2/condition_codes"}],
                  text: "code text"
                },
                condition: %{
                  display_value: nil,
                  identifier: %{
                    type: %{
                      coding: [%{code: "condition", system: "eHealth/resources"}],
                      text: "code text"
                    },
                    value: "4911e2d8-6d34-4354-a33a-b5c126dea5d8"
                  }
                },
                rank: 467,
                role: %{
                  coding: [%{code: "primary", system: "eHealth/diagnosis_roles"}],
                  text: "code text"
                }
              },
              %{
                code: %{
                  coding: [%{code: "R80", system: "eHealth/ICPC2/condition_codes"}],
                  text: "code text"
                },
                condition: %{
                  display_value: nil,
                  identifier: %{
                    type: %{
                      coding: [%{code: "condition", system: "eHealth/resources"}],
                      text: "code text"
                    },
                    value: "8f1dfa5e-ca9b-46b5-a05b-4c851b011c6d"
                  }
                },
                rank: 651,
                role: %{
                  coding: [%{code: "primary", system: "eHealth/diagnosis_roles"}],
                  text: "code text"
                }
              }
            ],
            evidence: %{
              display_value: nil,
              identifier: %{
                type: %{
                  coding: [%{code: "1", system: "eHealth/resources"}],
                  text: "code text"
                },
                value: "6b3ee468-8244-49a9-ac63-26c8649311ce"
              }
            },
            is_active: true
          }
        ],
        explanatory_letter: "explanatory letter",
        id: "1ff18cca-8957-4354-b8e6-81eb42c39efc",
        inserted_at: #DateTime<2019-03-18 08:22:01.012Z>,
        managing_organization: %{
          display_value: nil,
          identifier: %{
            type: %{
              coding: [%{code: "legal_entity", system: "eHealth/resources"}],
              text: "code text"
            },
            value: "7c16de4a-bc0e-4458-8636-90a36a17bf4f"
          }
        },
        name: "ОРВИ 2018",
        period: %{end: "2019-03-18", start: "2019-03-18"},
        referral_requests: [
          %{
            display_value: nil,
            identifier: %{
              type: %{
                coding: [%{code: "service_request", system: "eHealth/resources"}],
                text: "code text"
              },
              value: "7b0bf6e1-9b6b-413d-aca9-620015c8a162"
            }
          }
        ],
        status: "active",
        status_history: [
          %{
            inserted_at: "2019-03-18T08:22:01.012Z",
            inserted_by: "c522bb58-cbe7-49f1-b6ed-de6d759d008c",
            status: "active",
            status_reason: %{
              coding: [%{code: "1", system: "eHealth/episode_closing_reasons"}],
              text: "code text"
            }
          }
        ],
        status_reason: %{
          coding: [%{code: "1", system: "eHealth/resources"}],
          text: "code text"
        },
        type: %{code: "primary_care", system: "eHealth/episode_types"},
        updated_at: #DateTime<2019-03-18 08:22:01.012Z>
      }}
  """
  @spec episode_by_risk_assessment_id(
          patient_id :: binary(),
          risk_assessment_id :: binary()
        ) :: nil | {:ok, episode}
  def episode_by_risk_assessment_id(patient_id, risk_assessment_id) do
    patient_id_hash = Patients.get_pk_hash(patient_id)

    with {:ok, risk_assessment} <- RiskAssessments.get_by_id(patient_id_hash, risk_assessment_id),
         {:ok, encounter} <- Encounters.get_by_id(patient_id_hash, to_string(risk_assessment.context.identifier.value)),
         {:ok, episode} <- Episodes.get_by_id(patient_id_hash, to_string(encounter.episode.identifier.value)) do
      {:ok, EpisodeView.render("show.json", %{episode: episode})}
    end
  end

  @doc """
  Get episode by patient id, device id

  ## Examples

      iex> Api.Rpc.episode_by_device_id(
        "26e673e1-1d68-413e-b96c-407b45d9f572",
        "341dd9aa-06d9-423d-a40e-b795ddca11be"
      )
      {:ok,
      %{
        care_manager: %{
          display_value: nil,
          identifier: %{
            type: %{
              coding: [%{code: "employee", system: "eHealth/resources"}],
              text: "code text"
            },
            value: "8784ff97-d94e-43c1-9662-eac202ed12bd"
          }
        },
        closing_summary: "closing summary",
        current_diagnoses: [
          %{
            code: %{
              coding: [%{code: "R80", system: "eHealth/ICPC2/condition_codes"}],
              text: "code text"
            },
            condition: %{
              display_value: nil,
              identifier: %{
                type: %{
                  coding: [%{code: "condition", system: "eHealth/resources"}],
                  text: "code text"
                },
                value: "d12d7fa3-59cd-43c9-ae22-3fedc7cc8540"
              }
            },
            rank: 112,
            role: %{
              coding: [%{code: "primary", system: "eHealth/diagnosis_roles"}],
              text: "code text"
            }
          },
          %{
            code: %{
              coding: [%{code: "R80", system: "eHealth/ICPC2/condition_codes"}],
              text: "code text"
            },
            condition: %{
              display_value: nil,
              identifier: %{
                type: %{
                  coding: [%{code: "condition", system: "eHealth/resources"}],
                  text: "code text"
                },
                value: "fbb1ce05-7044-41f5-98d1-eb3d473b52ce"
              }
            },
            rank: 276,
            role: %{
              coding: [%{code: "primary", system: "eHealth/diagnosis_roles"}],
              text: "code text"
            }
          }
        ],
        diagnoses_history: [
          %{
            date: ~D[2019-03-18],
            diagnoses: [
              %{
                code: %{
                  coding: [%{code: "R80", system: "eHealth/ICPC2/condition_codes"}],
                  text: "code text"
                },
                condition: %{
                  display_value: nil,
                  identifier: %{
                    type: %{
                      coding: [%{code: "condition", system: "eHealth/resources"}],
                      text: "code text"
                    },
                    value: "d12d7fa3-59cd-43c9-ae22-3fedc7cc8540"
                  }
                },
                rank: 112,
                role: %{
                  coding: [%{code: "primary", system: "eHealth/diagnosis_roles"}],
                  text: "code text"
                }
              },
              %{
                code: %{
                  coding: [%{code: "R80", system: "eHealth/ICPC2/condition_codes"}],
                  text: "code text"
                },
                condition: %{
                  display_value: nil,
                  identifier: %{
                    type: %{
                      coding: [%{code: "condition", system: "eHealth/resources"}],
                      text: "code text"
                    },
                    value: "fbb1ce05-7044-41f5-98d1-eb3d473b52ce"
                  }
                },
                rank: 276,
                role: %{
                  coding: [%{code: "primary", system: "eHealth/diagnosis_roles"}],
                  text: "code text"
                }
              }
            ],
            evidence: %{
              display_value: nil,
              identifier: %{
                type: %{
                  coding: [%{code: "1", system: "eHealth/resources"}],
                  text: "code text"
                },
                value: "11da8e67-4f48-42ea-aa42-03717a28c45c"
              }
            },
            is_active: true
          }
        ],
        explanatory_letter: "explanatory letter",
        id: "61997d38-c4b3-41bc-a990-c46017e55f22",
        inserted_at: #DateTime<2019-03-18 09:12:46.716Z>,
        managing_organization: %{
          display_value: nil,
          identifier: %{
            type: %{
              coding: [%{code: "legal_entity", system: "eHealth/resources"}],
              text: "code text"
            },
            value: "9633439b-4426-4d2d-87c3-eb717ba4856b"
          }
        },
        name: "ОРВИ 2018",
        period: %{end: "2019-03-18", start: "2019-03-18"},
        referral_requests: [
          %{
            display_value: nil,
            identifier: %{
              type: %{
                coding: [%{code: "service_request", system: "eHealth/resources"}],
                text: "code text"
              },
              value: "78d606c7-a2ae-4f33-9b20-0429082ec5a5"
            }
          }
        ],
        status: "active",
        status_history: [
          %{
            inserted_at: "2019-03-18T09:12:46.716Z",
            inserted_by: "3caf6079-0f57-453e-a9e1-12a3fd36664d",
            status: "active",
            status_reason: %{
              coding: [%{code: "1", system: "eHealth/episode_closing_reasons"}],
              text: "code text"
            }
          }
        ],
        status_reason: %{
          coding: [%{code: "1", system: "eHealth/resources"}],
          text: "code text"
        },
        type: %{code: "primary_care", system: "eHealth/episode_types"},
        updated_at: #DateTime<2019-03-18 09:12:46.716Z>
      }}
  """
  @spec episode_by_device_id(
          patient_id :: binary(),
          device_id :: binary()
        ) :: nil | {:ok, episode}
  def episode_by_device_id(patient_id, device_id) do
    patient_id_hash = Patients.get_pk_hash(patient_id)

    with {:ok, device} <- Devices.get_by_id(patient_id_hash, device_id),
         {:ok, encounter} <- Encounters.get_by_id(patient_id_hash, to_string(device.context.identifier.value)),
         {:ok, episode} <- Episodes.get_by_id(patient_id_hash, to_string(encounter.episode.identifier.value)) do
      {:ok, EpisodeView.render("show.json", %{episode: episode})}
    end
  end

  @doc """
  Get episode by patient id, medication statement id

  ## Examples

      iex> Api.Rpc.episode_by_medication_statement_id(
        "26e673e1-1d68-413e-b96c-407b45d9f572",
        "6b4ed713-890e-4d38-80f9-37965989b25d"
      )
      {:ok,
      %{
        care_manager: %{
          display_value: nil,
          identifier: %{
            type: %{
              coding: [%{code: "employee", system: "eHealth/resources"}],
              text: "code text"
            },
            value: "c5697675-f84d-4cc6-b664-79a9dbfaca3e"
          }
        },
        closing_summary: "closing summary",
        current_diagnoses: [
          %{
            code: %{
              coding: [%{code: "R80", system: "eHealth/ICPC2/condition_codes"}],
              text: "code text"
            },
            condition: %{
              display_value: nil,
              identifier: %{
                type: %{
                  coding: [%{code: "condition", system: "eHealth/resources"}],
                  text: "code text"
                },
                value: "6ab8bb3b-3030-464a-9ede-3af27c6187e7"
              }
            },
            rank: 518,
            role: %{
              coding: [%{code: "primary", system: "eHealth/diagnosis_roles"}],
              text: "code text"
            }
          },
          %{
            code: %{
              coding: [%{code: "R80", system: "eHealth/ICPC2/condition_codes"}],
              text: "code text"
            },
            condition: %{
              display_value: nil,
              identifier: %{
                type: %{
                  coding: [%{code: "condition", system: "eHealth/resources"}],
                  text: "code text"
                },
                value: "ba51edf4-f284-46be-bdfe-997965661efd"
              }
            },
            rank: 119,
            role: %{
              coding: [%{code: "primary", system: "eHealth/diagnosis_roles"}],
              text: "code text"
            }
          }
        ],
        diagnoses_history: [
          %{
            date: ~D[2019-03-18],
            diagnoses: [
              %{
                code: %{
                  coding: [%{code: "R80", system: "eHealth/ICPC2/condition_codes"}],
                  text: "code text"
                },
                condition: %{
                  display_value: nil,
                  identifier: %{
                    type: %{
                      coding: [%{code: "condition", system: "eHealth/resources"}],
                      text: "code text"
                    },
                    value: "6ab8bb3b-3030-464a-9ede-3af27c6187e7"
                  }
                },
                rank: 518,
                role: %{
                  coding: [%{code: "primary", system: "eHealth/diagnosis_roles"}],
                  text: "code text"
                }
              },
              %{
                code: %{
                  coding: [%{code: "R80", system: "eHealth/ICPC2/condition_codes"}],
                  text: "code text"
                },
                condition: %{
                  display_value: nil,
                  identifier: %{
                    type: %{
                      coding: [%{code: "condition", system: "eHealth/resources"}],
                      text: "code text"
                    },
                    value: "ba51edf4-f284-46be-bdfe-997965661efd"
                  }
                },
                rank: 119,
                role: %{
                  coding: [%{code: "primary", system: "eHealth/diagnosis_roles"}],
                  text: "code text"
                }
              }
            ],
            evidence: %{
              display_value: nil,
              identifier: %{
                type: %{
                  coding: [%{code: "1", system: "eHealth/resources"}],
                  text: "code text"
                },
                value: "8940612c-1318-4962-a1d2-65f223e55035"
              }
            },
            is_active: true
          }
        ],
        explanatory_letter: "explanatory letter",
        id: "15f45f2f-5de8-43b9-a75b-d33fa5f81f52",
        inserted_at: #DateTime<2019-03-18 09:18:32.479Z>,
        managing_organization: %{
          display_value: nil,
          identifier: %{
            type: %{
              coding: [%{code: "legal_entity", system: "eHealth/resources"}],
              text: "code text"
            },
            value: "9ade5124-08cb-438b-ae6b-37c352c134ce"
          }
        },
        name: "ОРВИ 2018",
        period: %{end: "2019-03-18", start: "2019-03-18"},
        referral_requests: [
          %{
            display_value: nil,
            identifier: %{
              type: %{
                coding: [%{code: "service_request", system: "eHealth/resources"}],
                text: "code text"
              },
              value: "6317aa42-bf50-4dce-88b6-9385646ec8be"
            }
          }
        ],
        status: "active",
        status_history: [
          %{
            inserted_at: "2019-03-18T09:18:32.478Z",
            inserted_by: "5dd18b1b-9264-4944-8627-02e0efa0e98f",
            status: "active",
            status_reason: %{
              coding: [%{code: "1", system: "eHealth/episode_closing_reasons"}],
              text: "code text"
            }
          }
        ],
        status_reason: %{
          coding: [%{code: "1", system: "eHealth/resources"}],
          text: "code text"
        },
        type: %{code: "primary_care", system: "eHealth/episode_types"},
        updated_at: #DateTime<2019-03-18 09:18:32.479Z>
      }}
  """
  @spec episode_by_medication_statement_id(
          patient_id :: binary(),
          medication_statement_id :: binary()
        ) :: nil | {:ok, episode}
  def episode_by_medication_statement_id(patient_id, medication_statement_id) do
    patient_id_hash = Patients.get_pk_hash(patient_id)

    with {:ok, medication_statement} <- MedicationStatements.get_by_id(patient_id_hash, medication_statement_id),
         {:ok, encounter} <-
           Encounters.get_by_id(patient_id_hash, to_string(medication_statement.context.identifier.value)),
         {:ok, episode} <- Episodes.get_by_id(patient_id_hash, to_string(encounter.episode.identifier.value)) do
      {:ok, EpisodeView.render("show.json", %{episode: episode})}
    end
  end

  @doc """
  Get episode by patient id, service request id

  ## Examples

      iex> Api.Rpc.episode_by_service_request_id(
        "26e673e1-1d68-413e-b96c-407b45d9f572",
        "6b4ed713-890e-4d38-80f9-37965989b25d"
      )
      {:ok,
      %{
        care_manager: %{
          display_value: nil,
          identifier: %{
            type: %{
              coding: [%{code: "employee", system: "eHealth/resources"}],
              text: "code text"
            },
            value: "72de5580-35c6-4df0-a7fd-27fa7c89681a"
          }
        },
        closing_summary: "closing summary",
        current_diagnoses: [
          %{
            code: %{
              coding: [%{code: "R80", system: "eHealth/ICPC2/condition_codes"}],
              text: "code text"
            },
            condition: %{
              display_value: nil,
              identifier: %{
                type: %{
                  coding: [%{code: "condition", system: "eHealth/resources"}],
                  text: "code text"
                },
                value: "636f1b63-687a-4e1c-8bba-df82161d6431"
              }
            },
            rank: 980,
            role: %{
              coding: [%{code: "primary", system: "eHealth/diagnosis_roles"}],
              text: "code text"
            }
          },
          %{
            code: %{
              coding: [%{code: "R80", system: "eHealth/ICPC2/condition_codes"}],
              text: "code text"
            },
            condition: %{
              display_value: nil,
              identifier: %{
                type: %{
                  coding: [%{code: "condition", system: "eHealth/resources"}],
                  text: "code text"
                },
                value: "11533d47-29c2-413e-bb1b-d993872ce30a"
              }
            },
            rank: 738,
            role: %{
              coding: [%{code: "primary", system: "eHealth/diagnosis_roles"}],
              text: "code text"
            }
          }
        ],
        diagnoses_history: [
          %{
            date: ~D[2019-04-11],
            diagnoses: [
              %{
                code: %{
                  coding: [%{code: "R80", system: "eHealth/ICPC2/condition_codes"}],
                  text: "code text"
                },
                condition: %{
                  display_value: nil,
                  identifier: %{
                    type: %{
                      coding: [%{code: "condition", system: "eHealth/resources"}],
                      text: "code text"
                    },
                    value: "636f1b63-687a-4e1c-8bba-df82161d6431"
                  }
                },
                rank: 980,
                role: %{
                  coding: [%{code: "primary", system: "eHealth/diagnosis_roles"}],
                  text: "code text"
                }
              },
              %{
                code: %{
                  coding: [%{code: "R80", system: "eHealth/ICPC2/condition_codes"}],
                  text: "code text"
                },
                condition: %{
                  display_value: nil,
                  identifier: %{
                    type: %{
                      coding: [%{code: "condition", system: "eHealth/resources"}],
                      text: "code text"
                    },
                    value: "11533d47-29c2-413e-bb1b-d993872ce30a"
                  }
                },
                rank: 738,
                role: %{
                  coding: [%{code: "primary", system: "eHealth/diagnosis_roles"}],
                  text: "code text"
                }
              }
            ],
            evidence: %{
              display_value: nil,
              identifier: %{
                type: %{
                  coding: [%{code: "1", system: "eHealth/resources"}],
                  text: "code text"
                },
                value: "bae90976-c5ef-4a6e-8ea1-cff42541fe26"
              }
            },
            is_active: true
          }
        ],
        explanatory_letter: "explanatory letter",
        id: "732462af-9a55-4a2a-88c3-fa55ad83f43d",
        inserted_at: #DateTime<2019-04-11 13:06:58.692Z>,
        managing_organization: %{
          display_value: nil,
          identifier: %{
            type: %{
              coding: [%{code: "legal_entity", system: "eHealth/resources"}],
              text: "code text"
            },
            value: "e89667f9-d0a1-46c8-b3cb-53faa33d5f46"
          }
        },
        name: "ОРВИ 2018",
        period: %{end: "2019-04-11", start: "2019-04-11"},
        referral_requests: [
          %{
            display_value: nil,
            identifier: %{
              type: %{
                coding: [%{code: "service_request", system: "eHealth/resources"}],
                text: "code text"
              },
              value: "a4f82537-af3e-48bd-bb7b-467c015e50f8"
            }
          }
        ],
        status: "active",
        status_history: [
          %{
            inserted_at: "2019-04-11T13:06:58.692Z",
            inserted_by: "0beb742e-4511-440f-9f96-3f725686ef01",
            status: "active",
            status_reason: %{
              coding: [%{code: "1", system: "eHealth/episode_closing_reasons"}],
              text: "code text"
            }
          }
        ],
        status_reason: %{
          coding: [%{code: "1", system: "eHealth/resources"}],
          text: "code text"
        },
        type: %{code: "primary_care", system: "eHealth/episode_types"},
        updated_at: #DateTime<2019-04-11 13:06:58.692Z>
      }}
  """
  @spec episode_by_service_request_id(
          patient_id :: binary(),
          service_request_id :: binary()
        ) :: nil | {:ok, episode}
  def episode_by_service_request_id(patient_id, service_request_id) do
    patient_id_hash = Patients.get_pk_hash(patient_id)

    with {:ok, service_request} <- ServiceRequests.get_by_id(service_request_id),
         {:ok, encounter} <-
           Encounters.get_by_id(patient_id_hash, to_string(service_request.context.identifier.value)),
         {:ok, episode} <- Episodes.get_by_id(patient_id_hash, to_string(encounter.episode.identifier.value)) do
      {:ok, EpisodeView.render("show.json", %{episode: episode})}
    end
  end

  @doc """
  Get episode by patient id, diagnostic report id

  ## Examples

      iex> Api.Rpc.episode_by_diagnostic_report_id(
        "26e673e1-1d68-413e-b96c-407b45d9f572",
        "6b4ed713-890e-4d38-80f9-37965989b25d"
      )
      {:ok,
      %{
        care_manager: %{
          display_value: nil,
          identifier: %{
            type: %{
              coding: [%{code: "employee", system: "eHealth/resources"}],
              text: "code text"
            },
            value: "616aa065-ba7c-478b-a907-82b1b33c91d1"
          }
        },
        closing_summary: "closing summary",
        current_diagnoses: [
          %{
            code: %{
              coding: [%{code: "R80", system: "eHealth/ICPC2/condition_codes"}],
              text: "code text"
            },
            condition: %{
              display_value: nil,
              identifier: %{
                type: %{
                  coding: [%{code: "condition", system: "eHealth/resources"}],
                  text: "code text"
                },
                value: "87c4b0dd-0c64-4476-8fbd-5554f44886bf"
              }
            },
            rank: 181,
            role: %{
              coding: [%{code: "primary", system: "eHealth/diagnosis_roles"}],
              text: "code text"
            }
          },
          %{
            code: %{
              coding: [%{code: "R80", system: "eHealth/ICPC2/condition_codes"}],
              text: "code text"
            },
            condition: %{
              display_value: nil,
              identifier: %{
                type: %{
                  coding: [%{code: "condition", system: "eHealth/resources"}],
                  text: "code text"
                },
                value: "86dfc4ec-79fb-4b04-9c31-e019d76c94a5"
              }
            },
            rank: 477,
            role: %{
              coding: [%{code: "primary", system: "eHealth/diagnosis_roles"}],
              text: "code text"
            }
          }
        ],
        diagnoses_history: [
          %{
            date: ~D[2019-04-11],
            diagnoses: [
              %{
                code: %{
                  coding: [%{code: "R80", system: "eHealth/ICPC2/condition_codes"}],
                  text: "code text"
                },
                condition: %{
                  display_value: nil,
                  identifier: %{
                    type: %{
                      coding: [%{code: "condition", system: "eHealth/resources"}],
                      text: "code text"
                    },
                    value: "87c4b0dd-0c64-4476-8fbd-5554f44886bf"
                  }
                },
                rank: 181,
                role: %{
                  coding: [%{code: "primary", system: "eHealth/diagnosis_roles"}],
                  text: "code text"
                }
              },
              %{
                code: %{
                  coding: [%{code: "R80", system: "eHealth/ICPC2/condition_codes"}],
                  text: "code text"
                },
                condition: %{
                  display_value: nil,
                  identifier: %{
                    type: %{
                      coding: [%{code: "condition", system: "eHealth/resources"}],
                      text: "code text"
                    },
                    value: "86dfc4ec-79fb-4b04-9c31-e019d76c94a5"
                  }
                },
                rank: 477,
                role: %{
                  coding: [%{code: "primary", system: "eHealth/diagnosis_roles"}],
                  text: "code text"
                }
              }
            ],
            evidence: %{
              display_value: nil,
              identifier: %{
                type: %{
                  coding: [%{code: "1", system: "eHealth/resources"}],
                  text: "code text"
                },
                value: "b4c39de6-e30f-4672-be8c-7defbef7d672"
              }
            },
            is_active: true
          }
        ],
        explanatory_letter: "explanatory letter",
        id: "0113d298-103b-48ce-ad72-561c84327d0e",
        inserted_at: #DateTime<2019-04-11 13:25:23.044Z>,
        managing_organization: %{
          display_value: nil,
          identifier: %{
            type: %{
              coding: [%{code: "legal_entity", system: "eHealth/resources"}],
              text: "code text"
            },
            value: "36f27d27-138e-41f7-90db-5b9b545e3253"
          }
        },
        name: "ОРВИ 2018",
        period: %{end: "2019-04-11", start: "2019-04-11"},
        referral_requests: [
          %{
            display_value: nil,
            identifier: %{
              type: %{
                coding: [%{code: "service_request", system: "eHealth/resources"}],
                text: "code text"
              },
              value: "c7222be0-b3d1-4ab3-b826-f5b7bbfedc7f"
            }
          }
        ],
        status: "active",
        status_history: [
          %{
            inserted_at: "2019-04-11T13:25:23.044Z",
            inserted_by: "59d0571c-0aba-483c-99ca-bb5d975a1cbb",
            status: "active",
            status_reason: %{
              coding: [%{code: "1", system: "eHealth/episode_closing_reasons"}],
              text: "code text"
            }
          }
        ],
        status_reason: %{
          coding: [%{code: "1", system: "eHealth/resources"}],
          text: "code text"
        },
        type: %{code: "primary_care", system: "eHealth/episode_types"},
        updated_at: #DateTime<2019-04-11 13:25:23.044Z>
      }}

  """
  @spec episode_by_diagnostic_report_id(
          patient_id :: binary(),
          diagnostic_report_id :: binary()
        ) :: nil | {:ok, episode}
  def episode_by_diagnostic_report_id(patient_id, diagnostic_report_id) do
    patient_id_hash = Patients.get_pk_hash(patient_id)

    with {:ok, diagnostic_report} <- DiagnosticReports.get_by_id(patient_id_hash, diagnostic_report_id),
         {:ok, encounter} <-
           Encounters.get_by_id(patient_id_hash, to_string(diagnostic_report.encounter.identifier.value)),
         {:ok, episode} <- Episodes.get_by_id(patient_id_hash, to_string(encounter.episode.identifier.value)) do
      {:ok, EpisodeView.render("show.json", %{episode: episode})}
    end
  end

  @doc """
  Get approvals by patient id, employee ids, eipsode id

  ## Examples

      iex> Api.Rpc.approvals_by_episode(
        "26e673e1-1d68-413e-b96c-407b45d9f572",
        ["79707880-e3f6-471a-b6bf-e19725ad749e"],
        "d221d7f1-81cb-44d3-b6d4-8d7e42f97ff9"
      )
      [
        %{
          access_level: "read",
          granted_by: %{
            display_value: nil,
            identifier: %{
              type: %{
                coding: [%{code: "mpi-hash", system: "eHealth/resources"}],
                text: "code text"
              },
              value: "32f74603-9d19-4ebc-aea6-08668d766e38"
            }
          },
          granted_resources: [
            %{
              display_value: nil,
              identifier: %{
                type: %{
                  coding: [%{code: "episode_of_care", system: "eHealth/resources"}],
                  text: "code text"
                },
                value: "34ad80db-77cb-48c4-aacb-ade41aa7fcfc"
              }
            }
          ],
          granted_to: %{
            display_value: nil,
            identifier: %{
              type: %{
                coding: [%{code: "employee", system: "eHealth/resources"}],
                text: "code text"
              },
              value: "4a3386ff-ccfe-41e8-8e77-55147c41aa15"
            }
          },
          id: "196ccb6f-0195-4bf2-b639-800292b1ba10",
          inserted_at: #DateTime<2019-02-04 09:09:25.070Z>,
          reason: nil,
          status: "new",
          updated_at: #DateTime<2019-02-04 09:09:25.070Z>,
          urgent: %{
            "authentication_method_current" => %{
              "number" => "+38093*****85",
              "type" => "OTP"
            }
          }
        }
      ]
  """
  @spec approvals_by_episode(
          patient_id :: binary(),
          employee_ids :: list(binary),
          episode_id :: binary(),
          status :: binary()
        ) :: list(approval)
  def approvals_by_episode(patient_id, employee_ids, episode_id, status \\ @status_active) do
    approvals = Approvals.get_by_patient_id_granted_to_episode_id_status(patient_id, employee_ids, episode_id, status)
    ApprovalView.render("index.json", %{approvals: approvals})
  end

  @doc """
  Get service_request by id

  ## Examples

      iex> Api.Rpc.service_request_by_id("26e673e1-1d68-413e-b96c-407b45d9f572", "26e673e1-1d68-413e-b96c-407b45d9f572")
      {:ok,
      %{
        authored_on: "2019-04-11T14:32:57.843325Z",
        category: %{
          coding: [
            %{code: "counselling", system: "eHealth/SNOMED/service_request_categories"}
          ],
          text: "code text"
        },
        code: %{
          display_value: nil,
          identifier: %{
            type: %{
              coding: [%{code: "service", system: "eHealth/resources"}],
              text: "code text"
            },
            value: "f6f7a5bb-ee93-4510-baaa-0b7abf85b2e9"
          }
        },
        completed_with: nil,
        context: %{
          display_value: nil,
          identifier: %{
            type: %{
              coding: [%{code: "encounter", system: "eHealth/resources"}],
              text: "code text"
            },
            value: "614ae39c-4af5-44e9-8b55-c75db5f31026"
          }
        },
        expiration_date: #DateTime<2019-04-12 23:59:59Z>,
        id: "2ab3fe49-d6cb-4522-babc-8ffdcce536dc",
        inserted_at: "2019-04-11T14:32:57.840Z",
        intent: "plan",
        note: nil,
        occurrence_date_time: "2019-04-11T14:32:57.843198Z",
        patient_instruction: nil,
        permitted_resources: nil,
        priority: nil,
        reason_reference: nil,
        requester_employee: %{
          display_value: nil,
          identifier: %{
            type: %{
              coding: [%{code: "employee", system: "eHealth/resources"}],
              text: "code text"
            },
            value: "85fc5bde-9c2e-4947-a9e4-14ba1706ae12"
          }
        },
        requester_legal_entity: %{
          display_value: nil,
          identifier: %{
            type: %{
              coding: [%{code: "legal_entity", system: "eHealth/resources"}],
              text: "code text"
            },
            value: "52850036-2050-499a-b00e-ed9ebcb5e998"
          }
        },
        requisition: "7e6b4f4d-388e-4782-9a32-f20d79292e5b",
        status: "active",
        status_history: [],
        status_reason: nil,
        subject: %{
          display_value: nil,
          identifier: %{
            type: %{
              coding: [%{code: "patient", system: "eHealth/resources"}],
              text: ""
            },
            value: "4187bcd5-a9f0-48f5-914d-f0f1c3579cba"
          }
        },
        supporting_info: nil,
        updated_at: "2019-04-11T14:32:57.840Z",
        used_by_employee: nil,
        used_by_legal_entity: nil
      }}
  """
  @spec service_request_by_id(patient_id :: binary(), service_request_id :: binary()) :: nil | {:ok, service_request}
  def service_request_by_id(patient_id, service_request_id) do
    with {:ok, service_request} <-
           ServiceRequests.get_by_id_patient_id(service_request_id, Patients.get_pk_hash(patient_id)) do
      {:ok, ServiceRequestView.render("show.json", %{service_request: service_request})}
    end
  end

  @doc """
  Get diagnostic_report by id

  ## Examples

      iex> Api.Rpc.diagnostic_report_by_id(
        "26e673e1-1d68-413e-b96c-407b45d9f572",
        "26e673e1-1d68-413e-b96c-407b45d9f572"
      )
      {:ok,
      %{
        based_on: %{
          display_value: nil,
          identifier: %{
            type: %{
              coding: [%{code: "service_request", system: "eHealth/resources"}],
              text: "code text"
            },
            value: "107acd76-8ad7-4d13-be86-13e463f98aa5"
          }
        },
        cancellation_reason: %{
          coding: [%{code: "misspelling", system: "eHealth/cancellation_reasons"}],
          text: "code text"
        },
        category: [
          %{
            coding: [%{code: "LAB", system: "eHealth/diagnostic_report_categories"}],
            text: "code text"
          }
        ],
        code: %{
          display_value: nil,
          identifier: %{
            type: %{
              coding: [%{code: "service", system: "eHealth/resources"}],
              text: "code text"
            },
            value: "f6f7a5bb-ee93-4510-baaa-0b7abf85b2e9"
          }
        },
        conclusion: "conclusion",
        conclusion_code: %{
          coding: [%{code: "109006", system: "eHealth/SNOMED/clinical_findings"}],
          text: "code text"
        },
        effective_date_time: "2019-04-12T15:33:11.291Z",
        encounter: %{
          display_value: nil,
          identifier: %{
            type: %{
              coding: [%{code: "encounter", system: "eHealth/resources"}],
              text: "code text"
            },
            value: "5cc51928-25de-402c-839a-a8aae1d4da0c"
          }
        },
        explanatory_letter: "some explanations",
        id: "f0f060d3-8093-4307-a567-79215eade784",
        inserted_at: #DateTime<2019-04-12 15:33:11.291Z>,
        issued: "2019-04-12T15:33:11.291Z",
        managing_organization: %{
          display_value: nil,
          identifier: %{
            type: %{
              coding: [%{code: "legal_entity", system: "eHealth/resources"}],
              text: "code text"
            },
            value: "d1e30755-876e-45a9-b07f-fa46a9a11873"
          }
        },
        origin_episode: %{
          display_value: nil,
          identifier: %{
            type: %{
              coding: [%{code: "episode", system: "eHealth/resources"}],
              text: "code text"
            },
            value: "adc6bd7f-4a7d-462c-91fe-f85d1f957e4f"
          }
        },
        performer: %{
          "reference" => %{
            display_value: nil,
            identifier: %{
              type: %{
                coding: [%{code: "employee", system: "eHealth/resources"}],
                text: "code text"
              },
              value: "34172dd5-e472-430d-a8ce-8f8b59ede4fb"
            }
          }
        },
        primary_source: true,
        recorded_by: %{
          display_value: nil,
          identifier: %{
            type: %{
              coding: [%{code: "employee", system: "eHealth/resources"}],
              text: "code text"
            },
            value: "372e689e-5b70-4df3-9513-80608967dd07"
          }
        },
        results_interpreter: %{
          "reference" => %{
            display_value: nil,
            identifier: %{
              type: %{
                coding: [%{code: "employee", system: "eHealth/resources"}],
                text: "code text"
              },
              value: "07fc3bc4-abc2-4117-b77f-e55ef4d0a9a9"
            }
          }
        },
        status: "final",
        updated_at: #DateTime<2019-04-12 15:33:11.291Z>
      }}
  """
  @spec diagnostic_report_by_id(patient_id :: binary(), diagnostic_report_id :: binary()) ::
          nil | {:ok, diagnostic_report}
  def diagnostic_report_by_id(patient_id, diagnostic_report_id) do
    patient_id_hash = Patients.get_pk_hash(patient_id)

    with {:ok, diagnostic_report} <- DiagnosticReports.get_by_id(patient_id_hash, diagnostic_report_id) do
      {:ok, DiagnosticReportView.render("show.json", %{diagnostic_report: diagnostic_report})}
    end
  end
end
