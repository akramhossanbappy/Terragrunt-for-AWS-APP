import json
import re
import urllib.request
import urllib.error
import urllib.parse
import os
import logging
from datetime import datetime

logger = logging.getLogger()
logger.setLevel(logging.INFO)

OP_SYMBOL = {
    "GreaterThanThreshold":          ">",
    "GreaterThanOrEqualToThreshold": "≥",
    "LessThanThreshold":             "<",
    "LessThanOrEqualToThreshold":    "≤",
}


def parse_region_from_arn(arn):
    try:
        return arn.split(":")[3]
    except (IndexError, AttributeError):
        return ""


def format_timestamp(state_change_time):
    try:
        normalized = state_change_time.replace("+0000", "+00:00").replace("Z", "+00:00")
        dt = datetime.fromisoformat(normalized)
        return dt.strftime("%Y-%m-%d %H:%M UTC")
    except Exception:
        return ""


def build_console_url(arn, alarm_name):
    try:
        region = parse_region_from_arn(arn)
        encoded = urllib.parse.quote(alarm_name, safe="")
        return f"https://{region}.console.aws.amazon.com/cloudwatch/home?region={region}#alarmsV2:alarm/{encoded}"
    except Exception:
        return ""


def fmt_num(val):
    """Format a float to a concise, readable string without trailing zeros."""
    if val == 0:
        return "0"
    if val >= 1000:
        return f"{val:,.0f}"
    if val >= 100:
        return f"{val:.0f}"
    if val >= 10:
        return f"{val:.1f}".rstrip("0").rstrip(".")
    if val >= 1:
        return f"{val:.2f}".rstrip("0").rstrip(".")
    return f"{val:.4f}".rstrip("0").rstrip(".")


def humanize_reason(reason, state, trigger):
    """
    Convert raw CloudWatch NewStateReason into a plain-English one-liner.

    Handles two CloudWatch reason formats:
      - Datapoints: "Threshold Crossed: N datapoints [val (ts), ...] were [not] greater than X"
      - No data:    "no datapoints were received for N periods ... treated as [NonBreaching]"
    """
    try:
        threshold = trigger.get("Threshold")
        operator  = trigger.get("ComparisonOperator", "")
        op        = OP_SYMBOL.get(operator, operator)
        thr_str   = fmt_num(float(threshold)) if threshold is not None else "?"

        # Extract numeric values paired with a timestamp "(dd/mm/yy HH:MM:SS)"
        values = [
            float(v)
            for v in re.findall(
                r"([\d]+\.[\d]+(?:[Ee][+-]?\d+)?|[\d]+)\s*\([\d/: ]+\)", reason
            )
        ]

        if values:
            latest = fmt_num(values[0])
            if state == "ALARM":
                return f"Reason: Current value *{latest}* exceeded threshold ({op} {thr_str})"
            else:
                return f"Reason: Current value *{latest}* is within threshold ({op} {thr_str})"

        # No-datapoints / missing-data pattern
        if re.search(r"no datapoints|missing datapoint", reason, re.IGNORECASE):
            return f"Reason: No data received — treated as OK (threshold: {op} {thr_str})"

        # Fallback: truncate raw reason
        return (reason[:200] + "…") if len(reason) > 200 else reason

    except Exception:
        return (reason[:200] + "…") if len(reason) > 200 else reason


def handler(event, context):
    webhook_url = os.environ["GCHAT_WEBHOOK_URL"]

    for record in event.get("Records", []):
        try:
            msg = json.loads(record["Sns"]["Message"])

            state   = msg.get("NewStateValue", "UNKNOWN")
            name    = msg.get("AlarmName", "Unknown Alarm")
            reason  = msg.get("NewStateReason", "")
            region  = msg.get("Region", "")
            desc    = msg.get("AlarmDescription", "")
            arn     = msg.get("AlarmArn", "")
            ts      = msg.get("StateChangeTime", "")
            trigger = msg.get("Trigger", {})

            icon      = {"ALARM": "🔴", "OK": "🟢"}.get(state, "🟡")
            timestamp = format_timestamp(ts)
            url       = build_console_url(arn, name)
            summary   = humanize_reason(reason, state, trigger)

            state_line = f"State: *{state}*"
            if timestamp:
                state_line += f" | {timestamp}"

            lines = [f"{icon} *{name}*", state_line]
            if desc:
                lines.append(f"Condition: {desc}")
            if summary:
                lines.append(summary)
            if region:
                lines.append(f"Region: {region}")
            if url:
                lines.append(f"🔗 {url}")

            body = json.dumps({"text": "\n".join(lines)}).encode("utf-8")
            req  = urllib.request.Request(
                webhook_url,
                data=body,
                headers={"Content-Type": "application/json"},
                method="POST",
            )
            urllib.request.urlopen(req, timeout=10)
            logger.info("Sent GChat notification for alarm: %s state: %s", name, state)

        except urllib.error.HTTPError as e:
            logger.error("GChat webhook HTTP error %s: %s", e.code, e.read().decode())
        except urllib.error.URLError as e:
            logger.error("GChat webhook URL error: %s", e.reason)
        except Exception as e:
            logger.error("Failed to process SNS record: %s", str(e))

    return {"statusCode": 200}
