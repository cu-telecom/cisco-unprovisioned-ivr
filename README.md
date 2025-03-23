# cisco-unprovisioned-ivr

A simple IVR to place on an "unprovisioned" Cisco 2811, VG224 etc so the subscriber hears a network announcement if they try to use their apparatus before it's fully configured. It includes a "hidden" IVR that will read back the circuit ID if any button is pressed - useful if engineers are installing equipment before the backend is available.

It's mostly specific for the CuTEL environment but might prove useful for someone in future.

This work was heavily inspired by joe_z's excellent [Cisco ISR notes](http://www.dms-100.net/telephony/cisco-isr/config-notes/#tclivr)

**NOTE:** I'm no expert on TCL so this might be terrible, but it seems to work

## Configuration

Copy the unprovisioned_announce.tcl script and media files to a Cisco ISR using your preferred method.

Then define the application:
```
application
 service ivr flash:/unprovisioned_announce.tcl
  paramspace english index 1
  paramspace english location flash:/media/en/
```

Then configure a dial-peer to route to the application:
```
dial-peer voice 3001 voip
 service unprovisioned_announce out-bound
 destination-pattern 3001
 session target loopback:rtp
 ```

Optionally, make a line automatically dial the announcement when the handset is lifted:
```
voice-port 0/1/2
 connection plar 3001
```

## Generating audio files

The Cisco devices expect raw 8kHz sampled audio files in either a-law or u-law.

The `generate_au.py ` python script will use AWS Polly to generate files from the list of prompts in `prompt.txt` You'll need an AWS account and some dependencies:

```
pip install boto3 pydub
sudo apt install sox ffmpeg
```

