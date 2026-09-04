import json

def lambda_handler(event, context):
    for record in event.get("Records", []):
        key = record["s3"]["object"]["key"]
        size = record["s3"]["object"]["size"]
        print(f"INGEST TRIGGERED: {key} ({size} bytes)")
    return {"processed": len(event.get("Records", []))}
