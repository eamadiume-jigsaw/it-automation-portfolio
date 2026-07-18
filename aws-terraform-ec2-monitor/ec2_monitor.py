"""
EC2 Monitor - Snapshot Report
Pulls running EC2 instances across regions and reports basic CloudWatch metrics.
"""

import boto3
from datetime import datetime, timedelta, timezone

# Regions to check - add/remove as needed
REGIONS = ["eu-west-2", "eu-north-1"]


def get_instances(region):
    """Return a list of EC2 instances (with key details) for a given region."""
    ec2 = boto3.client("ec2", region_name=region)
    response = ec2.describe_instances()

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

    print("=" * 70)
    print(f"Total running instances: {total_running}")
    print()


if __name__ == "__main__":
    main()