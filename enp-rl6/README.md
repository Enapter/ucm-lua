## First Start

When ENP-RL6 edge processing script uploaded on brand new devices it enables the default configuration:

* All relays are set in **Open** state on boot.
* In case of connection lost the relay status **stays at it was before disconnect**(Respect the state).

## Blueprints Integration

This ENP-RL6 edge processing script procvides following high level functions which are available for Enapter Blueprints:

### set ( { param = "on_boot" | "on_disconnect", value = "Open" | "Close" |  "Respect" } )

Sets the default settings.

**on_boot**

* **Open** - open all relays during boot (default)
* **Close** - close all relays during boot
* **Respect** - respect the previous state during boot

**on_disconnect**

* **Open** - open all relays on connection lost
* **Close** - close all relays on connection lost
* **Rrespect** - respect the previous state on connection lost (default)

### close ( { id = relay_id } )

Closes the relay with id number relay_id.

### open ( { id = relay_id } )

Opens the relay with id number relay_id.

### toggle ( { id = relay_id } )

Invert the relay with id number relay_id.

### impulse ( { id = relay_id, time = mseconds } )

opens the relay with id number relay_id for required number of milliseconds.

## Documentation

Find more information at ENP-RL6 page at [Enapter Developer Center](https://developers.enapter.com/docs/reference/ucm/rl6)

## Disclaimer	

Edge processing scripting should be used as a convenience feature for basic non-realtime automations and not for life-sustaining or safety-critical use cases. Normal operation depend on working internet, Wi-Fi, and Enapter Cloud. Enapter is not responsible for any harms or losses incurred as a result of any failed automation.