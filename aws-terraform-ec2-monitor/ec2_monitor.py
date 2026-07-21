"""
EC2 Monitor - Snapshot Report
Pulls running EC2 instances across regions, reports CloudWatch CPU metrics,
and summarizes configured S3 buckets.
"""

import boto3
from datetime import datetime, timedelta, timezone

# Regions to check - add/remove as needed
REGIONS = ["eu-west-2", "eu-north-1"]

# S3 buckets to check - add bucket names as needed
BUCKETS = ["enyioma-web-server-logs-d6a88c32"]


def get_instances(region):
    """Return a list of EC2 instances (with key details) for a given region."""
    ec2 = boto3.client("ec2", region_name=region)
    response = ec2.describe_instances(
        Filters=[{"Name": "instance-state-name", "Values": ["running", "stopped", "pending", "stopping"]}]
    )

    instances = []
    for reservation in response["Reservations"]:
        for instance in reservation["Instances"]:
            name = next(
                (tag["Value"] for tag in instance.get("Tags", []) if tag["Key"] == "Name"),
                "(unnamed)"
            )
            instances.append({
                "id": instance["InstanceId"],
                "name": name,
                "state": instance["State"]["Name"],
                "type": instance["InstanceType"],
                "public_ip": instance.get("PublicIpAddress", "N/A"),
                "region": region,
            })
    return instances


def get_cpu_utilization(instance_id, region):
    """Return average CPU utilization over the last 10 minutes, if available."""
    cw = boto3.client("cloudwatch", region_name=region)
    end = datetime.now(timezone.utc)
    start = end - timedelta(minutes=10)

    response = cw.get_metric_statistics(
        Namespace="AWS/EC2",
        MetricName="CPUUtilization",
        Dimensions=[{"Name": "InstanceId", "Value": instance_id}],
        StartTime=start,
        EndTime=end,
        Period=300,
        Statistics=["Average"],
    )

    datapoints = response.get("Datapoints", [])
    if not datapoints:
        return None

    avg = sum(dp["Average"] for dp in datapoints) / len(datapoints)
    return round(avg, 2)


def get_bucket_summary(bucket_name):
    """Return object count and total size (in MB) for a given S3 bucket."""
    s3 = boto3.client("s3")

    paginator = s3.get_paginator("list_objects_v2")
    total_objects = 0
    total_bytes = 0

    try:
        for page in paginator.paginate(Bucket=bucket_name):
            for obj in page.get("Contents", []):
                total_objects += 1
                total_bytes += obj["Size"]
    except s3.exceptions.NoSuchBucket:
        return None

    total_mb = round(total_bytes / (1024 * 1024), 2)
    return {"objects": total_objects, "size_mb": total_mb}


def get_public_access_status(bucket_name):
    """Return whether public access is fully blocked for a bucket."""
    s3 = boto3.client("s3")
    try:
        response = s3.get_public_access_block(Bucket=bucket_name)
        config = response["PublicAccessBlockConfiguration"]
        return all(config.values())
    except s3.exceptions.ClientError:
        return None


def main():
    print(f"\nEC2 Snapshot Report - {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M UTC')}")
    print("=" * 70)

    total_running = 0

    for region in REGIONS:
        instances = get_instances(region)
        if not instances:
            continue

        print(f"\nRegion: {region}")
        print("-" * 70)

        for inst in instances:
            print(f"  Name:       {inst['name']}")
            print(f"  Instance:   {inst['id']} ({inst['type']})")
            print(f"  State:      {inst['state']}")
            print(f"  Public IP:  {inst['public_ip']}")

            if inst["state"] == "running":
                total_running += 1
                cpu = get_cpu_utilization(inst["id"], region)
                if cpu is not None:
                    print(f"  CPU Avg:    {cpu}%")
                else:
                    print(f"  CPU Avg:    No data yet (instance may be too new)")

            print()

    if BUCKETS:
        print("S3 Buckets")
        print("-" * 70)
        for bucket in BUCKETS:
            summary = get_bucket_summary(bucket)
            public_blocked = get_public_access_status(bucket)

            print(f"  Bucket:     {bucket}")
            if summary is not None:
                print(f"  Objects:    {summary['objects']}")
                print(f"  Size:       {summary['size_mb']} MB")
            else:
                print(f"  Status:     Not found or inaccessible")

            if public_blocked is True:
                print(f"  Public access:  Blocked (secure)")
            elif public_blocked is False:
                print(f"  Public access:  WARNING - not fully blocked")
            else:
                print(f"  Public access:  Unable to determine")

            print()

    print("=" * 70)
    print(f"Total running instances: {total_running}")
    print()


if __name__ == "__main__":
    main()