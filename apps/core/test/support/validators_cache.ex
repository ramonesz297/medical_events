defmodule Core.Validators.CacheTest do
  @moduledoc false

  @behaviour Core.Validators.CacheBehaviour

  def get_json_schema(_key), do: {:ok, nil}

  def set_json_schema(_key, _schema), do: :ok

  def get_dictionaries do
    {:ok,
     [
       %{name: "eHealth/reason_explanations", values: %{"429060002" => "429060002"}},
       %{name: "eHealth/report_origins", values: %{"employee" => "employee"}},
       %{name: "eHealth/vaccination_target_diseases", values: %{"1857005" => "1857005"}},
       %{name: "eHealth/vaccination_authorities", values: %{"WVO" => "WVO", "1857005" => "1857005"}},
       %{name: "eHealth/observation_categories", values: %{"1" => "1"}},
       %{name: "eHealth/ICPC2/actions", values: %{"action" => "action"}},
       %{name: "eHealth/ICPC2/reasons", values: %{"reason" => "reason", "A02" => "A02"}},
       %{name: "eHealth/encounter_classes", values: %{"PHC" => "PHC", "AMB" => "AMB"}},
       %{name: "eHealth/allergy_intolerance_codes", values: %{"227493005" => "227493005", "1" => "1"}},
       %{
         name: "eHealth/risk_assessment_codes",
         values: %{"default_risk_assessment_code" => "default_risk_assessment_code"}
       },
       %{name: "eHealth/vaccine_codes", values: %{"FLUVAX" => "FLUVAX"}},
       %{name: "eHealth/vaccination_routes", values: %{"IM" => "IM"}},
       %{name: "eHealth/observation_methods", values: %{"1" => "1"}},
       %{name: "eHealth/observation_interpretations", values: %{"1" => "1"}},
       %{name: "eHealth/body_sites", values: %{"1" => "1"}},
       %{name: "eHealth/condition_severities", values: %{"1" => "1"}},
       %{name: "eHealth/condition_stages", values: %{"1" => "1"}},
       %{name: "eHealth/encounter_types", values: %{"AMB" => "AMB"}},
       %{name: "eHealth/episode_types", values: %{"primary_care" => "primary_care"}},
       %{name: "eHealth/service_request_recall_reasons", values: %{"1" => "1"}},
       %{name: "eHealth/service_request_cancel_reasons", values: %{"1" => "1"}},
       %{
         name: "eHealth/episode_closing_reasons",
         values: %{
           "legal_entity" => "legal_entity"
         }
       },
       %{
         name: "eHealth/cancellation_reasons",
         values: %{
           "misspelling" => "misspelling"
         }
       },
       %{
         name: "eHealth/resources",
         values: %{
           "1" => "1",
           "employee" => "test",
           "condition" => "test",
           "service_request" => "test",
           "encounter" => "test",
           "legal_entity" => "test",
           "patient" => "test"
         }
       },
       %{
         name: "eHealth/ICD10/condition_codes",
         values: %{
           "A10" => "test",
           "A11" => "test",
           "A70" => "test",
           "J11" => "J11",
           "R80" => "R80",
           "code" => "code"
         }
       },
       %{
         name: "eHealth/ICPC2/condition_codes",
         values: %{"A10" => "test", "B10" => "test", "R80" => "R80", "T90" => "T90", "code" => "code"}
       },
       %{
         name: "eHealth/LOINC/observation_codes",
         values: %{
           "1" => "1",
           "condition" => "condition",
           "B70" => "test",
           "8310-5" => "8310-5",
           "8462-4" => "8462-4",
           "8480-6" => "8480-6",
           "code" => "code"
         }
       },
       %{
         name: "eHealth/SNOMED/service_request_categories",
         values: %{"counselling" => "counselling", "laboratory_procedure" => "laboratory_procedure"}
       },
       %{
         name: "eHealth/SNOMED/service_request_performer_roles",
         values: %{"psychiatrist" => "psychiatrist"}
       },
       %{
         name: "eHealth/SNOMED/clinical_findings",
         values: %{"109006" => "109006"}
       },
       %{
         name: "eHealth/diagnostic_report_categories",
         values: %{"LAB" => "LAB", "MB" => "MB"}
       }
     ]}
  end

  def set_dictionaries(_), do: :ok
end
