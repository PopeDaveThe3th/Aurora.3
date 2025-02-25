// Relays don't handle any actual communication. Global NTNet datum does that, relays only tell the datum if it should or shouldn't work.
/obj/machinery/ntnet_relay
	name = "NTNet Quantum Relay"
	desc = "A very complex router and transmitter capable of connecting electronic devices together. Looks fragile."
	use_power = POWER_USE_ACTIVE
	active_power_usage = 20000 //20kW, appropriate for machine that keeps massive cross-Zlevel wireless network operational.
	idle_power_usage = 100
	icon_state = "relay"
	icon = 'icons/obj/machinery/telecomms.dmi'
	anchored = TRUE
	density = TRUE
	var/datum/ntnet/NTNet			// This is mostly for backwards reference and to allow varedit modifications from ingame.
	var/enabled = TRUE				// Set to FALSE if the relay was turned off
	var/dos_failure = FALSE			// Set to TRUE if the relay failed due to (D)DoS attack
	var/list/dos_sources = list()	// Backwards reference for qdel() stuff

	// Denial of Service attack variables
	var/dos_overload = 0		// Amount of DoS "packets" in this relay's buffer
	var/dos_capacity = 500		// Amount of DoS "packets" in buffer required to crash the relay
	var/dos_dissipate = 1		// Amount of DoS "packets" dissipated over time.

	component_types = list(
		/obj/item/stack/cable_coil{amount = 15},
		/obj/item/circuitboard/ntnet_relay
	)

// TODO: Implement more logic here. For now it's only a placeholder.
/obj/machinery/ntnet_relay/operable()
	if(!..(EMPED))
		return FALSE
	if(dos_failure)
		return FALSE
	if(!enabled)
		return FALSE
	return TRUE

/obj/machinery/ntnet_relay/update_icon()
	ClearOverlays()
	if(operable())
		AddOverlays(emissive_appearance(icon, "[icon_state]_lights"))
		AddOverlays("[icon_state]_lights")
	if(dos_failure)
		AddOverlays(emissive_appearance(icon, "[icon_state]_failure"))
		AddOverlays("[icon_state]_failure")
	if(!enabled)
		AddOverlays(emissive_appearance(icon, "[icon_state]_lights_failure"))
		AddOverlays("[icon_state]_lights_failure")
	if(panel_open)
		AddOverlays("[icon_state]_panel")

/obj/machinery/ntnet_relay/process()
	if(operable())
		update_use_power(POWER_USE_ACTIVE)
	else
		update_use_power(POWER_USE_IDLE)

	if(dos_overload)
		dos_overload = max(0, dos_overload - dos_dissipate)

	// If DoS traffic exceeded capacity, crash.
	if((dos_overload > dos_capacity) && !dos_failure)
		dos_failure = TRUE
		update_icon()
		GLOB.ntnet_global.add_log("Quantum relay switched from normal operation mode to overload recovery mode.")
	// If the DoS buffer reaches 0 again, restart.
	if((dos_overload == 0) && dos_failure)
		dos_failure = FALSE
		update_icon()
		GLOB.ntnet_global.add_log("Quantum relay switched from overload recovery mode to normal operation mode.")
	..()

/obj/machinery/ntnet_relay/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "NTNetRelay")
		ui.open()

/obj/machinery/ntnet_relay/ui_data(mob/user)
	var/list/data = list()
	data["enabled"] = enabled
	data["dos_capacity"] = dos_capacity
	data["dos_overload"] = dos_overload
	data["dos_crashed"] = dos_failure

	return data

/obj/machinery/ntnet_relay/ui_act(action, params)
	. = ..()
	if(.)
		return
	if(action=="restart")
		dos_overload = FALSE
		dos_failure = FALSE
		update_icon()
		GLOB.ntnet_global.add_log("Quantum relay manually restarted from overload recovery mode to normal operation mode.")
		. = TRUE
	if(action=="toggle")
		enabled = !enabled
		GLOB.ntnet_global.add_log("Quantum relay manually [enabled ? "enabled" : "disabled"].")
		update_icon()
		. = TRUE

/obj/machinery/ntnet_relay/attack_hand(var/mob/living/user)
	ui_interact(user)

/obj/machinery/ntnet_relay/Initialize()
	. = ..()
	uid = gl_uid
	gl_uid++

	update_icon()

	if(GLOB.ntnet_global)
		GLOB.ntnet_global.relays.Add(src)
		NTNet = GLOB.ntnet_global
		GLOB.ntnet_global.add_log("New quantum relay activated. Current amount of linked relays: [NTNet.relays.len]")

/obj/machinery/ntnet_relay/Destroy()
	if(GLOB.ntnet_global)
		GLOB.ntnet_global.relays.Remove(src)
		GLOB.ntnet_global.add_log("Quantum relay connection severed. Current amount of linked relays: [NTNet.relays.len]")
	return ..()

/obj/machinery/ntnet_relay/attackby(obj/item/attacking_item, mob/user)
	if(attacking_item.isscrewdriver())
		attacking_item.play_tool_sound(get_turf(src), 50)
		panel_open = !panel_open
		to_chat(user, SPAN_NOTICE("You [panel_open ? "open" : "close"] the maintenance hatch."))
		return
	if(attacking_item.iscrowbar())
		if(!panel_open)
			to_chat(user, SPAN_WARNING("Open the maintenance panel first."))
			return
		attacking_item.play_tool_sound(get_turf(src), 50)
		to_chat(user, SPAN_NOTICE("You disassemble \the [src]!"))

		for(var/atom/movable/A in component_parts)
			A.forceMove(get_turf(src))
		new /obj/machinery/constructable_frame/machine_frame(get_turf(src))
		qdel(src)
		return
	..()
