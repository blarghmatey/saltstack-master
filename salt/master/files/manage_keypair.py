from libcloud.compute.types import Provider
from libcloud.compute.providers import get_driver
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('-p', '--provider', required=True,
                    dest='provider', type=str,
                    help='The cloud service being used (e.g. openstack)')
parser.add_argument('-u', '--username', required=True,
                    default='salt', type=str, dest='username',
                    help='Username for authenticating to the cloud service')
parser.add_argument('-P', '--password', required=True,
                    dest='password', type=str,
                    help='Password for authenticating to the cloud service')
parser.add_argument('-k', '--key', dest='key', required=True,
                    help='The file path for the key pair to be imported')
parser.add_argument('-n', '--name', dest='keyname', required=True,
                    help='The name to be used for the key pair')
parser.add_argument('extra_params', nargs=argparse.REMAINDER,
                    help='Extra parameters to be passed in. key=value format')
args = parser.parse_args()

provider_dict = {
    'openstack': Provider.OPENSTACK,
    'aws': Provider.EC2
}

extra_args = {k: v for k, v in (arg.split('=') for arg in args.extra_params)}

print(extra_args)

cls = get_driver(provider_dict[args.provider])
driver = cls(args.username, args.password, **extra_args)

keypairs = driver.list_key_pairs()
for keyobj in keypairs:
    if keyobj.name == args.keyname:
        driver.delete_key_pair(keyobj)
driver.import_key_pair_from_file(args.keyname, args.key)
