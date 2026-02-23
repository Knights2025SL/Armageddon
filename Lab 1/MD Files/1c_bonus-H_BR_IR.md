Lab 1C-Bonus-H: Bedrock Auto-Generated Incident Reports
Student Handout 
What you’re building:

When an alarm fires, you will automatically:
  1) collect evidence (alarm metadata + Logs Insights + param/secret reads)
  2) generate a structured incident report using Amazon Bedrock Runtime InvokeModel 
  3) store report + evidence bundle to S3
  4) notify the on-call engineer (SNS)

Why it matters
This is how mature companies reduce MTTR:
  A) evidence collection is automated (less guesswork)
  B) postmortems are consistent (better prevention)
  C) alerts include context (fewer “what’s happening?” pages)

1) The “Integration Contract” (what Lambda must output)
You must write two objects to S3:

A) Evidence bundle (JSON)
s3://<bucket>/reports/<incident_id>.json

Must contain:
  1) incident_id
  2) time_window_utc (start/end)
  3) alarm (name, metric, threshold, state)
  4) queries: results for WAF + app Logs Insights
  5) ssm_params (endpoint/port/name)
  6) secret_meta (host/port/dbname/username only — no password)

B) Human report (Markdown)
s3://<bucket>/reports/<incident_id>.md

Must follow your template headings exactly.

2) The Logs Insights Query Pack (Minimum required)
Your Lambda must run at least these via Logs Insights:
  App: error rate over time (bin 1m)
  App: latest 50 DB-related error lines
  WAF: allow vs block
  WAF: top blocked IP/URI pairs

This is built on StartQuery + GetQueryResults.

3) Bedrock invocation: two supported paths (You need to pick one)

Critical reality: Bedrock request bodies differ per model provider/family. 
AWS explicitly warns that models differ in what they accept/return. 
Documentation: https://docs.aws.amazon.com/bedrock/latest/userguide/inference-invoke.html?utm_source=chatgpt.com


Option 1: Anthropic Claude via Bedrock “messages” style payload
Use AWS’s own examples as the canonical reference. 
AWS Documentation: https://docs.aws.amazon.com/bedrock/latest/userguide/bedrock-runtime_example_bedrock-runtime_InvokeModel_AnthropicClaude_section.html?utm_source=chatgpt.com


Python snippet (framework): claude.py (folder)

Option 2: “Generic” InvokeModel (students adapt)
This exists to teach them to read provider-specific schemas and not cargo-cult. Start here, then adapt based on the model chosen

4) Lambda packaging: the clean “class-safe” way
Directory

lambda_ir_reporter/
  handler.py
  requirements.txt   (optional)
  build.sh
  lambda_ir_reporter.zip


build.sh (students run locally)


#!/usr/bin/env bash
set -euo pipefail

rm -rf build lambda_ir_reporter.zip
mkdir -p build

cp handler.py build/

# If you add external deps (usually you don't need any for boto3):
# pip install -r requirements.txt -t build/

cd build
zip -r ../lambda_ir_reporter.zip .
cd ..


Then in Terraform:
  filename = "lambda_ir_reporter.zip"

5) “Fake alarm event” test harness (no waiting for real alarms)
SNS → Lambda payloads can vary, so students should make Lambda accept:
  direct SNS event (Records[0].Sns.Message)
  or direct test JSON

Local test event (paste into Lambda console “Test”)

{
  "Records": [
    {
      "Sns": {
        "Subject": "ALARM: chewbacca-alb-5xx-alarm01",
        "Message": "{\"AlarmName\":\"chewbacca-alb-5xx-alarm01\",\"NewStateValue\":\"ALARM\",\"NewStateReason\":\"Threshold crossed\",\"StateChangeTime\":\"2025-12-27T16:00:00Z\"}"
      }
    }
  ]
}

Lambda parsing pattern (required) 

def parse_alarm_event(event):
    # SNS wrapped?
    if "Records" in event and event["Records"] and "Sns" in event["Records"][0]:
        msg = event["Records"][0]["Sns"]["Message"]
        try:
            return json.loads(msg)
        except json.JSONDecodeError:
            return {"raw_message": msg}
    return event

6) How students validate success (objective)
A) Confirm Lambda invoked
  aws logs tail /aws/lambda/<function-name> --since 10m

B) Confirm report objects exist
  aws s3 ls s3://<REPORT_BUCKET>/reports/ --recursive | tail

C) Open the report
  aws s3 cp s3://<REPORT_BUCKET>/reports/<incident_id>.md -

D) Confirm the evidence bundle does NOT include secrets
  aws s3 cp s3://<REPORT_BUCKET>/reports/<incident_id>.json - | grep -i password && echo "FAIL"


7) “No hallucinations” enforcement (advanced requirement)
Inside the prompt you give Bedrock, include:
  “Use only evidence”
  “If unknown, say Unknown”
  “Cite the evidence key used for each claim”

This matches the Bedrock guidance that you pass model-specific inference parameters in the request body—students must shape the prompt accordingly.

8) Add the missing Terraform glue (SNS publish + report-ready)
You already have SNS and Lambda wired. Add a second SNS message (optional but fun):
  Subject: IR Report Ready
  Message: S3 path + incident_id

This is just sns.publish(...) (you already used it).

9) Upgrade path (extra credit, very “enterprise”)
A) Attach the report to the incident thread
  send the S3 path in SNS email
  or publish to Slack via webhook (optional)

B) Add a “Deep report” mode
  Run 60-minute window queries
  Add top URIs, top IPs, block rate bins
  Add ALB metrics query (GetMetricData)

C) Add WAF redaction / filtering
AWS WAF supports redacted fields and filtering when enabling logging.
Documentation: https://docs.aws.amazon.com/waf/latest/developerguide/logging-destinations.html?utm_source=chatgpt.com













