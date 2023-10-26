import boto3 


def start_instance(name_tag):
    
    ec2 = boto3.client('ec2')
    tagged_instances = ec2.describe_instances(
        Filters=[
            {
                'Name': 'tag:Name',
                'Values': [
                    name_tag
                ]
            },
            {
                'Name': 'instance-state-name',
                'Values': [
                    'running',
                    'pending',
                    'stopped', 
                    'stopping'
                ]
            }
        ]
    )
    try:
        instance_state = tagged_instances['Reservations'][0]['Instances'][0]['State']['Name']
        instanceID = tagged_instances['Reservations'][0]['Instances'][0]['InstanceId']
    except IndexError:
        print(f'Instance with "Name" tag "{name_tag}" has been terminated or does not exist')
        instanceID = 0
        return instanceID
    
    stopped_waiter = ec2.get_waiter('instance_stopped')
    running_waiter = ec2.get_waiter('instance_running')

    if instance_state in ['stopped', 'stopping']:
        if instance_state == 'stopping':
            print('Waiting for instance to stop...')
            stopped_waiter.wait(InstanceIds=[instanceID])
            ec2.start_instances(
                InstanceIds=[
                    instanceID
                ],
            )
            print('Waiting for instance to start...')
            running_waiter.wait(InstanceIds=[instanceID])
            print('Instance is running')
            return instanceID
        else:
            ec2.start_instances(
                InstanceIds=[
                    instanceID
                ],
            )
            print('Waiting for instance to start...')
            running_waiter.wait(InstanceIds=[instanceID])
            print('Instance is running')
            return instanceID
    
    elif instance_state == 'running':
        print('Instance is running')
        return instanceID
    
    elif instance_state == 'pending':
        print('Instance is pending...')
        running_waiter.wait(InstanceIds=[instanceID])
        print('Instance is running')
        return instanceID
    
    else:
        print('Instance is terminated or does not exist')
        instanceID = 0
        return instanceID
    

def get_public_ip(instanceID):
    ec2 = boto3.client('ec2')
    if instanceID == 0:
        exit
    else:
        response = ec2.describe_instances(
            InstanceIds=[
                instanceID
            ],
        )
        for instance in response['Reservations']:
            ssh_access = f'SSH: ssh ubuntu@{instance["Instances"][0]["PublicIpAddress"]}'
            web_access = f'Web Access: http://{instance["Instances"][0]["PublicIpAddress"]}:8080'
            print(ssh_access)
            print(web_access)

        with open('../terraform/Jenkins_Public_IP.txt', 'r') as file:
            lines = file.readlines()
            lines[0] = f'{ssh_access}\n'
            lines[1] = f'{web_access}\n'

        with open('../terraform/Jenkins_Public_IP.txt', 'w') as file:
            file.writelines(lines)


def main():
    name_tag = 'Jenkins_Server'
    instanceID = start_instance(name_tag)
    get_public_ip(instanceID)


if __name__ == "__main__":
    main()
