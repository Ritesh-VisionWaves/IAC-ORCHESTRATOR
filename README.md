# IAC-ORCHESTRATOR

Terraform for the DevSecOps platform's Environments & IaC trial on Google Cloud
(project `thematic-carver-469716-e5`).

- Code reaches `main` only through pull requests; the platform's AI author opens them on new `iac/ai-…` branches.
- State lives in Google Cloud Storage (`gs://thematic-carver-469716-e5-tfstate`), locked by the GCS backend itself.
- Terraform 1.5.7 (the last MPL-licensed release), run by the platform: plan, approve, apply exactly the approved plan.
