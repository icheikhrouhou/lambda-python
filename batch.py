import boto3
import paramiko


REGION = 'eu-central-1'

def lambda_handler(event, context):
    ec2 = boto3.resource('ec2', region_name=REGION)

    ssm = boto3.client('ssm')
    parameter = ssm.get_parameter(Name='/user/creds', WithDecryption=True)
    username = parameter['Parameter']['Value']
    password = parameter['Parameter']['Value']


    commands = [
        "cd /tmp/",
        "/tmp/run_batch.sh"
        ]


    instances = ['instance_id1', 'instance_id2', 'instance_id3']
    for inst in instances:
        instance = ec2.Instance(inst)

        print("Instance id - ", instance.id)
        print("Instance private IP - ", instance.private_ip_address)
        print("Public dns name - ", instance.public_dns_name)
    
        batch_client = paramiko.SSHClient()
        batch_client.load_system_host_keys()
        batch_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        
        batch_client.connect(
            instance.public_dns_name, username=username, password=password
        )

        stdin, stdout, stderr = batch_client.exec_command(
            'cd /tmp;ls -l;/tmp/run_batch.sh')
        stdin.flush()
        data = stdout.read().splitlines()
        for line in data:
            print line

        batch_client.close()


    return {'message' : stdout}
