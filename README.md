# TFM Secrets Leaker

A utility for obtaining the hardcoded secrets within the Transformice client.

## Building

To build, you should use the [asconfig.json](https://github.com/friedkeenan/tfm-secrets-leaker/blob/main/asconfig.json) file to compile the `TFMSecretsLeaker.swf` file. This can be done with [vscode-as3mxml](https://github.com/BowlerHatLLC/vscode-as3mxml) or [asconfigc](https://www.npmjs.com/package/asconfigc).

If you wish to save yourself the hassle, then there is also a pre-built SWF in the [releases](https://github.com/friedkeenan/tfm-secrets-leaker/releases) of this repo.

## Usage

When running the built SWF file, it will `trace` out the obtained secrets. These can be viewed in something like [ffdec](https://github.com/jindrapetrik/jpexs-decompiler), though a helpful `leak-secrets.py` script is also provided to get the output using the standalone debug projector, used like so:

```
./leak_secrets.py <path/to/TFMSecretsLeaker.swf>
```

When running the SWF, a window will pop up for a short moment, seem to begin to load the game, and then exit. This is normal.

Unfortunately this is not currently compatible with [Ruffle](https://github.com/ruffle-rs/ruffle/) as it does not currently support Transformice.

## The Secrets

Transformice's networking protocol utilizes several hardcoded, frequently-changing secrets that are contained within the client. Every five minutes or so, a different main SWF is served for the game, changing most of these hardcoded secrets. Therefore it is required to have a dynamic utility to get these secrets automatically, as they change far too often to just manually obtain.

These secrets include:

- The game version.
    - This is what the game displays in the bottom right corner of the login screen, showing text like `1.740`. The game version that this reports is the `740` component of that, and is sent in the handshake packet that the client sends to the server. This does not change as often as the other secrets do.
- The connection token.
    - This is a random set of characters which is similarly sent in the handshake packet. I believe it used by the server to identify what the expected values of the other secrets should be.
- The auth key.
    - After the client sends the handshake packet to the server, the server then responds with a packet containing an "auth token". This is an integer that is used again when the client sends the login packet. The client XOR's the auth token with the hardcoded "auth key", resulting in a ciphered token, which is then sent to the server in the login packet.
- The packet key sources.
    - Certain packets within Transformice's network protocol are encrypted, for example the login packet. The particular cipher varies per packet, but the keys used are derived from an array of integers called the "packet key sources". These integers are combined with a key name, a string (e.g. "identification"), to obtain the actual key used to encrypt a packet.
