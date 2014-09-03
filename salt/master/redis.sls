#!py

import redis


def run():
    client = redis.Redis(host={{ redis_host }}, db={{ redis_db }},
                         password={{ redis_password }})
    keys = client.keys()
    data = {}
    for key in keys:
        value = client.get(key)
        try:
            data[key] = eval(value)
        except (NameError, SyntaxError):
            data[key] = value
    return data
