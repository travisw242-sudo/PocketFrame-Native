"""Refresh only PocketFrame artwork via Steam's already-enabled LOCAL console.

Does not enable debugging, open a port, restart Steam or edit its shortcut DB.
Uses the same SetCustomArtworkForApp API as Steam's artwork picker.
"""
import base64
import hashlib
import json
import os
from pathlib import Path
import socket
import struct
import sys
import urllib.parse
import urllib.request


class Console:
    def __init__(self, address):
        url = urllib.parse.urlsplit(address)
        if url.hostname not in {"127.0.0.1", "localhost"} or url.port != 8080:
            raise ValueError("Refusing a nonlocal Steam console")
        self.socket = socket.create_connection((url.hostname, url.port), timeout=12)
        nonce = base64.b64encode(os.urandom(16)).decode()
        request = f"GET {url.path} HTTP/1.1\r\nHost: 127.0.0.1:8080\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: {nonce}\r\nSec-WebSocket-Version: 13\r\n\r\n"
        self.socket.sendall(request.encode())
        headers = b""
        while not headers.endswith(b"\r\n\r\n"):
            headers += self.socket.recv(1)
            if len(headers)>16384:raise ValueError("Unexpected console handshake")
        expected = base64.b64encode(hashlib.sha1((nonce+"258EAFA5-E914-47DA-95CA-C5AB0DC85B11").encode()).digest())
        if b" 101 " not in headers.split(b"\r\n")[0] or expected not in headers:
            raise ValueError("Steam console handshake rejected")

    def exact(self, count):
        result = b""
        while len(result)<count:
            incoming = self.socket.recv(count-len(result))
            if not incoming:raise OSError("Console disconnected")
            result += incoming
        return result

    def send(self, payload, opcode=1):
        mask = os.urandom(4);size=len(payload)
        length = bytes([0x80|size]) if size<126 else b"\xfe"+struct.pack("!H",size) if size<65536 else b"\xff"+struct.pack("!Q",size)
        self.socket.sendall(bytes([0x80|opcode])+length+mask+bytes(value^mask[i%4] for i,value in enumerate(payload)))

    def evaluate(self, expression):
        self.send(json.dumps({"id":1,"method":"Runtime.evaluate","params":{"expression":expression,"awaitPromise":True,"returnByValue":True}}).encode())
        message = b""
        while True:
            header=self.exact(2);opcode=header[0]&15;size=header[1]&127
            if size==126:size=struct.unpack("!H",self.exact(2))[0]
            elif size==127:size=struct.unpack("!Q",self.exact(8))[0]
            if size>4*1024*1024:raise ValueError("Console response too large")
            mask=self.exact(4) if header[1]&128 else None
            data=self.exact(size)
            if mask:data=bytes(value^mask[i%4] for i,value in enumerate(data))
            if opcode==9:self.send(data,10);continue
            if opcode==8:raise OSError("Console closed")
            if opcode not in {0,1}:continue
            message+=data
            if not header[0]&128:continue
            reply=json.loads(message);message=b""
            if reply.get("id")!=1:continue
            result=reply.get("result",{})
            if "error" in reply or "exceptionDetails" in result:raise ValueError("Artwork API call failed")
            return result.get("result",{}).get("value")


def apply(folder, app_id):
    tabs=json.load(urllib.request.urlopen("http://127.0.0.1:8080/json/list",timeout=5))
    targets=[item for item in tabs if item.get("title")=="SharedJSContext" and item.get("url","").startswith("https://steamloopback.host/")]
    if len(targets)!=1:raise ValueError("Steam shared library context unavailable")
    console=Console(targets[0]["webSocketDebuggerUrl"])
    try:
        # Constants verified against this Steam client's library.js:
        # capsule=0, hero=1, transparent logo=2, horizontal header=3.
        images=[{"type":kind,"data":base64.b64encode((folder/name).read_bytes()).decode()} for kind,name in [(0,"portrait.png"),(1,"hero.png"),(2,"logo.png"),(3,"capsule.png")]]
        expression="(async()=>{if(typeof SteamClient?.Apps?.SetCustomArtworkForApp!=='function')return false; const images="+json.dumps(images)+"; for(const image of images)await SteamClient.Apps.SetCustomArtworkForApp("+str(int(app_id))+",image.data,'png',image.type);return true;})()"
        if console.evaluate(expression) is not True:raise ValueError("Artwork API unavailable")
    finally:console.socket.close()
    print("Steam accepted PocketFrame artwork and cache refresh (4 image slots)")


if __name__=="__main__":
    try:apply(Path(__file__).resolve().parent/"artwork",int(sys.argv[1]))
    except (OSError,ValueError,KeyError) as error:raise SystemExit("Artwork refresh unavailable: "+str(error))
