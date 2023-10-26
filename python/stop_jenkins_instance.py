import boto3
import json


def stop_ec2_instance(name_tag):
    ec2 = boto3.client('ec2')
    response = ec2.describe_instances(
        Filters=[
            {
                'Name': 'tag:Name',
                'Values': [
                    name_tag
                ]
            },
        ]
    )
    try:
        instanceID = response['Reservations'][0]['Instances'][0]['InstanceId']
    except IndexError:
        print(f'Instance with "Name" tag "{name_tag}" has been terminated or does not exist')
        exit
    
    response = ec2.stop_instances(
        InstanceIds=[
            instanceID,
        ]
    )

    if "stopped" in response["StoppingInstances"][0]["CurrentState"]["Name"]:
        print()
        print("Instance is already stopped")
        print()
    else:
        print(json.dumps(response, indent=4, default=str))


def main():
    
    name_tag = "Jenkins_Server"
    stop_ec2_instance(name_tag)

if __name__ == '__main__':
    main()