# TFM Secrets Leaker

A utility for obtaining the hardcoded secrets within the Transformice client.

## Building

To build, you should use the [asconfig.json](https://github.com/friedkeenan/tfm-secrets-leaker/blob/main/asconfig.json) file to compile the `TFMSecretsLeaker.swf` file. This can be done with [vscode-as3mxml](https://github.com/BowlerHatLLC/vscode-as3mxml) or [asconfigc](https://www.npmjs.com/package/asconfigc).

If you wish to save yourself the hassle, then there is also a pre-built SWF in the [releases](https://github.com/friedkeenan/tfm-secrets-leaker/releases) of this repo.

## Usage

When running the built SWF file, it will `trace` out the obtained secrets. These can be viewed in something like [ffdec](https://github.com/jindrapetrik/jpexs-decompiler), though a helpful `leak-secrets.py` script is also provided to get the output using the standalone debug projector, used like so:

```
./leak-secrets.py <path/to/TFMSecretsLeaker.swf>
```

```
You can also edit the code for leak-secrets.py at line 14 to use a standalone debugger.
```

Get it here: https://archive.org/details/flashplayer_32_sa_debug_2 and place it on the same directory.

When running the SWF, a window will pop up for a short moment, seem to begin to load the game, and then exit. This is normal.

Unfortunately this is not currently compatible with [Ruffle](https://github.com/ruffle-rs/ruffle/) as it does not currently implement `fscommand("quit")`.

## The Secrets

Transformice's networking protocol utilizes several hardcoded, frequently-changing secrets that are contained within the client. Every five minutes or so, a different main SWF is served for the game, changing most of these hardcoded secrets. Therefore it is required to have a dynamic utility to get these secrets automatically, as they change far too often to just manually obtain.

These secrets include:

- The server address.
    - This is the address of the server that the client connects to. This changes and has changed, but infrequently enough that I think it could feasibly be hardcoded and manually rediscovered when it does change.
- The server ports.
    - The ports of the server that the client can connect to. These to my knowledge have never changed, but theoretically they could, and we are able to report them, and so we do. The client will randomly shuffle these ports and then try to connect to them in sequence, moving on to the next one if the connection is unsuccessful.
- The game version.
    - This is what the game displays in the bottom right corner of the login screen, showing text like `1.740`. The game version that this reports is the `740` component of that, and is sent in the handshake packet that the client sends to the server. This does not change as often as the other secrets do.
- The connection token.
    - This is a random set of characters which is similarly sent in the handshake packet. I believe it used by the server to identify what the expected values of the other secrets should be.
- The auth key.
    - After the client sends the handshake packet to the server, the server then responds with a packet containing an "auth token". This is an integer that is used again when the client sends the login packet. The client XOR's the auth token with the hardcoded "auth key", resulting in a ciphered token, which is then sent to the server in the login packet.
- The packet key sources.
    - Certain packets within Transformice's network protocol are encrypted, for example the login packet. The particular cipher varies per packet, but the keys used are derived from an array of integers called the "packet key sources". These integers are combined with a key name, e.g. "identification", to obtain the actual key used to encrypt a packet.
- The client verification template.
    - Shortly after the handshake sequence has been completed by the client and server, the server will send a packet to the client to make sure that the client is official and otherwise proper (i.e. not a bot). This packet contains a "verification token" (an integer) which the client will then use in its response. The client will respond with a ciphered packet using the XXTEA algorithm with the verification token converted to a string as the name for the key. The (plaintext) packet data will begin with the verification token, and then some semi-random, hardcoded fields, with the verification token thrown in again in the midst of it. This does not seem to change as often as the other secrets do, but it does change.

        What this reports is a hex string representing a string of bytes of the plaintext body of this packet (in Python, something you could use `bytes.fromhex` on). In place of where the verification token should go, `aabbccdd` is used, and should be replaced with the actual packed verification token.

## Other Games

Other Atelier 801 games have very similar structures to Transformice, and so this utility is able to also support the following games:

- Transformice
- Dead Maze
- Bouboum
- Nekodancer
- Fortoresse

Transformice and Dead Maze are the only games that have client verification templates. And so for the others, no client verification template will be traced out.

To obtain the secrets to a particular game, its name should be supplied to the `game` loader parameter. For instance, here is how you would do so using the `leak-secrets.py` script:

```
./leak-secrets.py path/to/TFMSecretsLeaker.swf?game=transformice

./leak-secrets.py path/to/TFMSecretsLeaker.swf?game=deadmaze

./leak-secrets.py path/to/TFMSecretsLeaker.swf?game=bouboum

./leak-secrets.py path/to/TFMSecretsLeaker.swf?game=nekodancer

./leak-secrets.py path/to/TFMSecretsLeaker.swf?game=fortoresse
```

If no `game` parameter is supplied, then the utility will default to leaking Transformice's secrets.
